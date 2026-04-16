from __future__ import annotations

import json
import re
import sqlite3
import subprocess
from collections import deque
from pathlib import Path

from sf_repo_ai.query_interpreter import parse_question


FLOW_OUT_EDGES = {
    "FLOW_CALLS_SUBFLOW",
    "FLOW_CALLS_APEX_ACTION",
    "FLOW_WRITES_FIELD",
    "FLOW_UPDATES_OBJECT",
    "FLOW_CREATES_OBJECT",
}
APEX_OUT_EDGES = {
    "CLASS_CALLS_CLASS",
    "CLASS_WRITES_FIELD",
    "CLASS_QUERIES_OBJECT",
    "CLASS_CALLS_ENDPOINT",
    "CLASS_READS_FIELD",
}
TRIGGER_OUT_EDGES = {"TRIGGER_CALLS_CLASS"}

FIELD_IN_EDGES = {
    "FLOW_READS_FIELD",
    "FLOW_WRITES_FIELD",
    "CLASS_READS_FIELD",
    "CLASS_WRITES_FIELD",
}
OBJECT_IN_EDGES = {"CLASS_QUERIES_OBJECT", "FLOW_UPDATES_OBJECT", "FLOW_CREATES_OBJECT"}
ENDPOINT_IN_EDGES = {"CLASS_CALLS_ENDPOINT"}

DEPENDENT_IN_EDGES = {
    "FIELD": FIELD_IN_EDGES,
    "OBJECT": OBJECT_IN_EDGES,
    "ENDPOINT": ENDPOINT_IN_EDGES,
    "FLOW": {"FLOW_CALLS_SUBFLOW"},
    "APEX_CLASS": {"CLASS_CALLS_CLASS", "TRIGGER_CALLS_CLASS", "FLOW_CALLS_APEX_ACTION"},
    "TRIGGER": set(),
}


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


def _git_changed_files(repo_root: Path, base_ref: str, head_ref: str) -> tuple[list[str], list[str]]:
    notes: list[str] = []
    cmd = ["git", "-C", str(repo_root), "diff", "--name-only", base_ref, head_ref]
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        notes.append(f"git diff failed: {proc.stderr.strip() or proc.stdout.strip()}")
        return [], notes

    files = [line.strip().replace("\\", "/") for line in proc.stdout.splitlines() if line.strip()]
    return files, notes


def _parse_changed_components(
    conn: sqlite3.Connection,
    changed_files: list[str],
    sfdx_root: str,
) -> tuple[dict[str, set[str]], set[tuple[str, str]], list[str]]:
    changed: dict[str, set[str]] = {
        "FLOW": set(),
        "APEX_CLASS": set(),
        "TRIGGER": set(),
        "FIELD": set(),
        "OBJECT": set(),
    }
    start_nodes: set[tuple[str, str]] = set()
    notes: list[str] = []

    sfdx_prefix = sfdx_root.strip("/") + "/"

    for path in changed_files:
        rel = path
        if not rel.startswith(sfdx_prefix):
            continue
        inner = rel[len(sfdx_prefix) :]

        m = re.match(r"^flows/([^/]+)\.flow-meta\.xml$", inner)
        if m:
            flow = m.group(1)
            changed["FLOW"].add(flow)
            start_nodes.add(("FLOW", flow))
            continue

        m = re.match(r"^classes/([^/]+)\.cls$", inner)
        if m:
            cls = m.group(1)
            changed["APEX_CLASS"].add(cls)
            start_nodes.add(("APEX_CLASS", cls))
            continue

        m = re.match(r"^triggers/([^/]+)\.trigger$", inner)
        if m:
            trig = m.group(1)
            changed["TRIGGER"].add(trig)
            start_nodes.add(("TRIGGER", trig))
            continue

        m = re.match(r"^objects/([^/]+)/fields/([^/]+)\.field-meta\.xml$", inner)
        if m:
            obj = m.group(1)
            fld = m.group(2)
            full = f"{obj}.{fld}"
            changed["FIELD"].add(full)
            start_nodes.add(("FIELD", full))
            continue

        m = re.match(r"^objects/([^/]+)/[^/]+\.object-meta\.xml$", inner)
        if m:
            obj = m.group(1)
            changed["OBJECT"].add(obj)
            start_nodes.add(("OBJECT", obj))
            continue

        m = re.match(r"^objects/([^/]+)/validationRules/[^/]+\.validationRule-meta\.xml$", inner)
        if m:
            obj = m.group(1)
            changed["OBJECT"].add(obj)
            start_nodes.add(("OBJECT", obj))

        if (
            inner.startswith("permissionsets/")
            or inner.startswith("profiles/")
            or inner.startswith("layouts/")
            or inner.startswith("flexipages/")
            or inner.startswith("objects/")
        ):
            ref_rows = conn.execute(
                "SELECT ref_type, ref_key FROM \"references\" WHERE src_path = ?",
                (rel,),
            ).fetchall()
            if not ref_rows:
                notes.append(f"no reference-derived graph start nodes from changed file: {rel}")
            for r in ref_rows:
                if r["ref_type"] == "FIELD":
                    changed["FIELD"].add(r["ref_key"])
                    start_nodes.add(("FIELD", r["ref_key"]))
                elif r["ref_type"] == "OBJECT":
                    changed["OBJECT"].add(r["ref_key"])
                    start_nodes.add(("OBJECT", r["ref_key"]))

    return changed, start_nodes, notes


