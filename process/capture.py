from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional
import uuid

from llm.ollama_client import OllamaClient
from process.log_parser import parse_apex_log
from process.storage import CaptureStore
from process.trace_builder import (
    build_mermaid_flow,
    build_mermaid_sequence,
    build_trace_graph,
    graph_hash,
    summarize_trace,
)
from process.video_analysis import analyze_video_to_steps
from sfdc.tooling_client import SalesforceToolingClient


@dataclass
class CaptureStartResult:
    capture_id: str
    marker_text: str
    start_ts: str
    trace_flag_id: str
    debug_level_id: str
    execute_anonymous: Dict[str, Any]


@dataclass
class CaptureStopResult:
    capture_id: str
    start_ts: str
    end_ts: str
    fetched_logs: int
    analyzed_logs: int
    marker_matched_logs: int
    artifact_paths: List[str]
    graph_hash: str
    llm_used: bool = False
    llm_model: Optional[str] = None
    narration_path: Optional[str] = None
    llm_error: Optional[str] = None


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(dt_obj: datetime) -> str:
    return dt_obj.replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _soql_datetime(dt_obj: datetime) -> str:
    # SOQL datetime literal format (UTC)
    return dt_obj.strftime("%Y-%m-%dT%H:%M:%SZ")


def _build_narration_prompt(trace_payload: Dict[str, Any]) -> str:
    return (
        "You are a Salesforce technical analyst.\n"
        "Use ONLY the provided trace payload. Do not invent missing facts.\n"
        "Produce concise markdown with these sections:\n"
        "1) Process Summary\n"
        "2) Step-by-step Technical Trace\n"
        "3) Entry Points\n"
        "4) Components Invoked (Flow/Apex/Trigger/Approval/Callout)\n"
        "5) Data Changes (best-effort)\n"
        "6) Risks and Validation Checks\n\n"
        f"TRACE JSON:\n{json.dumps(trace_payload, ensure_ascii=False)}"
    )


def generate_capture_narration(
    *,
    capture_id: str,
    llm_model: str = "gpt-oss:20b",
    ollama_host: Optional[str] = None,
    store: Optional[CaptureStore] = None,
) -> Dict[str, Optional[str]]:
    db = store or CaptureStore()
    artifacts = db.list_artifacts(capture_id)
    trace_json_path = None
    for item in artifacts:
        if item["artifact_type"] == "TRACE_JSON":
            trace_json_path = item["path"]
            break
    if trace_json_path is None:
        raise RuntimeError(f"TRACE_JSON artifact missing for capture {capture_id}")

    trace_payload = json.loads(Path(trace_json_path).read_text(encoding="utf-8"))
    prompt = _build_narration_prompt(trace_payload)
    host = ollama_host or "http://localhost:11434"
    ollama = OllamaClient(host=host, model=llm_model)
    narration = ollama.chat(prompt)

    artifacts_dir = Path("data/artifacts") / capture_id
    artifacts_dir.mkdir(parents=True, exist_ok=True)
    narration_path = artifacts_dir / "narration.md"
    narration_path.write_text(narration, encoding="utf-8")
    now_iso = _iso(_utc_now())
    db.add_artifact(capture_id, "NARRATION_MD", str(narration_path), now_iso)
    return {"narration_path": str(narration_path), "llm_model": llm_model}


