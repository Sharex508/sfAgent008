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
