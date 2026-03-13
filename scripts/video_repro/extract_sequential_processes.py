#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

ROOT = Path(__file__).resolve().parents[2]
DB_PATH = ROOT / "data" / "index.sqlite"


def _now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _load_trace(trace_json: Path) -> Dict[str, Any]:
    return json.loads(trace_json.read_text(encoding="utf-8"))


def _unique_preserve(items: List[str]) -> List[str]:
    out: List[str] = []
    seen = set()
    for i in items:
        if i and i not in seen:
            seen.add(i)
            out.append(i)
    return out


def _sorted_logs_sequential(logs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    # capture.stop currently fetches logs in StartTime DESC, then appends in that order.
    # Reverse for "oldest -> newest" sequence.
    return list(reversed(logs))


def _is_noise_log(log_item: Dict[str, Any]) -> bool:
    if not isinstance(log_item, dict):
        return True
    has_signal = any(
        [
            log_item.get("stack_frames"),
            log_item.get("flows"),
            log_item.get("objects"),
            log_item.get("debug_ids"),
            log_item.get("ui_events"),
            log_item.get("step_markers"),
            log_item.get("has_approval_tokens"),
            log_item.get("exceptions"),
        ]
    )
    if has_signal:
        return False
    operation = str(log_item.get("operation") or "").strip().lower()
    markers = log_item.get("markers") or []
    return operation.endswith("executeanonymous") and bool(markers)


def _parse_ts(value: str) -> datetime:
    raw = (value or "").strip()
    if not raw:
        return datetime.min.replace(tzinfo=timezone.utc)
    candidates = [raw]
    if raw.endswith("Z"):
        candidates.append(raw.replace("Z", "+00:00"))
    if len(raw) > 5 and raw[-5] in {"+", "-"} and raw[-3] != ":":
        candidates.append(f"{raw[:-2]}:{raw[-2:]}")
    for candidate in candidates:
        try:
            dt = datetime.fromisoformat(candidate)
            if dt.tzinfo is None:
                return dt.replace(tzinfo=timezone.utc)
            return dt.astimezone(timezone.utc)
        except ValueError:
            continue
    return datetime.min.replace(tzinfo=timezone.utc)


def _build_component_sequence(logs: List[Dict[str, Any]], ui_events: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    seq: List[Dict[str, Any]] = []
    seen = set()
    idx = 1

    for ev in ui_events:
        event_id = str(ev.get("event_id") or "")
        ui_log_id = f"UI:{event_id}" if event_id else None
        component_name = str(ev.get("component_name") or "").strip()
        action_name = str(ev.get("action_name") or "").strip()
        if component_name:
            key = ("LWC_COMPONENT", component_name, event_id)
            if key not in seen:
                seen.add(key)
                seq.append(
                    {
                        "seq_no": idx,
                        "component_type": "LWC_COMPONENT",
                        "component_name": component_name,
                        "log_id": ui_log_id,
                        "confidence": "HIGH",
                    }
                )
                idx += 1
        if action_name:
            key = ("UI_ACTION", action_name, event_id)
            if key not in seen:
                seen.add(key)
                seq.append(
                    {
                        "seq_no": idx,
                        "component_type": "UI_ACTION",
                        "component_name": action_name,
                        "log_id": ui_log_id,
                        "confidence": "HIGH",
                    }
                )
                idx += 1

    for lg in logs:
        log_id = str(lg.get("log_id") or "")

        for sf in lg.get("stack_frames", []) or []:
            cls = str(sf.get("class") or "").strip()
            if not cls:
                continue
            key = ("APEX_CLASS", cls, log_id)
            if key in seen:
                continue
            seen.add(key)
            seq.append(
                {
                    "seq_no": idx,
                    "component_type": "APEX_CLASS",
                    "component_name": cls,
                    "log_id": log_id,
                    "confidence": "HIGH",
                }
            )
            idx += 1

        for fl in lg.get("flows", []) or []:
            f = str(fl).strip()
            if not f:
                continue
            key = ("FLOW", f, log_id)
            if key in seen:
                continue
            seen.add(key)
            seq.append(
                {
                    "seq_no": idx,
                    "component_type": "FLOW",
                    "component_name": f,
                    "log_id": log_id,
                    "confidence": "MED",
                }
            )
            idx += 1

        if bool(lg.get("has_approval_tokens")):
            key = ("APPROVAL_PROCESS", "Approval/ProcessInstance", log_id)
            if key not in seen:
                seen.add(key)
                seq.append(
                    {
                        "seq_no": idx,
                        "component_type": "APPROVAL_PROCESS",
                        "component_name": "Approval/ProcessInstance",
                        "log_id": log_id,
                        "confidence": "LOW",
                    }
                )
                idx += 1

        for obj in lg.get("objects", []) or []:
            o = str(obj).strip()
            if not o:
                continue
            key = ("DML_OBJECT", o, log_id)
            if key in seen:
                continue
            seen.add(key)
            seq.append(
                {
                    "seq_no": idx,
                    "component_type": "DML_OBJECT",
                    "component_name": o,
                    "log_id": log_id,
                    "confidence": "MED",
                }
            )
            idx += 1
    return seq


def _build_step_sequence(logs: List[Dict[str, Any]], ui_events: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    active_step_label: Optional[str] = None
    timeline: List[Dict[str, Any]] = []
    for ev in ui_events:
        timeline.append(
            {
                "kind": "ui",
                "ts": _parse_ts(str(ev.get("event_ts") or "")),
                "item": ev,
            }
        )
    for lg in logs:
        timeline.append(
            {
                "kind": "log",
                "ts": _parse_ts(str(lg.get("start_time") or "")),
                "item": lg,
            }
        )
    timeline.sort(key=lambda x: (x["ts"], 0 if x["kind"] == "ui" else 1))

    for i, entry in enumerate(timeline, start=1):
        if entry["kind"] == "ui":
            ev = entry["item"]
            event_id = str(ev.get("event_id") or "")
            step_label = str(ev.get("action_name") or ev.get("event_type") or "UI Event").strip()
            active_step_label = step_label or active_step_label
            details = {
                "log_id": f"UI:{event_id}" if event_id else None,
                "step_label": step_label,
                "step_markers": [],
                "start_time": ev.get("event_ts"),
                "operation": ev.get("event_type"),
                "location": ev.get("page_url") or "Browser UI",
                "line_count": None,
                "classes": [],
                "flows": [],
                "dml_ops": [],
                "objects": [],
                "has_approval_tokens": False,
                "exceptions": [],
                "event_source": "ui",
                "component_name": ev.get("component_name"),
                "action_name": ev.get("action_name"),
                "element_label": ev.get("element_label"),
                "record_id": ev.get("record_id"),
            }
            out.append({"seq_no": i, "details": details})
            continue

        lg = entry["item"]
        classes = _unique_preserve([str(sf.get("class") or "").strip() for sf in (lg.get("stack_frames") or []) if sf])
        flows = _unique_preserve([str(x).strip() for x in (lg.get("flows") or []) if str(x).strip()])
        objs = _unique_preserve([str(x).strip() for x in (lg.get("objects") or []) if str(x).strip()])
        dml = _unique_preserve([str(x).upper().strip() for x in (lg.get("dml_ops") or []) if str(x).strip()])
        exceptions = [f"{e.get('type')}: {e.get('message')}" for e in (lg.get("exceptions") or []) if isinstance(e, dict)]
        step_markers = _unique_preserve([str(x).strip() for x in (lg.get("step_markers") or []) if str(x).strip()])
        step_label = None
        if step_markers:
            active_step_label = step_markers[-1]
            step_label = active_step_label
        else:
            if active_step_label:
                step_label = active_step_label
            else:
                op = str(lg.get("operation") or "").strip()
                if op:
                    step_label = op
                else:
                    step_label = f"Step {i}"
        details = {
            "log_id": lg.get("log_id"),
            "step_label": step_label,
            "step_markers": step_markers,
            "start_time": lg.get("start_time"),
            "operation": lg.get("operation"),
            "location": lg.get("location"),
            "line_count": lg.get("line_count"),
            "classes": classes,
            "flows": flows,
            "dml_ops": dml,
            "objects": objs,
            "has_approval_tokens": bool(lg.get("has_approval_tokens")),
            "exceptions": exceptions,
            "event_source": "log",
        }
        out.append({"seq_no": i, "details": details})
    return out


def _extract_invoker_tokens(text: str) -> List[str]:
    out: List[str] = []
    if not text:
        return out
    patterns = [
        r"/lightning/cmp/c__([A-Za-z0-9_]+)",
        r"\bc__([A-Za-z0-9_]+)\b",
        r"\bc:([A-Za-z0-9_]+)\b",
    ]
    for p in patterns:
        for m in re.findall(p, text):
            token = str(m).strip()
            if token and token not in out:
                out.append(token)
    return out


def _heuristic_invoker_from_text(text: str) -> Optional[str]:
    t = (text or "").lower()
    # Keyword-to-LWC heuristics from repo naming.
    if "clone deal" in t and "quote" in t:
        return "clone_opportunity_quote_linesdirectSales"
    if "create opportunity" in t or "new opportunity" in t:
        return "createNattOppLwc"
    if "create quote" in t or "new quote" in t:
        return "createNattQuoteLwc"
    return None


def _infer_ui_invoker(
    *,
    artifacts_dir: Path,
    ui_events: List[Dict[str, Any]],
    explicit_invoker: Optional[str],
    explicit_source: str,
    explicit_confidence: str,
) -> Tuple[Optional[str], str, str]:
    inv = (explicit_invoker or "").strip()
    if inv:
        return inv, (explicit_source or "manual"), (explicit_confidence or "HIGH")

    for event in ui_events:
        component = str(event.get("component_name") or "").strip()
        if component:
            if component.startswith("c:"):
                return component, "ui_event", "HIGH"
            return f"c:{component}", "ui_event", "HIGH"

    candidate_tokens: List[str] = []
    aggregate_text = ""
    for fn in ("video_steps.json", "video_steps.md", "video_execution_plan.md"):
        p = artifacts_dir / fn
        if not p.exists():
            continue
        txt = p.read_text(encoding="utf-8", errors="ignore")
        aggregate_text += "\n" + txt
        candidate_tokens.extend(_extract_invoker_tokens(txt))

    # 1) Explicit invoker tokens from artifacts.
    if candidate_tokens:
        first = candidate_tokens[0]
        # Store canonical LWC token format as c:<bundleName>
        return f"c:{first}", "artifact_explicit", "MED"

    # 2) Heuristic based on textual action labels in video notes.
    h = _heuristic_invoker_from_text(aggregate_text)
    if h:
        return f"c:{h}", "artifact_heuristic", "LOW"

    return None, "unknown", "UNKNOWN"


def _to_markdown(
    *,
    process_name: str,
    capture_id: str,
    trace_path: Path,
    ui_invoker: Optional[str],
    ui_invoker_source: str,
    ui_invoker_confidence: str,
    logs: List[Dict[str, Any]],
    components: List[Dict[str, Any]],
    steps: List[Dict[str, Any]],
) -> str:
    lines: List[str] = [
        f"# Sequential Process Components - {process_name}",
        "",
        f"- Capture ID: `{capture_id}`",
        f"- Trace JSON: `{trace_path}`",
        f"- Generated At: `{_now_iso()}`",
        f"- Logs analyzed: `{len(logs)}`",
        f"- Components identified: `{len(components)}`",
        f"- UI Invoker: `{ui_invoker or 'UNKNOWN'}`",
        f"- UI Invoker Source: `{ui_invoker_source}`",
        f"- UI Invoker Confidence: `{ui_invoker_confidence}`",
        "",
        "## Component Sequence",
    ]
    for c in components:
        lines.append(
            f"{c['seq_no']}. [{c['component_type']}] {c['component_name']} "
            f"(log: {c['log_id']}, confidence: {c['confidence']})"
        )

    lines.extend(["", "## Per-Log Sequential Notes"])
    for s in steps:
        d = s["details"]
        step_target = d.get("log_id") or d.get("component_name") or "UI"
        lines.append(f"### Step {s['seq_no']} - {d.get('step_label') or 'Unknown'} (`{step_target}`)")
        lines.append(f"- start_time: {d.get('start_time') or 'unknown'}")
        lines.append(f"- operation: {d.get('operation') or 'unknown'}")
        lines.append(f"- location: {d.get('location') or 'unknown'}")
        lines.append(f"- event_source: {d.get('event_source') or 'unknown'}")
        if d.get("component_name"):
            lines.append(f"- ui_component: {d.get('component_name')}")
        if d.get("action_name"):
            lines.append(f"- ui_action: {d.get('action_name')}")
        if d.get("element_label"):
            lines.append(f"- ui_element: {d.get('element_label')}")
        lines.append(f"- line_count: {d.get('line_count')}")
        lines.append(f"- classes: {', '.join(d.get('classes') or []) or 'none'}")
        lines.append(f"- flows: {', '.join(d.get('flows') or []) or 'none'}")
        lines.append(f"- dml_ops: {', '.join(d.get('dml_ops') or []) or 'none'}")
        lines.append(f"- objects: {', '.join(d.get('objects') or []) or 'none'}")
        lines.append(f"- has_approval_tokens: {d.get('has_approval_tokens')}")
        ex = d.get("exceptions") or []
        if ex:
            lines.append(f"- exceptions: {' | '.join(ex)}")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def _ensure_tables(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS process_run_sequence (
            run_id TEXT PRIMARY KEY,
            process_name TEXT NOT NULL,
            capture_id TEXT NOT NULL,
            trace_json_path TEXT NOT NULL,
            created_ts TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS process_step_sequence (
            run_id TEXT NOT NULL,
            seq_no INTEGER NOT NULL,
            log_id TEXT,
            details_json TEXT NOT NULL,
            PRIMARY KEY (run_id, seq_no)
        );

        CREATE TABLE IF NOT EXISTS process_component_sequence (
            run_id TEXT NOT NULL,
            seq_no INTEGER NOT NULL,
            component_type TEXT NOT NULL,
            component_name TEXT NOT NULL,
            log_id TEXT,
            confidence TEXT,
            PRIMARY KEY (run_id, seq_no)
        );

        CREATE TABLE IF NOT EXISTS process_run_context (
            run_id TEXT PRIMARY KEY,
            ui_invoker TEXT,
            ui_invoker_source TEXT,
            ui_invoker_confidence TEXT,
            notes TEXT,
            updated_ts TEXT NOT NULL
        );
        """
    )


def _persist(
    *,
    run_id: str,
    process_name: str,
    capture_id: str,
    trace_json_path: Path,
    ui_invoker: Optional[str],
    ui_invoker_source: str,
    ui_invoker_confidence: str,
    steps: List[Dict[str, Any]],
    components: List[Dict[str, Any]],
    db_path: Path,
) -> None:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(db_path) as conn:
        _ensure_tables(conn)
        conn.execute(
            """
            INSERT OR REPLACE INTO process_run_sequence
            (run_id, process_name, capture_id, trace_json_path, created_ts)
            VALUES (?, ?, ?, ?, ?)
            """,
            (run_id, process_name, capture_id, str(trace_json_path), _now_iso()),
        )
        conn.execute(
            """
            INSERT OR REPLACE INTO process_run_context
            (run_id, ui_invoker, ui_invoker_source, ui_invoker_confidence, notes, updated_ts)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                run_id,
                ui_invoker,
                ui_invoker_source,
                ui_invoker_confidence,
                "Persisted by extract_sequential_processes.py",
                _now_iso(),
            ),
        )
        for s in steps:
            d = s["details"]
            conn.execute(
                """
                INSERT OR REPLACE INTO process_step_sequence
                (run_id, seq_no, log_id, details_json)
                VALUES (?, ?, ?, ?)
                """,
                (run_id, int(s["seq_no"]), str(d.get("log_id") or ""), json.dumps(d, ensure_ascii=False)),
            )
        for c in components:
            conn.execute(
                """
                INSERT OR REPLACE INTO process_component_sequence
                (run_id, seq_no, component_type, component_name, log_id, confidence)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    run_id,
                    int(c["seq_no"]),
                    c["component_type"],
                    c["component_name"],
                    c.get("log_id"),
                    c.get("confidence"),
                ),
            )


def _find_trace_by_capture(capture_id: str) -> Path:
    trace = ROOT / "data" / "artifacts" / capture_id / "trace.json"
    if trace.exists():
        return trace
    raise FileNotFoundError(f"Trace JSON not found for capture: {capture_id}")


def main() -> None:
    ap = argparse.ArgumentParser(description="Extract and persist sequential process components from trace.json")
    ap.add_argument("--process-name", default="direct_sales")
    ap.add_argument("--capture-id", required=True)
    ap.add_argument("--trace-json", default=None, help="Optional trace JSON path; default data/artifacts/<capture_id>/trace.json")
    ap.add_argument("--out", default=None, help="Output markdown path")
    ap.add_argument("--ui-invoker", default=None, help="Optional explicit invoker component, e.g. c:createNattOppLwc")
    ap.add_argument("--ui-invoker-source", default="manual", help="Invoker source label when --ui-invoker is passed")
    ap.add_argument("--ui-invoker-confidence", default="HIGH", help="Invoker confidence label when --ui-invoker is passed")
    ap.add_argument("--db", default=str(DB_PATH))
    args = ap.parse_args()

    trace_path = Path(args.trace_json) if args.trace_json else _find_trace_by_capture(args.capture_id)
    payload = _load_trace(trace_path)
    logs_raw = payload.get("logs") or []
    logs = _sorted_logs_sequential([x for x in logs_raw if isinstance(x, dict)])
    logs = [x for x in logs if not _is_noise_log(x)]
    ui_events = [x for x in (payload.get("ui_events") or []) if isinstance(x, dict)]
    ui_events = sorted(ui_events, key=lambda x: (_parse_ts(str(x.get("event_ts") or "")), str(x.get("event_id") or "")))
    artifacts_dir = trace_path.parent

    ui_invoker, ui_invoker_source, ui_invoker_confidence = _infer_ui_invoker(
        artifacts_dir=artifacts_dir,
        ui_events=ui_events,
        explicit_invoker=args.ui_invoker,
        explicit_source=args.ui_invoker_source,
        explicit_confidence=args.ui_invoker_confidence,
    )

    components = _build_component_sequence(logs, ui_events)
    steps = _build_step_sequence(logs, ui_events)

    out_path = Path(args.out) if args.out else (trace_path.parent / "sequential_components.md")
    out_path.write_text(
        _to_markdown(
            process_name=args.process_name,
            capture_id=args.capture_id,
            trace_path=trace_path,
            ui_invoker=ui_invoker,
            ui_invoker_source=ui_invoker_source,
            ui_invoker_confidence=ui_invoker_confidence,
            logs=logs,
            components=components,
            steps=steps,
        ),
        encoding="utf-8",
    )

    run_id = f"{args.process_name}_{args.capture_id}"
    _persist(
        run_id=run_id,
        process_name=args.process_name,
        capture_id=args.capture_id,
        trace_json_path=trace_path,
        ui_invoker=ui_invoker,
        ui_invoker_source=ui_invoker_source,
        ui_invoker_confidence=ui_invoker_confidence,
        steps=steps,
        components=components,
        db_path=Path(args.db),
    )

    print(
        json.dumps(
            {
                "ok": True,
                "process_name": args.process_name,
                "capture_id": args.capture_id,
                "trace_json": str(trace_path),
                "markdown": str(out_path),
                "db": str(Path(args.db)),
                "run_id": run_id,
                "step_count": len(steps),
                "component_count": len(components),
                "ui_invoker": ui_invoker,
                "ui_invoker_source": ui_invoker_source,
                "ui_invoker_confidence": ui_invoker_confidence,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
