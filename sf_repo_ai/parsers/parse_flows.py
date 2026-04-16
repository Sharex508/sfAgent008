from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

from sf_repo_ai.util import line_range_for_span, line_snippet, read_text, xml_local_name

EXPLICIT_FIELD = re.compile(
    r"\b([A-Za-z][A-Za-z0-9_]*__(?:c|r)?|[A-Z][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*__(?:c|r)?|[A-Za-z][A-Za-z0-9_]*)\b"
)
DOLLAR_RECORD = re.compile(r"(?:\{!\$Record\.([A-Za-z_][A-Za-z0-9_]*)\}|\$Record\.([A-Za-z_][A-Za-z0-9_]*))")
RECORD_FIELD = re.compile(r"\bRecord\.([A-Za-z_][A-Za-z0-9_]*)\b")
ASSIGN_REF = re.compile(r"^\{!?([^\}]+)\}$")
VAR_FIELD_REF = re.compile(
    r"^([A-Za-z_][A-Za-z0-9_]*|\$Record)\.([A-Za-z_][A-Za-z0-9_]*(?:__c|__r)?|Id|Name|Status|StageName|OwnerId|CreatedDate|LastModifiedDate)$"
)


def _find_text(parent: ET.Element, local_name: str) -> str | None:
    node = parent.find(f"{{*}}{local_name}")
    if node is None or node.text is None:
        return None
    value = node.text.strip()
    return value or None


def _bool_text(parent: ET.Element, local_name: str, default: bool = False) -> bool:
    raw = (_find_text(parent, local_name) or "").strip().lower()
    if raw == "true":
        return True
    if raw == "false":
        return False
    return default


def _clean_ref(text: str | None) -> str:
    if not text:
        return ""
    t = text.strip()
    m = ASSIGN_REF.match(t)
    if m:
        return m.group(1).strip()
    if t.startswith("{!") and t.endswith("}"):
        return t[2:-1].strip()
    return t


def _extract_rhs_value(value_node: ET.Element | None) -> str:
    if value_node is None:
        return ""
    for tag_name in (
        "elementReference",
        "stringValue",
        "numberValue",
        "booleanValue",
        "dateValue",
        "dateTimeValue",
        "sObjectValue",
    ):
        child = value_node.find(f"{{*}}{tag_name}")
        if child is not None and child.text:
            return child.text.strip()
    joined = " ".join((x or "").strip() for x in value_node.itertext()).strip()
    return joined


def _extract_object_field_from_text(
    text: str,
    *,
    trigger_object: str | None,
    default_conf: float,
    allow_ambiguous: bool,
) -> list[tuple[str, float, int, int, str]]:
    out: list[tuple[str, float, int, int, str]] = []

    for m in EXPLICIT_FIELD.finditer(text):
        key = f"{m.group(1)}.{m.group(2)}"
        ls, le = line_range_for_span(text, m.start(), m.end())
        out.append((key, 0.9, ls, le, line_snippet(text, ls)))

    for m in DOLLAR_RECORD.finditer(text):
        field = m.group(1) or m.group(2)
        if not field:
            continue
        if trigger_object:
            key = f"{trigger_object}.{field}"
            conf = 0.7
        else:
            if not allow_ambiguous:
                continue
            key = field
            conf = 0.5
        ls, le = line_range_for_span(text, m.start(), m.end())
        out.append((key, conf, ls, le, line_snippet(text, ls)))

    for m in RECORD_FIELD.finditer(text):
        field = m.group(1)
        if trigger_object:
            key = f"{trigger_object}.{field}"
            conf = default_conf
        else:
            if not allow_ambiguous:
                continue
            key = field
            conf = 0.5
        ls, le = line_range_for_span(text, m.start(), m.end())
        out.append((key, conf, ls, le, line_snippet(text, ls)))

    dedup: dict[tuple[str, int], tuple[str, float, int, int, str]] = {}
    for item in out:
        key = (item[0], item[2])
        if key not in dedup or item[1] > dedup[key][1]:
            dedup[key] = item
    return list(dedup.values())