def _build_video_repro_plan(
    *,
    capture_id: str,
    video_path: str,
    steps: List[Dict[str, Any]],
    artifact_steps: Path,
) -> str:
    lines = [
        "# Video Replay and Repro Plan",
        "",
        f"- Capture ID: `{capture_id}`",
        f"- Source Video: `{video_path}`",
        "- Objective: Reproduce the sequence shown in the video with deterministic inputs, then capture logs for the same run.",
        "",
        "## 1) Repro steps inferred from video",
    ]
    for idx, step in enumerate(steps, start=1):
        title = str(step.get("title") or f"Step {idx}")
        instruction = str(step.get("instruction") or "No instruction detected.")
        ts = step.get("timestamp") or "00:00:00"
        frame = step.get("evidence_frame")
        frame_note = f" Evidence frame: `{frame}`" if frame else ""
        lines.append(f"{idx}. **[{ts}] {title}** - {instruction}.{frame_note}")

    if not steps:
        lines.append("- No deterministic steps detected. Re-run with smaller interval and higher max_frames.")

    lines.extend(
        [
            "",
            "## 2) CLI: Setup and capture",
            "",
            "Run in this repo with valid org credentials (env or --username/--password/token):",
            "",
            "```bash",
            f"python3 scripts/process_capture.py start --user <SF_USERNAME_OR_USER_ID> --minutes 15 --tail-seconds 180 --capture-id {capture_id}",
            "```\n",
            "Note: keep the same user id/session active while reproducing the flow.",
            "",
            "Reproduce the flow exactly as observed in the video, then stop:",
            "",
            "```bash",
            f"python3 scripts/process_capture.py stop --capture-id {capture_id}",
            "```",
            "",
            "## 3) Scriptable record setup placeholders",
            "",
            "Use these placeholders in a scratch runbook as ground truth for data seeding:",
            "",
            "```apex",
            "/* Auto-generated from video replay analysis (placeholder template) */",
            "String captureId = '{capture_id}';",
            "System.debug('PROCESS_CAPTURE_ID=' + captureId);",
            "// 1) Create seed records shown in video",
            "// 2) Navigate in UI and perform exact user actions per sequence above",
            "// 3) Submit/save/update as demonstrated",
            "",
            "// Example: if your video creates/edits Opportunity lines",
            "Opportunity opp = new Opportunity(Name='Replay-'+captureId, StageName='Prospecting', CloseDate=Date.today());",
            "// insert opp;",
            "```\n",
            "",
            "## 4) Debug log prerequisites",
            "- Trace flag is created at capture start with `SF_REPO_AI_FINEST` if using the CLI flow.",
            "- If running manually in another session, ensure Apex debug levels include FINEST for ApexCode and Workflow.",
            "- Use marker line above (`PROCESS_CAPTURE_ID=<capture_id>`) to correlate logs.",
            "",
            "## 4) Files produced",
            f"- Steps JSON: `{artifact_steps}`",
        ]
    )
    return "\n".join(lines)


def start_capture(
    *,
    client: SalesforceToolingClient,
    user: str,
    minutes: int = 10,
    filter_text: Optional[str] = None,
    tail_seconds: int = 120,
    store: Optional[CaptureStore] = None,
) -> CaptureStartResult:
    db = store or CaptureStore()
    user_id = client.resolve_user_id(user)
    debug_level_id = client.upsert_debug_level("SF_REPO_AI_FINEST")
    trace_flag_id = client.upsert_trace_flag(user_id=user_id, debug_level_id=debug_level_id, minutes=minutes)

    start_ts = _iso(_utc_now())
    capture_id = uuid.uuid4().hex
    capture = db.create_capture(
        capture_id=capture_id,
        org_instance_url=client.cfg.instance_url,
        log_user_id=user_id,
        start_ts=start_ts,
        tail_seconds=tail_seconds,
        filter_text=filter_text,
        marker_text=f"PROCESS_CAPTURE_ID={capture_id}",
    )

    marker_line = capture.marker_text
    anon = f"System.debug('{marker_line}');"
    exec_result = client.execute_anonymous(anon)

    return CaptureStartResult(
        capture_id=capture.id,
        marker_text=capture.marker_text,
        start_ts=capture.start_ts,
        trace_flag_id=trace_flag_id,
        debug_level_id=debug_level_id,
        execute_anonymous=exec_result,
    )


