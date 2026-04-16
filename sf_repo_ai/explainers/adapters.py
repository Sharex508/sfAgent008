from __future__ import annotations

import re
import sqlite3
from pathlib import Path
from typing import Any
from xml.etree import ElementTree as ET

from .base import ExplainerAdapter
from ..util import read_text, xml_local_name


def _base_result(resolved: dict[str, Any]) -> dict[str, Any]:
    return {
        "type": resolved.get("resolved_type") or "Unknown",
        "name": resolved.get("resolved_name") or resolved.get("raw_target") or "Unknown",
        "path": resolved.get("resolved_path"),
        "facts": {},
        "deps": {"calls": [], "called_by": [], "reads": [], "writes": [], "touches": []},
        "risks": [],
        "tests": [],
        "evidence": [],
    }


def _safe_rows(conn: sqlite3.Connection, sql: str, params: tuple[Any, ...] = ()) -> list[sqlite3.Row]:
    try:
        return conn.execute(sql, params).fetchall()
    except Exception:
        return []


def _safe_row(conn: sqlite3.Connection, sql: str, params: tuple[Any, ...] = ()) -> sqlite3.Row | None:
    try:
        return conn.execute(sql, params).fetchone()
    except Exception:
        return None


def _bundle_from_path(path: str | None) -> str | None:
    if not path:
        return None
    m = re.search(r"/lwc/([^/]+)/", path)
    return m.group(1) if m else None


def _line_count(text: str) -> int:
    return len(text.splitlines()) if text else 0


def _extract_xml_tag_counts(text: str, limit: int = 20) -> list[tuple[str, int]]:
    if not text:
        return []
    try:
        root = ET.fromstring(text)
    except Exception:
        return []
    counts: dict[str, int] = {}
    for elem in root.iter():
        name = xml_local_name(elem.tag)
        counts[name] = counts.get(name, 0) + 1
    ranked = sorted(counts.items(), key=lambda x: (-x[1], x[0]))
    return ranked[:limit]


def _collect_file_evidence(conn: sqlite3.Connection, path: str | None, limit: int = 40) -> list[dict[str, Any]]:
    if not path:
        return []
    out: list[dict[str, Any]] = []
    ref_rows = _safe_rows(
        conn,
        """
        SELECT src_path AS path, line_no, snippet, confidence
        FROM meta_refs
        WHERE lower(src_path)=lower(?)
        ORDER BY confidence DESC, COALESCE(line_no, 0)
        LIMIT ?
        """,
        (path, limit),
    )
    for r in ref_rows:
        out.append({"path": r["path"], "line_no": r["line_no"], "snippet": r["snippet"] or "", "confidence": r["confidence"]})

    det_rows = _safe_rows(
        conn,
        'SELECT src_path AS path, line_start AS line_no, snippet, confidence FROM "references" WHERE lower(src_path)=lower(?) ORDER BY confidence DESC, COALESCE(line_start, 0) LIMIT ?',
        (path, limit),
    )
    seen = {(e["path"], e["line_no"], e["snippet"]) for e in out}
    for r in det_rows:
        key = (r["path"], r["line_no"], r["snippet"] or "")
        if key in seen:
            continue
        seen.add(key)
        out.append({"path": r["path"], "line_no": r["line_no"], "snippet": r["snippet"] or "", "confidence": r["confidence"]})

    if not out:
        out.append({"path": path, "line_no": None, "snippet": "", "confidence": None})
    return out[:limit]


def _graph_edges(conn: sqlite3.Connection, node_type: str, node_name: str, *, incoming: bool = False, limit: int = 100) -> list[dict[str, Any]]:
    if not node_name:
        return []
    if incoming:
        sql = """
        SELECT s.node_type AS src_type, s.name AS src_name, s.path AS src_path,
               d.node_type AS dst_type, d.name AS dst_name, d.path AS dst_path,
               e.edge_type, e.confidence, e.evidence_path, e.evidence_line_start, e.evidence_snippet
        FROM graph_edges e
        JOIN graph_nodes s ON s.node_id=e.src_node_id
        JOIN graph_nodes d ON d.node_id=e.dst_node_id
        WHERE d.node_type=? AND lower(d.name)=lower(?)
        ORDER BY e.confidence DESC, e.edge_type
        LIMIT ?
        """
    else:
        sql = """
        SELECT s.node_type AS src_type, s.name AS src_name, s.path AS src_path,
               d.node_type AS dst_type, d.name AS dst_name, d.path AS dst_path,
               e.edge_type, e.confidence, e.evidence_path, e.evidence_line_start, e.evidence_snippet
        FROM graph_edges e
        JOIN graph_nodes s ON s.node_id=e.src_node_id
        JOIN graph_nodes d ON d.node_id=e.dst_node_id
        WHERE s.node_type=? AND lower(s.name)=lower(?)
        ORDER BY e.confidence DESC, e.edge_type
        LIMIT ?
        """
    rows = _safe_rows(conn, sql, (node_type, node_name, limit))
    return [dict(r) for r in rows]


