from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from sf_repo_ai.util import line_range_for_span, line_snippet, read_text

SET_ENDPOINT = re.compile(r"setEndpoint\s*\(\s*['\"]([^'\"]+)['\"]\s*\)", re.IGNORECASE)
FROM_OBJECT = re.compile(r"\bFROM\s+([A-Za-z][A-Za-z0-9_]*(?:__c|__kav|__x|__mdt)?)\b", re.IGNORECASE)
SOQL_SELECT = re.compile(
    r"\bSELECT\s+(.+?)\s+\bFROM\s+([A-Za-z][A-Za-z0-9_]*(?:__c|__kav|__x|__mdt)?)",
    re.IGNORECASE | re.DOTALL,
)
EXPLICIT_FIELD = re.compile(
    r"\b([A-Za-z][A-Za-z0-9_]*(?:__c|__kav|__x|__mdt)?|Account|Case|Opportunity|Contact|Lead|Order|Asset|Product2)\.([A-Za-z_][A-Za-z0-9_]*(?:__c|__r)?)\b"
)
DYNAMIC_SOQL = re.compile(r"\bDatabase\.query\s*\(", re.IGNORECASE)
LIST_DECL = re.compile(r"\b(?:List|Set)\s*<\s*([A-Za-z_][A-Za-z0-9_]*)\s*>\s+([A-Za-z_][A-Za-z0-9_]*)")
MAP_DECL = re.compile(
    r"\bMap\s*<\s*[A-Za-z_][A-Za-z0-9_]*\s*,\s*([A-Za-z_][A-Za-z0-9_]*)\s*>\s+([A-Za-z_][A-Za-z0-9_]*)"
)
SIMPLE_DECL = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:=|;)")
DOT_WRITE = re.compile(
    r"\b([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*(?:__c|__r)?|Id|Name|Status|StageName|OwnerId|CreatedDate|LastModifiedDate)\s*="
)
PUT_WRITE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\.put\s*\(\s*['\"]([A-Za-z_][A-Za-z0-9_]*__c)['\"]")
DOT_FIELD = re.compile(
    r"\b([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*(?:__c|__r)?|Id|Name|Status|StageName|OwnerId|CreatedDate|LastModifiedDate)\b"
)
DML_STMT = re.compile(r"\b(insert|update|upsert|delete|undelete)\s+([A-Za-z_][A-Za-z0-9_\.]*)", re.IGNORECASE)
DML_DB = re.compile(
    r"\bDatabase\.(insert|update|upsert|delete|undelete)\s*\(\s*([A-Za-z_][A-Za-z0-9_\.]*)?",
    re.IGNORECASE,
)


def _is_sobject_type(token: str) -> bool:
    if not token:
        return False
    standard = {
        "Account",
        "Case",
        "Opportunity",
        "Contact",
        "Lead",
        "Order",
        "Asset",
        "Product2",
        "User",
        "Task",
        "Event",
        "Quote",
    }
    if token in standard:
        return True
    return token.endswith(("__c", "__x", "__kav", "__mdt"))


def _extract_var_types(text: str) -> dict[str, str]:
    var_to_obj: dict[str, str] = {}

    for m in LIST_DECL.finditer(text):
        obj = m.group(1)
        var = m.group(2)
        if _is_sobject_type(obj):
            var_to_obj[var] = obj

    for m in MAP_DECL.finditer(text):
        obj = m.group(1)
        var = m.group(2)
        if _is_sobject_type(obj):
            var_to_obj[var] = obj

    for m in SIMPLE_DECL.finditer(text):
        obj = m.group(1)
        var = m.group(2)
        if _is_sobject_type(obj):
            var_to_obj[var] = obj

    return var_to_obj


def _dedup_rw(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    best: dict[tuple[str, str | None, str | None, str], dict[str, Any]] = {}
    for row in rows:
        key = (
            row["class_name"],
            row.get("sobject_type"),
            row.get("field_full_name"),
            row.get("rw") or "",
        )
        cur = best.get(key)
        if cur is None or float(row.get("confidence") or 0.0) > float(cur.get("confidence") or 0.0):
            best[key] = row
    return list(best.values())


def parse_apex_file(path: Path, rel_path: str, src_type: str) -> dict:
    text = read_text(path)
    class_name = path.stem

    endpoints: list[dict[str, Any]] = []
    refs: list[dict[str, Any]] = []
    rw_rows: list[dict[str, Any]] = []

    for m in SET_ENDPOINT.finditer(text):
        endpoint_value = m.group(1)
        endpoint_type = "named_credential" if endpoint_value.startswith("callout:") else "hardcoded"
        ls, le = line_range_for_span(text, m.start(), m.end())
        snip = line_snippet(text, ls)
        endpoints.append(
            {
                "class_name": class_name,
                "path": rel_path,
                "endpoint_value": endpoint_value,
                "endpoint_type": endpoint_type,
                "line_start": ls,
                "line_end": le,
            }
        )
        refs.append(
            {
                "ref_type": "ENDPOINT",
                "ref_key": endpoint_value,
                "src_type": "APEX",
                "src_name": class_name,
                "src_path": rel_path,
                "line_start": ls,
                "line_end": le,
                "snippet": snip,
                "confidence": 1.0,
            }
        )

    soql_matches = list(SOQL_SELECT.finditer(text))
    for m in soql_matches:
        fields_part = m.group(1)
        obj = m.group(2)
        ls, le = line_range_for_span(text, m.start(), m.end())
        snip = line_snippet(text, ls)
        refs.append(
            {
                "ref_type": "OBJECT",
                "ref_key": obj,
                "src_type": "APEX",
                "src_name": class_name,
                "src_path": rel_path,
                "line_start": ls,
                "line_end": le,
                "snippet": snip,
                "confidence": 0.85,
            }
        )
        rw_rows.append(
            {
                "class_name": class_name,
                "sobject_type": obj,
                "field_full_name": None,
                "rw": "read",
                "confidence": 0.8,
                "path": rel_path,
                "evidence_snippet": snip,
            }
        )
        fields = [f.strip() for f in fields_part.split(",")]
        for fld in fields:
            if not fld or "(" in fld or ")" in fld or " " in fld or "." in fld:
                continue
            full = f"{obj}.{fld}"
            refs.append(
                {
                    "ref_type": "FIELD",
                    "ref_key": full,
                    "src_type": "APEX",
                    "src_name": class_name,
                    "src_path": rel_path,
                    "line_start": ls,
                    "line_end": le,
                    "snippet": snip,
                    "confidence": 0.85,
                }
            )
            rw_rows.append(
                {
                    "class_name": class_name,
                    "sobject_type": obj,
                    "field_full_name": full,
                    "rw": "read",
                    "confidence": 0.8,
                    "path": rel_path,
                    "evidence_snippet": snip,
                }
            )

    for m in FROM_OBJECT.finditer(text):
        obj = m.group(1)
        ls, le = line_range_for_span(text, m.start(), m.end())
        refs.append(
            {
                "ref_type": "OBJECT",
                "ref_key": obj,
                "src_type": "APEX",
                "src_name": class_name,
                "src_path": rel_path,
                "line_start": ls,
                "line_end": le,
                "snippet": line_snippet(text, ls),
                "confidence": 0.8,
            }
        )

    var_to_obj = _extract_var_types(text)

    write_spans: list[tuple[int, int]] = []
    for m in DOT_WRITE.finditer(text):
        var_name = m.group(1)
        field_name = m.group(2)
        obj = var_to_obj.get(var_name)
        full = f"{obj}.{field_name}" if obj else None
        ls, _ = line_range_for_span(text, m.start(), m.end())
        snip = line_snippet(text, ls)
        write_spans.append((m.start(), m.end()))
        refs.append(
            {
                "ref_type": "FIELD",
                "ref_key": full or f"*.{field_name}",
                "src_type": "APEX",
                "src_name": class_name,
                "src_path": rel_path,
                "line_start": ls,
                "line_end": ls,
                "snippet": snip,
                "confidence": 0.7 if full else 0.5,
            }
        )
        rw_rows.append(
            {
                "class_name": class_name,
                "sobject_type": obj,
                "field_full_name": full,
                "rw": "write",
                "confidence": 0.7 if full else 0.55,
                "path": rel_path,
                "evidence_snippet": snip,
            }
        )

    for m in PUT_WRITE.finditer(text):
        var_name = m.group(1)
        field_name = m.group(2)
        obj = var_to_obj.get(var_name)
        full = f"{obj}.{field_name}" if obj else None
        ls, _ = line_range_for_span(text, m.start(), m.end())
        snip = line_snippet(text, ls)
        write_spans.append((m.start(), m.end()))
        refs.append(
            {
                "ref_type": "FIELD",
                "ref_key": full or f"*.{field_name}",
                "src_type": "APEX",
                "src_name": class_name,
                "src_path": rel_path,
                "line_start": ls,
                "line_end": ls,
                "snippet": snip,
                "confidence": 0.7 if full else 0.5,
            }
        )
        rw_rows.append(
            {
                "class_name": class_name,
                "sobject_type": obj,
                "field_full_name": full,
                "rw": "write",
                "confidence": 0.7 if full else 0.55,
                "path": rel_path,
                "evidence_snippet": snip,
            }
        )

    def _in_write_span(pos: int) -> bool:
        return any(start <= pos < end for start, end in write_spans)

    for m in DOT_FIELD.finditer(text):
        if _in_write_span(m.start()):
            continue
        var_name = m.group(1)
        field_name = m.group(2)
        obj = var_to_obj.get(var_name)
        if not obj:
            continue
        full = f"{obj}.{field_name}"
        ls, _ = line_range_for_span(text, m.start(), m.end())
        snip = line_snippet(text, ls)
        refs.append(
            {
                "ref_type": "FIELD",
                "ref_key": full,
                "src_type": "APEX",
                "src_name": class_name,
                "src_path": rel_path,
                "line_start": ls,
                "line_end": ls,
                "snippet": snip,
                "confidence": 0.6,
            }
        )
        rw_rows.append(
            {
                "class_name": class_name,
                "sobject_type": obj,
                "field_full_name": full,
                "rw": "read",
                "confidence": 0.6,
                "path": rel_path,
                "evidence_snippet": snip,
            }
        )

    for m in DML_STMT.finditer(text):
        expr = (m.group(2) or "").strip()
        var = expr.split(".", 1)[0]
        obj = var_to_obj.get(var)
        ls, _ = line_range_for_span(text, m.start(), m.end())
        rw_rows.append(
            {
                "class_name": class_name,
                "sobject_type": obj,
                "field_full_name": None,
                "rw": "dml",
                "confidence": 0.7 if obj else 0.5,
                "path": rel_path,
                "evidence_snippet": line_snippet(text, ls),
            }
        )

    for m in DML_DB.finditer(text):
        expr = (m.group(2) or "").strip()
        var = expr.split(".", 1)[0] if expr else ""
        obj = var_to_obj.get(var)
        ls, _ = line_range_for_span(text, m.start(), m.end())
        rw_rows.append(
            {
                "class_name": class_name,
                "sobject_type": obj,
                "field_full_name": None,
                "rw": "dml",
                "confidence": 0.7 if obj else 0.5,
                "path": rel_path,
                "evidence_snippet": line_snippet(text, ls),
            }
        )

    for m in EXPLICIT_FIELD.finditer(text):
        full_name = f"{m.group(1)}.{m.group(2)}"
        ls, le = line_range_for_span(text, m.start(), m.end())
        refs.append(
            {
                "ref_type": "FIELD",
                "ref_key": full_name,
                "src_type": "APEX",
                "src_name": class_name,
                "src_path": rel_path,
                "line_start": ls,
                "line_end": le,
                "snippet": line_snippet(text, ls),
                "confidence": 0.9,
            }
        )

    rw_rows = _dedup_rw(rw_rows)
    class_stats = {
        "class_name": class_name,
        "loc": len([ln for ln in text.splitlines() if ln.strip()]),
        "soql_count": len(soql_matches),
        "dml_count": len(list(DML_STMT.finditer(text))) + len(list(DML_DB.finditer(text))),
        "has_dynamic_soql": 1 if DYNAMIC_SOQL.search(text) else 0,
        "has_callout": 1 if endpoints else 0,
        "path": rel_path,
    }

    dedup_refs: dict[tuple[str, str, int], dict[str, Any]] = {}
    for r in refs:
        key = (r["ref_type"], r["ref_key"], int(r["line_start"] or 0))
        cur = dedup_refs.get(key)
        if cur is None or float(r["confidence"] or 0.0) > float(cur["confidence"] or 0.0):
            dedup_refs[key] = r

    return {
        "class_name": class_name,
        "endpoints": endpoints,
        "references": list(dedup_refs.values()),
        "source_type": src_type,
        "class_stats": class_stats,
        "apex_rw": rw_rows,
    }
