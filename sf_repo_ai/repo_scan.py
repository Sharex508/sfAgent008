from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
import re
import sqlite3
import xml.etree.ElementTree as ET

from sf_repo_ai.config import AppConfig
from sf_repo_ai.db import (
    all_component_paths,
    clear_rows_for_path,
    connect,
    delete_component_path,
    get_component_hash,
    get_meta_file_state,
    init_schema,
    upsert_component,
)
from sf_repo_ai.meta.catalog import build_metadata_catalog
from sf_repo_ai.parsers.parse_apex import parse_apex_file
from sf_repo_ai.parsers.parse_approval_processes import parse_approval_process_meta
from sf_repo_ai.parsers.parse_flexipages import parse_flexipage_file
from sf_repo_ai.parsers.parse_flows import parse_flow_meta
from sf_repo_ai.parsers.parse_layouts import parse_layout_file
from sf_repo_ai.parsers.parse_objects import parse_field_meta, parse_object_meta
from sf_repo_ai.parsers.parse_permissions import parse_permission_file
from sf_repo_ai.parsers.parse_sharing_rules import parse_sharing_rules_meta
from sf_repo_ai.parsers.parse_validation_rules import parse_validation_rule_meta
from sf_repo_ai.rag.chroma_store import rebuild_store
from sf_repo_ai.util import read_text, rel_path, sha1_file, xml_local_name


FOLDER_TYPE_HINTS = {
    "approvalProcesses": "ApprovalProcess",
    "assignmentRules": "AssignmentRule",
    "autoResponseRules": "AutoResponseRule",
    "classes": "ApexClass",
    "customMetadata": "CustomMetadata",
    "flows": "Flow",
    "flexipages": "FlexiPage",
    "layouts": "Layout",
    "objects": "CustomObject",
    "permissionsets": "PermissionSet",
    "profiles": "Profile",
    "sharingRules": "SharingRules",
    "triggers": "ApexTrigger",
}

FIELD_REF_RE = re.compile(r"\b([A-Za-z_]\w*)\.([A-Za-z_]\w*__c|[A-Za-z_]\w*)\b")
NC_RE = re.compile(r"\bcallout:[A-Za-z0-9_]+\b")
URL_RE = re.compile(r"https?://[^\s'\"<]+")
LABEL_RE = re.compile(r"\bLabel\.([A-Za-z0-9_]+)\b")
OBJECT_TAG_RE = re.compile(
    r"<(?:\w+:)?(?:object|tableEnumOrId|sObject|sObjectType)>\s*([A-Za-z_][A-Za-z0-9_]*)\s*</",
    re.IGNORECASE,
)
RECORDTYPE_RE = re.compile(r"\bRecordType\.([A-Za-z0-9_]+)\b")
WORD_TOKEN_RE = re.compile(r"\b[A-Za-z][A-Za-z0-9_]{2,}\b")


@dataclass(slots=True)
class ScanStats:
    total_files: int = 0
    indexed_files: int = 0
    skipped_files: int = 0
    deleted_files: int = 0
    errors: int = 0