def _window(lines: list[str], line_no: int, radius: int = 25) -> tuple[int, int, str]:
    if not lines:
        return 1, 1, ""
    ln = max(1, min(line_no, len(lines)))
    start = max(1, ln - radius)
    end = min(len(lines), ln + radius)
    text = "\n".join(lines[start - 1 : end])
    return start, end, text


def collect_snippets(
    repo_root: Path,
    evidence: list[dict[str, Any]],
    keywords: list[str],
    *,
    max_snippets: int = 12,
    max_chars: int = 25000,
) -> list[dict[str, Any]]:
    snippets: list[dict[str, Any]] = []
    used = 0
    seen: set[tuple[str, int, int]] = set()
    keys = [k.lower() for k in keywords if isinstance(k, str) and k.strip()]

    by_path: dict[str, list[dict[str, Any]]] = {}
    for ev in evidence:
        p = ev.get("path")
        if not isinstance(p, str) or not p:
            continue
        by_path.setdefault(p, []).append(ev)

    for rel, rows in by_path.items():
        if len(snippets) >= max_snippets or used >= max_chars:
            break
        full = repo_root / rel
        text = read_text(full)
        if not text:
            continue
        lines = text.splitlines()

        # First: line-based snippets from evidence.
        for row in rows:
            if len(snippets) >= max_snippets or used >= max_chars:
                break
            ln = row.get("line_no")
            if not isinstance(ln, int) or ln <= 0:
                continue
            start, end, block = _window(lines, ln, radius=25)
            key = (rel, start, end)
            if key in seen or not block:
                continue
            if used + len(block) > max_chars:
                continue
            seen.add(key)
            snippets.append({"path": rel, "start_line": start, "end_line": end, "text": block})
            used += len(block)

        # Second: keyword search snippets.
        if len(snippets) >= max_snippets or used >= max_chars:
            continue
        low_lines = [ln.lower() for ln in lines]
        for idx, low in enumerate(low_lines, start=1):
            if len(snippets) >= max_snippets or used >= max_chars:
                break
            if keys and not any(k in low for k in keys):
                continue
            start, end, block = _window(lines, idx, radius=25)
            key = (rel, start, end)
            if key in seen or not block:
                continue
            if used + len(block) > max_chars:
                continue
            seen.add(key)
            snippets.append({"path": rel, "start_line": start, "end_line": end, "text": block})
            used += len(block)

        # Last fallback: first chunk.
        if not any(s["path"] == rel for s in snippets) and len(snippets) < max_snippets and used < max_chars:
            start, end, block = _window(lines, 1, radius=25)
            key = (rel, start, end)
            if block and key not in seen and used + len(block) <= max_chars:
                seen.add(key)
                snippets.append({"path": rel, "start_line": start, "end_line": end, "text": block})
                used += len(block)

    return snippets


def snippets_to_text(snippets: list[dict[str, Any]], max_chars: int = 25000) -> str:
    out: list[str] = []
    used = 0
    for s in snippets:
        head = f"### {s.get('path')}:{s.get('start_line')}-{s.get('end_line')}"
        block = str(s.get("text") or "")
        chunk = f"{head}\n{block}\n"
        if used + len(chunk) > max_chars:
            break
        out.append(chunk)
        used += len(chunk)
    return "\n".join(out).strip()


