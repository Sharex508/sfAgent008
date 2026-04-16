from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime, timezone
import hashlib
import json
import re
import sqlite3
from collections import deque
from typing import Any

from rapidfuzz import fuzz, process

from sf_repo_ai.entity_dict import build_entity_dictionary, normalize
from sf_repo_ai.query_interpreter import resolve_field_phrase, resolve_object_phrase


@dataclass
class EvidenceResult:
    target: dict[str, Any]
    summary_counts: dict[str, int]
    top_hotspots: list[dict[str, Any]]
    writers: list[dict[str, Any]]
    readers: list[dict[str, Any]]
    automations: list[dict[str, Any]]
    security_surface: list[dict[str, Any]]
    integration_surface: list[dict[str, Any]]
    ui_surface: list[dict[str, Any]]
    refs: list[dict[str, Any]]
    unknowns: list[str]
    evidence_paths: list[str]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


NODE_TYPE_BY_TARGET = {
    "OBJECT": "OBJECT",
    "FIELD": "FIELD",
    "FLOW": "FLOW",
    "APEX_CLASS": "APEX_CLASS",
    "TRIGGER": "TRIGGER",
    "ENDPOINT": "ENDPOINT",
}

WRITER_EDGE_TYPES = {
    "FLOW_WRITES_FIELD",
    "CLASS_WRITES_FIELD",
    "FLOW_UPDATES_OBJECT",
    "FLOW_CREATES_OBJECT",
}
READER_EDGE_TYPES = {
    "FLOW_READS_FIELD",
    "CLASS_READS_FIELD",
    "CLASS_QUERIES_OBJECT",
}

INTEGRATION_FOLDERS = [
    "connectedApps",
    "authproviders",
    "corsWhitelistOrigins",
    "cspTrustedSites",
    "remoteSiteSettings",
]
EVIDENCE_ENGINE_VERSION = "2026-02-19-v3"


def _find_graph_node(conn: sqlite3.Connection, node_type: str, name: str) -> sqlite3.Row | None:
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


def _target_tokens(resolved: dict[str, Any]) -> list[str]:
    t = resolved.get("type")
    name = resolved.get("name") or ""
    out: list[str] = []
    if t == "FIELD":
        out.append(name)
        if "." in name:
            obj, fld = name.split(".", 1)
            out.append(obj)
            out.append(fld)
    elif t in {"OBJECT", "FLOW", "APEX_CLASS", "TRIGGER", "ENDPOINT"}:
        out.append(name)
    elif t == "FILE":
        out.append(resolved.get("path") or "")
        if name:
            out.append(name)
    return [x for x in out if x]


def _compute_input_hash(conn: sqlite3.Connection) -> str:
    stats = {
        "engine_version": EVIDENCE_ENGINE_VERSION,
        "meta_files_count": int(conn.execute("SELECT COUNT(*) AS c FROM meta_files").fetchone()["c"]),
        "meta_files_max_idx": (conn.execute("SELECT MAX(indexed_at) AS m FROM meta_files").fetchone()["m"] or ""),
        "graph_nodes_count": int(conn.execute("SELECT COUNT(*) AS c FROM graph_nodes").fetchone()["c"]),
        "graph_edges_count": int(conn.execute("SELECT COUNT(*) AS c FROM graph_edges").fetchone()["c"]),
        "refs_count": int(conn.execute("SELECT COUNT(*) AS c FROM \"references\"").fetchone()["c"]),
        "meta_refs_count": int(conn.execute("SELECT COUNT(*) AS c FROM meta_refs").fetchone()["c"]),
        "approval_count": int(conn.execute("SELECT COUNT(*) AS c FROM approval_processes").fetchone()["c"]),
        "sharing_rules_count": int(conn.execute("SELECT COUNT(*) AS c FROM sharing_rules").fetchone()["c"]),
    }
    return hashlib.sha1(json.dumps(stats, sort_keys=True).encode("utf-8")).hexdigest()


def _cache_key(resolved: dict[str, Any], depth: int, top_n: int) -> str:
    t = resolved.get("type") or "UNKNOWN"
    if t == "FILE":
        val = resolved.get("path") or resolved.get("name") or ""
    else:
        val = resolved.get("name") or ""
    return f"{t}:{val}|d={depth}|n={top_n}"