def _blast_step_rules(node_type: str) -> tuple[str, set[str]]:
    if node_type == "FLOW":
        return "out", FLOW_OUT_EDGES
    if node_type == "APEX_CLASS":
        return "out", APEX_OUT_EDGES
    if node_type == "TRIGGER":
        return "out", TRIGGER_OUT_EDGES
    if node_type == "FIELD":
        return "in", FIELD_IN_EDGES
    if node_type == "OBJECT":
        return "in", OBJECT_IN_EDGES
    if node_type == "ENDPOINT":
        return "in", ENDPOINT_IN_EDGES
    return "out", set()


def _neighbors(
    conn: sqlite3.Connection,
    node_id: int,
    *,
    direction: str,
    edge_types: set[str],
) -> list[sqlite3.Row]:
    if not edge_types:
        return []
    marks = ",".join("?" for _ in edge_types)
    if direction == "out":
        sql = f"""
            SELECT e.edge_type, e.confidence, e.evidence_path, e.evidence_line_start, e.evidence_line_end, e.evidence_snippet,
                   d.node_id, d.node_type, d.name, d.path
            FROM graph_edges e
            JOIN graph_nodes d ON d.node_id = e.dst_node_id
            WHERE e.src_node_id = ?
              AND e.edge_type IN ({marks})
            ORDER BY e.confidence DESC
        """
        params = (node_id, *edge_types)
    else:
        sql = f"""
            SELECT e.edge_type, e.confidence, e.evidence_path, e.evidence_line_start, e.evidence_line_end, e.evidence_snippet,
                   s.node_id, s.node_type, s.name, s.path
            FROM graph_edges e
            JOIN graph_nodes s ON s.node_id = e.src_node_id
            WHERE e.dst_node_id = ?
              AND e.edge_type IN ({marks})
            ORDER BY e.confidence DESC
        """
        params = (node_id, *edge_types)

    return conn.execute(sql, params).fetchall()


