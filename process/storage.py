from __future__ import annotations

import json
import os
import sqlite3
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional


DEFAULT_DB = Path("data/index.sqlite")


@dataclass
class CaptureRecord:
    id: str
    org_instance_url: str
    log_user_id: str
    start_ts: str
    end_ts: Optional[str]
    tail_seconds: int
    filter_text: Optional[str]
    marker_text: str
    status: str
    error: Optional[str]


class CaptureStore:
    def __init__(self, db_path: Path = DEFAULT_DB):
        self.db_path = db_path
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _conn(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_db(self) -> None:
        with self._conn() as conn:
            conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS process_captures (
                    id TEXT PRIMARY KEY,
                    org_instance_url TEXT NOT NULL,
                    log_user_id TEXT NOT NULL,
                    start_ts TEXT NOT NULL,
                    end_ts TEXT,
                    tail_seconds INTEGER NOT NULL,
                    filter_text TEXT,
                    marker_text TEXT NOT NULL,
                    status TEXT NOT NULL,
                    error TEXT
                );

                CREATE TABLE IF NOT EXISTS process_capture_logs (
                    capture_id TEXT NOT NULL,
                    apex_log_id TEXT NOT NULL,
                    start_time TEXT,
                    log_length INTEGER,
                    status TEXT,
                    operation TEXT,
                    location TEXT,
                    has_marker INTEGER NOT NULL DEFAULT 0,
                    contains_error INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (capture_id, apex_log_id)
                );

                CREATE TABLE IF NOT EXISTS process_artifacts (
                    capture_id TEXT NOT NULL,
                    artifact_type TEXT NOT NULL,
                    path TEXT NOT NULL,
                    created_ts TEXT NOT NULL,
                    PRIMARY KEY (capture_id, artifact_type, path)
                );

                CREATE TABLE IF NOT EXISTS process_capture_ui_events (
                    event_id TEXT PRIMARY KEY,
                    capture_id TEXT NOT NULL,
                    event_ts TEXT NOT NULL,
                    event_type TEXT NOT NULL,
                    component_name TEXT,
                    action_name TEXT,
                    element_label TEXT,
                    page_url TEXT,
                    record_id TEXT,
                    details_json TEXT
                );

                CREATE TABLE IF NOT EXISTS process_definitions (
                    process_id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    description TEXT,
                    entry_points_json TEXT,
                    latest_capture_id TEXT,
                    graph_hash TEXT,
                    version INTEGER NOT NULL,
                    last_verified_at TEXT NOT NULL
                );

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

    def create_capture(
        self,
        *,
        capture_id: Optional[str] = None,
        org_instance_url: str,
        log_user_id: str,
        start_ts: str,
        tail_seconds: int,
        filter_text: Optional[str],
        marker_text: str,
    ) -> CaptureRecord:
        cid = capture_id or str(uuid.uuid4())
        with self._conn() as conn:
            conn.execute(
                """
                INSERT INTO process_captures
                (id, org_instance_url, log_user_id, start_ts, end_ts, tail_seconds, filter_text, marker_text, status, error)
                VALUES (?, ?, ?, ?, NULL, ?, ?, ?, 'STARTED', NULL)
                """,
                (cid, org_instance_url, log_user_id, start_ts, tail_seconds, filter_text, marker_text),
            )
        return self.get_capture(cid)

    def get_capture(self, capture_id: str) -> CaptureRecord:
        with self._conn() as conn:
            row = conn.execute("SELECT * FROM process_captures WHERE id = ?", (capture_id,)).fetchone()
        if row is None:
            raise KeyError(f"Capture not found: {capture_id}")
        return CaptureRecord(**dict(row))

    def update_capture(self, capture_id: str, *, end_ts: Optional[str] = None, status: Optional[str] = None, error: Optional[str] = None) -> None:
        sets: List[str] = []
        vals: List[Any] = []
        if end_ts is not None:
            sets.append("end_ts = ?")
            vals.append(end_ts)
        if status is not None:
            sets.append("status = ?")
            vals.append(status)
        if error is not None:
            sets.append("error = ?")
            vals.append(error)
        if not sets:
            return
        vals.append(capture_id)
        with self._conn() as conn:
            conn.execute(f"UPDATE process_captures SET {', '.join(sets)} WHERE id = ?", vals)

    def upsert_capture_log(self, capture_id: str, row: Dict[str, Any]) -> None:
        with self._conn() as conn:
            conn.execute(
                """
                INSERT INTO process_capture_logs
                (capture_id, apex_log_id, start_time, log_length, status, operation, location, has_marker, contains_error)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(capture_id, apex_log_id) DO UPDATE SET
                    start_time=excluded.start_time,
                    log_length=excluded.log_length,
                    status=excluded.status,
                    operation=excluded.operation,
                    location=excluded.location,
                    has_marker=excluded.has_marker,
                    contains_error=excluded.contains_error
                """,
                (
                    capture_id,
                    row.get("apex_log_id"),
                    row.get("start_time"),
                    row.get("log_length"),
                    row.get("status"),
                    row.get("operation"),
                    row.get("location"),
                    int(bool(row.get("has_marker"))),
                    int(bool(row.get("contains_error"))),
                ),
            )

    def add_artifact(self, capture_id: str, artifact_type: str, path: str, created_ts: str) -> None:
        with self._conn() as conn:
            conn.execute(
                """
                INSERT OR IGNORE INTO process_artifacts (capture_id, artifact_type, path, created_ts)
                VALUES (?, ?, ?, ?)
                """,
                (capture_id, artifact_type, path, created_ts),
            )

    def list_artifacts(self, capture_id: str) -> List[Dict[str, Any]]:
        with self._conn() as conn:
            rows = conn.execute(
                "SELECT capture_id, artifact_type, path, created_ts FROM process_artifacts WHERE capture_id = ? ORDER BY artifact_type",
                (capture_id,),
            ).fetchall()
        return [dict(r) for r in rows]

    def add_ui_event(
        self,
        *,
        capture_id: str,
        event_ts: str,
        event_type: str,
        component_name: Optional[str],
        action_name: Optional[str],
        element_label: Optional[str],
        page_url: Optional[str],
        record_id: Optional[str],
        details: Optional[Dict[str, Any]],
        event_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        eid = event_id or str(uuid.uuid4())
        payload = json.dumps(details or {}, ensure_ascii=False)
        with self._conn() as conn:
            conn.execute(
                """
                INSERT INTO process_capture_ui_events
                (event_id, capture_id, event_ts, event_type, component_name, action_name, element_label, page_url, record_id, details_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    eid,
                    capture_id,
                    event_ts,
                    event_type,
                    component_name,
                    action_name,
                    element_label,
                    page_url,
                    record_id,
                    payload,
                ),
            )
        return {
            "event_id": eid,
            "capture_id": capture_id,
            "event_ts": event_ts,
            "event_type": event_type,
            "component_name": component_name,
            "action_name": action_name,
            "element_label": element_label,
            "page_url": page_url,
            "record_id": record_id,
            "details": details or {},
        }

    def list_ui_events(self, capture_id: str) -> List[Dict[str, Any]]:
        with self._conn() as conn:
            rows = conn.execute(
                """
                SELECT event_id, capture_id, event_ts, event_type, component_name, action_name, element_label, page_url, record_id, details_json
                FROM process_capture_ui_events
                WHERE capture_id = ?
                ORDER BY event_ts ASC, event_id ASC
                """,
                (capture_id,),
            ).fetchall()

        out: List[Dict[str, Any]] = []
        for row in rows:
            item = dict(row)
            raw = item.pop("details_json", None)
            try:
                item["details"] = json.loads(raw) if raw else {}
            except Exception:
                item["details"] = {}
            out.append(item)
        return out

    def save_process_definition(
        self,
        *,
        name: str,
        description: Optional[str],
        entry_points: Iterable[str],
        latest_capture_id: str,
        graph_hash: str,
        now_iso: str,
    ) -> Dict[str, Any]:
        with self._conn() as conn:
            existing = conn.execute(
                "SELECT process_id, version FROM process_definitions WHERE name = ? ORDER BY version DESC LIMIT 1",
                (name,),
            ).fetchone()
            if existing:
                process_id = existing["process_id"]
                version = int(existing["version"]) + 1
                conn.execute(
                    """
                    UPDATE process_definitions
                    SET description = ?, entry_points_json = ?, latest_capture_id = ?, graph_hash = ?, version = ?, last_verified_at = ?
                    WHERE process_id = ?
                    """,
                    (
                        description,
                        json.dumps(list(entry_points)),
                        latest_capture_id,
                        graph_hash,
                        version,
                        now_iso,
                        process_id,
                    ),
                )
            else:
                process_id = str(uuid.uuid4())
                version = 1
                conn.execute(
                    """
                    INSERT INTO process_definitions
                    (process_id, name, description, entry_points_json, latest_capture_id, graph_hash, version, last_verified_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        process_id,
                        name,
                        description,
                        json.dumps(list(entry_points)),
                        latest_capture_id,
                        graph_hash,
                        version,
                        now_iso,
                    ),
                )
        return {
            "process_id": process_id,
            "name": name,
            "version": version,
            "latest_capture_id": latest_capture_id,
            "graph_hash": graph_hash,
        }

    def list_process_definitions(self) -> List[Dict[str, Any]]:
        with self._conn() as conn:
            rows = conn.execute(
                """
                SELECT process_id, name, description, entry_points_json, latest_capture_id, graph_hash, version, last_verified_at
                FROM process_definitions
                ORDER BY name ASC
                """
            ).fetchall()
        out: List[Dict[str, Any]] = []
        for row in rows:
            item = dict(row)
            raw = item.get("entry_points_json")
            try:
                item["entry_points"] = json.loads(raw) if raw else []
            except Exception:
                item["entry_points"] = []
            item.pop("entry_points_json", None)
            out.append(item)
        return out

    def list_process_runs(self, *, process_name: Optional[str] = None, limit: int = 50) -> List[Dict[str, Any]]:
        sql = """
            SELECT prs.run_id, prs.process_name, prs.capture_id, prs.trace_json_path, prs.created_ts,
                   prc.ui_invoker, prc.ui_invoker_source, prc.ui_invoker_confidence,
                   COALESCE(ps.step_count, 0) AS step_count,
                   COALESCE(pc.component_count, 0) AS component_count
            FROM process_run_sequence prs
            LEFT JOIN process_run_context prc ON prc.run_id = prs.run_id
            LEFT JOIN (
                SELECT run_id, COUNT(*) AS step_count
                FROM process_step_sequence
                GROUP BY run_id
            ) ps ON ps.run_id = prs.run_id
            LEFT JOIN (
                SELECT run_id, COUNT(*) AS component_count
                FROM process_component_sequence
                GROUP BY run_id
            ) pc ON pc.run_id = prs.run_id
        """
        params: List[Any] = []
        if process_name:
            sql += " WHERE prs.process_name = ?"
            params.append(process_name)
        sql += " ORDER BY prs.created_ts DESC LIMIT ?"
        params.append(max(1, int(limit)))

        with self._conn() as conn:
            rows = conn.execute(sql, params).fetchall()
        return [dict(r) for r in rows]

    def get_process_run_sequence(self, run_id: str) -> Dict[str, Any]:
        with self._conn() as conn:
            row = conn.execute(
                """
                SELECT prs.run_id, prs.process_name, prs.capture_id, prs.trace_json_path, prs.created_ts,
                       prc.ui_invoker, prc.ui_invoker_source, prc.ui_invoker_confidence
                FROM process_run_sequence
                prs
                LEFT JOIN process_run_context prc ON prc.run_id = prs.run_id
                WHERE prs.run_id = ?
                """,
                (run_id,),
            ).fetchone()
            if row is None:
                raise KeyError(f"Process run not found: {run_id}")

            step_rows = conn.execute(
                """
                SELECT seq_no, log_id, details_json
                FROM process_step_sequence
                WHERE run_id = ?
                ORDER BY seq_no ASC
                """,
                (run_id,),
            ).fetchall()
            component_rows = conn.execute(
                """
                SELECT seq_no, component_type, component_name, log_id, confidence
                FROM process_component_sequence
                WHERE run_id = ?
                ORDER BY seq_no ASC
                """,
                (run_id,),
            ).fetchall()

        steps: List[Dict[str, Any]] = []
        for r in step_rows:
            item = dict(r)
            raw = item.get("details_json")
            try:
                item["details"] = json.loads(raw) if raw else {}
            except Exception:
                item["details"] = {}
            item.pop("details_json", None)
            steps.append(item)

        return {
            **dict(row),
            "steps": steps,
            "components": [dict(r) for r in component_rows],
        }

    def upsert_process_run_context(
        self,
        *,
        run_id: str,
        ui_invoker: Optional[str],
        source: Optional[str],
        confidence: Optional[str],
        notes: Optional[str],
        updated_ts: str,
    ) -> Dict[str, Any]:
        with self._conn() as conn:
            conn.execute(
                """
                INSERT INTO process_run_context
                (run_id, ui_invoker, ui_invoker_source, ui_invoker_confidence, notes, updated_ts)
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(run_id) DO UPDATE SET
                    ui_invoker=excluded.ui_invoker,
                    ui_invoker_source=excluded.ui_invoker_source,
                    ui_invoker_confidence=excluded.ui_invoker_confidence,
                    notes=excluded.notes,
                    updated_ts=excluded.updated_ts
                """,
                (run_id, ui_invoker, source, confidence, notes, updated_ts),
            )
            row = conn.execute(
                """
                SELECT run_id, ui_invoker, ui_invoker_source, ui_invoker_confidence, notes, updated_ts
                FROM process_run_context
                WHERE run_id = ?
                """,
                (run_id,),
            ).fetchone()
        return dict(row) if row else {
            "run_id": run_id,
            "ui_invoker": ui_invoker,
            "ui_invoker_source": source,
            "ui_invoker_confidence": confidence,
            "notes": notes,
            "updated_ts": updated_ts,
        }