class FlowExplainer(ExplainerAdapter):
    adapter_name = "flow"

    def explain(self, resolved: dict[str, Any], repo_root: Path, db: sqlite3.Connection) -> dict[str, Any]:
        result = _base_result(resolved)
        name = resolved.get("resolved_name")
        path = resolved.get("resolved_path")
        row = None
        if name:
            row = _safe_row(db, "SELECT flow_name, status, trigger_object, trigger_type, path FROM flows WHERE lower(flow_name)=lower(?) LIMIT 1", (name,))
        if not row and path:
            row = _safe_row(db, "SELECT flow_name, status, trigger_object, trigger_type, path FROM flows WHERE lower(path)=lower(?) LIMIT 1", (path,))
        if row:
            name = row["flow_name"]
            path = row["path"]
            result["name"] = name
            result["path"] = path
            result["facts"].update(
                {
                    "status": row["status"],
                    "trigger_object": row["trigger_object"],
                    "trigger_type": row["trigger_type"],
                }
            )

        text = read_text(repo_root / path) if path else ""
        result["facts"]["loc"] = _line_count(text)
        result["facts"]["decision_count"] = len(re.findall(r"Decision", text or "", flags=re.IGNORECASE))
        result["facts"]["update_like_elements"] = len(re.findall(r"(RecordUpdate|UpdateRecords)", text or "", flags=re.IGNORECASE))
        result["facts"]["create_like_elements"] = len(re.findall(r"(RecordCreate|CreateRecords)", text or "", flags=re.IGNORECASE))
        result["facts"]["fault_paths"] = len(re.findall(r"faultConnector", text or "", flags=re.IGNORECASE))

        writes = _safe_rows(db, "SELECT DISTINCT field_full_name, confidence, evidence_path, evidence_snippet FROM flow_true_writes WHERE lower(flow_name)=lower(?) ORDER BY confidence DESC", (name or "",))
        if not writes:
            writes = _safe_rows(db, "SELECT DISTINCT full_field_name AS field_full_name, confidence, path AS evidence_path, '' AS evidence_snippet FROM flow_field_writes WHERE lower(flow_name)=lower(?) ORDER BY confidence DESC", (name or "",))
        reads = _safe_rows(db, "SELECT DISTINCT full_field_name, confidence, path FROM flow_field_reads WHERE lower(flow_name)=lower(?) ORDER BY confidence DESC", (name or "",))

        result["deps"]["writes"] = [{"name": r["field_full_name"], "confidence": r["confidence"], "path": r["evidence_path"]} for r in writes[:50]]
        result["deps"]["reads"] = [{"name": r["full_field_name"], "confidence": r["confidence"], "path": r["path"]} for r in reads[:50]]

        out_edges = _graph_edges(db, "FLOW", name or "", incoming=False, limit=200)
        for e in out_edges:
            if e["edge_type"] in {"FLOW_CALLS_SUBFLOW", "FLOW_CALLS_APEX_ACTION"}:
                result["deps"]["calls"].append({"type": e["dst_type"], "name": e["dst_name"], "edge_type": e["edge_type"], "path": e["evidence_path"] or e["dst_path"], "confidence": e["confidence"]})
            if e["edge_type"] in {"FLOW_UPDATES_OBJECT", "FLOW_CREATES_OBJECT", "FLOW_READS_FIELD", "FLOW_WRITES_FIELD"}:
                result["deps"]["touches"].append({"type": e["dst_type"], "name": e["dst_name"], "edge_type": e["edge_type"], "path": e["evidence_path"] or e["dst_path"], "confidence": e["confidence"]})

        if int(result["facts"].get("decision_count", 0)) > 20:
            result["risks"].append("High decision count can make maintenance difficult.")
        if int(result["facts"].get("fault_paths", 0)) == 0:
            result["risks"].append("No fault path evidence detected; exception handling may be limited.")
        if len(result["deps"]["writes"]) > 20:
            result["risks"].append("Flow writes many fields; check for side-effects and collisions.")

        result["tests"] = [
            "Run record-triggered tests for create/update paths and entry criteria.",
            "Validate fault connectors and error handling paths.",
            "Verify downstream field updates and any invoked Apex actions/subflows.",
        ]

        ev = _collect_file_evidence(db, path, limit=40)
        for w in writes[:20]:
            ev.append({"path": w["evidence_path"] or path, "line_no": None, "snippet": w["evidence_snippet"] or w["field_full_name"], "confidence": w["confidence"]})
        result["evidence"] = ev[:60]
        return result