def _insert_reference(conn: sqlite3.Connection, row: dict) -> None:
    conn.execute(
        """
        INSERT INTO "references"(
            ref_type, ref_key, src_type, src_name, src_path,
            line_start, line_end, snippet, confidence
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            row.get("ref_type"),
            row.get("ref_key"),
            row.get("src_type"),
            row.get("src_name"),
            row.get("src_path"),
            row.get("line_start"),
            row.get("line_end"),
            row.get("snippet"),
            row.get("confidence"),
        ),
    )


def _folder_from_rel(rel: str, sfdx_root: str) -> str:
    root = sfdx_root.strip("/").rstrip("/")
    prefix = root + "/"
    tail = rel[len(prefix) :] if rel.startswith(prefix) else rel
    return tail.split("/", 1)[0] if "/" in tail else tail


def _api_name(file_name: str, path: Path) -> str:
    if file_name.endswith("-meta.xml"):
        base = file_name[: -len("-meta.xml")]
    elif file_name.endswith(".xml"):
        base = file_name[: -len(".xml")]
    else:
        base = path.stem

    parts = base.split(".")
    if len(parts) >= 2 and parts[-1] in {
        "approvalProcess",
        "field",
        "object",
        "validationRule",
        "flow",
        "layout",
        "flexipage",
        "permissionset",
        "profile",
    }:
        return ".".join(parts[:-1]) or base
    return base


def _quick_xml_meta(path: Path) -> tuple[str | None, int | None, str | None, int]:
    if path.suffix.lower() != ".xml":
        return None, None, None, 0
    try:
        tree = ET.parse(path)
        root = tree.getroot()
    except Exception:
        return None, None, None, 1

    xml_root = xml_local_name(root.tag)
    active: int | None = None
    sobject: str | None = None

    for node in root.iter():
        local = xml_local_name(node.tag)
        text = (node.text or "").strip()
        if not text:
            continue
        local_low = local.lower()
        if active is None and local_low == "active":
            low = text.lower()
            if low == "true":
                active = 1
            elif low == "false":
                active = 0
        if sobject is None and local in {"object", "tableEnumOrId", "sObject", "sObjectType"}:
            sobject = text
        if active is not None and sobject:
            break

    return xml_root, active, sobject, 0


def _index_meta_file(
    conn: sqlite3.Connection,
    *,
    path: Path,
    rel: str,
    sha1: str,
    sfdx_root: str,
    file_size: int | None = None,
    mtime_ns: int | None = None,
) -> None:
    folder = _folder_from_rel(rel, sfdx_root)
    xml_root, active, sobject, xml_parse_error = _quick_xml_meta(path)
    type_guess = FOLDER_TYPE_HINTS.get(folder) or xml_root or folder or "Unknown"
    row = {
        "path": rel,
        "folder": folder,
        "file_name": path.name,
        "extension": path.suffix.lower(),
        "type_guess": type_guess,
        "api_name": _api_name(path.name, path),
        "xml_root": xml_root,
        "active": active,
        "sobject": sobject,
        "xml_parse_error": xml_parse_error,
        "file_size": file_size,
        "mtime_ns": mtime_ns,
        "hash": sha1,
        "indexed_at": datetime.now(timezone.utc).isoformat(),
    }
    conn.execute(
        """
        INSERT INTO meta_files(
            path, folder, file_name, extension, type_guess, api_name,
            xml_root, active, sobject, xml_parse_error, file_size, mtime_ns, hash, indexed_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(path) DO UPDATE SET
          folder=excluded.folder,
          file_name=excluded.file_name,
          extension=excluded.extension,
          type_guess=excluded.type_guess,
          api_name=excluded.api_name,
          xml_root=excluded.xml_root,
          active=excluded.active,
          sobject=excluded.sobject,
          xml_parse_error=excluded.xml_parse_error,
          file_size=excluded.file_size,
          mtime_ns=excluded.mtime_ns,
          hash=excluded.hash,
          indexed_at=excluded.indexed_at
        """,
        (
            row["path"],
            row["folder"],
            row["file_name"],
            row["extension"],
            row["type_guess"],
            row["api_name"],
            row["xml_root"],
            row["active"],
            row["sobject"],
            row["xml_parse_error"],
            row["file_size"],
            row["mtime_ns"],
            row["hash"],
            row["indexed_at"],
        ),
    )


def _extract_meta_refs_for_line(
    line: str,
    *,
    known_flows: dict[str, str],
    known_classes: dict[str, str],
    known_objects: dict[str, str],
) -> list[tuple[str, str, float]]:
    refs: list[tuple[str, str, float]] = []

    for m in FIELD_REF_RE.finditer(line):
        refs.append(("FIELD", f"{m.group(1)}.{m.group(2)}", 0.95))

    for m in NC_RE.finditer(line):
        refs.append(("ENDPOINT", m.group(0), 0.95))

    for m in URL_RE.finditer(line):
        refs.append(("ENDPOINT", m.group(0), 0.90))

    for m in LABEL_RE.finditer(line):
        refs.append(("LABEL", f"Label.{m.group(1)}", 0.90))

    for m in OBJECT_TAG_RE.finditer(line):
        refs.append(("OBJECT", m.group(1), 0.90))

    for m in RECORDTYPE_RE.finditer(line):
        refs.append(("RECORDTYPE", m.group(1), 0.80))

    for token in WORD_TOKEN_RE.findall(line):
        low = token.lower()
        if low in known_flows:
            refs.append(("FLOW", known_flows[low], 0.65))
        if low in known_classes:
            refs.append(("CLASS", known_classes[low], 0.65))
        if low in known_objects:
            refs.append(("OBJECT", known_objects[low], 0.60))

    dedup: dict[tuple[str, str], tuple[str, str, float]] = {}
    for kind, value, conf in refs:
        key = (kind, value)
        cur = dedup.get(key)
        if cur is None or conf > cur[2]:
            dedup[key] = (kind, value, conf)
    return list(dedup.values())


def _rebuild_approval_processes(
    conn: sqlite3.Connection,
    *,
    repo_root: Path,
    files: list[Path],
) -> int:
    conn.execute("DELETE FROM approval_processes")
    count = 0
    for file_path in files:
        if not file_path.name.endswith(".approvalProcess-meta.xml"):
            continue
        rel = rel_path(file_path, repo_root)
        row = parse_approval_process_meta(file_path, rel)
        conn.execute(
            """
            INSERT INTO approval_processes(name, object_name, active, path)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(path) DO UPDATE SET
              name=excluded.name,
              object_name=excluded.object_name,
              active=excluded.active
            """,
            (row["name"], row["object_name"], row["active"], row["path"]),
        )
        count += 1
    return count


def _rebuild_sharing_rules(
    conn: sqlite3.Connection,
    *,
    repo_root: Path,
    files: list[Path],
) -> int:
    conn.execute("DELETE FROM sharing_rules")
    conn.execute("DELETE FROM \"references\" WHERE src_type = 'SHARING_RULE'")
    count = 0
    for file_path in files:
        if not file_path.name.endswith(".sharingRules-meta.xml"):
            continue
        rel = rel_path(file_path, repo_root)
        data = parse_sharing_rules_meta(file_path, rel)
        for row in data["rows"]:
            conn.execute(
                """
                INSERT OR REPLACE INTO sharing_rules(
                  name, object_name, rule_type, access_level, active, path, extra_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    row["name"],
                    row["object_name"],
                    row["rule_type"],
                    row["access_level"],
                    row["active"],
                    row["path"],
                    row["extra_json"],
                ),
            )
        for ref in data["references"]:
            _insert_reference(conn, ref)
        count += len(data["rows"])
    return count


def _index_meta_refs(
    conn: sqlite3.Connection,
    *,
    repo_root: Path,
    files: list[Path],
    sfdx_root: str,
) -> int:
    flow_rows = conn.execute("SELECT flow_name FROM flows").fetchall()
    class_rows = conn.execute("SELECT DISTINCT name FROM components WHERE type='APEX'").fetchall()
    object_rows = conn.execute("SELECT object_name AS val FROM objects").fetchall()
    object_rows_2 = conn.execute("SELECT DISTINCT object_name AS val FROM fields").fetchall()
    object_rows_3 = conn.execute(
        "SELECT DISTINCT trigger_object AS val FROM flows WHERE trigger_object IS NOT NULL AND trigger_object <> ''"
    ).fetchall()
    object_rows_4 = conn.execute(
        "SELECT DISTINCT object_name AS val FROM approval_processes WHERE object_name IS NOT NULL AND object_name <> ''"
    ).fetchall()

    known_flows = {r["flow_name"].lower(): r["flow_name"] for r in flow_rows}
    known_classes = {r["name"].lower(): r["name"] for r in class_rows}
    known_objects: dict[str, str] = {}
    for r in object_rows + object_rows_2 + object_rows_3 + object_rows_4:
        value = (r["val"] or "").strip()
        if not value:
            continue
        known_objects[value.lower()] = value

    total = 0
    for file_path in files:
        try:
            if file_path.stat().st_size > 5 * 1024 * 1024:
                continue
        except Exception:
            continue
        rel = rel_path(file_path, repo_root)
        conn.execute("DELETE FROM meta_refs WHERE src_path = ?", (rel,))
        folder = _folder_from_rel(rel, sfdx_root)
        text = read_text(file_path)
        if not text:
            continue
        rows_to_insert: list[tuple[str, str, str, str, int, str, float]] = []
        for line_no, line in enumerate(text.splitlines(), start=1):
            refs = _extract_meta_refs_for_line(
                line,
                known_flows=known_flows,
                known_classes=known_classes,
                known_objects=known_objects,
            )
            snippet = line.strip()
            if len(snippet) > 240:
                snippet = snippet[:237] + "..."
            for kind, value, conf in refs:
                rows_to_insert.append((kind, value, rel, folder, line_no, snippet, conf))

        if rows_to_insert:
            conn.executemany(
                """
                INSERT INTO meta_refs(ref_kind, ref_value, src_path, src_folder, line_no, snippet, confidence)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                rows_to_insert,
            )
            total += len(rows_to_insert)

    return total


def _index_file(
    conn: sqlite3.Connection,
    path: Path,
    rel: str,
    sha1: str,
    *,
    sfdx_root: str,
    file_size: int | None = None,
    mtime_ns: int | None = None,
) -> tuple[str, str]:
    name = path.stem
    _index_meta_file(
        conn,
        path=path,
        rel=rel,
        sha1=sha1,
        sfdx_root=sfdx_root,
        file_size=file_size,
        mtime_ns=mtime_ns,
    )

    if path.name.endswith(".object-meta.xml"):
        obj_row, field_rows = parse_object_meta(path, rel)
        conn.execute(
            "INSERT OR REPLACE INTO objects(object_name, path) VALUES (?, ?)",
            (obj_row["object_name"], obj_row["path"]),
        )
        for f in field_rows:
            conn.execute(
                """
                INSERT INTO fields(object_name, field_api, full_name, data_type, formula, reference_to, path)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(full_name) DO UPDATE SET
                  object_name=excluded.object_name,
                  field_api=excluded.field_api,
                  data_type=excluded.data_type,
                  formula=excluded.formula,
                  reference_to=excluded.reference_to,
                  path=excluded.path
                """,
                (
                    f["object_name"],
                    f["field_api"],
                    f["full_name"],
                    f["data_type"],
                    f["formula"],
                    f["reference_to"],
                    f["path"],
                ),
            )
        upsert_component(
            conn,
            comp_type="OBJECT",
            name=obj_row["object_name"],
            path=rel,
            sha1=sha1,
        )
        return "OBJECT", obj_row["object_name"]

    if path.name.endswith(".field-meta.xml"):
        f = parse_field_meta(path, rel)
        if f:
            conn.execute(
                """
                INSERT INTO fields(object_name, field_api, full_name, data_type, formula, reference_to, path)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(full_name) DO UPDATE SET
                  object_name=excluded.object_name,
                  field_api=excluded.field_api,
                  data_type=excluded.data_type,
                  formula=excluded.formula,
                  reference_to=excluded.reference_to,
                  path=excluded.path
                """,
                (
                    f["object_name"],
                    f["field_api"],
                    f["full_name"],
                    f["data_type"],
                    f["formula"],
                    f["reference_to"],
                    f["path"],
                ),
            )
            upsert_component(conn, comp_type="FIELD", name=f["full_name"], path=rel, sha1=sha1)
            return "FIELD", f["full_name"]
        upsert_component(conn, comp_type="FIELD", name=name, path=rel, sha1=sha1)
        return "FIELD", name

    if path.name.endswith(".validationRule-meta.xml"):
        vr, refs = parse_validation_rule_meta(path, rel)
        conn.execute(
            """
            INSERT INTO validation_rules(object_name, rule_name, active, error_condition, error_message, path)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                vr["object_name"],
                vr["rule_name"],
                vr["active"],
                vr["error_condition"],
                vr["error_message"],
                vr["path"],
            ),
        )
        for r in refs:
            _insert_reference(conn, r)
        upsert_component(conn, comp_type="VR", name=vr["rule_name"], path=rel, sha1=sha1)
        return "VR", vr["rule_name"]

    if path.name.endswith(".flow-meta.xml"):
        flow_data = parse_flow_meta(path, rel)
        flow = flow_data["flow"]
        conn.execute(
            """
            INSERT OR REPLACE INTO flows(flow_name, status, trigger_object, trigger_type, path)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                flow["flow_name"],
                flow["status"],
                flow["trigger_object"],
                flow["trigger_type"],
                flow["path"],
            ),
        )
        for row in flow_data["reads"]:
            conn.execute(
                "INSERT INTO flow_field_reads(flow_name, full_field_name, path, confidence) VALUES (?, ?, ?, ?)",
                (row["flow_name"], row["full_field_name"], row["path"], row["confidence"]),
            )
        for row in flow_data["writes"]:
            conn.execute(
                "INSERT INTO flow_field_writes(flow_name, full_field_name, path, confidence) VALUES (?, ?, ?, ?)",
                (row["flow_name"], row["full_field_name"], row["path"], row["confidence"]),
            )
        for row in flow_data.get("flow_vars", []):
            conn.execute(
                """
                INSERT INTO flow_vars(flow_name, var_name, data_type, is_collection, sobject_type, path)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    row["flow_name"],
                    row["var_name"],
                    row.get("data_type"),
                    row.get("is_collection"),
                    row.get("sobject_type"),
                    row["path"],
                ),
            )
        for row in flow_data.get("flow_assignments", []):
            conn.execute(
                """
                INSERT INTO flow_assignments(flow_name, assignment_name, lhs, rhs, path)
                VALUES (?, ?, ?, ?, ?)
                """,
                (
                    row["flow_name"],
                    row["assignment_name"],
                    row["lhs"],
                    row["rhs"],
                    row["path"],
                ),
            )
        for row in flow_data.get("flow_dml", []):
            conn.execute(
                """
                INSERT INTO flow_dml(flow_name, element_name, dml_type, record_var, sobject_type, path)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    row["flow_name"],
                    row["element_name"],
                    row["dml_type"],
                    row["record_var"],
                    row.get("sobject_type"),
                    row["path"],
                ),
            )
        for row in flow_data.get("flow_true_writes", []):
            conn.execute(
                """
                INSERT INTO flow_true_writes(
                  flow_name, sobject_type, field_full_name, write_kind, confidence,
                  evidence_path, evidence_snippet, source_element
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    row["flow_name"],
                    row.get("sobject_type"),
                    row.get("field_full_name"),
                    row["write_kind"],
                    row["confidence"],
                    row["evidence_path"],
                    row.get("evidence_snippet"),
                    row.get("source_element"),
                ),
            )
        for r in flow_data["references"]:
            _insert_reference(conn, r)
        upsert_component(conn, comp_type="FLOW", name=flow["flow_name"], path=rel, sha1=sha1)
        return "FLOW", flow["flow_name"]

    if path.suffix == ".cls":
        data = parse_apex_file(path, rel, "APEX")
        for ep in data["endpoints"]:
            conn.execute(
                """
                INSERT INTO apex_endpoints(class_name, path, endpoint_value, endpoint_type, line_start, line_end)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    ep["class_name"],
                    ep["path"],
                    ep["endpoint_value"],
                    ep["endpoint_type"],
                    ep["line_start"],
                    ep["line_end"],
                ),
            )
        for r in data["references"]:
            _insert_reference(conn, r)
        stats = data.get("class_stats")
        if stats:
            conn.execute(
                """
                INSERT INTO apex_class_stats(
                  class_name, loc, soql_count, dml_count, has_dynamic_soql, has_callout, path
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(class_name) DO UPDATE SET
                  loc=excluded.loc,
                  soql_count=excluded.soql_count,
                  dml_count=excluded.dml_count,
                  has_dynamic_soql=excluded.has_dynamic_soql,
                  has_callout=excluded.has_callout,
                  path=excluded.path
                """,
                (
                    stats["class_name"],
                    stats["loc"],
                    stats["soql_count"],
                    stats["dml_count"],
                    stats["has_dynamic_soql"],
                    stats["has_callout"],
                    stats["path"],
                ),
            )
        for row in data.get("apex_rw", []):
            conn.execute(
                """
                INSERT INTO apex_rw(class_name, sobject_type, field_full_name, rw, confidence, path, evidence_snippet)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    row["class_name"],
                    row.get("sobject_type"),
                    row.get("field_full_name"),
                    row["rw"],
                    row["confidence"],
                    row["path"],
                    row.get("evidence_snippet"),
                ),
            )
        upsert_component(conn, comp_type="APEX", name=data["class_name"], path=rel, sha1=sha1)
        return "APEX", data["class_name"]

    if path.suffix == ".trigger":
        data = parse_apex_file(path, rel, "TRIGGER")
        for ep in data["endpoints"]:
            conn.execute(
                """
                INSERT INTO apex_endpoints(class_name, path, endpoint_value, endpoint_type, line_start, line_end)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    ep["class_name"],
                    ep["path"],
                    ep["endpoint_value"],
                    ep["endpoint_type"],
                    ep["line_start"],
                    ep["line_end"],
                ),
            )
        for r in data["references"]:
            _insert_reference(conn, r)
        upsert_component(conn, comp_type="TRIGGER", name=data["class_name"], path=rel, sha1=sha1)
        return "TRIGGER", data["class_name"]

    if path.name.endswith(".layout-meta.xml"):
        refs = parse_layout_file(path, rel)
        layout_name = path.name.replace(".layout-meta.xml", "")
        for r in refs:
            _insert_reference(conn, r)
        upsert_component(conn, comp_type="LAYOUT", name=layout_name, path=rel, sha1=sha1)
        return "LAYOUT", layout_name

    if path.name.endswith(".flexipage-meta.xml"):
        refs = parse_flexipage_file(path, rel)
        page_name = path.name.replace(".flexipage-meta.xml", "")
        for r in refs:
            _insert_reference(conn, r)
        upsert_component(conn, comp_type="FLEXIPAGE", name=page_name, path=rel, sha1=sha1)
        return "FLEXIPAGE", page_name

    if path.name.endswith(".permissionset-meta.xml") or path.name.endswith(".profile-meta.xml"):
        data = parse_permission_file(path, rel)
        for r in data["references"]:
            _insert_reference(conn, r)
        upsert_component(
            conn,
            comp_type=data["component_type"],
            name=data["component_name"],
            path=rel,
            sha1=sha1,
        )
        return data["component_type"], data["component_name"]

    if path.name.endswith(".approvalProcess-meta.xml"):
        row = parse_approval_process_meta(path, rel)
        conn.execute(
            """
            INSERT INTO approval_processes(name, object_name, active, path)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(path) DO UPDATE SET
              name=excluded.name,
              object_name=excluded.object_name,
              active=excluded.active
            """,
            (row["name"], row["object_name"], row["active"], row["path"]),
        )
        upsert_component(conn, comp_type="OTHER", name=row["name"], path=rel, sha1=sha1)
        return "OTHER", row["name"]

    if path.name.endswith(".sharingRules-meta.xml"):
        data = parse_sharing_rules_meta(path, rel)
        for row in data["rows"]:
            conn.execute(
                """
                INSERT OR REPLACE INTO sharing_rules(
                  name, object_name, rule_type, access_level, active, path, extra_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    row["name"],
                    row["object_name"],
                    row["rule_type"],
                    row["access_level"],
                    row["active"],
                    row["path"],
                    row["extra_json"],
                ),
            )
        for ref in data["references"]:
            _insert_reference(conn, ref)
        upsert_component(conn, comp_type="OTHER", name=data["object_name"], path=rel, sha1=sha1)
        return "OTHER", data["object_name"]

    upsert_component(conn, comp_type="OTHER", name=name, path=rel, sha1=sha1)
    return "OTHER", name