def _resolve_target(conn: sqlite3.Connection, target: str) -> dict[str, Any]:
    raw = (target or "").strip()
    lowered = raw.lower()
    d = build_entity_dictionary(conn)
    resolved: dict[str, Any] = {
        "raw": raw,
        "found": False,
        "type": "UNKNOWN",
        "name": None,
        "path": None,
        "suggestions": [],
    }

    def _suggestions() -> list[str]:
        pool = list(d.objects[:2000]) + list(d.fields[:2000]) + list(d.flows[:2000]) + list(d.apex_classes[:2000])
        if not pool:
            return []
        m = process.extract(raw, pool, scorer=fuzz.WRatio, limit=5)
        return [x[0] for x in m if x and int(x[1]) >= 70]

    # Explicit prefixes.
    if ":" in raw and not lowered.startswith("callout:") and not lowered.startswith("http://") and not lowered.startswith("https://"):
        prefix, value = raw.split(":", 1)
        p = normalize(prefix)
        value = value.strip()
        if p in {"flow"}:
            row = conn.execute("SELECT flow_name, path FROM flows WHERE lower(flow_name)=lower(?) LIMIT 1", (value,)).fetchone()
            if row:
                resolved.update({"found": True, "type": "FLOW", "name": row["flow_name"], "path": row["path"]})
                return resolved
        if p in {"class", "apex class", "apex"}:
            row = conn.execute(
                "SELECT name, path FROM components WHERE type='APEX' AND lower(name)=lower(?) LIMIT 1",
                (value,),
            ).fetchone()
            if row:
                resolved.update({"found": True, "type": "APEX_CLASS", "name": row["name"], "path": row["path"]})
                return resolved
        if p in {"trigger"}:
            row = conn.execute(
                "SELECT name, path FROM components WHERE type='TRIGGER' AND lower(name)=lower(?) LIMIT 1",
                (value,),
            ).fetchone()
            if row:
                resolved.update({"found": True, "type": "TRIGGER", "name": row["name"], "path": row["path"]})
                return resolved
        if p in {"object"}:
            obj = None
            row = conn.execute("SELECT object_name FROM objects WHERE lower(object_name)=lower(?) LIMIT 1", (value,)).fetchone()
            if row:
                obj = row["object_name"]
            else:
                obj_match = resolve_object_phrase(value, d.object_alias_map, score_cutoff=90)
                if obj_match:
                    obj = obj_match[0]
            if obj:
                resolved.update({"found": True, "type": "OBJECT", "name": obj})
                return resolved
        if p in {"field"}:
            field = None
            row = conn.execute("SELECT full_name FROM fields WHERE lower(full_name)=lower(?) LIMIT 1", (value,)).fetchone()
            if row:
                field = row["full_name"]
            else:
                fld_match = resolve_field_phrase(value, d.field_alias_map, score_cutoff=90)
                if fld_match:
                    field = fld_match[0]
            if field:
                resolved.update({"found": True, "type": "FIELD", "name": field})
                return resolved
        if p in {"endpoint"}:
            resolved.update({"found": True, "type": "ENDPOINT", "name": value})
            return resolved
        if p in {"path", "file"}:
            row = conn.execute(
                "SELECT path, api_name FROM meta_files WHERE path=? OR lower(path)=lower(?) LIMIT 1",
                (value, value),
            ).fetchone()
            if row:
                resolved.update({"found": True, "type": "FILE", "path": row["path"], "name": row["api_name"]})
                return resolved
            resolved["suggestions"] = _suggestions()
            return resolved

    if lowered.startswith("callout:") or lowered.startswith("http://") or lowered.startswith("https://"):
        resolved.update({"found": True, "type": "ENDPOINT", "name": raw})
        return resolved

    if "." in raw:
        row = conn.execute("SELECT full_name FROM fields WHERE lower(full_name)=lower(?) LIMIT 1", (raw,)).fetchone()
        if row:
            resolved.update({"found": True, "type": "FIELD", "name": row["full_name"]})
            return resolved
        fld_match = resolve_field_phrase(raw, d.field_alias_map, score_cutoff=90)
        if fld_match:
            resolved.update({"found": True, "type": "FIELD", "name": fld_match[0]})
            return resolved

    obj_row = conn.execute("SELECT object_name FROM objects WHERE lower(object_name)=lower(?) LIMIT 1", (raw,)).fetchone()
    if obj_row:
        resolved.update({"found": True, "type": "OBJECT", "name": obj_row["object_name"]})
        return resolved
    obj_match = resolve_object_phrase(raw, d.object_alias_map, score_cutoff=90)
    if obj_match:
        resolved.update({"found": True, "type": "OBJECT", "name": obj_match[0]})
        return resolved

    flow_row = conn.execute("SELECT flow_name, path FROM flows WHERE lower(flow_name)=lower(?) LIMIT 1", (raw,)).fetchone()
    if flow_row:
        resolved.update({"found": True, "type": "FLOW", "name": flow_row["flow_name"], "path": flow_row["path"]})
        return resolved

    class_row = conn.execute(
        "SELECT name, path FROM components WHERE type='APEX' AND lower(name)=lower(?) LIMIT 1",
        (raw,),
    ).fetchone()
    if class_row:
        resolved.update({"found": True, "type": "APEX_CLASS", "name": class_row["name"], "path": class_row["path"]})
        return resolved

    file_row = conn.execute("SELECT path, api_name FROM meta_files WHERE path=? OR lower(path)=lower(?) LIMIT 1", (raw, raw)).fetchone()
    if file_row:
        resolved.update({"found": True, "type": "FILE", "path": file_row["path"], "name": file_row["api_name"]})
        return resolved

    resolved["suggestions"] = _suggestions()
    return resolved


