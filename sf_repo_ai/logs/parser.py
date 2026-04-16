from __future__ import annotations

import re
from typing import Any

EXCEPTION_RE = re.compile(r"\b(System\.[A-Za-z0-9_$.]+Exception):\s*(.+)")
CLASS_FRAME_RE = re.compile(r"Class\.([A-Za-z0-9_]+)\.([A-Za-z0-9_<>$]+):\s*line\s*(\d+),\s*column\s*(\d+)")
TRIGGER_FRAME_RE = re.compile(r"Trigger\.([A-Za-z0-9_]+):\s*line\s*(\d+),\s*column\s*(\d+)")
FLOW_ERR_RE = re.compile(r"\b(FLOW_[A-Z_]+|FLOW_ELEMENT_ERROR|FLOW_FAULT)\b")

SOQL_LIMIT_RE = re.compile(r"Number of SOQL queries:\s*(\d+) out of (\d+)")
DML_LIMIT_RE = re.compile(r"Number of DML statements:\s*(\d+) out of (\d+)")
CPU_LIMIT_RE = re.compile(r"Maximum CPU time:\s*(\d+) out of (\d+)")
HEAP_LIMIT_RE = re.compile(r"Maximum heap size:\s*(\d+) out of (\d+)")
CALLOUT_LIMIT_RE = re.compile(r"Number of callouts:\s*(\d+) out of (\d+)")


def parse_log_text(text: str) -> dict[str, Any]:
    lines = text.splitlines() if text else []
    exceptions: list[dict[str, Any]] = []
    class_frames: list[dict[str, Any]] = []
    trigger_frames: list[dict[str, Any]] = []
    flow_errors: list[str] = []

    for i, line in enumerate(lines, start=1):
        for m in EXCEPTION_RE.finditer(line):
            exceptions.append(
                {
                    "type": m.group(1),
                    "message": m.group(2).strip(),
                    "line_no": i,
                    "raw": line.strip(),
                }
            )

        for m in CLASS_FRAME_RE.finditer(line):
            class_frames.append(
                {
                    "frame_type": "CLASS",
                    "class_name": m.group(1),
                    "method": m.group(2),
                    "line": int(m.group(3)),
                    "column": int(m.group(4)),
                    "log_line_no": i,
                    "raw": line.strip(),
                }
            )

        for m in TRIGGER_FRAME_RE.finditer(line):
            trigger_frames.append(
                {
                    "frame_type": "TRIGGER",
                    "trigger_name": m.group(1),
                    "line": int(m.group(2)),
                    "column": int(m.group(3)),
                    "log_line_no": i,
                    "raw": line.strip(),
                }
            )

        for m in FLOW_ERR_RE.finditer(line):
            flow_errors.append(m.group(1))

    def _extract_limit(rx: re.Pattern[str]) -> dict[str, int] | None:
        m = rx.search(text or "")
        if not m:
            return None
        return {"used": int(m.group(1)), "limit": int(m.group(2))}

    limits = {
        "soql": _extract_limit(SOQL_LIMIT_RE),
        "dml": _extract_limit(DML_LIMIT_RE),
        "cpu": _extract_limit(CPU_LIMIT_RE),
        "heap": _extract_limit(HEAP_LIMIT_RE),
        "callouts": _extract_limit(CALLOUT_LIMIT_RE),
    }

    return {
        "exceptions": exceptions,
        "stack_frames": class_frames + trigger_frames,
        "flow_errors": sorted(set(flow_errors)),
        "limits": limits,
        "line_count": len(lines),
    }