def _scan_paths(sfdx_base: Path) -> list[Path]:
    files = [p.resolve() for p in sfdx_base.rglob("*") if p.is_file()]
    return sorted(set(files))


def index_repository(cfg: AppConfig, *, project_root: Path | None = None, rebuild_rag: bool = False) -> ScanStats:
    project_root = project_root or Path.cwd()
    repo_root = cfg.resolve_repo_root(project_root)
    sqlite_path = cfg.resolve_sqlite_path(project_root)
    sfdx_base = repo_root / cfg.sfdx_root

    if not sfdx_base.exists():
        raise FileNotFoundError(f"SFDX root not found: {sfdx_base}")

    conn = connect(sqlite_path)
    init_schema(conn)

    stats = ScanStats()
    files = _scan_paths(sfdx_base)
    stats.total_files = len(files)
    changed_files: list[Path] = []

    # Backfill for newly added derived tables even when hashes are unchanged.
    flow_backfill_needed = (
        int(conn.execute("SELECT COUNT(*) AS c FROM flow_true_writes").fetchone()["c"]) == 0
        or int(conn.execute("SELECT COUNT(*) AS c FROM flow_vars").fetchone()["c"]) == 0
        or int(conn.execute("SELECT COUNT(*) AS c FROM flow_dml").fetchone()["c"]) == 0
    )
    apex_backfill_needed = (
        int(conn.execute("SELECT COUNT(*) AS c FROM apex_class_stats").fetchone()["c"]) == 0
        or int(conn.execute("SELECT COUNT(*) AS c FROM apex_rw").fetchone()["c"]) == 0
    )

    seen_paths: set[str] = set()

    for idx, file_path in enumerate(files, start=1):
        rel = rel_path(file_path, repo_root)
        seen_paths.add(rel)
        stat = file_path.stat()
        file_size = int(stat.st_size)
        mtime_ns = int(getattr(stat, "st_mtime_ns", int(stat.st_mtime * 1_000_000_000)))
        force_reindex = (
            (flow_backfill_needed and file_path.name.endswith(".flow-meta.xml"))
            or (apex_backfill_needed and file_path.suffix == ".cls")
        )

        meta_state = get_meta_file_state(conn, rel)
        if (
            meta_state
            and not force_reindex
            and meta_state["hash"]
            and meta_state["file_size"] == file_size
            and meta_state["mtime_ns"] == mtime_ns
        ):
            stats.skipped_files += 1
            continue

        file_hash = sha1_file(file_path)
        old_hash = get_component_hash(conn, rel)
        if old_hash == file_hash and not force_reindex:
            _index_meta_file(
                conn,
                path=file_path,
                rel=rel,
                sha1=file_hash,
                sfdx_root=cfg.sfdx_root,
                file_size=file_size,
                mtime_ns=mtime_ns,
            )
            stats.skipped_files += 1
            continue

        changed_files.append(file_path)
        clear_rows_for_path(conn, rel)
        try:
            _index_file(
                conn,
                file_path,
                rel,
                file_hash,
                sfdx_root=cfg.sfdx_root,
                file_size=file_size,
                mtime_ns=mtime_ns,
            )
            stats.indexed_files += 1
        except Exception:
            stats.errors += 1

        if idx % 200 == 0:
            conn.commit()
            print(
                f"progress: {idx}/{stats.total_files} files | indexed={stats.indexed_files} "
                f"skipped={stats.skipped_files} errors={stats.errors}"
            )

    existing = all_component_paths(conn)
    stale = existing - seen_paths
    for p in stale:
        delete_component_path(conn, p)
        stats.deleted_files += 1

    approval_count = _rebuild_approval_processes(conn, repo_root=repo_root, files=files)
    sharing_rule_count = _rebuild_sharing_rules(conn, repo_root=repo_root, files=files)
    existing_meta_refs = int(conn.execute("SELECT COUNT(*) AS c FROM meta_refs").fetchone()["c"])
    meta_ref_files = files if existing_meta_refs == 0 else changed_files
    meta_ref_count = _index_meta_refs(conn, repo_root=repo_root, files=meta_ref_files, sfdx_root=cfg.sfdx_root)
    catalog_count = build_metadata_catalog(conn)
    print(
        f"meta: approval_processes={approval_count} sharing_rules={sharing_rule_count} "
        f"meta_refs_indexed={meta_ref_count} metadata_catalog={catalog_count} "
        f"meta_ref_files={len(meta_ref_files)}"
    )

    conn.commit()

    if cfg.rag.enabled and rebuild_rag:
        try:
            chroma_dir = cfg.resolve_chroma_dir(project_root)
            count = rebuild_store(
                conn=conn,
                repo_root=repo_root,
                chroma_dir=chroma_dir,
                ollama_base_url=cfg.ollama.base_url,
                embed_model=cfg.ollama.embed_model,
            )
            print(f"rag: indexed {count} chunks")
        except Exception as exc:
            print(f"rag: skipped ({exc})")

    conn.close()
    return stats