def stop_capture(
    *,
    client: SalesforceToolingClient,
    capture_id: str,
    analyze: bool = True,
    llm: bool = False,
    llm_model: str = "gpt-oss:20b",
    ollama_host: Optional[str] = None,
    store: Optional[CaptureStore] = None,
) -> CaptureStopResult:
    db = store or CaptureStore()
    capture = db.get_capture(capture_id)

    end_dt = _utc_now()
    db.update_capture(capture_id, end_ts=_iso(end_dt), status="STOPPED")

    start_dt = datetime.fromisoformat(capture.start_ts.replace("Z", "+00:00"))
    tail_end = end_dt + timedelta(seconds=max(0, capture.tail_seconds))
    rows = client.query_apex_logs(
        start_iso=_soql_datetime(start_dt),
        end_iso=_soql_datetime(tail_end),
        user_id=capture.log_user_id,
    )

    parsed_logs: List[Dict[str, Any]] = []
    marker_matches = 0
    for row in rows:
        log_id = row["Id"]
        body = client.get_apex_log_body(log_id)
        parsed = parse_apex_log(log_id, body)
        has_marker = any(capture.marker_text in m for m in parsed.get("markers", [])) or (capture.marker_text in body)
        if has_marker:
            marker_matches += 1

        if analyze:
            include_log = has_marker
            if not include_log and capture.filter_text:
                include_log = capture.filter_text.lower() in body.lower()
            if not include_log and parsed.get("contains_error"):
                include_log = True
            if include_log:
                parsed_logs.append(parsed)

        db.upsert_capture_log(
            capture_id,
            {
                "apex_log_id": log_id,
                "start_time": row.get("StartTime"),
                "log_length": row.get("LogLength"),
                "status": row.get("Status"),
                "operation": row.get("Operation"),
                "location": row.get("Location"),
                "has_marker": has_marker,
                "contains_error": parsed.get("contains_error"),
            },
        )

    artifact_paths: List[str] = []
    ghash = ""
    llm_used = False
    narration_path: Optional[str] = None
    llm_error: Optional[str] = None

    if analyze:
        artifacts_dir = Path("data/artifacts") / capture_id
        artifacts_dir.mkdir(parents=True, exist_ok=True)

        graph = build_trace_graph(parsed_logs)
        ghash = graph_hash(graph)

        trace_path = artifacts_dir / "trace.json"
        seq_path = artifacts_dir / "process_sequence.mmd"
        flow_path = artifacts_dir / "process_flow.mmd"
        summary_path = artifacts_dir / "summary.md"

        trace_path.write_text(json.dumps({"graph": graph, "logs": parsed_logs}, indent=2), encoding="utf-8")
        seq_path.write_text(build_mermaid_sequence(graph), encoding="utf-8")
        flow_path.write_text(build_mermaid_flow(graph), encoding="utf-8")
        summary_path.write_text(summarize_trace(graph, parsed_logs), encoding="utf-8")

        now_iso = _iso(_utc_now())
        db.add_artifact(capture_id, "TRACE_JSON", str(trace_path), now_iso)
        db.add_artifact(capture_id, "MERMAID_SEQ", str(seq_path), now_iso)
        db.add_artifact(capture_id, "MERMAID_FLOW", str(flow_path), now_iso)
        db.add_artifact(capture_id, "SUMMARY_MD", str(summary_path), now_iso)

        artifact_paths = [str(trace_path), str(seq_path), str(flow_path), str(summary_path)]
        db.update_capture(capture_id, status="ANALYZED")

        if llm:
            try:
                narr = generate_capture_narration(
                    capture_id=capture_id,
                    llm_model=llm_model,
                    ollama_host=ollama_host,
                    store=db,
                )
                llm_used = True
                narration_path = narr["narration_path"]
                if narration_path:
                    artifact_paths.append(narration_path)
            except Exception as exc:
                llm_error = str(exc)
    else:
        db.update_capture(capture_id, status="STOPPED")

    return CaptureStopResult(
        capture_id=capture_id,
        start_ts=capture.start_ts,
        end_ts=_iso(end_dt),
        fetched_logs=len(rows),
        analyzed_logs=len(parsed_logs),
        marker_matched_logs=marker_matches,
        artifact_paths=artifact_paths,
        graph_hash=ghash,
        llm_used=llm_used,
        llm_model=llm_model if llm else None,
        narration_path=narration_path,
        llm_error=llm_error,
    )


