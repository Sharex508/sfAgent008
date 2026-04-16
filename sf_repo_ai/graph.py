from __future__ import annotations

import json
import re
import sqlite3
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from sf_repo_ai.util import read_text


@dataclass(slots=True)
class GraphBuildStats:
    nodes: int = 0
    edges: int = 0
    flow_edges: int = 0
    trigger_edges: int = 0
    apex_edges: int = 0
    metadata_edges: int = 0


def _line_number(text: str, offset: int) -> int:
    if offset <= 0:
        return 1
    return text.count("\n", 0, offset) + 1


def _line_span(text: str, start: int, end: int) -> tuple[int, int]:
    return _line_number(text, start), _line_number(text, end)


def _snippet(text: str, start: int, end: int, width: int = 200) -> str:
    lo = max(0, start - width // 2)
    hi = min(len(text), end + width // 2)
    out = text[lo:hi].replace("\n", " ").strip()
    if len(out) > 240:
        out = out[:237] + "..."
    return out


def _snippet_line(text: str, line_no: int) -> str:
    lines = text.splitlines()
    if line_no < 1 or line_no > len(lines):
        return ""
    s = lines[line_no - 1].strip()
    if len(s) > 240:
        return s[:237] + "..."
    return s


def clear_graph(conn: sqlite3.Connection) -> None:
    conn.execute("DELETE FROM graph_edges")
    conn.execute("DELETE FROM graph_nodes")


def get_or_create_node(
    conn: sqlite3.Connection,
    node_type: str,
    name: str,
    path: str | None = None,
    extra: dict | None = None,
) -> int:
    row = conn.execute(
        "SELECT node_id FROM graph_nodes WHERE node_type=? AND name=?",
        (node_type, name),
    ).fetchone()
    if row:
        node_id = row["node_id"]
        if path is not None or extra is not None:
            conn.execute(
                """
                UPDATE graph_nodes
                SET path = COALESCE(?, path),
                    extra_json = COALESCE(?, extra_json)
                WHERE node_id = ?
                """,
                (path, json.dumps(extra) if extra is not None else None, node_id),
            )
        return node_id

    conn.execute(
        "INSERT INTO graph_nodes(node_type, name, path, extra_json) VALUES (?, ?, ?, ?)",
        (node_type, name, path, json.dumps(extra) if extra is not None else None),
    )
    return int(conn.execute("SELECT last_insert_rowid()").fetchone()[0])


def _add_edge(
    conn: sqlite3.Connection,
    *,
    src_node_id: int,
    dst_node_id: int,
    edge_type: str,
    confidence: float,
    evidence_path: str | None = None,
    evidence_line_start: int | None = None,
    evidence_line_end: int | None = None,
    evidence_snippet: str | None = None,
    extra: dict | None = None,
) -> int:
    cur = conn.execute(
        """
        INSERT OR IGNORE INTO graph_edges(
            src_node_id, dst_node_id, edge_type, confidence,
            evidence_path, evidence_line_start, evidence_line_end,
            evidence_snippet, extra_json
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            src_node_id,
            dst_node_id,
            edge_type,
            confidence,
            evidence_path,
            evidence_line_start,
            evidence_line_end,
            evidence_snippet,
            json.dumps(extra) if extra is not None else None,
        ),
    )
    return 1 if cur.rowcount > 0 else 0


_GENERIC_SRC_FOLDERS: dict[str, str] = {
    "applications": "APPLICATION",
    "approvalProcesses": "APPROVAL_PROCESS",
    "aura": "AURA",
    "components": "VISUALFORCE_COMPONENT",
    "customMetadata": "CUSTOM_METADATA",
    "flexipages": "FLEXIPAGE",
    "layouts": "LAYOUT",
    "lwc": "LWC",
    "pages": "VISUALFORCE_PAGE",
    "permissionsets": "PERMISSION_SET",
    "profiles": "PROFILE",
    "quickActions": "QUICK_ACTION",
    "sharingRules": "SHARING_RULE",
    "tabs": "TAB",
    "workflows": "WORKFLOW",
}

_META_SRC_TYPES: dict[str, str] = {
    "ApprovalProcess": "APPROVAL_PROCESS",
    "AuraDefinitionBundle": "AURA",
    "CustomApplication": "APPLICATION",
    "CustomMetadata": "CUSTOM_METADATA",
    "CustomTab": "TAB",
    "FlexiPage": "FLEXIPAGE",
    "Layout": "LAYOUT",
    "LightningComponentBundle": "LWC",
    "PermissionSet": "PERMISSION_SET",
    "Profile": "PROFILE",
    "QuickAction": "QUICK_ACTION",
    "SharingRules": "SHARING_RULE",
    "VisualforceComponent": "VISUALFORCE_COMPONENT",
    "VisualforcePage": "VISUALFORCE_PAGE",
    "Workflow": "WORKFLOW",
}

_REF_DST_TYPES: dict[str, str] = {
    "CLASS": "APEX_CLASS",
    "ENDPOINT": "ENDPOINT",
    "FIELD": "FIELD",
    "FLOW": "FLOW",
    "LABEL": "LABEL",
    "OBJECT": "OBJECT",
    "RECORDTYPE": "RECORDTYPE",
}

_REF_EDGE_SUFFIXES: dict[str, str] = {
    "CLASS": "CALLS_CLASS",
    "ENDPOINT": "CALLS_ENDPOINT",
    "FIELD": "USES_FIELD",
    "FLOW": "REFERENCES_FLOW",
    "LABEL": "USES_LABEL",
    "OBJECT": "USES_OBJECT",
    "RECORDTYPE": "USES_RECORDTYPE",
}

_IGNORED_REF_VALUES = {"soap.sforce", "http://soap.sforce.com/2006/04/metadata", "https://soap.sforce.com/2006/04/metadata"}


def _row_get(row: sqlite3.Row | dict[str, Any], key: str) -> Any:
    if isinstance(row, dict):
        return row.get(key)
    return row[key]


def _bundle_name_for_path(path: str, folder: str) -> str | None:
    parts = Path(path).parts
    try:
        idx = parts.index(folder)
    except ValueError:
        return None
    if idx + 1 >= len(parts):
        return None
    return parts[idx + 1]


def _node_name_from_meta_row(row: sqlite3.Row | dict[str, Any]) -> str:
    folder = str(_row_get(row, "folder") or "").strip()
    path = str(_row_get(row, "path") or "")
    if folder in {"lwc", "aura"}:
        bundle = _bundle_name_for_path(path, folder)
        if bundle:
            return bundle
    api_name = str(_row_get(row, "api_name") or "").strip()
    if api_name:
        return api_name
    return Path(path).stem


def _src_node_type(row: sqlite3.Row | dict[str, Any]) -> str | None:
    folder = str(_row_get(row, "folder") or "").strip()
    if folder in _GENERIC_SRC_FOLDERS:
        return _GENERIC_SRC_FOLDERS[folder]
    type_guess = str(_row_get(row, "type_guess") or "").strip()
    return _META_SRC_TYPES.get(type_guess)


def _edge_type_for(src_node_type: str, ref_kind: str) -> str | None:
    suffix = _REF_EDGE_SUFFIXES.get(ref_kind)
    if not suffix:
        return None
    return f"{src_node_type}_{suffix}"


def _dst_name_for_ref(row: sqlite3.Row) -> str:
    ref_kind = row["ref_kind"]
    value = (row["ref_value"] or "").strip()
    if ref_kind == "RECORDTYPE" and row["sobject"]:
        return f"{row['sobject']}.{value}"
    return value


def _seed_special_metadata_nodes(conn: sqlite3.Connection) -> int:
    edges_added = 0

    approval_rows = conn.execute(
        """
        SELECT ap.name, ap.object_name, ap.active, ap.path, mf.api_name
        FROM approval_processes ap
        LEFT JOIN meta_files mf ON mf.path = ap.path
        """
    ).fetchall()
    for row in approval_rows:
        name = (row["api_name"] or row["name"] or "").strip()
        if not name:
            continue
        src = get_or_create_node(
            conn,
            "APPROVAL_PROCESS",
            name,
            path=row["path"],
            extra={"active": row["active"], "object_name": row["object_name"]},
        )
        obj = (row["object_name"] or "").strip()
        if obj:
            dst = get_or_create_node(conn, "OBJECT", obj)
            edges_added += _add_edge(
                conn,
                src_node_id=src,
                dst_node_id=dst,
                edge_type="APPROVAL_PROCESS_APPLIES_TO_OBJECT",
                confidence=0.95,
                evidence_path=row["path"],
            )

    sharing_rows = conn.execute(
        """
        SELECT name, object_name, access_level, active, path, extra_json
        FROM sharing_rules
        """
    ).fetchall()
    for row in sharing_rows:
        name = (row["name"] or "").strip()
        if not name:
            continue
        extra: dict[str, Any] = {}
        if row["extra_json"]:
            try:
                extra = json.loads(row["extra_json"])
            except json.JSONDecodeError:
                extra = {"raw_extra_json": row["extra_json"]}
        extra.update({"access_level": row["access_level"], "active": row["active"]})
        src = get_or_create_node(conn, "SHARING_RULE", name, path=row["path"], extra=extra)
        obj = (row["object_name"] or "").strip()
        if obj:
            dst = get_or_create_node(conn, "OBJECT", obj)
            edges_added += _add_edge(
                conn,
                src_node_id=src,
                dst_node_id=dst,
                edge_type="SHARING_RULE_APPLIES_TO_OBJECT",
                confidence=0.95,
                evidence_path=row["path"],
            )

    return edges_added


def _build_flow_edges(conn: sqlite3.Connection, repo_root: Path) -> int:
    edges_added = 0

    flow_rows = conn.execute("SELECT flow_name, path FROM flows").fetchall()
    flow_paths = {r["flow_name"]: r["path"] for r in flow_rows}
    flow_names = set(flow_paths.keys())

    class_rows = conn.execute("SELECT name FROM components WHERE type='APEX'").fetchall()
    class_names = {r["name"] for r in class_rows}

    read_rows = conn.execute(
        "SELECT flow_name, full_field_name, path, confidence FROM flow_field_reads"
    ).fetchall()
    for r in read_rows:
        src = get_or_create_node(conn, "FLOW", r["flow_name"], path=r["path"])
        dst = get_or_create_node(conn, "FIELD", r["full_field_name"])
        edges_added += _add_edge(
            conn,
            src_node_id=src,
            dst_node_id=dst,
            edge_type="FLOW_READS_FIELD",
            confidence=float(r["confidence"] or 0.0),
            evidence_path=r["path"],
        )

    write_rows = conn.execute(
        """
        SELECT
          flow_name,
          field_full_name AS full_field_name,
          evidence_path AS path,
          confidence,
          sobject_type,
          write_kind,
          evidence_snippet
        FROM flow_true_writes
        """
    ).fetchall()
    if not write_rows:
        write_rows = conn.execute(
            """
            SELECT
              flow_name,
              full_field_name,
              path,
              confidence,
              NULL AS sobject_type,
              'field_write' AS write_kind,
              NULL AS evidence_snippet
            FROM flow_field_writes
            """
        ).fetchall()
    flow_object_conf: dict[tuple[str, str, str], float] = {}
    for r in write_rows:
        conf = float(r["confidence"] or 0.0)
        src = get_or_create_node(conn, "FLOW", r["flow_name"], path=r["path"])
        field = (r["full_field_name"] or "").strip()
        obj = (r["sobject_type"] or "").strip()
        if not obj and "." in field:
            obj = field.split(".", 1)[0]

        if r["write_kind"] == "field_write" and field:
            dst_field = get_or_create_node(conn, "FIELD", field)
            edges_added += _add_edge(
                conn,
                src_node_id=src,
                dst_node_id=dst_field,
                edge_type="FLOW_WRITES_FIELD",
                confidence=conf,
                evidence_path=r["path"],
                evidence_snippet=r["evidence_snippet"],
            )

        if obj:
            key = (r["flow_name"], r["path"], obj)
            flow_object_conf[key] = max(flow_object_conf.get(key, 0.0), conf)

    for (flow_name, path, obj), conf in flow_object_conf.items():
        src = get_or_create_node(conn, "FLOW", flow_name, path=path)
        dst = get_or_create_node(conn, "OBJECT", obj)
        edges_added += _add_edge(
            conn,
            src_node_id=src,
            dst_node_id=dst,
            edge_type="FLOW_UPDATES_OBJECT",
            confidence=conf,
            evidence_path=path,
        )

    known_objects = {
        r["object_name"] for r in conn.execute("SELECT object_name FROM objects").fetchall()
    }

    for flow_name, rel_path in flow_paths.items():
        full_path = repo_root / rel_path
        text = read_text(full_path)
        if not text:
            continue

        src_flow = get_or_create_node(conn, "FLOW", flow_name, path=rel_path)

        token_candidates = set(re.findall(r"\b[A-Za-z_][A-Za-z0-9_]*\b", text))
        for cls in sorted(token_candidates & class_names):
            for m in re.finditer(rf"\b{re.escape(cls)}\b", text):
                lo = max(0, m.start() - 120)
                hi = min(len(text), m.end() + 120)
                ctx = text[lo:hi].lower()
                conf = 0.9 if "apex" in ctx else 0.6
                ls, le = _line_span(text, m.start(), m.end())
                dst = get_or_create_node(conn, "APEX_CLASS", cls)
                edges_added += _add_edge(
                    conn,
                    src_node_id=src_flow,
                    dst_node_id=dst,
                    edge_type="FLOW_CALLS_APEX_ACTION",
                    confidence=conf,
                    evidence_path=rel_path,
                    evidence_line_start=ls,
                    evidence_line_end=le,
                    evidence_snippet=_snippet(text, m.start(), m.end()),
                )

        for child in sorted(flow_names):
            if child == flow_name:
                continue
            for m in re.finditer(rf"\b{re.escape(child)}\b", text):
                lo = max(0, m.start() - 120)
                hi = min(len(text), m.end() + 120)
                ctx = text[lo:hi].lower()
                conf = 0.9 if ("subflow" in ctx or "flowreference" in ctx) else 0.6
                ls, le = _line_span(text, m.start(), m.end())
                dst = get_or_create_node(conn, "FLOW", child, path=flow_paths.get(child))
                edges_added += _add_edge(
                    conn,
                    src_node_id=src_flow,
                    dst_node_id=dst,
                    edge_type="FLOW_CALLS_SUBFLOW",
                    confidence=conf,
                    evidence_path=rel_path,
                    evidence_line_start=ls,
                    evidence_line_end=le,
                    evidence_snippet=_snippet(text, m.start(), m.end()),
                )

        create_blocks = re.finditer(
            r"(?is)<[^>]*(?:createRecords|recordCreates|create)\b[^>]*>.*?</[^>]+>", text
        )
        for block in create_blocks:
            chunk = block.group(0)
            for m_obj in re.finditer(r"<[^>]*(?:object|sObject|objectType)[^>]*>([^<]+)</", chunk):
                obj = (m_obj.group(1) or "").strip()
                if obj not in known_objects:
                    continue
                dst = get_or_create_node(conn, "OBJECT", obj)
                ls, le = _line_span(text, block.start(), block.end())
                edges_added += _add_edge(
                    conn,
                    src_node_id=src_flow,
                    dst_node_id=dst,
                    edge_type="FLOW_CREATES_OBJECT",
                    confidence=0.85,
                    evidence_path=rel_path,
                    evidence_line_start=ls,
                    evidence_line_end=le,
                    evidence_snippet=_snippet(text, block.start(), block.end()),
                )

    return edges_added


def _build_trigger_edges(conn: sqlite3.Connection, repo_root: Path) -> int:
    edges_added = 0

    class_names = {
        r["name"] for r in conn.execute("SELECT name FROM components WHERE type='APEX'").fetchall()
    }
    trig_rows = conn.execute("SELECT name, path FROM components WHERE type='TRIGGER'").fetchall()

    for row in trig_rows:
        trig_name = row["name"]
        rel_path = row["path"]
        full_path = repo_root / rel_path
        text = read_text(full_path)
        if not text:
            continue

        trig_node = get_or_create_node(conn, "TRIGGER", trig_name, path=rel_path)
        tokens = set(re.findall(r"\b[A-Za-z_][A-Za-z0-9_]*\b", text))
        candidates = sorted(tokens & class_names)

        for cls in candidates:
            best: tuple[float, int, int, str] | None = None

            for m in re.finditer(rf"\bnew\s+{re.escape(cls)}\s*\(", text):
                ls, le = _line_span(text, m.start(), m.end())
                best = (0.9, ls, le, _snippet_line(text, ls))
                break

            if best is None:
                for m in re.finditer(rf"\b{re.escape(cls)}\.[A-Za-z_][A-Za-z0-9_]*\s*\(", text):
                    ls, le = _line_span(text, m.start(), m.end())
                    best = (0.8, ls, le, _snippet_line(text, ls))
                    break

            if best is None:
                low_hits = list(re.finditer(rf"\b{re.escape(cls)}\b", text))
                if 0 < len(low_hits) <= 2:
                    m = low_hits[0]
                    ls, le = _line_span(text, m.start(), m.end())
                    best = (0.5, ls, le, _snippet_line(text, ls))

            if best is None:
                continue

            dst = get_or_create_node(conn, "APEX_CLASS", cls)
            conf, ls, le, snip = best
            edges_added += _add_edge(
                conn,
                src_node_id=trig_node,
                dst_node_id=dst,
                edge_type="TRIGGER_CALLS_CLASS",
                confidence=conf,
                evidence_path=rel_path,
                evidence_line_start=ls,
                evidence_line_end=le,
                evidence_snippet=snip,
            )

    return edges_added


def _build_apex_edges(conn: sqlite3.Connection, repo_root: Path) -> int:
    edges_added = 0

    class_rows = conn.execute("SELECT name, path FROM components WHERE type='APEX'").fetchall()
    class_names = {r["name"] for r in class_rows}

    endpoint_rows = conn.execute(
        "SELECT class_name, path, endpoint_value, endpoint_type, line_start, line_end FROM apex_endpoints"
    ).fetchall()
    for r in endpoint_rows:
        src = get_or_create_node(conn, "APEX_CLASS", r["class_name"], path=r["path"])
        dst = get_or_create_node(conn, "ENDPOINT", r["endpoint_value"])
        conf = 0.9 if (r["endpoint_type"] == "named_credential") else 0.8
        edges_added += _add_edge(
            conn,
            src_node_id=src,
            dst_node_id=dst,
            edge_type="CLASS_CALLS_ENDPOINT",
            confidence=conf,
            evidence_path=r["path"],
            evidence_line_start=r["line_start"],
            evidence_line_end=r["line_end"],
        )

    for row in class_rows:
        cls_name = row["name"]
        rel_path = row["path"]
        full_path = repo_root / rel_path
        text = read_text(full_path)
        if not text:
            continue

        src = get_or_create_node(conn, "APEX_CLASS", cls_name, path=rel_path)

        tokens = set(re.findall(r"\b[A-Za-z_][A-Za-z0-9_]*\b", text))
        for other in sorted((tokens & class_names) - {cls_name}):
            m_new = re.search(rf"\bnew\s+{re.escape(other)}\s*\(", text)
            if m_new:
                ls, le = _line_span(text, m_new.start(), m_new.end())
                dst = get_or_create_node(conn, "APEX_CLASS", other)
                edges_added += _add_edge(
                    conn,
                    src_node_id=src,
                    dst_node_id=dst,
                    edge_type="CLASS_CALLS_CLASS",
                    confidence=0.8,
                    evidence_path=rel_path,
                    evidence_line_start=ls,
                    evidence_line_end=le,
                    evidence_snippet=_snippet_line(text, ls),
                )
                continue

            m_call = re.search(rf"\b{re.escape(other)}\.[A-Za-z_][A-Za-z0-9_]*\s*\(", text)
            if m_call:
                ls, le = _line_span(text, m_call.start(), m_call.end())
                dst = get_or_create_node(conn, "APEX_CLASS", other)
                edges_added += _add_edge(
                    conn,
                    src_node_id=src,
                    dst_node_id=dst,
                    edge_type="CLASS_CALLS_CLASS",
                    confidence=0.7,
                    evidence_path=rel_path,
                    evidence_line_start=ls,
                    evidence_line_end=le,
                    evidence_snippet=_snippet_line(text, ls),
                )

        rw_rows = conn.execute(
            """
            SELECT sobject_type, field_full_name, rw, confidence, evidence_snippet
            FROM apex_rw
            WHERE lower(class_name)=lower(?)
            ORDER BY confidence DESC
            """,
            (cls_name,),
        ).fetchall()
        for rw in rw_rows:
            obj = (rw["sobject_type"] or "").strip()
            field = (rw["field_full_name"] or "").strip()
            confidence = float(rw["confidence"] or 0.0)
            snippet = rw["evidence_snippet"] or None

            if rw["rw"] == "read" and obj:
                dst_obj = get_or_create_node(conn, "OBJECT", obj)
                edges_added += _add_edge(
                    conn,
                    src_node_id=src,
                    dst_node_id=dst_obj,
                    edge_type="CLASS_QUERIES_OBJECT",
                    confidence=max(0.6, confidence),
                    evidence_path=rel_path,
                    evidence_snippet=snippet,
                )
            if rw["rw"] == "read" and field:
                dst = get_or_create_node(conn, "FIELD", field)
                edges_added += _add_edge(
                    conn,
                    src_node_id=src,
                    dst_node_id=dst,
                    edge_type="CLASS_READS_FIELD",
                    confidence=max(0.6, confidence),
                    evidence_path=rel_path,
                    evidence_snippet=snippet,
                )
            if rw["rw"] == "write" and field:
                dst = get_or_create_node(conn, "FIELD", field)
                edges_added += _add_edge(
                    conn,
                    src_node_id=src,
                    dst_node_id=dst,
                    edge_type="CLASS_WRITES_FIELD",
                    confidence=max(0.55, confidence),
                    evidence_path=rel_path,
                    evidence_snippet=snippet,
                )

    return edges_added


def _build_metadata_edges(conn: sqlite3.Connection) -> int:
    edges_added = _seed_special_metadata_nodes(conn)

    meta_rows = conn.execute(
        """
        SELECT path, folder, type_guess, api_name, sobject, active
        FROM meta_files
        """
    ).fetchall()
    for row in meta_rows:
        src_node_type = _src_node_type(row)
        sobject = (row["sobject"] or "").strip()
        if not src_node_type or not sobject:
            continue
        src_name = _node_name_from_meta_row(row)
        src = get_or_create_node(
            conn,
            src_node_type,
            src_name,
            path=row["path"],
            extra={"active": row["active"], "sobject": row["sobject"]},
        )
        dst = get_or_create_node(conn, "OBJECT", sobject)
        edges_added += _add_edge(
            conn,
            src_node_id=src,
            dst_node_id=dst,
            edge_type=f"{src_node_type}_USES_OBJECT",
            confidence=0.9,
            evidence_path=row["path"],
        )

    rows = conn.execute(
        """
        SELECT
          mr.ref_kind,
          mr.ref_value,
          mr.src_path,
          mr.src_folder,
          mr.line_no,
          mr.snippet,
          mr.confidence,
          mf.type_guess,
          mf.api_name,
          mf.sobject,
          mf.active
        FROM meta_refs mr
        JOIN meta_files mf ON mf.path = mr.src_path
        WHERE mr.ref_kind IN ('FIELD','OBJECT','CLASS','FLOW','ENDPOINT','LABEL','RECORDTYPE')
        ORDER BY mr.src_path, mr.ref_kind, mr.ref_value
        """
    ).fetchall()

    for row in rows:
        if not row["ref_value"]:
            continue
        if (row["ref_value"] or "").strip().lower() in _IGNORED_REF_VALUES:
            continue

        src_node_type = _src_node_type({
            "folder": row["src_folder"],
            "type_guess": row["type_guess"],
            "api_name": row["api_name"],
            "path": row["src_path"],
        })
        if not src_node_type:
            continue

        dst_node_type = _REF_DST_TYPES.get(row["ref_kind"])
        edge_type = _edge_type_for(src_node_type, row["ref_kind"])
        dst_name = _dst_name_for_ref(row)
        if not dst_node_type or not edge_type or not dst_name:
            continue

        src_name = _node_name_from_meta_row(
            {
                "folder": row["src_folder"],
                "api_name": row["api_name"],
                "path": row["src_path"],
            }
        )
        src = get_or_create_node(
            conn,
            src_node_type,
            src_name,
            path=row["src_path"],
            extra={"active": row["active"], "sobject": row["sobject"]},
        )
        dst = get_or_create_node(conn, dst_node_type, dst_name)
        edges_added += _add_edge(
            conn,
            src_node_id=src,
            dst_node_id=dst,
            edge_type=edge_type,
            confidence=float(row["confidence"] or 0.0),
            evidence_path=row["src_path"],
            evidence_line_start=row["line_no"],
            evidence_line_end=row["line_no"],
            evidence_snippet=row["snippet"],
        )

    return edges_added


def build_dependency_graph(conn: sqlite3.Connection, repo_root: Path, sfdx_root: str) -> GraphBuildStats:
    _ = sfdx_root

    clear_graph(conn)
    stats = GraphBuildStats()

    stats.flow_edges = _build_flow_edges(conn, repo_root)
    stats.trigger_edges = _build_trigger_edges(conn, repo_root)
    stats.apex_edges = _build_apex_edges(conn, repo_root)
    stats.metadata_edges = _build_metadata_edges(conn)

    conn.commit()

    stats.nodes = int(conn.execute("SELECT COUNT(*) AS c FROM graph_nodes").fetchone()["c"])
    stats.edges = int(conn.execute("SELECT COUNT(*) AS c FROM graph_edges").fetchone()["c"])
    return stats


def _find_node(conn: sqlite3.Connection, node_type: str, name: str) -> sqlite3.Row | None:
    row = conn.execute(
        "SELECT node_id, node_type, name, path FROM graph_nodes WHERE node_type=? AND name=?",
        (node_type, name),
    ).fetchone()
    if row:
        return row
    return conn.execute(
        "SELECT node_id, node_type, name, path FROM graph_nodes WHERE node_type=? AND lower(name)=lower(?) LIMIT 1",
        (node_type, name),
    ).fetchone()


def deps_for_flow(conn: sqlite3.Connection, flow_name: str) -> dict:
    node = _find_node(conn, "FLOW", flow_name)
    if not node:
        return {"node": None, "groups": {}}

    rows = conn.execute(
        """
        SELECT e.edge_type, e.confidence, e.evidence_path, e.evidence_line_start, e.evidence_line_end, e.evidence_snippet,
               d.node_type AS dst_type, d.name AS dst_name
        FROM graph_edges e
        JOIN graph_nodes d ON d.node_id = e.dst_node_id
        WHERE e.src_node_id = ?
        ORDER BY e.edge_type, e.confidence DESC, d.name
        """,
        (node["node_id"],),
    ).fetchall()

    groups: dict[str, list[sqlite3.Row]] = {}
    for r in rows:
        groups.setdefault(r["edge_type"], []).append(r)
    return {"node": node, "groups": groups}


def deps_for_class(conn: sqlite3.Connection, class_name: str) -> dict:
    node = _find_node(conn, "APEX_CLASS", class_name)
    if not node:
        return {"node": None, "outgoing": {}, "inbound": {}}

    out_rows = conn.execute(
        """
        SELECT e.edge_type, e.confidence, e.evidence_path, e.evidence_line_start, e.evidence_line_end, e.evidence_snippet,
               d.node_type AS dst_type, d.name AS dst_name
        FROM graph_edges e
        JOIN graph_nodes d ON d.node_id = e.dst_node_id
        WHERE e.src_node_id = ?
        ORDER BY e.edge_type, e.confidence DESC, d.name
        """,
        (node["node_id"],),
    ).fetchall()

    in_rows = conn.execute(
        """
        SELECT e.edge_type, e.confidence, e.evidence_path, e.evidence_line_start, e.evidence_line_end, e.evidence_snippet,
               s.node_type AS src_type, s.name AS src_name
        FROM graph_edges e
        JOIN graph_nodes s ON s.node_id = e.src_node_id
        WHERE e.dst_node_id = ?
          AND e.edge_type LIKE '%CALLS_CLASS'
        ORDER BY e.edge_type, e.confidence DESC, s.name
        """,
        (node["node_id"],),
    ).fetchall()

    out_groups: dict[str, list[sqlite3.Row]] = {}
    for r in out_rows:
        out_groups.setdefault(r["edge_type"], []).append(r)

    in_groups: dict[str, list[sqlite3.Row]] = {}
    for r in in_rows:
        in_groups.setdefault(r["edge_type"], []).append(r)

    return {"node": node, "outgoing": out_groups, "inbound": in_groups}


def impact_field_graph(conn: sqlite3.Connection, full_field_name: str) -> dict:
    node = _find_node(conn, "FIELD", full_field_name)
    if not node:
        return {"node": None}

    inbound = conn.execute(
        """
        SELECT e.edge_type, e.confidence, e.evidence_path, e.evidence_line_start, e.evidence_line_end, e.evidence_snippet,
               s.node_id AS src_id, s.node_type AS src_type, s.name AS src_name
        FROM graph_edges e
        JOIN graph_nodes s ON s.node_id = e.src_node_id
        WHERE e.dst_node_id = ?
        ORDER BY e.edge_type, e.confidence DESC, s.name
        """,
        (node["node_id"],),
    ).fetchall()

    counts: dict[str, int] = {}
    src_nodes = set()
    for r in inbound:
        counts[r["edge_type"]] = counts.get(r["edge_type"], 0) + 1
        src_nodes.add(r["src_id"])

    context: list[sqlite3.Row] = []
    if src_nodes:
        marks = ",".join("?" for _ in src_nodes)
        context = conn.execute(
            f"""
            SELECT e.edge_type, e.confidence, d.node_type AS dst_type, d.name AS dst_name
            FROM graph_edges e
            JOIN graph_nodes d ON d.node_id = e.dst_node_id
            WHERE e.src_node_id IN ({marks})
              AND e.dst_node_id != ?
            ORDER BY e.confidence DESC, e.edge_type
            LIMIT 10
            """,
            tuple(src_nodes) + (node["node_id"],),
        ).fetchall()

    return {
        "node": node,
        "inbound": inbound,
        "counts": counts,
        "context": context,
    }


def impact_object_graph(conn: sqlite3.Connection, object_name: str) -> dict:
    node = _find_node(conn, "OBJECT", object_name)
    if not node:
        return {"node": None}

    inbound = conn.execute(
        """
        SELECT e.edge_type, e.confidence, e.evidence_path, e.evidence_line_start, e.evidence_line_end, e.evidence_snippet,
               s.node_type AS src_type, s.name AS src_name
        FROM graph_edges e
        JOIN graph_nodes s ON s.node_id = e.src_node_id
        WHERE e.dst_node_id = ?
        ORDER BY e.edge_type, e.confidence DESC, s.name
        """,
        (node["node_id"],),
    ).fetchall()

    counts: dict[str, int] = {}
    for r in inbound:
        counts[r["edge_type"]] = counts.get(r["edge_type"], 0) + 1

    fields_count = int(
        conn.execute(
            "SELECT COUNT(*) AS c FROM fields WHERE lower(object_name)=lower(?)",
            (node["name"],),
        ).fetchone()["c"]
    )

    touched_fields = conn.execute(
        """
        SELECT d.name AS field_name, COUNT(*) AS c
        FROM graph_edges e
        JOIN graph_nodes d ON d.node_id = e.dst_node_id
        WHERE d.node_type='FIELD'
          AND lower(d.name) LIKE lower(?)
        GROUP BY d.name
        ORDER BY c DESC, d.name
        LIMIT 10
        """,
        (f"{node['name']}.%",),
    ).fetchall()

    return {
        "node": node,
        "inbound": inbound,
        "counts": counts,
        "fields_count": fields_count,
        "touched_fields": touched_fields,
    }
