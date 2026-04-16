from __future__ import annotations

import sqlite3
from pathlib import Path

from sf_repo_ai.logs.analyzer import analyze_logs
from sf_repo_ai.logs.capture_store import (
    add_capture_log,
    close_capture,
    create_capture,
    ensure_tables,
    get_capture,
    list_capture_logs,
)
from sf_repo_ai.logs.fetcher import fetch_logs_for_window
from sf_repo_ai.logs.parser import parse_log_text


class _FakeToolingClient:
    def __init__(self) -> None:
        self._logs = [
            {"Id": "07L1", "StartTime": "2026-02-20T10:00:00Z", "Status": "Success", "LogLength": 100},
            {"Id": "07L2", "StartTime": "2026-02-20T10:01:00Z", "Status": "Success", "LogLength": 120},
        ]
        self._bodies = {
            "07L1": "System.NullPointerException: Attempt to de-reference a null object",
            "07L2": "USER_DEBUG|[1]|DEBUG|All good",
        }

    def list_apex_logs(self, *, user_id: str, start_ts: str, end_ts: str, limit: int = 200):  # noqa: ANN001
        return self._logs[:limit]

    def get_log_body(self, log_id: str) -> str:
        return self._bodies[log_id]


def test_fetch_logs_for_window_filters_by_text() -> None:
    client = _FakeToolingClient()
    rows = fetch_logs_for_window(
        client,
        user_id="005U1",
        start_ts="2026-02-20T10:00:00Z",
        end_ts="2026-02-20T10:10:00Z",
        filter_text="nullpointerexception",
    )
    assert len(rows) == 1
    assert rows[0]["log"]["Id"] == "07L1"


def test_parse_log_text_extracts_exception_frames_and_limits() -> None:
    text = "\n".join(
        [
            "System.NullPointerException: Attempt to de-reference a null object",
            "Class.SyncACRBatchCallout.execute: line 12, column 1",
            "Trigger.AccountTrigger: line 4, column 1",
            "FLOW_ERROR",
            "Number of SOQL queries: 20 out of 100",
        ]
    )
    parsed = parse_log_text(text)
    assert parsed["exceptions"][0]["type"] == "System.NullPointerException"
    assert len(parsed["stack_frames"]) >= 2
    assert parsed["flow_errors"] == ["FLOW_ERROR"]
    assert parsed["limits"]["soql"] == {"used": 20, "limit": 100}


def test_analyze_logs_maps_stack_frames_to_repo_files(tmp_path: Path) -> None:
    cls_path = tmp_path / "force-app/main/default/classes/SyncACRBatchCallout.cls"
    trg_path = tmp_path / "force-app/main/default/triggers/AccountTrigger.trigger"
    cls_path.parent.mkdir(parents=True, exist_ok=True)
    trg_path.parent.mkdir(parents=True, exist_ok=True)

    cls_path.write_text("\n".join(f"line {i}" for i in range(1, 40)), encoding="utf-8")
    trg_path.write_text("\n".join(f"trigger line {i}" for i in range(1, 20)), encoding="utf-8")

    parsed = parse_log_text(
        "\n".join(
            [
                "System.NullPointerException: Attempt to de-reference a null object",
                "Class.SyncACRBatchCallout.execute: line 12, column 1",
                "Trigger.AccountTrigger: line 4, column 1",
            ]
        )
    )
    report = analyze_logs([{"parsed": parsed}], repo_root=tmp_path)
    assert report["likely_cause"] == "Null dereference"
    assert report["top_stack_frames"][0]["repo_path"] == "force-app/main/default/classes/SyncACRBatchCallout.cls"
    assert report["top_stack_frames"][0]["snippet"]


def test_capture_store_roundtrip() -> None:
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    ensure_tables(conn)
    cid = create_capture(conn, org_alias="myorg", user_id="005U1", filter_text="NullPointer")
    cap = get_capture(conn, cid)
    assert cap is not None
    assert cap["status"] == "running"

    add_capture_log(
        conn,
        capture_id=cid,
        log_id="07L1",
        start_ts="2026-02-20T10:00:00Z",
        length=1000,
        status="Success",
        error=None,
    )
    rows = list_capture_logs(conn, cid)
    assert len(rows) == 1
    assert rows[0]["log_id"] == "07L1"

    close_capture(conn, cid, end_ts="2026-02-20T10:05:00Z", status="completed")
    cap2 = get_capture(conn, cid)
    assert cap2 is not None
    assert cap2["status"] == "completed"

