from __future__ import annotations

import re
from typing import Any, Dict, List


EXCEPTION_RE = re.compile(r"(?P<etype>[A-Za-z_][A-Za-z0-9_.]+Exception):\s*(?P<msg>.+)")
STACK_RE = re.compile(r"(?P<class>[A-Za-z_][A-Za-z0-9_]*)\.(?P<method>[A-Za-z_][A-Za-z0-9_]*)\:\s*line\s*(?P<line>\d+)")
FLOW_RE = re.compile(r"FLOW[_\w]*\|(?P<name>[A-Za-z0-9_ -]+)")
APPROVAL_RE = re.compile(r"Approval|ProcessInstance|ProcessDefinition", re.IGNORECASE)
CALLOUT_RE = re.compile(r"https?://[^\s\|\"']+")
DML_RE = re.compile(r"\b(INSERT|UPDATE|DELETE|UPSERT|MERGE)\b", re.IGNORECASE)
SOBJECT_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]{1,39})\b")
ID_RE = re.compile(r"\b[0-9A-Za-z]{15}(?:[0-9A-Za-z]{3})?\b")


def parse_apex_log(log_id: str, body: str) -> Dict[str, Any]:
    lines = body.splitlines()
    exceptions: List[Dict[str, str]] = []
    stack_frames: List[Dict[str, Any]] = []
    flows: List[str] = []
    callouts: List[str] = []
    dml_ops: List[str] = []
    object_candidates: List[str] = []
    record_ids: List[str] = []
    markers: List[str] = []
    has_approval_tokens = False

    for line in lines:
        if "PROCESS_CAPTURE_ID=" in line:
            markers.append(line.strip())
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
            flows.append(fm.group("name").strip())

        for url in CALLOUT_RE.findall(line):
            callouts.append(url)

        for op in DML_RE.findall(line):
            dml_ops.append(op.upper())

        if APPROVAL_RE.search(line):
            has_approval_tokens = True

        for rid in ID_RE.findall(line):
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
        "has_approval_tokens": has_approval_tokens,
        "contains_error": bool(exceptions) or ("FATAL_ERROR" in body),
    }