def save_process(
    *,
    capture_id: str,
    name: str,
    description: Optional[str],
    store: Optional[CaptureStore] = None,
) -> Dict[str, Any]:
    db = store or CaptureStore()
    capture = db.get_capture(capture_id)
    artifacts = db.list_artifacts(capture_id)
    trace_json_path = None
    for item in artifacts:
        if item["artifact_type"] == "TRACE_JSON":
            trace_json_path = item["path"]
            break
    if trace_json_path is None:
        raise RuntimeError(f"TRACE_JSON artifact missing for capture {capture_id}")

    data = json.loads(Path(trace_json_path).read_text(encoding="utf-8"))
    graph = data.get("graph", {})
    ghash = graph_hash(graph)

    entry_points = graph.get("entry_points", [])
    now_iso = _iso(_utc_now())
    return db.save_process_definition(
        name=name,
        description=description,
        entry_points=entry_points,
        latest_capture_id=capture.id,
        graph_hash=ghash,
        now_iso=now_iso,
    )


def ingest_video(
    *,
    capture_id: str,
    video_path: str,
    analyze: bool = True,
    llm_model: str = "gpt-oss:20b",
    vision_model: Optional[str] = None,
    ollama_host: Optional[str] = None,
    interval_seconds: int = 5,
    max_frames: int = 80,
    store: Optional[CaptureStore] = None,
) -> Dict[str, Any]:
    db = store or CaptureStore()
    _ = db.get_capture(capture_id)
    artifacts_dir = Path("data/artifacts") / capture_id
    artifacts_dir.mkdir(parents=True, exist_ok=True)
    out_path = artifacts_dir / "video_steps.json"
    steps_path = artifacts_dir / "video_steps.md"
    plan_path = artifacts_dir / "video_execution_plan.md"
    if analyze:
        payload = analyze_video_to_steps(
            capture_id=capture_id,
            video_path=video_path,
            artifacts_dir=artifacts_dir,
            ollama_host=ollama_host or "http://localhost:11434",
            llm_model=llm_model,
            vision_model=vision_model,
            interval_seconds=interval_seconds,
            max_frames=max_frames,
        )
    else:
        payload = {
            "capture_id": capture_id,
            "video_path": video_path,
            "steps": [],
            "status": "STUB",
            "note": "Video attached without analysis.",
        }
    out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    steps_json = payload.get("steps", [])
    steps_lines = ["# Video Steps", ""]
    if steps_json:
        for step in steps_json:
            step_no = step.get("step_number", 0)
            title = step.get("title", f"Step {step_no}")
            ts = step.get("timestamp", "00:00:00")
            instruction = step.get("instruction", "")
            frame = step.get("evidence_frame", "")
            steps_lines.append(f"## {step_no}. {ts} - {title}")
            steps_lines.append(f"- {instruction}")
            if frame:
                steps_lines.append(f"- Evidence: `{frame}`")
            steps_lines.append("")
    else:
        steps_lines.append("- No parsed steps found.")
    steps_path.write_text("\n".join(steps_lines), encoding="utf-8")

    plan_content = _build_video_repro_plan(
        capture_id=capture_id,
        video_path=video_path,
        steps=steps_json,
        artifact_steps=out_path,
    )
    plan_path.write_text(plan_content, encoding="utf-8")
    now_iso = _iso(_utc_now())
    db.add_artifact(capture_id, "VIDEO_STEPS_JSON", str(out_path), now_iso)
    db.add_artifact(capture_id, "VIDEO_STEPS_MD", str(steps_path), now_iso)
    db.add_artifact(capture_id, "VIDEO_EXECUTION_PLAN", str(plan_path), now_iso)
    return {
        "capture_id": capture_id,
        "artifact_path": str(out_path),
        "steps_artifact_path": str(steps_path),
        "execution_plan_path": str(plan_path),
        "status": payload.get("status", "OK"),
        "step_count": len(payload.get("steps", [])),
        "vision_used": bool(payload.get("vision_used", False)),
        "vision_model": payload.get("vision_model"),
        "llm_model": payload.get("llm_model"),
    }
