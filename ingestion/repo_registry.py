from __future__ import annotations

import sqlite3
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

DEFAULT_DB = Path("data/index.sqlite")


class RepoRegistry:
    def __init__(self, db_path: Path = DEFAULT_DB):
        self.db_path = db_path
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _conn(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _ensure_column(self, conn: sqlite3.Connection, table: str, column: str, definition: str) -> None:
        cols = {row[1] for row in conn.execute(f"PRAGMA table_info({table})").fetchall()}
        if column in cols:
            return
        try:
            conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")
        except sqlite3.OperationalError as exc:
            if "duplicate column name" not in str(exc).lower():
                raise

    def _init_db(self) -> None:
        with self._conn() as conn:
            conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS repo_sources (
                    source_id TEXT PRIMARY KEY,
                    provider TEXT NOT NULL,
                    name TEXT NOT NULL,
                    clone_url TEXT NOT NULL,
                    branch TEXT,
                    local_path TEXT NOT NULL,
                    is_active INTEGER NOT NULL DEFAULT 0,
                    sync_enabled INTEGER NOT NULL DEFAULT 1,
                    sync_interval_minutes INTEGER NOT NULL DEFAULT 1440,
                    last_synced_ts TEXT,
                    last_synced_commit TEXT,
                    last_sync_status TEXT,
                    last_sync_error TEXT,
                    created_ts TEXT NOT NULL,
                    updated_ts TEXT NOT NULL
                );

                CREATE UNIQUE INDEX IF NOT EXISTS idx_repo_sources_clone_url ON repo_sources(clone_url);
                CREATE INDEX IF NOT EXISTS idx_repo_sources_active ON repo_sources(is_active);
                CREATE INDEX IF NOT EXISTS idx_repo_sources_sync_enabled ON repo_sources(sync_enabled);
                """
            )
            extra_columns = {
                "repo_kind": "TEXT",
                "has_sfdx_project": "INTEGER DEFAULT 0",
                "has_force_app": "INTEGER DEFAULT 0",
                "metadata_root": "TEXT",
                "validation_status": "TEXT",
                "validation_error": "TEXT",
                "last_indexed_ts": "TEXT",
                "last_indexed_commit": "TEXT",
                "last_index_status": "TEXT",
                "last_index_error": "TEXT",
                "docs_count": "INTEGER DEFAULT 0",
                "meta_files": "INTEGER DEFAULT 0",
                "graph_nodes": "INTEGER DEFAULT 0",
                "graph_edges": "INTEGER DEFAULT 0",
                "objects_count": "INTEGER DEFAULT 0",
                "fields_count": "INTEGER DEFAULT 0",
                "classes_count": "INTEGER DEFAULT 0",
                "triggers_count": "INTEGER DEFAULT 0",
                "flows_count": "INTEGER DEFAULT 0",
                "cleanup_exempt": "INTEGER DEFAULT 0",
            }
            for column, definition in extra_columns.items():
                self._ensure_column(conn, "repo_sources", column, definition)

    def list_sources(self) -> List[Dict[str, Any]]:
        with self._conn() as conn:
            rows = conn.execute(
                "SELECT * FROM repo_sources ORDER BY is_active DESC, updated_ts DESC"
            ).fetchall()
        return [dict(r) for r in rows]

    def get_source(self, source_id: str) -> Dict[str, Any]:
        with self._conn() as conn:
            row = conn.execute("SELECT * FROM repo_sources WHERE source_id = ?", (source_id,)).fetchone()
        if row is None:
            raise KeyError(f"Repo source not found: {source_id}")
        return dict(row)

    def get_source_by_clone_url(self, clone_url: str) -> Optional[Dict[str, Any]]:
        with self._conn() as conn:
            row = conn.execute("SELECT * FROM repo_sources WHERE clone_url = ?", (clone_url,)).fetchone()
        return dict(row) if row is not None else None

    def create_or_update_source(
        self,
        *,
        provider: str,
        name: str,
        clone_url: str,
        branch: Optional[str],
        local_path: str,
        active: bool,
        sync_enabled: bool,
        sync_interval_minutes: int,
        ts: str,
    ) -> Dict[str, Any]:
        existing = self.get_source_by_clone_url(clone_url)
        fields = dict(
            provider=provider,
            name=name,
            branch=branch,
            local_path=local_path,
            is_active=1 if active else 0,
            sync_enabled=1 if sync_enabled else 0,
            sync_interval_minutes=int(sync_interval_minutes),
        )
        if existing:
            return self.update_source(existing["source_id"], updated_ts=ts, **fields)

        source_id = str(uuid.uuid4())
        with self._conn() as conn:
            if active:
                conn.execute("UPDATE repo_sources SET is_active = 0")
            conn.execute(
                """
                INSERT INTO repo_sources (
                    source_id, provider, name, clone_url, branch, local_path,
                    is_active, sync_enabled, sync_interval_minutes,
                    last_synced_ts, last_synced_commit, last_sync_status, last_sync_error,
                    repo_kind, has_sfdx_project, has_force_app, metadata_root,
                    validation_status, validation_error,
                    last_indexed_ts, last_indexed_commit, last_index_status, last_index_error,
                    docs_count, meta_files, graph_nodes, graph_edges,
                    objects_count, fields_count, classes_count, triggers_count, flows_count,
                    cleanup_exempt,
                    created_ts, updated_ts
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 0, 0, 0, 0, 0, 0, 0, 0, ?, ?)
                """,
                (
                    source_id,
                    provider,
                    name,
                    clone_url,
                    branch,
                    local_path,
                    1 if active else 0,
                    1 if sync_enabled else 0,
                    int(sync_interval_minutes),
                    ts,
                    ts,
                ),
            )
        return self.get_source(source_id)

    def update_source(self, source_id: str, *, updated_ts: str, **fields: Any) -> Dict[str, Any]:
        if not fields:
            return self.get_source(source_id)
        with self._conn() as conn:
            if int(fields.get("is_active", 0)) == 1:
                conn.execute("UPDATE repo_sources SET is_active = 0 WHERE source_id <> ?", (source_id,))
            sets = [f"{k} = ?" for k in fields.keys()]
            values = list(fields.values())
            sets.append("updated_ts = ?")
            values.append(updated_ts)
            values.append(source_id)
            conn.execute(f"UPDATE repo_sources SET {', '.join(sets)} WHERE source_id = ?", values)
        return self.get_source(source_id)

    def active_source(self) -> Optional[Dict[str, Any]]:
        with self._conn() as conn:
            row = conn.execute("SELECT * FROM repo_sources WHERE is_active = 1 ORDER BY updated_ts DESC LIMIT 1").fetchone()
        return dict(row) if row is not None else None

    def cleanup_inactive_sources(self, *, max_age_days: int, delete_local: bool = False) -> List[Dict[str, Any]]:
        cutoff = datetime.now(timezone.utc) - timedelta(days=max(0, int(max_age_days)))
        removed: List[Dict[str, Any]] = []
        with self._conn() as conn:
            rows = conn.execute(
                "SELECT * FROM repo_sources WHERE is_active = 0 AND cleanup_exempt = 0"
            ).fetchall()
            for row in rows:
                item = dict(row)
                ts_raw = item.get("updated_ts") or item.get("created_ts")
                try:
                    ts = datetime.fromisoformat(str(ts_raw).replace("Z", "+00:00"))
                except ValueError:
                    ts = cutoff - timedelta(seconds=1)
                if ts > cutoff:
                    continue
                local_path = Path(item["local_path"]).expanduser().resolve()
                if delete_local and local_path.exists():
                    import shutil
                    shutil.rmtree(local_path, ignore_errors=True)
                conn.execute("DELETE FROM repo_sources WHERE source_id = ?", (item["source_id"],))
                removed.append(item)
        return removed
