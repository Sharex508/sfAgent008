from __future__ import annotations

from pathlib import PurePosixPath
import re
import sqlite3
from typing import Any

from rapidfuzz import fuzz, process

from .catalog import MetadataCatalogEntry


META_SUFFIX_RE = re.compile(r"\.([A-Za-z0-9_]+)-meta\.xml$", re.IGNORECASE)


def _name_from_file(path: str, suffix: str) -> str:
    name = PurePosixPath(path).name
    if suffix and name.lower().endswith(suffix.lower()):
        return name[: -len(suffix)]
    if name.lower().endswith("-meta.xml"):
        stem = name[: -len("-meta.xml")]
        if "." in stem:
            return stem.rsplit(".", 1)[0]
        return stem
    return name


def _object_from_path(path: str) -> str | None:
    parts = path.split("/")
    if len(parts) >= 4 and parts[0].lower() == "objects":
        return parts[1]
    return None


def _base_rows_for_entry(conn: sqlite3.Connection, entry: MetadataCatalogEntry) -> list[sqlite3.Row]:
    if entry.scope == "OBJECT_CHILD" and entry.object_child_folder:
        return conn.execute(
            """
            SELECT path, file_name, folder, api_name, sobject, active
            FROM meta_files
            WHERE path LIKE '%/objects/%/' || ? || '/%'
              AND lower(file_name) LIKE lower(?)
            ORDER BY path
            """,
            (entry.object_child_folder, f"%{entry.suffix}"),
        ).fetchall()
    return conn.execute(
        """
        SELECT path, file_name, folder, api_name, sobject, active
        FROM meta_files
        WHERE lower(folder)=lower(?)
          AND lower(file_name) LIKE lower(?)
        ORDER BY path
        """,
        (entry.top_folder, f"%{entry.suffix}"),
    ).fetchall()


def _filter_rows_by_object(rows: list[sqlite3.Row], object_name: str, entry: MetadataCatalogEntry) -> list[sqlite3.Row]:
    obj = (object_name or "").lower()
    out: list[sqlite3.Row] = []
    for r in rows:
        path = str(r["path"])
        obj_from_path = _object_from_path(path)
        if entry.scope == "OBJECT_CHILD":
            if obj_from_path and obj_from_path.lower() == obj:
                out.append(r)
            continue
        sobject = str(r["sobject"] or "")
        if sobject and sobject.lower() == obj:
            out.append(r)
            continue
        file_name = str(r["file_name"] or "")
        if file_name.lower().startswith(obj + "."):
            out.append(r)
            continue
        if f"/{object_name}." in path or f"/{object_name}/" in path:
            out.append(r)
    return out


def _rows_to_items(rows: list[sqlite3.Row], entry: MetadataCatalogEntry) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for r in rows:
        path = str(r["path"])
        obj = _object_from_path(path) or (str(r["sobject"]) if r["sobject"] else None)
        name = _name_from_file(path, entry.suffix)
        items.append(
            {
                "name": name,
                "path": path,
                "object_name": obj,
                "type_key": entry.type_key,
                "scope": entry.scope,
            }
        )
    return items


def count_inventory(conn: sqlite3.Connection, *, entry: MetadataCatalogEntry, object_name: str | None = None) -> dict[str, Any]:
    rows = _base_rows_for_entry(conn, entry)
    if object_name:
        rows = _filter_rows_by_object(rows, object_name, entry)
        line = f"{entry.type_key} on {object_name}: {len(rows)}"
    else:
        line = f"{entry.type_key} total: {len(rows)}"
    items = _rows_to_items(rows, entry)
    evidence = [{"path": x["path"], "line_no": None, "snippet": x["name"], "confidence": 1.0} for x in items[:50]]
    return {"answer_lines": [line], "items": items[:5000], "evidence": evidence[:50], "count": len(items)}


def list_inventory(
    conn: sqlite3.Connection,
    *,
    entry: MetadataCatalogEntry,
    object_name: str | None = None,
    limit: int = 50,
) -> dict[str, Any]:
    rows = _base_rows_for_entry(conn, entry)
    if object_name:
        rows = _filter_rows_by_object(rows, object_name, entry)
        line = f"{entry.type_key} on {object_name}: {len(rows)}"
    else:
        line = f"{entry.type_key} total: {len(rows)}"
    items = _rows_to_items(rows, entry)
    evidence = [{"path": x["path"], "line_no": None, "snippet": x["name"], "confidence": 1.0} for x in items[:50]]
    shown = items[: max(limit, 50)]
    answer_lines = [line]
    answer_lines.extend(f"- {item['name']}" for item in shown)
    if len(items) > len(shown):
        answer_lines.append(f"... and {len(items) - len(shown)} more")
    return {
        "answer_lines": answer_lines,
        "items": shown,
        "evidence": evidence[:50],
        "count": len(items),
    }


def extract_name_candidate(question: str, *, alias: str, object_name: str | None) -> str | None:
    q = (question or "").strip()
    q_low = q.lower()
    alias_low = alias.lower()
    if alias_low in q_low:
        idx = q_low.find(alias_low)
        tail = q[idx + len(alias_low) :].strip(" :.-")
        if tail:
            for stop in (" and ", " which ", " that ", " why ", " where ", " for ", " on "):
                sidx = tail.lower().find(stop)
                if sidx > 0:
                    tail = tail[:sidx].strip()
                    break
            if tail:
                return tail
    if object_name:
        m = re.search(rf"\b{re.escape(object_name)}\.([A-Za-z0-9_]+)\b", q, flags=re.IGNORECASE)
        if m:
            return m.group(1)
    m2 = re.search(r"\b([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)\b", q)
    if m2:
        return f"{m2.group(1)}.{m2.group(2)}"
    return None


def find_inventory_by_name(
    conn: sqlite3.Connection,
    *,
    entry: MetadataCatalogEntry,
    name: str,
    object_name: str | None = None,
) -> dict[str, Any] | None:
    rows = _base_rows_for_entry(conn, entry)
    if object_name:
        rows = _filter_rows_by_object(rows, object_name, entry)
    items = _rows_to_items(rows, entry)
    if not items:
        return None

    raw_name = (name or "").strip()
    query_name = raw_name
    if "." in raw_name and not object_name:
        left, right = raw_name.split(".", 1)
        object_name = left
        query_name = right
    elif "." in raw_name and object_name:
        left, right = raw_name.split(".", 1)
        if left.lower() == object_name.lower():
            query_name = right

    for it in items:
        if str(it["name"]).lower() == query_name.lower():
            return it
        full = f"{it.get('object_name')}.{it['name']}" if it.get("object_name") else it["name"]
        if full.lower() == raw_name.lower():
            return it

    choices = [str(it["name"]) for it in items]
    m = process.extractOne(query_name, choices, scorer=fuzz.WRatio, score_cutoff=80)
    if m:
        best = m[0]
        for it in items:
            if it["name"] == best:
                return it
    return None