class ApexClassExplainer(ExplainerAdapter):
    adapter_name = "apex_class"

    def explain(self, resolved: dict[str, Any], repo_root: Path, db: sqlite3.Connection) -> dict[str, Any]:
        result = _base_result(resolved)
        name = resolved.get("resolved_name")
        path = resolved.get("resolved_path")
        row = None
        if name:
            row = _safe_row(db, "SELECT name, path FROM components WHERE type='APEX' AND lower(name)=lower(?) LIMIT 1", (name,))
        if not row and path:
            row = _safe_row(db, "SELECT name, path FROM components WHERE type='APEX' AND lower(path)=lower(?) LIMIT 1", (path,))
        if row:
            name, path = row["name"], row["path"]
            result["name"] = name
            result["path"] = path

        text = read_text(repo_root / path) if path else ""
        methods = re.findall(r"\b(?:public|private|protected|global)\b[^\n;{}]*\([^\)]*\)\s*\{", text)
        result["facts"]["method_count"] = len(methods)
        stats = _safe_row(
            db,
            "SELECT loc, soql_count, dml_count, has_dynamic_soql, has_callout FROM apex_class_stats WHERE lower(class_name)=lower(?) LIMIT 1",
            (name or "",),
        )
        if stats:
            result["facts"].update(
                {
                    "loc": stats["loc"],
                    "soql_count": stats["soql_count"],
                    "dml_count": stats["dml_count"],
                    "dynamic_soql": bool(stats["has_dynamic_soql"]),
                    "has_callout": bool(stats["has_callout"]),
                }
            )
        else:
            result["facts"]["loc"] = _line_count(text)
            result["facts"]["soql_count"] = len(re.findall(r"\bSELECT\b", text, flags=re.IGNORECASE))
            result["facts"]["dml_count"] = len(re.findall(r"\b(insert|update|delete|upsert)\b", text, flags=re.IGNORECASE))
            result["facts"]["dynamic_soql"] = bool(re.search(r"Database\.query\(", text, flags=re.IGNORECASE))
            result["facts"]["has_callout"] = "callout:" in text or "setEndpoint(" in text

        rw = _safe_rows(
            db,
            "SELECT rw, field_full_name, sobject_type, confidence, evidence_snippet FROM apex_rw WHERE lower(class_name)=lower(?) ORDER BY confidence DESC",
            (name or "",),
        )
        endpoints = _safe_rows(
            db,
            "SELECT endpoint_value, endpoint_type, line_start, line_end, path FROM apex_endpoints WHERE lower(class_name)=lower(?) ORDER BY endpoint_value",
            (name or "",),
        )
        for r in rw:
            if r["rw"] == "write":
                result["deps"]["writes"].append({"name": r["field_full_name"] or r["sobject_type"], "confidence": r["confidence"], "snippet": r["evidence_snippet"]})
            elif r["rw"] == "read":
                result["deps"]["reads"].append({"name": r["field_full_name"] or r["sobject_type"], "confidence": r["confidence"], "snippet": r["evidence_snippet"]})
            else:
                result["deps"]["touches"].append({"name": r["sobject_type"], "confidence": r["confidence"]})
        for r in endpoints:
            result["deps"]["calls"].append({"type": "ENDPOINT", "name": r["endpoint_value"], "confidence": 1.0, "path": r["path"], "line_start": r["line_start"], "line_end": r["line_end"], "endpoint_type": r["endpoint_type"]})

        out_edges = _graph_edges(db, "APEX_CLASS", name or "", incoming=False, limit=200)
        in_edges = _graph_edges(db, "APEX_CLASS", name or "", incoming=True, limit=200)
        for e in out_edges:
            if e["edge_type"] in {"CLASS_CALLS_CLASS", "CLASS_CALLS_ENDPOINT"}:
                result["deps"]["calls"].append({"type": e["dst_type"], "name": e["dst_name"], "edge_type": e["edge_type"], "path": e["evidence_path"] or e["dst_path"], "confidence": e["confidence"]})
        for e in in_edges:
            if e["edge_type"] in {"TRIGGER_CALLS_CLASS", "CLASS_CALLS_CLASS", "FLOW_CALLS_APEX_ACTION"}:
                result["deps"]["called_by"].append({"type": e["src_type"], "name": e["src_name"], "edge_type": e["edge_type"], "path": e["evidence_path"] or e["src_path"], "confidence": e["confidence"]})

        if bool(result["facts"].get("dynamic_soql")):
            result["risks"].append("Dynamic SOQL detected; static impact analysis may be incomplete.")
        if bool(result["facts"].get("has_callout")):
            result["risks"].append("External callout usage detected; validate mocks/retries/timeouts.")
        if int(result["facts"].get("dml_count", 0)) > 20:
            result["risks"].append("High DML volume; verify transaction boundaries and bulk safety.")

        result["tests"] = [
            "Add/verify Apex unit tests for write paths and negative validations.",
            "If callouts exist, verify HttpCalloutMock coverage and error handling.",
            "Test class-to-class call chain for critical paths.",
        ]
        result["evidence"] = _collect_file_evidence(db, path, limit=50)
        return result