def _collect_graph_edges(
    conn: sqlite3.Connection,
    *,
    start_node_id: int,
    depth: int,
    min_confidence: float,
) -> tuple[list[dict[str, Any]], dict[int, int]]:
    queue: deque[tuple[int, int]] = deque([(start_node_id, 0)])
    seen_depth: dict[int, int] = {start_node_id: 0}
    edges_by_id: dict[int, dict[str, Any]] = {}

    while queue:
        node_id, cur_depth = queue.popleft()
        if cur_depth >= depth:
            continue

        out_rows = conn.execute(
            """
            SELECT e.edge_id, e.edge_type, e.confidence, e.evidence_path, e.evidence_line_start, e.evidence_line_end, e.evidence_snippet,
                   s.node_id AS src_id, s.node_type AS src_type, s.name AS src_name, s.path AS src_path,
                   d.node_id AS dst_id, d.node_type AS dst_type, d.name AS dst_name, d.path AS dst_path
            FROM graph_edges e
            JOIN graph_nodes s ON s.node_id=e.src_node_id
            JOIN graph_nodes d ON d.node_id=e.dst_node_id
            WHERE e.src_node_id=? AND COALESCE(e.confidence,0) >= ?
            """,
            (node_id, min_confidence),
        ).fetchall()

        in_rows = conn.execute(
            """
            SELECT e.edge_id, e.edge_type, e.confidence, e.evidence_path, e.evidence_line_start, e.evidence_line_end, e.evidence_snippet,
                   s.node_id AS src_id, s.node_type AS src_type, s.name AS src_name, s.path AS src_path,
                   d.node_id AS dst_id, d.node_type AS dst_type, d.name AS dst_name, d.path AS dst_path
            FROM graph_edges e
            JOIN graph_nodes s ON s.node_id=e.src_node_id
            JOIN graph_nodes d ON d.node_id=e.dst_node_id
            WHERE e.dst_node_id=? AND COALESCE(e.confidence,0) >= ?
            """,
            (node_id, min_confidence),
        ).fetchall()

        for row in list(out_rows) + list(in_rows):
            edge_id = int(row["edge_id"])
            if edge_id not in edges_by_id:
                edges_by_id[edge_id] = {
                    "edge_id": edge_id,
                    "edge_type": row["edge_type"],
                    "confidence": float(row["confidence"] or 0.0),
                    "evidence_path": row["evidence_path"],
                    "evidence_line_start": row["evidence_line_start"],
                    "evidence_line_end": row["evidence_line_end"],
                    "evidence_snippet": row["evidence_snippet"],
                    "src": {
                        "node_id": int(row["src_id"]),
                        "node_type": row["src_type"],
                        "name": row["src_name"],
                        "path": row["src_path"],
                    },
                    "dst": {
                        "node_id": int(row["dst_id"]),
                        "node_type": row["dst_type"],
                        "name": row["dst_name"],
                        "path": row["dst_path"],
                    },
                    "depth": cur_depth + 1,
                }

            next_ids = [int(row["src_id"]), int(row["dst_id"])]
            for next_id in next_ids:
                nd = cur_depth + 1
                if next_id not in seen_depth or nd < seen_depth[next_id]:
                    seen_depth[next_id] = nd
                    if nd <= depth:
                        queue.append((next_id, nd))

    return list(edges_by_id.values()), seen_depth