def build_blast_radius(
    conn: sqlite3.Connection,
    *,
    repo_root: Path,
    sfdx_root: str,
    base_ref: str,
    head_ref: str,
    depth: int,
) -> dict:
    changed_files, notes = _git_changed_files(repo_root, base_ref, head_ref)
    changed, start_nodes, more_notes = _parse_changed_components(conn, changed_files, sfdx_root)
    notes.extend(more_notes)

    queue: deque[tuple[int, str, int]] = deque()
    start_ids: set[int] = set()
    missing_starts: list[str] = []

    for nt, name in sorted(start_nodes):
        node = _find_node(conn, nt, name)
        if not node:
            missing_starts.append(f"{nt}:{name}")
            continue
        nid = int(node["node_id"])
        start_ids.add(nid)
        queue.append((nid, node["node_type"], 0))

    if missing_starts:
        notes.append("start nodes not found in graph: " + ", ".join(missing_starts[:50]))

    seen_depth: dict[int, int] = {}
    impacted_ids: set[int] = set()

    while queue:
        node_id, node_type, cur_depth = queue.popleft()
        if node_id in seen_depth and seen_depth[node_id] <= cur_depth:
            continue
        seen_depth[node_id] = cur_depth

        if cur_depth >= depth:
            continue

        direction, allowed = _blast_step_rules(node_type)
        for nb in _neighbors(conn, node_id, direction=direction, edge_types=allowed):
            nid = int(nb["node_id"])
            if nid not in start_ids:
                impacted_ids.add(nid)
            nd = cur_depth + 1
            if nid not in seen_depth or seen_depth[nid] > nd:
                queue.append((nid, nb["node_type"], nd))

    impacted_rows = []
    if impacted_ids:
        marks = ",".join("?" for _ in impacted_ids)
        impacted_rows = conn.execute(
            f"SELECT node_id, node_type, name, path FROM graph_nodes WHERE node_id IN ({marks})",
            tuple(impacted_ids),
        ).fetchall()

    impacted: dict[str, list[str]] = {
        "FLOW": [],
        "APEX_CLASS": [],
        "TRIGGER": [],
        "FIELD": [],
        "OBJECT": [],
        "ENDPOINT": [],
    }
    impacted_details: dict[str, list[dict]] = {k: [] for k in impacted}

    for r in impacted_rows:
        nt = r["node_type"]
        if nt not in impacted:
            continue
        impacted[nt].append(r["name"])
        impacted_details[nt].append({"name": r["name"], "path": r["path"]})

    for k in impacted:
        impacted[k] = sorted(set(impacted[k]))
        impacted_details[k] = sorted(impacted_details[k], key=lambda x: (x["name"], x.get("path") or ""))

    hotspots: list[dict] = []
    for r in impacted_rows:
        nid = int(r["node_id"])
        indeg = int(conn.execute("SELECT COUNT(*) AS c FROM graph_edges WHERE dst_node_id=?", (nid,)).fetchone()["c"])
        outdeg = int(conn.execute("SELECT COUNT(*) AS c FROM graph_edges WHERE src_node_id=?", (nid,)).fetchone()["c"])
        hotspots.append(
            {
                "node_type": r["node_type"],
                "name": r["name"],
                "path": r["path"],
                "in_degree": indeg,
                "out_degree": outdeg,
                "degree": indeg + outdeg,
            }
        )

    hotspots.sort(key=lambda x: (x["degree"], x["in_degree"], x["out_degree"], x["name"]), reverse=True)

    return {
        "base_ref": base_ref,
        "head_ref": head_ref,
        "changed": {k: sorted(v) for k, v in changed.items()},
        "changed_files": changed_files,
        "impacted": impacted,
        "impacted_details": impacted_details,
        "hotspots": [
            {
                "node_type": h["node_type"],
                "name": h["name"],
                "in_degree": h["in_degree"],
                "out_degree": h["out_degree"],
                "path": h.get("path"),
            }
            for h in hotspots[:25]
        ],
        "notes": notes + [f"Traversal depth={depth}", "Graph version=v1"],
    }


def _risk_bump(level: str) -> str:
    order = ["LOW", "MEDIUM", "HIGH"]
    idx = order.index(level)
    return order[min(idx + 1, len(order) - 1)]


def _collision_risk(writers: list[dict]) -> str:
    if len(writers) >= 3:
        level = "HIGH"
    elif len(writers) == 2:
        level = "MEDIUM"
    else:
        level = "LOW"

    types = {w["type"] for w in writers}
    if "FLOW" in types and "APEX_CLASS" in types:
        level = _risk_bump(level)
    return level


def _field_node_name(conn: sqlite3.Connection, target: str) -> str | None:
    value = (target or "").strip()
    if "." in value:
        row = conn.execute("SELECT full_name FROM fields WHERE lower(full_name)=lower(?)", (value,)).fetchone()
        if row:
            return row["full_name"]

    parsed = parse_question(f"where {value} is used", conn)
    return parsed.full_field_name


def _object_name(conn: sqlite3.Connection, target: str) -> str | None:
    row = conn.execute("SELECT object_name FROM objects WHERE lower(object_name)=lower(?)", (target,)).fetchone()
    if row:
        return row["object_name"]
    parsed = parse_question(f"explain {target}", conn)
    return parsed.object_name


def _writers_for_field(conn: sqlite3.Connection, full_field_name: str) -> list[dict]:
    field_node = _find_node(conn, "FIELD", full_field_name)
    if not field_node:
        return []

    rows = conn.execute(
        """
        SELECT s.node_type AS src_type, s.name AS src_name, s.path AS src_path,
               e.confidence, e.evidence_path
        FROM graph_edges e
        JOIN graph_nodes s ON s.node_id = e.src_node_id
        WHERE e.dst_node_id = ?
          AND e.edge_type IN ('FLOW_WRITES_FIELD','CLASS_WRITES_FIELD')
        ORDER BY e.confidence DESC
        """,
        (field_node["node_id"],),
    ).fetchall()

    merged: dict[tuple[str, str], dict] = {}
    for r in rows:
        if r["src_type"] not in {"FLOW", "APEX_CLASS"}:
            continue
        k = (r["src_type"], r["src_name"])
        cur = merged.get(k)
        payload = {
            "type": r["src_type"],
            "name": r["src_name"],
            "path": r["src_path"] or r["evidence_path"],
            "confidence": float(r["confidence"] or 0.0),
        }
        if cur is None or payload["confidence"] > cur["confidence"]:
            merged[k] = payload

    out = sorted(merged.values(), key=lambda x: (-x["confidence"], x["type"], x["name"]))
    return out