class TriggerExplainer(ExplainerAdapter):
    adapter_name = "trigger"

    def explain(self, resolved: dict[str, Any], repo_root: Path, db: sqlite3.Connection) -> dict[str, Any]:
        result = _base_result(resolved)
        name = resolved.get("resolved_name")
        path = resolved.get("resolved_path")
        row = None
        if name:
            row = _safe_row(db, "SELECT name, path FROM components WHERE type='TRIGGER' AND lower(name)=lower(?) LIMIT 1", (name,))
        if not row and path:
            row = _safe_row(db, "SELECT name, path FROM components WHERE type='TRIGGER' AND lower(path)=lower(?) LIMIT 1", (path,))
        if row:
            name, path = row["name"], row["path"]
            result["name"] = name
            result["path"] = path

        text = read_text(repo_root / path) if path else ""
        m = re.search(r"trigger\s+\w+\s+on\s+([A-Za-z0-9_]+)\s*\(([^\)]+)\)", text, flags=re.IGNORECASE)
        if m:
            result["facts"]["sobject"] = m.group(1)
            result["facts"]["events"] = [x.strip() for x in m.group(2).split(",") if x.strip()]

        out_edges = _graph_edges(db, "TRIGGER", name or "", incoming=False, limit=200)
        in_edges = _graph_edges(db, "TRIGGER", name or "", incoming=True, limit=200)
        for e in out_edges:
            result["deps"]["calls"].append({"type": e["dst_type"], "name": e["dst_name"], "edge_type": e["edge_type"], "path": e["evidence_path"] or e["dst_path"], "confidence": e["confidence"]})
        for e in in_edges:
            result["deps"]["called_by"].append({"type": e["src_type"], "name": e["src_name"], "edge_type": e["edge_type"], "path": e["evidence_path"] or e["src_path"], "confidence": e["confidence"]})

        result["tests"] = [
            "Validate before/after event behavior for each trigger event.",
            "Verify handler class invocation and recursion controls.",
        ]
        result["evidence"] = _collect_file_evidence(db, path, limit=50)
        return result


class LWCExplainer(ExplainerAdapter):
    adapter_name = "lwc"

    def explain(self, resolved: dict[str, Any], repo_root: Path, db: sqlite3.Connection) -> dict[str, Any]:
        result = _base_result(resolved)
        bundle = resolved.get("resolved_name") or _bundle_from_path(resolved.get("resolved_path"))
        if not bundle:
            result["evidence"] = []
            return result

        row = _safe_row(
            db,
            "SELECT path FROM meta_files WHERE lower(folder)='lwc' AND lower(path) LIKE lower(?) ORDER BY path LIMIT 1",
            (f"%/lwc/{bundle}/%",),
        )
        if row:
            result["path"] = row["path"]
        result["name"] = bundle

        files = _safe_rows(
            db,
            "SELECT path FROM meta_files WHERE lower(folder)='lwc' AND lower(path) LIKE lower(?) ORDER BY path LIMIT 500",
            (f"%/lwc/{bundle}/%",),
        )
        paths = [r["path"] for r in files]
        result["facts"]["file_count"] = len(paths)

        schema_refs: set[str] = set()
        apex_refs: set[str] = set()
        for rel in paths:
            txt = read_text(repo_root / rel)
            for m in re.findall(r"@salesforce/schema/([A-Za-z0-9_\.]+)", txt):
                schema_refs.add(m)
            for m in re.findall(r"@salesforce/apex/([A-Za-z0-9_\.]+)", txt):
                apex_refs.add(m)
        result["facts"]["schema_refs"] = sorted(schema_refs)[:50]
        result["facts"]["apex_imports"] = sorted(apex_refs)[:50]

        for s in sorted(schema_refs):
            result["deps"]["reads"].append({"type": "FIELD", "name": s})
        for a in sorted(apex_refs):
            result["deps"]["calls"].append({"type": "APEX_METHOD", "name": a})

        result["tests"] = [
            "Validate LWC rendering and wire/adaptor data loading paths.",
            "Verify Apex method invocation and error handling in UI.",
        ]
        ev: list[dict[str, Any]] = []
        for rel in paths[:60]:
            ev.append({"path": rel, "line_no": None, "snippet": bundle, "confidence": 1.0})
        result["evidence"] = ev
        return result