def _rank_hotspots(
    conn: sqlite3.Connection,
    *,
    seen_depth: dict[int, int],
    graph_edges: list[dict[str, Any]],
    start_node_id: int,
    top_n: int,
) -> list[dict[str, Any]]:
    node_ids = [nid for nid in seen_depth if nid != start_node_id]
    if not node_ids:
        return []
    marks = ",".join("?" for _ in node_ids)
    node_rows = conn.execute(
        f"SELECT node_id, node_type, name, path FROM graph_nodes WHERE node_id IN ({marks})",
        tuple(node_ids),
    ).fetchall()
    node_by_id = {int(r["node_id"]): r for r in node_rows}

    edge_conf_by_node: dict[int, float] = {}
    for e in graph_edges:
        src = int(e["src"]["node_id"])
        dst = int(e["dst"]["node_id"])
        conf = float(e["confidence"] or 0.0)
        edge_conf_by_node[src] = max(edge_conf_by_node.get(src, 0.0), conf)
        edge_conf_by_node[dst] = max(edge_conf_by_node.get(dst, 0.0), conf)

    hotspots: list[dict[str, Any]] = []
    for nid in node_ids:
        row = node_by_id.get(nid)
        if not row:
            continue
        indeg = int(conn.execute("SELECT COUNT(*) AS c FROM graph_edges WHERE dst_node_id=?", (nid,)).fetchone()["c"])
        outdeg = int(conn.execute("SELECT COUNT(*) AS c FROM graph_edges WHERE src_node_id=?", (nid,)).fetchone()["c"])
        degree = indeg + outdeg
        d = int(seen_depth.get(nid, 99))
        conf = float(edge_conf_by_node.get(nid, 0.0))
        score = (3 - min(3, d)) * 100 + conf * 10 + degree * 0.25
        hotspots.append(
            {
                "node_type": row["node_type"],
                "name": row["name"],
                "path": row["path"],
                "depth": d,
                "confidence": conf,
                "in_degree": indeg,
                "out_degree": outdeg,
                "degree": degree,
                "score": round(score, 3),
            }
        )
    hotspots.sort(key=lambda x: (x["score"], x["degree"], x["confidence"]), reverse=True)
    return hotspots[:top_n]


