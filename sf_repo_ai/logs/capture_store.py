from __future__ import annotations

import sqlite3
from datetime import datetime, timezone
from typing import Any


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def ensure_tables(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS log_captures (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          org_alias TEXT,
          user_id TEXT,
          login_url TEXT,
          sf_username TEXT,
          sf_password TEXT,
          sf_token TEXT,
          start_ts TEXT,
          end_ts TEXT,
          filter_text TEXT,
          status TEXT
        );

        CREATE TABLE IF NOT EXISTS log_capture_logs (
          capture_id INTEGER,
          log_id TEXT,
          start_ts TEXT,
          length INTEGER,
          status TEXT,
          error TEXT,
          PRIMARY KEY (capture_id, log_id)
        );

        CREATE INDEX IF NOT EXISTS idx_log_captures_org_user ON log_captures(org_alias, user_id);
        CREATE INDEX IF NOT EXISTS idx_log_capture_logs_capture ON log_capture_logs(capture_id);
        """
    )
    cols = {str(r[1]) for r in conn.execute("PRAGMA table_info(log_captures)").fetchall()}
    for col, typ in [
        ("login_url", "TEXT"),
        ("sf_username", "TEXT"),
        ("sf_password", "TEXT"),
        ("sf_token", "TEXT"),
    ]:
        if col not in cols:
            conn.execute(f"ALTER TABLE log_captures ADD COLUMN {col} {typ}")
    conn.commit()


def create_capture(
    conn: sqlite3.Connection,
    *,
    org_alias: str,
    user_id: str,
    filter_text: str | None,
    login_url: str | None = None,
    sf_username: str | None = None,
    sf_password: str | None = None,
    sf_token: str | None = None,
    start_ts: str | None = None,
) -> int:
    ensure_tables(conn)
    st = start_ts or utc_now()
    cur = conn.execute(
        """
        INSERT INTO log_captures(
          org_alias, user_id, login_url, sf_username, sf_password, sf_token,
          start_ts, end_ts, filter_text, status
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, NULL, ?, 'running')
        """,
        (org_alias, user_id, login_url, sf_username, sf_password, sf_token, st, filter_text),
    )
    conn.commit()
    return int(cur.lastrowid)


def close_capture(conn: sqlite3.Connection, capture_id: int, *, end_ts: str | None = None, status: str = "completed") -> None:
    ensure_tables(conn)
    et = end_ts or utc_now()
    conn.execute(
        "UPDATE log_captures SET end_ts=?, status=? WHERE id=?",
        (et, status, capture_id),
    )
    conn.commit()


def get_capture(conn: sqlite3.Connection, capture_id: int) -> dict[str, Any] | None:
    ensure_tables(conn)
    row = conn.execute("SELECT * FROM log_captures WHERE id=?", (capture_id,)).fetchone()
    return dict(row) if row else None


def add_capture_log(
    conn: sqlite3.Connection,
    *,
    capture_id: int,
    log_id: str,
    start_ts: str | None,
    length: int | None,
    status: str,
    error: str | None = None,
) -> None:
    ensure_tables(conn)
    conn.execute(
        """
        INSERT OR REPLACE INTO log_capture_logs(capture_id, log_id, start_ts, length, status, error)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (capture_id, log_id, start_ts, int(length or 0), status, error),
    )
    conn.commit()


def list_capture_logs(conn: sqlite3.Connection, capture_id: int) -> list[dict[str, Any]]:
    ensure_tables(conn)
    rows = conn.execute("SELECT * FROM log_capture_logs WHERE capture_id=? ORDER BY start_ts", (capture_id,)).fetchall()
    return [dict(r) for r in rows]
