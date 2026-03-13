from __future__ import annotations

import json
import re
from typing import Any, Dict, List


EXCEPTION_RE = re.compile(r"(?P<etype>[A-Za-z_][A-Za-z0-9_.]+Exception):\s*(?P<msg>.+)")
STACK_RE = re.compile(r"(?P<class>[A-Za-z_][A-Za-z0-9_]*)\.(?P<method>[A-Za-z_][A-Za-z0-9_]*)\:\s*line\s*(?P<line>\d+)")
FLOW_RE = re.compile(r"FLOW[_\w]*\|(?P<name>[A-Za-z0-9_]{3,80})")
APPROVAL_RE = re.compile(r"Approval|ProcessInstance|ProcessDefinition", re.IGNORECASE)
CALLOUT_RE = re.compile(r"https?://[^\s\|\"']+")
DML_RE = re.compile(r"\b(INSERT|UPDATE|DELETE|UPSERT|MERGE)\b", re.IGNORECASE)
SOBJECT_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]{1,39})\b")
ID_RE = re.compile(r"\b[0-9A-Za-z]{15}(?:[0-9A-Za-z]{3})?\b")
DEBUG_ID_RE = re.compile(r"(?P<key>[A-Z][A-Z0-9_]{2,80}_ID)\s*=\s*(?P<rid>[0-9A-Za-z]{15}(?:[0-9A-Za-z]{3})?)")
STEP_MARKER_RE = re.compile(r"PROCESS_STEP=(?P<step>.+)$")
UI_EVENT_RE = re.compile(r"UI_CAPTURE\|(?P<payload>\{.+\})")

FLOW_BAD_FRAGMENTS = (
    "CPU",
    "CALLOUT",
    "SOQL",
    "DML",
    "LIMIT",
    "CODE_UNIT",
    "HEAP",
    "NUMBER OF",
    "MAXIMUM",
)

FLOW_GENERIC_NAMES = {
    "EMAIL",
    "FLOWASSIGNMENT",
    "FLOWDECISION",
    "FLOWLOOKUP",
    "FLOWRECORDCREATE",
    "FLOWRECORDDELETE",
    "FLOWRECORDUPDATE",
    "FLOWSUBFLOW",
    "FUTURE",
    "JOBS",
    "PUSH",
    "SOSL",
    "SOQL",
    "DML",
}


def _is_probable_flow_name(name: str) -> bool:
    n = (name or "").strip()
    if len(n) < 3 or len(n) > 80:
        return False
    if not re.match(r"^[A-Za-z][A-Za-z0-9_]*$", n):
        return False
    u = n.upper()
    if u in FLOW_GENERIC_NAMES:
        return False
    for frag in FLOW_BAD_FRAGMENTS:
        if frag in u:
            return False
    # Skip all-hex-ish tokens that are likely runtime IDs, not metadata names.
    if re.fullmatch(r"[A-Fa-f0-9]{8,}", n):
        return False
    return True


def _is_probable_sf_id(value: str) -> bool:
    v = (value or "").strip()
    if len(v) not in {15, 18}:
        return False
    if not re.fullmatch(r"[0-9A-Za-z]+", v):
        return False
    # Reduce false positives from plain words by requiring mixed character classes.
    has_upper = any(c.isupper() for c in v)
    has_lower = any(c.islower() for c in v)
    has_digit = any(c.isdigit() for c in v)
    return has_upper and has_lower and has_digit


def parse_apex_log(log_id: str, body: str) -> Dict[str, Any]:
    lines = body.splitlines()
    exceptions: List[Dict[str, str]] = []
    stack_frames: List[Dict[str, Any]] = []
    flows: List[str] = []
    callouts: List[str] = []
    dml_ops: List[str] = []
    object_candidates: List[str] = []
    record_ids: List[str] = []
    debug_ids: List[Dict[str, str]] = []
    step_markers: List[str] = []
    ui_events: List[Dict[str, Any]] = []
    markers: List[str] = []
    has_approval_tokens = False

    for line in lines:
        if "PROCESS_CAPTURE_ID=" in line:
            markers.append(line.strip())
        smk = STEP_MARKER_RE.search(line)
        if smk:
            step_name = smk.group("step").strip()
            if step_name and step_name not in step_markers:
                step_markers.append(step_name)
        uem = UI_EVENT_RE.search(line)
        if uem:
            try:
                payload = json.loads(uem.group("payload"))
                if isinstance(payload, dict):
                    ui_events.append(payload)
            except Exception:
                pass
        em = EXCEPTION_RE.search(line)
        if em:
            exceptions.append({"type": em.group("etype"), "message": em.group("msg")[:500]})

        sm = STACK_RE.search(line)
        if sm:
            stack_frames.append(
                {
                    "class": sm.group("class"),
                    "method": sm.group("method"),
                    "line": int(sm.group("line")),
                }
            )

        fm = FLOW_RE.search(line)
        if fm:
            flow_name = fm.group("name").strip()
            if _is_probable_flow_name(flow_name):
                flows.append(flow_name)

        for url in CALLOUT_RE.findall(line):
            callouts.append(url)

        for op in DML_RE.findall(line):
            dml_ops.append(op.upper())

        if APPROVAL_RE.search(line):
            has_approval_tokens = True

        for m in DEBUG_ID_RE.finditer(line):
            rid = m.group("rid")
            if not _is_probable_sf_id(rid):
                continue
            key = m.group("key")
            exists = any(d["record_id"] == rid and d["key"] == key for d in debug_ids)
            if not exists:
                debug_ids.append({"key": key, "record_id": rid})

        for rid in ID_RE.findall(line):
            if not _is_probable_sf_id(rid):
                continue
            if rid not in record_ids:
                record_ids.append(rid)

        if "|" in line and ("SOQL_EXECUTE" in line or "DML_" in line):
            for token in SOBJECT_RE.findall(line):
                if token in {"SOQL_EXECUTE", "DML_BEGIN", "DML_END", "LIMIT_USAGE_FOR_NS", "CODE_UNIT_STARTED"}:
                    continue
                if token.endswith("__c") or token in {"Account", "Opportunity", "Case", "Lead", "Contact", "Task", "User"}:
                    if token not in object_candidates:
                        object_candidates.append(token)

    return {
        "log_id": log_id,
        "line_count": len(lines),
        "markers": markers,
        "exceptions": exceptions,
        "stack_frames": stack_frames,
        "flows": sorted(set(flows)),
        "callouts": sorted(set(callouts)),
        "dml_ops": dml_ops,
        "objects": object_candidates,
        "record_ids": record_ids,
        "debug_ids": debug_ids,
        "step_markers": step_markers,
        "ui_events": ui_events,
        "has_approval_tokens": has_approval_tokens,
        "contains_error": bool(exceptions) or ("FATAL_ERROR" in body),
    }