def detect_collisions(
    conn: sqlite3.Connection,
    *,
    object_name: str | None = None,
    field_name: str | None = None,
) -> dict:
    collisions: list[dict] = []

    if field_name:
        canonical = _field_node_name(conn, field_name)
        if not canonical:
            return {"scope": field_name, "collisions": []}

        writers = _writers_for_field(conn, canonical)
        if len(writers) >= 2:
            collisions.append(
                {
                    "field": canonical,
                    "writers": writers,
                    "risk": _collision_risk(writers),
                    "reason": "Multiple writers can cause order-of-execution / overwrite bugs",
                }
            )
        return {"scope": canonical, "collisions": collisions}

    if object_name:
        obj = _object_name(conn, object_name)
        if not obj:
            return {"scope": object_name, "collisions": []}

        field_rows = conn.execute(
            "SELECT full_name FROM fields WHERE lower(object_name)=lower(?) ORDER BY full_name",
            (obj,),
        ).fetchall()
        for fr in field_rows:
            full = fr["full_name"]
            writers = _writers_for_field(conn, full)
            if len(writers) < 2:
                continue
            collisions.append(
                {
                    "field": full,
                    "writers": writers,
                    "risk": _collision_risk(writers),
                    "reason": "Multiple writers can cause order-of-execution / overwrite bugs",
                }
            )

        collisions.sort(key=lambda x: (len(x["writers"]), x["risk"] == "HIGH"), reverse=True)
        return {"scope": obj, "collisions": collisions[:100]}

    return {"scope": "", "collisions": []}


def _resolve_target_node(conn: sqlite3.Connection, target: str) -> tuple[str | None, str | None, float]:
    t = (target or "").strip()

    if t.startswith("callout:") or t.startswith("http://") or t.startswith("https://"):
        node = _find_node(conn, "ENDPOINT", t)
        if node:
            return "ENDPOINT", node["name"], 0.9
        return "ENDPOINT", t, 0.6

    if "." in t:
        row = conn.execute("SELECT full_name FROM fields WHERE lower(full_name)=lower(?)", (t,)).fetchone()
        if row:
            return "FIELD", row["full_name"], 0.9

    p = parse_question(f"what breaks if I change {t}", conn)
    if p.full_field_name:
        return "FIELD", p.full_field_name, p.confidence
    if p.object_name:
        return "OBJECT", p.object_name, p.confidence
    if p.endpoint:
        return "ENDPOINT", p.endpoint, p.confidence

    row_obj = conn.execute("SELECT object_name FROM objects WHERE lower(object_name)=lower(?)", (t,)).fetchone()
    if row_obj:
        return "OBJECT", row_obj["object_name"], 0.7

    return None, None, 0.0


def _inbound_neighbors(conn: sqlite3.Connection, node_id: int, node_type: str) -> list[sqlite3.Row]:
    allowed = DEPENDENT_IN_EDGES.get(node_type, set())
    if not allowed:
        return []
    marks = ",".join("?" for _ in allowed)
    sql = f"""
        SELECT e.edge_type, e.confidence, e.evidence_path, e.evidence_line_start, e.evidence_line_end, e.evidence_snippet,
               s.node_id, s.node_type, s.name, s.path
        FROM graph_edges e
        JOIN graph_nodes s ON s.node_id = e.src_node_id
        WHERE e.dst_node_id = ?
          AND e.edge_type IN ({marks})
        ORDER BY e.confidence DESC
    """
    return conn.execute(sql, (node_id, *allowed)).fetchall()