class PermissionSurfaceExplainer(ExplainerAdapter):
    adapter_name = "permission_surface"

    def explain(self, resolved: dict[str, Any], repo_root: Path, db: sqlite3.Connection) -> dict[str, Any]:
        result = _base_result(resolved)
        path = resolved.get("resolved_path")
        name = resolved.get("resolved_name")
        if path:
            row = _safe_row(db, "SELECT folder, api_name FROM meta_files WHERE lower(path)=lower(?) LIMIT 1", (path,))
            if row and row["api_name"]:
                name = row["api_name"]
                result["name"] = name

        txt = read_text(repo_root / path) if path else ""
        result["facts"]["view_all_data"] = "<viewAllData>true</viewAllData>" in txt
        result["facts"]["modify_all_data"] = "<modifyAllData>true</modifyAllData>" in txt

        obj_refs = _safe_rows(
            db,
            'SELECT ref_key, COUNT(*) AS c FROM "references" WHERE src_type=\'PERMISSION\' AND lower(src_path)=lower(?) AND ref_type=\'OBJECT\' GROUP BY ref_key ORDER BY c DESC, ref_key LIMIT 20',
            (path or "",),
        )
        fld_refs = _safe_rows(
            db,
            'SELECT ref_key, COUNT(*) AS c FROM "references" WHERE src_type=\'PERMISSION\' AND lower(src_path)=lower(?) AND ref_type=\'FIELD\' GROUP BY ref_key ORDER BY c DESC, ref_key LIMIT 20',
            (path or "",),
        )
        result["facts"]["object_permissions"] = [{"name": r["ref_key"], "count": r["c"]} for r in obj_refs]
        result["facts"]["field_permissions"] = [{"name": r["ref_key"], "count": r["c"]} for r in fld_refs]
        result["deps"]["touches"] = [{"type": "OBJECT", "name": r["ref_key"]} for r in obj_refs] + [{"type": "FIELD", "name": r["ref_key"]} for r in fld_refs]

        if result["facts"]["modify_all_data"]:
            result["risks"].append("Modify All Data is enabled.")
        if result["facts"]["view_all_data"]:
            result["risks"].append("View All Data is enabled.")
        result["tests"] = ["Verify least-privilege access and object/field grants in lower environments."]
        result["evidence"] = _collect_file_evidence(db, path, limit=50)
        return result


class SharingRulesExplainer(ExplainerAdapter):
    adapter_name = "sharing_rules"

    def explain(self, resolved: dict[str, Any], repo_root: Path, db: sqlite3.Connection) -> dict[str, Any]:
        result = _base_result(resolved)
        obj = resolved.get("resolved_name")
        path = resolved.get("resolved_path")
        rows = _safe_rows(
            db,
            "SELECT name, object_name, rule_type, access_level, active, path FROM sharing_rules WHERE lower(object_name)=lower(?) OR lower(path)=lower(?) ORDER BY name LIMIT 500",
            (obj or "", path or ""),
        )
        if rows:
            obj = rows[0]["object_name"]
            result["name"] = obj
            result["path"] = rows[0]["path"]
        result["facts"]["rule_count"] = len(rows)
        type_counts: dict[str, int] = {}
        for r in rows:
            t = r["rule_type"] or "unknown"
            type_counts[t] = type_counts.get(t, 0) + 1
            result["deps"]["touches"].append({"type": "OBJECT", "name": r["object_name"], "edge_type": "SHARING_RULE"})
        result["facts"]["rule_types"] = type_counts
        result["facts"]["rules"] = [
            {
                "name": r["name"],
                "type": r["rule_type"],
                "access_level": r["access_level"],
                "active": r["active"],
                "path": r["path"],
            }
            for r in rows[:100]
        ]

        if rows:
            txt = read_text(repo_root / rows[0]["path"])
            if txt:
                result["facts"]["classification_tokens"] = {
                    "criteria_rules": len(re.findall(r"criteria", txt, flags=re.IGNORECASE)),
                    "owner_rules": len(re.findall(r"owner", txt, flags=re.IGNORECASE)),
                    "shared_to_tokens": len(re.findall(r"sharedTo", txt, flags=re.IGNORECASE)),
                }

        result["tests"] = [
            "Validate access outcomes for sample users/roles before and after sharing rule changes.",
            "Verify object visibility with profile/permset and sharing rule combination.",
        ]

        ev: list[dict[str, Any]] = []
        for r in rows[:50]:
            ev.append({"path": r["path"], "line_no": None, "snippet": f"{r['name']} ({r['rule_type'] or 'unknown'})", "confidence": 1.0})
        result["evidence"] = ev
        return result


