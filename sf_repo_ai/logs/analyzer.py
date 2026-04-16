from __future__ import annotations

from pathlib import Path
from typing import Any

from sf_repo_ai.util import read_text


def _cause_from_exception(exc_type: str, message: str) -> str:
    t = (exc_type or "").lower()
    m = (message or "").lower()
    if "nullpointer" in t:
        return "Null dereference"
    if "queryexception" in t:
        return "QueryException"
    if "dmlexception" in t:
        return "DMLException"
    if "mixed dml" in m:
        return "Mixed DML"
    if "callout" in m:
        return "Callout exception"
    if "too many soql" in m:
        return "Too many SOQL"
    if "too many dml" in m:
        return "Too many DML"
    if "cpu" in m and "limit" in m:
        return "CPU timeout"
    return "Unknown"


def _snippet(path: Path, line_no: int, radius: int = 3) -> str:
    txt = read_text(path)
    if not txt:
        return ""
    lines = txt.splitlines()
    if not lines:
        return ""
    line_no = max(1, min(line_no, len(lines)))
    start = max(1, line_no - radius)
    end = min(len(lines), line_no + radius)
    return "\n".join(f"{i}: {lines[i-1]}" for i in range(start, end + 1))


def _map_frame_to_file(repo_root: Path, frame: dict[str, Any]) -> tuple[str | None, str]:
    if frame.get("frame_type") == "CLASS":
        cls = frame.get("class_name")
        if cls:
            rel = f"force-app/main/default/classes/{cls}.cls"
            p = repo_root / rel
            if p.exists():
                return rel, _snippet(p, int(frame.get("line") or 1))
    if frame.get("frame_type") == "TRIGGER":
        trg = frame.get("trigger_name")
        if trg:
            rel = f"force-app/main/default/triggers/{trg}.trigger"
            p = repo_root / rel
            if p.exists():
                return rel, _snippet(p, int(frame.get("line") or 1))
    return None, ""


def analyze_logs(parsed_logs: list[dict[str, Any]], repo_root: Path) -> dict[str, Any]:
    all_ex: list[dict[str, Any]] = []
    all_frames: list[dict[str, Any]] = []
    all_flow_errors: list[str] = []

    for lg in parsed_logs:
        parsed = lg.get("parsed") or {}
        all_ex.extend(parsed.get("exceptions") or [])
        all_frames.extend(parsed.get("stack_frames") or [])
        all_flow_errors.extend(parsed.get("flow_errors") or [])

    primary = all_ex[0] if all_ex else None
    likely_cause = _cause_from_exception(primary.get("type", ""), primary.get("message", "")) if primary else "Unknown"

    top_frames = all_frames[:10]
    mapped_frames: list[dict[str, Any]] = []
    for fr in top_frames:
        rel, sn = _map_frame_to_file(repo_root, fr)
        mapped_frames.append({
            "frame": fr,
            "repo_path": rel,
            "snippet": sn,
        })

    suspected_component = None
    for mf in mapped_frames:
        if mf.get("repo_path"):
            suspected_component = mf["repo_path"]
            break

    suggestions: list[str] = []
    if likely_cause == "Null dereference":
        suggestions.append("Add null guards before dereferencing object fields/methods.")
    if likely_cause == "QueryException":
        suggestions.append("Handle empty query results and avoid assuming rows exist.")
    if likely_cause == "DMLException":
        suggestions.append("Review validation rules/triggers for failing DML paths.")
    if likely_cause == "Callout exception":
        suggestions.append("Validate endpoint/auth and add callout retry/error handling.")
    if likely_cause == "Too many SOQL":
        suggestions.append("Move SOQL out of loops and batch queries.")
    if likely_cause == "Too many DML":
        suggestions.append("Bulkify DML and merge operations.")
    if likely_cause == "CPU timeout":
        suggestions.append("Reduce per-transaction work and optimize nested loops/queries.")
    if not suggestions:
        suggestions.append("Inspect top stack frame and reproduce with trace flags at FINEST.")

    return {
        "primary_failure": primary,
        "top_stack_frames": mapped_frames,
        "suspected_component": suspected_component,
        "likely_cause": likely_cause,
        "flow_errors": sorted(set(all_flow_errors)),
        "suggestions": suggestions,
        "log_count": len(parsed_logs),
    }