def _line_for_terms(text: str, *terms: str) -> tuple[int | None, int | None, str]:
    lower = text.lower()
    for term in terms:
        term = (term or "").strip()
        if not term:
            continue
        idx = lower.find(term.lower())
        if idx >= 0:
            ls, le = line_range_for_span(text, idx, idx + len(term))
            return ls, le, line_snippet(text, ls)
    return None, None, ""


def _split_var_field(ref: str) -> tuple[str, str] | None:
    cleaned = _clean_ref(ref)
    m = VAR_FIELD_REF.match(cleaned)
    if not m:
        return None
    return m.group(1), m.group(2)


def _dedup_true_writes(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    best: dict[tuple[str, str | None, str | None, str], dict[str, Any]] = {}
    for row in rows:
        key = (
            row["flow_name"],
            row.get("sobject_type"),
            row.get("field_full_name"),
            row.get("write_kind") or "",
        )
        cur = best.get(key)
        if cur is None or float(row.get("confidence") or 0.0) > float(cur.get("confidence") or 0.0):
            best[key] = row
    return list(best.values())


def parse_flow_meta(path: Path, rel_path: str) -> dict:
    text = read_text(path)
    tree = ET.parse(path)
    root = tree.getroot()

    flow_name = _find_text(root, "fullName") or path.name.replace(".flow-meta.xml", "")
    status = _find_text(root, "status")
    trigger_object = _find_text(root.find("{*}start") if root.find("{*}start") is not None else root, "object") or _find_text(root, "triggerObject")
    trigger_type = _find_text(root.find("{*}start") if root.find("{*}start") is not None else root, "triggerType") or _find_text(root, "triggerType")
    if trigger_type is None:
        start = root.find("{*}start")
        trigger_type = _find_text(start, "recordTriggerType") if start is not None else None

    flow_row = {
        "flow_name": flow_name,
        "status": status,
        "trigger_object": trigger_object,
        "trigger_type": trigger_type,
        "path": rel_path,
    }

    # Variable model (v2).
    var_rows: list[dict[str, Any]] = []
    var_types: dict[str, str | None] = {}
    var_is_collection: dict[str, int] = {}

    for var in root.findall("{*}variables"):
        var_name = _find_text(var, "name")
        if not var_name:
            continue
        data_type = _find_text(var, "dataType")
        is_collection = 1 if _bool_text(var, "isCollection") else 0
        sobject_type = _find_text(var, "objectType")
        row = {
            "flow_name": flow_name,
            "var_name": var_name,
            "data_type": data_type,
            "is_collection": is_collection,
            "sobject_type": sobject_type,
            "path": rel_path,
        }
        var_rows.append(row)
        var_types[var_name] = sobject_type
        var_is_collection[var_name] = is_collection

    if trigger_object:
        var_types["$Record"] = trigger_object
        var_is_collection["$Record"] = 0
        var_rows.append(
            {
                "flow_name": flow_name,
                "var_name": "$Record",
                "data_type": "SObject",
                "is_collection": 0,
                "sobject_type": trigger_object,
                "path": rel_path,
            }
        )

    # Lookup object map helps infer loop variable/object types.
    lookup_object: dict[str, str] = {}
    for lookup in root.findall("{*}recordLookups"):
        lookup_name = _find_text(lookup, "name")
        obj = _find_text(lookup, "object")
        if lookup_name and obj:
            lookup_object[lookup_name] = obj
            if lookup_name not in var_types:
                var_types[lookup_name] = obj
                var_is_collection[lookup_name] = 1
                var_rows.append(
                    {
                        "flow_name": flow_name,
                        "var_name": lookup_name,
                        "data_type": "SObject",
                        "is_collection": 1,
                        "sobject_type": obj,
                        "path": rel_path,
                    }
                )

    for loop in root.findall("{*}loops"):
        loop_name = _find_text(loop, "name")
        coll_ref = _find_text(loop, "collectionReference")
        if not loop_name:
            continue
        inferred_obj = var_types.get(coll_ref or "") or lookup_object.get(coll_ref or "")
        if loop_name not in var_types:
            var_types[loop_name] = inferred_obj
            var_is_collection[loop_name] = 0
            var_rows.append(
                {
                    "flow_name": flow_name,
                    "var_name": loop_name,
                    "data_type": "SObject",
                    "is_collection": 0,
                    "sobject_type": inferred_obj,
                    "path": rel_path,
                }
            )

    # Assignments model (v2).
    assignment_rows: list[dict[str, Any]] = []
    assignment_field_candidates: list[dict[str, Any]] = []
    collection_links: list[tuple[str, str]] = []

    for assignment in root.findall("{*}assignments"):
        assignment_name = _find_text(assignment, "name") or "Assignment"
        for item in assignment.findall("{*}assignmentItems"):
            lhs = _find_text(item, "assignToReference") or ""
            rhs = _extract_rhs_value(item.find("{*}value"))
            assignment_rows.append(
                {
                    "flow_name": flow_name,
                    "assignment_name": assignment_name,
                    "lhs": lhs,
                    "rhs": rhs,
                    "path": rel_path,
                }
            )
            split = _split_var_field(lhs)
            if split:
                var_name, field_api = split
                assignment_field_candidates.append(
                    {
                        "var_name": var_name,
                        "field_api": field_api,
                        "assignment_name": assignment_name,
                        "rhs": rhs,
                    }
                )
            op = (_find_text(item, "operator") or "").lower()
            rhs_ref = _clean_ref(rhs)
            if op == "add":
                dst_var = _clean_ref(lhs).split(".", 1)[0]
                src_var = rhs_ref.split(".", 1)[0]
                if dst_var and src_var:
                    collection_links.append((dst_var, src_var))

    # DML model (v2).
    dml_rows: list[dict[str, Any]] = []
    true_writes: list[dict[str, Any]] = []
    dml_tag_to_type = {
        "recordCreates": "create",
        "recordUpdates": "update",
        "recordDeletes": "delete",
        "recordUpserts": "upsert",
    }
    persisted_vars: set[str] = set()

    for tag_name, dml_type in dml_tag_to_type.items():
        for elem in root.findall(f"{{*}}{tag_name}"):
            elem_name = _find_text(elem, "name") or tag_name
            record_var = _find_text(elem, "inputReference") or ""
            obj = _find_text(elem, "object") or var_types.get(record_var) or (trigger_object if record_var == "$Record" else None)

            dml_rows.append(
                {
                    "flow_name": flow_name,
                    "element_name": elem_name,
                    "dml_type": dml_type,
                    "record_var": record_var,
                    "sobject_type": obj,
                    "path": rel_path,
                }
            )
            if record_var:
                persisted_vars.add(record_var)

            ls, le, snip = _line_for_terms(text, elem_name, record_var, obj or "")
            true_writes.append(
                {
                    "flow_name": flow_name,
                    "sobject_type": obj,
                    "field_full_name": None,
                    "write_kind": "record_write",
                    "confidence": 0.95 if obj else 0.70,
                    "evidence_path": rel_path,
                    "evidence_snippet": snip or f"{elem_name} ({dml_type})",
                    "source_element": elem_name,
                }
            )

            # Direct field assignments inside DML elements are true writes.
            for input_asg in elem.findall("{*}inputAssignments"):
                fld = _find_text(input_asg, "field")
                rhs = _extract_rhs_value(input_asg.find("{*}value"))
                if not fld:
                    continue
                full_field = f"{obj}.{fld}" if obj else None
                _, _, fsnip = _line_for_terms(text, fld, elem_name)
                true_writes.append(
                    {
                        "flow_name": flow_name,
                        "sobject_type": obj,
                        "field_full_name": full_field,
                        "write_kind": "field_write",
                        "confidence": 0.95 if full_field else 0.70,
                        "evidence_path": rel_path,
                        "evidence_snippet": fsnip or f"{elem_name}: {fld} <- {rhs}".strip(),
                        "source_element": elem_name,
                    }
                )
                assignment_rows.append(
                    {
                        "flow_name": flow_name,
                        "assignment_name": elem_name,
                        "lhs": f"{record_var}.{fld}" if record_var else fld,
                        "rhs": rhs,
                        "path": rel_path,
                    }
                )

    # Propagate persisted vars via collection add operations:
    # if collection var is persisted, each source var added to it becomes persisted too.
    changed = True
    while changed:
        changed = False
        for dst, src in collection_links:
            if dst in persisted_vars and src not in persisted_vars:
                persisted_vars.add(src)
                changed = True

    # True field writes from assignments become valid only when var is persisted.
    for cand in assignment_field_candidates:
        var_name = cand["var_name"]
        if var_name not in persisted_vars:
            continue
        obj = var_types.get(var_name) or (trigger_object if var_name == "$Record" else None)
        field_api = cand["field_api"]
        full_field = f"{obj}.{field_api}" if obj else None
        _, _, snip = _line_for_terms(text, cand["assignment_name"], f"{var_name}.{field_api}")
        true_writes.append(
            {
                "flow_name": flow_name,
                "sobject_type": obj,
                "field_full_name": full_field,
                "write_kind": "field_write",
                "confidence": 0.95 if full_field else 0.70,
                "evidence_path": rel_path,
                "evidence_snippet": snip or f"{cand['assignment_name']}: {var_name}.{field_api} <- {cand['rhs']}".strip(),
                "source_element": cand["assignment_name"],
            }
        )

    true_writes = _dedup_true_writes(true_writes)

    # Reads keep existing broad extraction; writes are strict true-writes.
    read_hits = _extract_object_field_from_text(
        text,
        trigger_object=trigger_object,
        default_conf=0.7,
        allow_ambiguous=True,
    )
    reads = [
        {
            "flow_name": flow_name,
            "full_field_name": key,
            "path": rel_path,
            "confidence": conf,
        }
        for key, conf, _, _, _ in read_hits
    ]

    writes = [
        {
            "flow_name": flow_name,
            "full_field_name": row["field_full_name"],
            "path": rel_path,
            "confidence": row["confidence"],
        }
        for row in true_writes
        if row["write_kind"] == "field_write" and row.get("field_full_name")
    ]

    refs = [
        {
            "ref_type": "FIELD",
            "ref_key": key,
            "src_type": "FLOW",
            "src_name": flow_name,
            "src_path": rel_path,
            "line_start": ls,
            "line_end": le,
            "snippet": snip,
            "confidence": conf,
        }
        for key, conf, ls, le, snip in read_hits
    ]
    for row in true_writes:
        if row["write_kind"] == "field_write" and row.get("field_full_name"):
            ls, le, snip = _line_for_terms(text, row.get("source_element") or "", row.get("field_full_name") or "")
            refs.append(
                {
                    "ref_type": "FIELD",
                    "ref_key": row["field_full_name"],
                    "src_type": "FLOW",
                    "src_name": flow_name,
                    "src_path": rel_path,
                    "line_start": ls,
                    "line_end": le,
                    "snippet": snip or row.get("evidence_snippet"),
                    "confidence": float(row.get("confidence") or 0.0),
                }
            )
        elif row["write_kind"] == "record_write" and row.get("sobject_type"):
            ls, le, snip = _line_for_terms(text, row.get("source_element") or "", row.get("sobject_type") or "")
            refs.append(
                {
                    "ref_type": "OBJECT",
                    "ref_key": row["sobject_type"],
                    "src_type": "FLOW",
                    "src_name": flow_name,
                    "src_path": rel_path,
                    "line_start": ls,
                    "line_end": le,
                    "snippet": snip or row.get("evidence_snippet"),
                    "confidence": float(row.get("confidence") or 0.0),
                }
            )

    # De-duplicate references by key + line.
    dedup_refs: dict[tuple[str, str, int], dict[str, Any]] = {}
    for r in refs:
        key = (r["ref_type"], r["ref_key"], int(r["line_start"] or 0))
        cur = dedup_refs.get(key)
        if cur is None or float(r["confidence"] or 0.0) > float(cur["confidence"] or 0.0):
            dedup_refs[key] = r

    # De-duplicate rows.
    dedup_vars = {(r["var_name"], r.get("sobject_type"), r["is_collection"]): r for r in var_rows}
    dedup_assign = {(r["assignment_name"], r["lhs"], r["rhs"]): r for r in assignment_rows}
    dedup_dml = {(r["element_name"], r["dml_type"], r["record_var"], r.get("sobject_type")): r for r in dml_rows}

    return {
        "flow": flow_row,
        "reads": reads,
        "writes": writes,
        "references": list(dedup_refs.values()),
        "flow_vars": list(dedup_vars.values()),
        "flow_assignments": list(dedup_assign.values()),
        "flow_dml": list(dedup_dml.values()),
        "flow_true_writes": true_writes,
    }