class ApprovalProcessExplainer(ExplainerAdapter):
    adapter_name = "approval_process"

    def explain(self, resolved: dict[str, Any], repo_root: Path, db: sqlite3.Connection) -> dict[str, Any]:
        result = _base_result(resolved)
        name = resolved.get("resolved_name")
        path = resolved.get("resolved_path")
        row = _safe_row(
            db,
            "SELECT name, object_name, active, path FROM approval_processes WHERE lower(name)=lower(?) OR lower(path)=lower(?) LIMIT 1",
            (name or "", path or ""),
        )
        if row:
            name, path = row["name"], row["path"]
            result["name"] = name
            result["path"] = path
            result["facts"]["object_name"] = row["object_name"]
            result["facts"]["active"] = bool(row["active"]) if row["active"] in (0, 1) else None
            if row["object_name"]:
                result["deps"]["touches"].append({"type": "OBJECT", "name": row["object_name"]})

        txt = read_text(repo_root / path) if path else ""
        result["facts"]["entry_criteria_count"] = len(re.findall(r"<entryCriteria>", txt))
        result["facts"]["step_count"] = len(re.findall(r"<approvalStep>", txt))
        result["facts"]["initial_action_blocks"] = len(re.findall(r"<initialSubmissionActions>", txt))
        result["facts"]["final_approval_blocks"] = len(re.findall(r"<finalApprovalActions>", txt))
        result["facts"]["final_rejection_blocks"] = len(re.findall(r"<finalRejectionActions>", txt))

        result["tests"] = [
            "Validate entry criteria and submitter rules.",
            "Test approval/rejection branches and resulting field/task/email actions.",
        ]
        result["evidence"] = _collect_file_evidence(db, path, limit=50)
        return result


class ValidationRuleExplainer(ExplainerAdapter):
    adapter_name = "validation_rule"

    def explain(self, resolved: dict[str, Any], repo_root: Path, db: sqlite3.Connection) -> dict[str, Any]:
        result = _base_result(resolved)
        name = resolved.get("resolved_name")
        path = resolved.get("resolved_path")
        row = _safe_row(
            db,
            "SELECT object_name, rule_name, active, error_condition, error_message, path FROM validation_rules WHERE lower(rule_name)=lower(?) OR lower(path)=lower(?) LIMIT 1",
            (name or "", path or ""),
        )
        if row:
            result["name"] = row["rule_name"]
            result["path"] = row["path"]
            result["facts"].update(
                {
                    "object_name": row["object_name"],
                    "active": bool(row["active"]),
                    "error_condition": row["error_condition"],
                    "error_message": row["error_message"],
                }
            )
            if row["object_name"]:
                result["deps"]["touches"].append({"type": "OBJECT", "name": row["object_name"]})

        refs = _safe_rows(
            db,
            'SELECT ref_key, src_path, line_start, snippet, confidence FROM "references" WHERE src_type=\'VR\' AND lower(src_name)=lower(?) ORDER BY confidence DESC LIMIT 100',
            (result["name"] or "",),
        )
        for r in refs:
            result["deps"]["reads"].append({"type": "FIELD", "name": r["ref_key"], "confidence": r["confidence"]})
        result["evidence"] = _collect_file_evidence(db, result.get("path"), limit=50)
        return result


class LayoutExplainer(ExplainerAdapter):
    adapter_name = "layout"

    def explain(self, resolved: dict[str, Any], repo_root: Path, db: sqlite3.Connection) -> dict[str, Any]:
        result = _base_result(resolved)
        path = resolved.get("resolved_path")
        txt = read_text(repo_root / path) if path else ""
        fields = re.findall(r"<field>([^<]+)</field>", txt)
        sections = len(re.findall(r"<layoutSections>", txt))
        related = len(re.findall(r"<relatedLists>", txt))
        quick_actions = len(re.findall(r"quickAction", txt, flags=re.IGNORECASE))
        result["facts"].update(
            {
                "section_count": sections,
                "field_count": len(fields),
                "sample_fields": fields[:20],
                "related_list_count": related,
                "quick_action_tokens": quick_actions,
            }
        )
        for f in fields[:100]:
            result["deps"]["touches"].append({"type": "FIELD", "name": f})
        result["evidence"] = _collect_file_evidence(db, path, limit=50)
        result["tests"] = ["Validate layout sections/fields/quick actions in target profiles and record types."]
        return result


class FlexipageExplainer(ExplainerAdapter):
    adapter_name = "flexipage"

    def explain(self, resolved: dict[str, Any], repo_root: Path, db: sqlite3.Connection) -> dict[str, Any]:
        result = _base_result(resolved)
        path = resolved.get("resolved_path")
        txt = read_text(repo_root / path) if path else ""
        result["facts"]["component_instance_count"] = len(re.findall(r"componentInstance", txt, flags=re.IGNORECASE))
        refs = _safe_rows(
            db,
            "SELECT ref_value, line_no, snippet, confidence FROM meta_refs WHERE lower(src_path)=lower(?) ORDER BY confidence DESC LIMIT 200",
            (path or "",),
        )
        for r in refs:
            result["deps"]["touches"].append({"type": "REF", "name": r["ref_value"], "confidence": r["confidence"]})
        result["evidence"] = _collect_file_evidence(db, path, limit=50)
        return result