def _collect_paths(*sections: list[dict[str, Any]]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for section in sections:
        for item in section:
            for key in ("path", "evidence_path", "src_path"):
                p = item.get(key)
                if not p or p in seen:
                    continue
                seen.add(p)
                out.append(p)
    return out


def _match_refs_by_tokens(
    conn: sqlite3.Connection,
    *,
    tokens: list[str],
    folders: list[str] | None = None,
    limit: int = 50,
) -> list[dict[str, Any]]:
    tokens = [t for t in tokens if t]
    if not tokens:
        return []

    folder_sql = ""
    params: list[Any] = []
    if folders:
        marks = ",".join("?" for _ in folders)
        folder_sql = f" AND lower(src_folder) IN ({marks})"
        params.extend([f.lower() for f in folders])

    conds = []
    for _ in tokens:
        conds.append("(lower(ref_value)=lower(?) OR lower(ref_value) LIKE lower(?) OR lower(snippet) LIKE lower(?))")
    cond_sql = " OR ".join(conds)

    q_params: list[Any] = []
    for t in tokens:
        q_params.extend([t, f"%{t}%", f"%{t}%"])
    q_params.extend(params)
    q_params.append(limit)

    rows = conn.execute(
        f"""
        SELECT ref_kind, ref_value, src_path, src_folder, line_no, snippet, confidence
        FROM meta_refs
        WHERE ({cond_sql}) {folder_sql}
        ORDER BY confidence DESC, src_path, COALESCE(line_no, 0)
        LIMIT ?
        """,
        tuple(q_params),
    ).fetchall()
    return [dict(r) for r in rows]


def _graph_writer_reader_for_target(
    conn: sqlite3.Connection,
    *,
    resolved: dict[str, Any],
    start_node: sqlite3.Row | None,
    top_n: int,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    t = resolved.get("type")
    if t not in {"FIELD", "OBJECT"}:
        return [], []

    writers: list[dict[str, Any]] = []
    readers: list[dict[str, Any]] = []

    if t == "FIELD" and start_node:
        rows = conn.execute(
            """
            SELECT e.edge_type, e.confidence, e.evidence_path, e.evidence_line_start, e.evidence_line_end, e.evidence_snippet,
                   s.node_type AS src_type, s.name AS src_name, s.path AS src_path
            FROM graph_edges e
            JOIN graph_nodes s ON s.node_id=e.src_node_id
            WHERE e.dst_node_id=?
            ORDER BY e.confidence DESC
            """,
            (int(start_node["node_id"]),),
        ).fetchall()
        for r in rows:
            item = {
                "type": r["src_type"],
                "name": r["src_name"],
                "path": r["src_path"] or r["evidence_path"],
                "edge_type": r["edge_type"],
                "confidence": float(r["confidence"] or 0.0),
                "evidence_path": r["evidence_path"],
                "line_start": r["evidence_line_start"],
                "line_end": r["evidence_line_end"],
                "snippet": r["evidence_snippet"],
            }
            if r["edge_type"] in WRITER_EDGE_TYPES:
                writers.append(item)
            if r["edge_type"] in READER_EDGE_TYPES:
                readers.append(item)
        return writers[:50], readers[:50]

    if t == "OBJECT":
        obj = resolved.get("name") or ""
        obj_node = start_node
        if obj_node:
            rows = conn.execute(
                """
                SELECT e.edge_type, e.confidence, e.evidence_path, e.evidence_line_start, e.evidence_line_end, e.evidence_snippet,
                       s.node_type AS src_type, s.name AS src_name, s.path AS src_path
                FROM graph_edges e
                JOIN graph_nodes s ON s.node_id=e.src_node_id
                WHERE e.dst_node_id=?
                  AND e.edge_type IN ('FLOW_UPDATES_OBJECT','FLOW_CREATES_OBJECT','CLASS_QUERIES_OBJECT')
                ORDER BY e.confidence DESC
                """,
                (int(obj_node["node_id"]),),
            ).fetchall()
            for r in rows:
                item = {
                    "type": r["src_type"],
                    "name": r["src_name"],
                    "path": r["src_path"] or r["evidence_path"],
                    "edge_type": r["edge_type"],
                    "confidence": float(r["confidence"] or 0.0),
                    "evidence_path": r["evidence_path"],
                    "line_start": r["evidence_line_start"],
                    "line_end": r["evidence_line_end"],
                    "snippet": r["evidence_snippet"],
                }
                if r["edge_type"] in {"FLOW_UPDATES_OBJECT", "FLOW_CREATES_OBJECT"}:
                    writers.append(item)
                if r["edge_type"] in {"CLASS_QUERIES_OBJECT"}:
                    readers.append(item)

        field_rows = conn.execute(
            """
            SELECT e.edge_type, e.confidence, e.evidence_path, e.evidence_line_start, e.evidence_line_end, e.evidence_snippet,
                   s.node_type AS src_type, s.name AS src_name, s.path AS src_path, d.name AS field_name
            FROM graph_edges e
            JOIN graph_nodes s ON s.node_id=e.src_node_id
            JOIN graph_nodes d ON d.node_id=e.dst_node_id
            WHERE d.node_type='FIELD'
              AND lower(d.name) LIKE lower(?)
              AND e.edge_type IN ('FLOW_WRITES_FIELD','CLASS_WRITES_FIELD','FLOW_READS_FIELD','CLASS_READS_FIELD')
            ORDER BY e.confidence DESC
            LIMIT ?
            """,
            (f"{obj}.%", top_n * 5),
        ).fetchall()
        for r in field_rows:
            item = {
                "type": r["src_type"],
                "name": r["src_name"],
                "path": r["src_path"] or r["evidence_path"],
                "edge_type": r["edge_type"],
                "field": r["field_name"],
                "confidence": float(r["confidence"] or 0.0),
                "evidence_path": r["evidence_path"],
                "line_start": r["evidence_line_start"],
                "line_end": r["evidence_line_end"],
                "snippet": r["evidence_snippet"],
            }
            if r["edge_type"] in {"FLOW_WRITES_FIELD", "CLASS_WRITES_FIELD"}:
                writers.append(item)
            if r["edge_type"] in {"FLOW_READS_FIELD", "CLASS_READS_FIELD"}:
                readers.append(item)

    writers.sort(key=lambda x: x.get("confidence", 0.0), reverse=True)
    readers.sort(key=lambda x: x.get("confidence", 0.0), reverse=True)
    return writers[:50], readers[:50]


def _automation_surface(conn: sqlite3.Connection, resolved: dict[str, Any], top_n: int) -> list[dict[str, Any]]:
    t = resolved.get("type")
    name = resolved.get("name") or ""
    out: list[dict[str, Any]] = []

    if t == "OBJECT":
        rows_trigger = conn.execute(
            "SELECT flow_name, path, status FROM flows WHERE lower(trigger_object)=lower(?) ORDER BY flow_name LIMIT ?",
            (name, top_n),
        ).fetchall()
        out.extend(
            {
                "surface": "record_triggered_flow",
                "name": r["flow_name"],
                "path": r["path"],
                "status": r["status"],
            }
            for r in rows_trigger
        )
        rows_touch = conn.execute(
            """
            SELECT DISTINCT flow_name, path
            FROM (
              SELECT flow_name, path FROM flow_field_reads WHERE lower(full_field_name) LIKE lower(?)
              UNION
              SELECT flow_name, evidence_path AS path
              FROM flow_true_writes
              WHERE write_kind='field_write'
                AND lower(field_full_name) LIKE lower(?)
              UNION
              SELECT flow_name, path FROM flow_field_writes WHERE lower(full_field_name) LIKE lower(?)
            )
            ORDER BY flow_name
            LIMIT ?
            """,
            (f"{name}.%", f"{name}.%", f"{name}.%", top_n),
        ).fetchall()
        out.extend(
            {
                "surface": "flow_touching_object_fields",
                "name": r["flow_name"],
                "path": r["path"],
            }
            for r in rows_touch
        )
        appr = conn.execute(
            """
            SELECT name, path, active
            FROM approval_processes
            WHERE lower(object_name)=lower(?) OR lower(object_name) LIKE lower(?)
            ORDER BY name
            LIMIT ?
            """,
            (name, f"%{name}%", top_n),
        ).fetchall()
        out.extend(
            {
                "surface": "approval_process",
                "name": r["name"],
                "path": r["path"],
                "active": r["active"],
            }
            for r in appr
        )
    elif t == "FIELD":
        rows = conn.execute(
            """
            SELECT DISTINCT flow_name, path, confidence
            FROM (
              SELECT flow_name, path, confidence FROM flow_field_reads WHERE lower(full_field_name)=lower(?) OR lower(full_field_name) LIKE lower(?)
              UNION
              SELECT flow_name, evidence_path AS path, confidence
              FROM flow_true_writes
              WHERE write_kind='field_write'
                AND (lower(field_full_name)=lower(?) OR lower(field_full_name) LIKE lower(?))
              UNION
              SELECT flow_name, path, confidence FROM flow_field_writes WHERE lower(full_field_name)=lower(?) OR lower(full_field_name) LIKE lower(?)
            )
            ORDER BY confidence DESC, flow_name
            LIMIT ?
            """,
            (
                name,
                f"%.{name.split('.',1)[1]}" if "." in name else f"%.{name}",
                name,
                f"%.{name.split('.',1)[1]}" if "." in name else f"%.{name}",
                name,
                f"%.{name.split('.',1)[1]}" if "." in name else f"%.{name}",
                top_n,
            ),
        ).fetchall()
        out.extend(
            {
                "surface": "flow_touching_field",
                "name": r["flow_name"],
                "path": r["path"],
                "confidence": float(r["confidence"] or 0.0),
            }
            for r in rows
        )
    elif t == "FLOW":
        row = conn.execute("SELECT flow_name, path, status, trigger_object FROM flows WHERE lower(flow_name)=lower(?) LIMIT 1", (name,)).fetchone()
        if row:
            out.append(
                {
                    "surface": "flow",
                    "name": row["flow_name"],
                    "path": row["path"],
                    "status": row["status"],
                    "trigger_object": row["trigger_object"],
                }
            )
    # Do not over-trim early; downstream renderers slice as needed.
    return out[:500]


def _security_surface(conn: sqlite3.Connection, tokens: list[str], top_n: int) -> list[dict[str, Any]]:
    refs = []
    for token in tokens:
        rows = conn.execute(
            """
            SELECT ref_type, ref_key, src_name, src_path, snippet, confidence
            FROM "references"
            WHERE src_type='PERMISSION'
              AND (
                lower(ref_key)=lower(?)
                OR lower(ref_key) LIKE lower(?)
              )
            ORDER BY confidence DESC, src_path
            LIMIT ?
            """,
            (token, f"%{token}%", top_n),
        ).fetchall()
        refs.extend(dict(r) for r in rows)

    meta = _match_refs_by_tokens(conn, tokens=tokens, folders=["profiles", "permissionsets"], limit=top_n)
    refs.extend(
        {
            "ref_type": r["ref_kind"],
            "ref_key": r["ref_value"],
            "src_name": "",
            "src_path": r["src_path"],
            "snippet": r["snippet"],
            "confidence": r["confidence"],
        }
        for r in meta
    )
    refs.sort(key=lambda x: float(x.get("confidence") or 0.0), reverse=True)

    dedup: dict[tuple[str, str, str], dict[str, Any]] = {}
    for r in refs:
        key = (r.get("src_path") or "", r.get("ref_key") or "", r.get("src_name") or "")
        if key not in dedup:
            dedup[key] = r
    return list(dedup.values())[:top_n]


def _integration_surface(
    conn: sqlite3.Connection,
    resolved: dict[str, Any],
    graph_edges: list[dict[str, Any]],
    top_n: int,
) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    t = resolved.get("type")
    name = resolved.get("name") or ""

    if t == "ENDPOINT":
        rows = conn.execute(
            """
            SELECT class_name, path, endpoint_value, endpoint_type, line_start, line_end
            FROM apex_endpoints
            WHERE lower(endpoint_value)=lower(?) OR lower(endpoint_value) LIKE lower(?)
            ORDER BY path, line_start
            LIMIT ?
            """,
            (name, f"%{name}%", top_n),
        ).fetchall()
        out.extend(
            {
                "surface": "endpoint_usage",
                "name": r["class_name"],
                "path": r["path"],
                "endpoint": r["endpoint_value"],
                "endpoint_type": r["endpoint_type"],
                "line_start": r["line_start"],
                "line_end": r["line_end"],
            }
            for r in rows
        )
    elif t == "APEX_CLASS":
        rows = conn.execute(
            """
            SELECT class_name, path, endpoint_value, endpoint_type, line_start, line_end
            FROM apex_endpoints
            WHERE lower(class_name)=lower(?)
            ORDER BY line_start
            LIMIT ?
            """,
            (name, top_n),
        ).fetchall()
        out.extend(
            {
                "surface": "class_endpoint",
                "name": r["class_name"],
                "path": r["path"],
                "endpoint": r["endpoint_value"],
                "endpoint_type": r["endpoint_type"],
                "line_start": r["line_start"],
                "line_end": r["line_end"],
            }
            for r in rows
        )

    for e in graph_edges:
        if e["edge_type"] == "CLASS_CALLS_ENDPOINT":
            out.append(
                {
                    "surface": "graph_class_endpoint",
                    "name": f"{e['src']['name']} -> {e['dst']['name']}",
                    "path": e.get("evidence_path") or e["src"].get("path") or e["dst"].get("path"),
                    "confidence": e["confidence"],
                    "snippet": e.get("evidence_snippet"),
                }
            )

    for folder in INTEGRATION_FOLDERS:
        c = int(conn.execute("SELECT COUNT(*) AS c FROM meta_files WHERE lower(folder)=lower(?)", (folder,)).fetchone()["c"])
        out.append({"surface": "folder_count", "name": folder, "path": None, "count": c})

    dedup: dict[tuple[str, str, str], dict[str, Any]] = {}
    for item in out:
        key = (item.get("surface") or "", item.get("name") or "", item.get("path") or "")
        if key not in dedup:
            dedup[key] = item
    return list(dedup.values())[: max(top_n, 10)]


def _ui_surface(conn: sqlite3.Connection, tokens: list[str], top_n: int) -> list[dict[str, Any]]:
    rows = _match_refs_by_tokens(conn, tokens=tokens, folders=["layouts", "flexipages"], limit=top_n)
    return [
        {
            "path": r["src_path"],
            "line_no": r["line_no"],
            "ref_kind": r["ref_kind"],
            "ref_value": r["ref_value"],
            "snippet": r["snippet"],
            "confidence": r["confidence"],
        }
        for r in rows
    ]


def _generic_refs(conn: sqlite3.Connection, tokens: list[str], top_n: int) -> list[dict[str, Any]]:
    rows = _match_refs_by_tokens(conn, tokens=tokens, folders=None, limit=top_n)
    return [
        {
            "path": r["src_path"],
            "folder": r["src_folder"],
            "line_no": r["line_no"],
            "ref_kind": r["ref_kind"],
            "ref_value": r["ref_value"],
            "snippet": r["snippet"],
            "confidence": r["confidence"],
        }
        for r in rows
    ]


def _unknowns(conn: sqlite3.Connection, resolved: dict[str, Any], start_node: sqlite3.Row | None) -> list[str]:
    notes: list[str] = []
    if resolved.get("type") in NODE_TYPE_BY_TARGET and not start_node:
        notes.append("Target not present in dependency graph; using non-graph evidence where possible.")
    graph_edges_count = int(conn.execute("SELECT COUNT(*) AS c FROM graph_edges").fetchone()["c"])
    if graph_edges_count == 0:
        notes.append("Dependency graph is empty; run graph-build for deeper evidence.")

    sharing_files = int(conn.execute("SELECT COUNT(*) AS c FROM meta_files WHERE lower(folder)='sharingrules'").fetchone()["c"])
    sharing_rows = int(conn.execute("SELECT COUNT(*) AS c FROM sharing_rules").fetchone()["c"])
    if sharing_files > 0 and sharing_rows == 0:
        notes.append("No structured sharing_rules rows available; fallback is token-based refs.")

    appr_unknown = conn.execute(
        """
        SELECT
          SUM(CASE WHEN object_name IS NULL OR object_name='' THEN 1 ELSE 0 END) AS unknown_object,
          SUM(CASE WHEN active IS NULL THEN 1 ELSE 0 END) AS unknown_active
        FROM approval_processes
        """
    ).fetchone()
    if int(appr_unknown["unknown_object"] or 0) > 0:
        notes.append(f"Approval process object unknown for {int(appr_unknown['unknown_object'] or 0)} rows.")
    if int(appr_unknown["unknown_active"] or 0) > 0:
        notes.append(f"Approval process active status unknown for {int(appr_unknown['unknown_active'] or 0)} rows.")
    return notes


def build_evidence(
    conn: sqlite3.Connection,
    *,
    target: str,
    depth: int = 2,
    top_n: int = 20,
    min_confidence: float = 0.6,
) -> dict[str, Any]:
    resolved = _resolve_target(conn, target)
    input_hash = _compute_input_hash(conn)
    ck = _cache_key(resolved, depth, top_n)

    cached = conn.execute(
        "SELECT json, input_hash FROM evidence_cache WHERE target_key=? AND depth=? AND top_n=?",
        (ck, depth, top_n),
    ).fetchone()
    if cached and cached["input_hash"] == input_hash:
        payload = json.loads(cached["json"])
        payload["cache_hit"] = True
        return payload

    if not resolved.get("found"):
        result = EvidenceResult(
            target=resolved,
            summary_counts={},
            top_hotspots=[],
            writers=[],
            readers=[],
            automations=[],
            security_surface=[],
            integration_surface=[],
            ui_surface=[],
            refs=[],
            unknowns=["Target not found in repo index."],
            evidence_paths=[],
        )
        payload = result.to_dict()
        payload["cache_hit"] = False
        payload["generated_at"] = datetime.now(timezone.utc).isoformat()
        return payload

    start_node = None
    if resolved["type"] in NODE_TYPE_BY_TARGET:
        start_node = _find_graph_node(conn, NODE_TYPE_BY_TARGET[resolved["type"]], resolved["name"])

    graph_edges: list[dict[str, Any]] = []
    seen_depth: dict[int, int] = {}
    if start_node:
        graph_edges, seen_depth = _collect_graph_edges(
            conn,
            start_node_id=int(start_node["node_id"]),
            depth=depth,
            min_confidence=min_confidence,
        )

    hotspots = _rank_hotspots(
        conn,
        seen_depth=seen_depth,
        graph_edges=graph_edges,
        start_node_id=int(start_node["node_id"]) if start_node else -1,
        top_n=top_n,
    )

    writers, readers = _graph_writer_reader_for_target(
        conn,
        resolved=resolved,
        start_node=start_node,
        top_n=top_n,
    )
    automations = _automation_surface(conn, resolved, top_n=top_n)
    tokens = _target_tokens(resolved)
    security = _security_surface(conn, tokens=tokens, top_n=top_n)
    integration = _integration_surface(conn, resolved=resolved, graph_edges=graph_edges, top_n=top_n)
    ui = _ui_surface(conn, tokens=tokens, top_n=top_n)
    refs = _generic_refs(conn, tokens=tokens, top_n=50)
    unknowns = _unknowns(conn, resolved, start_node)

    summary_counts = {
        "hotspots": len(hotspots),
        "writers": len(writers),
        "readers": len(readers),
        "automations": len(automations),
        "security_surface": len(security),
        "integration_surface": len(integration),
        "ui_surface": len(ui),
        "refs": len(refs),
        "graph_edges_considered": len(graph_edges),
    }

    paths = _collect_paths(
        hotspots,
        writers,
        readers,
        automations,
        security,
        integration,
        ui,
        refs,
        [{"path": resolved.get("path")}],
        [{"evidence_path": e.get("evidence_path")} for e in graph_edges],
    )

    result = EvidenceResult(
        target=resolved,
        summary_counts=summary_counts,
        top_hotspots=hotspots,
        writers=writers[:50],
        readers=readers[:50],
        automations=automations[:500],
        security_surface=security[: max(top_n, 20)],
        integration_surface=integration[: max(top_n, 20)],
        ui_surface=ui[: max(top_n, 20)],
        refs=refs[:50],
        unknowns=unknowns,
        evidence_paths=paths,
    )
    payload = result.to_dict()
    payload["cache_hit"] = False
    payload["generated_at"] = datetime.now(timezone.utc).isoformat()

    try:
        conn.execute(
            """
            INSERT INTO evidence_cache(target_key, depth, top_n, json, created_at, input_hash)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(target_key) DO UPDATE SET
              depth=excluded.depth,
              top_n=excluded.top_n,
              json=excluded.json,
              created_at=excluded.created_at,
              input_hash=excluded.input_hash
            """,
            (
                ck,
                depth,
                top_n,
                json.dumps(payload),
                datetime.now(timezone.utc).isoformat(),
                input_hash,
            ),
        )
        conn.commit()
    except sqlite3.OperationalError:
        # Reads are still valid even if cache write is blocked by another process.
        pass
    return payload