def what_breaks(conn: sqlite3.Connection, *, target: str, depth: int) -> dict:
    node_type, name, confidence = _resolve_target_node(conn, target)
    if not node_type or not name:
        return {
            "target": target,
            "resolved": {"node_type": None, "name": None, "confidence": 0.0},
            "counts": {},
            "dependents": [],
            "notes": ["Could not resolve target"],
        }

    node = _find_node(conn, node_type, name)
    if not node:
        return {
            "target": target,
            "resolved": {"node_type": node_type, "name": name, "confidence": confidence},
            "counts": {},
            "dependents": [],
            "notes": ["Target node not found in graph"],
        }

    start_id = int(node["node_id"])
    q: deque[tuple[int, str, int]] = deque([(start_id, node_type, 0)])
    best_depth: dict[int, int] = {}
    dep_best_conf: dict[int, float] = {}
    dep_rows: dict[int, dict] = {}

    while q:
        nid, nt, d = q.popleft()
        if nid in best_depth and best_depth[nid] <= d:
            continue
        best_depth[nid] = d

        if d >= depth:
            continue

        for nb in _inbound_neighbors(conn, nid, nt):
            sid = int(nb["node_id"])
            conf = float(nb["confidence"] or 0.0)
            cur_conf = dep_best_conf.get(sid, -1.0)
            if conf > cur_conf:
                dep_best_conf[sid] = conf
                dep_rows[sid] = {
                    "node_type": nb["node_type"],
                    "name": nb["name"],
                    "path": nb["path"] or nb["evidence_path"],
                    "edge_type": nb["edge_type"],
                    "confidence": conf,
                    "evidence_path": nb["evidence_path"],
                    "evidence_line_start": nb["evidence_line_start"],
                    "evidence_line_end": nb["evidence_line_end"],
                    "evidence_snippet": nb["evidence_snippet"],
                }

            if sid != start_id:
                q.append((sid, nb["node_type"], d + 1))

    dependents = sorted(dep_rows.values(), key=lambda x: (-x["confidence"], x["node_type"], x["name"]))
    counts: dict[str, int] = {}
    for d in dependents:
        counts[d["node_type"]] = counts.get(d["node_type"], 0) + 1

    notes = [f"Traversal depth={depth}"]
    if counts.get("FLOW", 0) > 0:
        notes.append("Update/retest these flows")
    if counts.get("APEX_CLASS", 0) > 0 or counts.get("TRIGGER", 0) > 0:
        notes.append("Retest these classes/triggers")

    if node_type in {"FIELD", "OBJECT"}:
        if node_type == "FIELD":
            perm_count = int(
                conn.execute(
                    "SELECT COUNT(*) AS c FROM \"references\" WHERE src_type='PERMISSION' AND ref_type='FIELD' AND lower(ref_key)=lower(?)",
                    (name,),
                ).fetchone()["c"]
            )
        else:
            perm_count = int(
                conn.execute(
                    """
                    SELECT COUNT(*) AS c
                    FROM "references"
                    WHERE src_type='PERMISSION'
                      AND ((ref_type='OBJECT' AND lower(ref_key)=lower(?))
                        OR (ref_type='FIELD' AND lower(ref_key) LIKE lower(?)))
                    """,
                    (name, f"{name}.%"),
                ).fetchone()["c"]
            )
        if perm_count > 0:
            notes.append("Review permissions")

    return {
        "target": target,
        "resolved": {"node_type": node_type, "name": name, "confidence": confidence},
        "counts": counts,
        "dependents": dependents[:500],
        "notes": notes,
    }


def write_json(path: Path, payload: dict) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return path


def build_test_checklist_markdown(report: dict) -> str:
    resolved = report.get("resolved", {})
    target = resolved.get("name") or report.get("target")
    counts = report.get("counts", {})

    lines: list[str] = []
    lines.append(f"# Test Checklist: {target}")
    lines.append("")
    lines.append("## Scope")
    lines.append(f"- Node Type: {resolved.get('node_type')}")
    lines.append(f"- Confidence: {resolved.get('confidence', 0.0):.2f}")
    lines.append("")

    if counts.get("FLOW", 0) > 0:
        lines.append("## Flow Validation")
        lines.append("- Run flow interviews for impacted flows with representative record types.")
        lines.append("- Validate before/after update transitions on impacted fields.")
        lines.append("- Verify no overwrite from parallel automations.")
        lines.append("")

    if counts.get("APEX_CLASS", 0) > 0 or counts.get("TRIGGER", 0) > 0:
        lines.append("## Apex/Trigger Validation")
        lines.append("- Add/execute unit tests for impacted classes and trigger entry points.")
        lines.append("- Cover DML paths that write affected fields.")
        lines.append("- Verify order-of-execution assumptions and recursion guards.")
        lines.append("")

    if counts.get("ENDPOINT", 0) > 0:
        lines.append("## Callout Validation")
        lines.append("- Add HTTP callout mocks for all endpoint-dependent code paths.")
        lines.append("- Validate timeout/retry/error handling behavior.")
        lines.append("")

    lines.append("## Regression")
    lines.append("- Run targeted smoke tests around impacted objects/fields.")
    lines.append("- Re-run deterministic CLI checks for `deps`, `impact`, and `what-breaks`.")

    return "\n".join(lines)