class QuickActionExplainer(ExplainerAdapter):
    adapter_name = "quick_action"

    def explain(self, resolved: dict[str, Any], repo_root: Path, db: sqlite3.Connection) -> dict[str, Any]:
        result = _base_result(resolved)
        path = resolved.get("resolved_path")
        txt = read_text(repo_root / path) if path else ""
        for tag in ["targetObject", "type", "label"]:
            m = re.search(rf"<{tag}>([^<]+)</{tag}>", txt)
            if m:
                result["facts"][tag] = m.group(1)
        result["evidence"] = _collect_file_evidence(db, path, limit=40)
        return result


class ConnectedAppExplainer(ExplainerAdapter):
    adapter_name = "connected_app"

    def explain(self, resolved: dict[str, Any], repo_root: Path, db: sqlite3.Connection) -> dict[str, Any]:
        result = _base_result(resolved)
        path = resolved.get("resolved_path")
        txt = read_text(repo_root / path) if path else ""
        callbacks = re.findall(r"<callbackUrl>([^<]+)</callbackUrl>", txt)
        scopes = re.findall(r"<scope>([^<]+)</scope>", txt)
        result["facts"].update(
            {
                "callback_url_count": len(callbacks),
                "callbacks": callbacks[:20],
                "scope_count": len(scopes),
                "scopes": scopes[:30],
            }
        )
        result["deps"]["touches"] = [{"type": "URL", "name": c} for c in callbacks[:50]]
        result["evidence"] = _collect_file_evidence(db, path, limit=50)
        result["tests"] = ["Validate connected app OAuth scopes, callback URLs, and auth flows."]
        return result


class AuthProviderExplainer(ExplainerAdapter):
    adapter_name = "auth_provider"

    def explain(self, resolved: dict[str, Any], repo_root: Path, db: sqlite3.Connection) -> dict[str, Any]:
        result = _base_result(resolved)
        path = resolved.get("resolved_path")
        txt = read_text(repo_root / path) if path else ""
        urls = re.findall(r"https?://[^<\"'\s]+", txt)
        result["facts"]["url_count"] = len(urls)
        result["facts"]["urls"] = urls[:20]
        result["deps"]["touches"] = [{"type": "URL", "name": u} for u in urls[:50]]
        result["evidence"] = _collect_file_evidence(db, path, limit=40)
        return result


class CspCorsExplainer(ExplainerAdapter):
    adapter_name = "csp_cors"

    def explain(self, resolved: dict[str, Any], repo_root: Path, db: sqlite3.Connection) -> dict[str, Any]:
        result = _base_result(resolved)
        path = resolved.get("resolved_path")
        txt = read_text(repo_root / path) if path else ""
        urls = re.findall(r"https?://[^<\"'\s]+", txt)
        result["facts"]["domain_count"] = len(urls)
        result["facts"]["domains"] = sorted(set(urls))[:30]
        result["deps"]["touches"] = [{"type": "DOMAIN", "name": u} for u in sorted(set(urls))[:50]]
        result["evidence"] = _collect_file_evidence(db, path, limit=40)
        return result


class GenericMetadataExplainer(ExplainerAdapter):
    adapter_name = "generic"

    def explain(self, resolved: dict[str, Any], repo_root: Path, db: sqlite3.Connection) -> dict[str, Any]:
        result = _base_result(resolved)
        path = resolved.get("resolved_path")
        txt = read_text(repo_root / path) if path else ""
        result["facts"]["line_count"] = _line_count(txt)
        tags = _extract_xml_tag_counts(txt, limit=20)
        if tags:
            result["facts"]["top_xml_tags"] = [{"tag": t, "count": c} for t, c in tags]

        name = str(result.get("name") or "")
        refs = _safe_rows(
            db,
            "SELECT ref_kind, ref_value, src_path, line_no, snippet, confidence FROM meta_refs WHERE lower(src_path)=lower(?) OR lower(ref_value)=lower(?) OR lower(snippet) LIKE lower(?) ORDER BY confidence DESC LIMIT 200",
            (path or "", name, f"%{name}%"),
        )
        for r in refs:
            result["deps"]["touches"].append({"type": r["ref_kind"], "name": r["ref_value"], "path": r["src_path"], "confidence": r["confidence"]})
        result["evidence"] = _collect_file_evidence(db, path, limit=50)
        if not result["evidence"] and path:
            result["evidence"] = [{"path": path, "line_no": None, "snippet": "", "confidence": None}]
        return result
