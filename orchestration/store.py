from __future__ import annotations

import json
import sqlite3
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional


DEFAULT_DB = Path("data/index.sqlite")


class OrchestrationStore:
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
                CREATE TABLE IF NOT EXISTS orchestration_work_items (
                    work_item_id TEXT PRIMARY KEY,
                    title TEXT,
                    story TEXT NOT NULL,
                    status TEXT NOT NULL,
                    llm_model TEXT,
                    metadata_project_dir TEXT,
                    target_org_alias TEXT,
                    analysis_json TEXT,
                    impacted_components_json TEXT,
                    changed_components_json TEXT,
                    deployment_result_json TEXT,
                    test_result_json TEXT,
                    debug_result_json TEXT,
                    final_summary TEXT,
                    created_ts TEXT NOT NULL,
                    updated_ts TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS orchestration_executions (
                    execution_id TEXT PRIMARY KEY,
                    work_item_id TEXT,
                    operation_type TEXT NOT NULL,
                    status TEXT NOT NULL,
                    command_summary TEXT,
                    request_json TEXT,
                    result_json TEXT,
                    exit_code INTEGER,
                    created_ts TEXT NOT NULL,
                    updated_ts TEXT NOT NULL
                );
                """
            )

    def create_work_item(
        self,
        *,
        story: str,
        title: Optional[str],
        llm_model: Optional[str],
        metadata_project_dir: Optional[str],
        target_org_alias: Optional[str],
        created_ts: str,
    ) -> Dict[str, Any]:
        work_item_id = str(uuid.uuid4())
        with self._conn() as conn:
            conn.execute(
                """
                INSERT INTO orchestration_work_items (
                    work_item_id, title, story, status, llm_model, metadata_project_dir, target_org_alias,
                    analysis_json, impacted_components_json, changed_components_json,
                    deployment_result_json, test_result_json, debug_result_json, final_summary,
                    created_ts, updated_ts
                ) VALUES (?, ?, ?, 'NEW', ?, ?, ?, NULL, NULL, NULL, NULL, NULL, NULL, NULL, ?, ?)
                """,
                (
                    work_item_id,
                    title,
                    story,
                    llm_model,
                    metadata_project_dir,
                    target_org_alias,
                    created_ts,
                    created_ts,
                ),
            )
        return self.get_work_item(work_item_id)

    def get_work_item(self, work_item_id: str) -> Dict[str, Any]:
        with self._conn() as conn:
            row = conn.execute(
                "SELECT * FROM orchestration_work_items WHERE work_item_id = ?",
                (work_item_id,),
            ).fetchone()
        if row is None:
            raise KeyError(f"Work item not found: {work_item_id}")
        return self._decode_work_item(dict(row))

    def list_work_items(self, *, limit: int = 50) -> List[Dict[str, Any]]:
        with self._conn() as conn:
            rows = conn.execute(
                "SELECT * FROM orchestration_work_items ORDER BY updated_ts DESC LIMIT ?",
                (max(1, int(limit)),),
            ).fetchall()
        return [self._decode_work_item(dict(r)) for r in rows]

    def update_work_item(self, work_item_id: str, *, updated_ts: str, **fields: Any) -> Dict[str, Any]:
        if not fields:
            return self.get_work_item(work_item_id)

        encoded: Dict[str, Any] = {}
        json_fields = {
            "analysis_json",
            "impacted_components_json",
            "changed_components_json",
            "deployment_result_json",
            "test_result_json",
            "debug_result_json",
        }
        for key, value in fields.items():
            if key in json_fields and value is not None:
                encoded[key] = json.dumps(value, ensure_ascii=False)
            else:
                encoded[key] = value

        sets = [f"{key} = ?" for key in encoded.keys()]
        vals = list(encoded.values())
        sets.append("updated_ts = ?")
        vals.append(updated_ts)
        vals.append(work_item_id)
        with self._conn() as conn:
            conn.execute(
                f"UPDATE orchestration_work_items SET {', '.join(sets)} WHERE work_item_id = ?",
                vals,
            )
        return self.get_work_item(work_item_id)

    def create_execution(
        self,
        *,
        operation_type: str,
        created_ts: str,
        work_item_id: Optional[str] = None,
        status: str = "STARTED",
        command_summary: Optional[str] = None,
        request_payload: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        execution_id = str(uuid.uuid4())
        with self._conn() as conn:
            conn.execute(
                """
                INSERT INTO orchestration_executions (
                    execution_id, work_item_id, operation_type, status, command_summary,
                    request_json, result_json, exit_code, created_ts, updated_ts
                ) VALUES (?, ?, ?, ?, ?, ?, NULL, NULL, ?, ?)
                """,
                (
                    execution_id,
                    work_item_id,
                    operation_type,
                    status,
                    command_summary,
                    json.dumps(request_payload or {}, ensure_ascii=False),
                    created_ts,
                    created_ts,
                ),
            )
        return self.get_execution(execution_id)

    def update_execution(
        self,
        execution_id: str,
        *,
        status: str,
        updated_ts: str,
        command_summary: Optional[str] = None,
        result_payload: Optional[Dict[str, Any]] = None,
        exit_code: Optional[int] = None,
    ) -> Dict[str, Any]:
        sets = ["status = ?", "updated_ts = ?"]
        vals: List[Any] = [status, updated_ts]
        if command_summary is not None:
            sets.append("command_summary = ?")
            vals.append(command_summary)
        if result_payload is not None:
            sets.append("result_json = ?")
            vals.append(json.dumps(result_payload, ensure_ascii=False))
        if exit_code is not None:
            sets.append("exit_code = ?")
            vals.append(int(exit_code))
        vals.append(execution_id)
        with self._conn() as conn:
            conn.execute(
                f"UPDATE orchestration_executions SET {', '.join(sets)} WHERE execution_id = ?",
                vals,
            )
        return self.get_execution(execution_id)

    def get_execution(self, execution_id: str) -> Dict[str, Any]:
        with self._conn() as conn:
            row = conn.execute(
                "SELECT * FROM orchestration_executions WHERE execution_id = ?",
                (execution_id,),
            ).fetchone()
        if row is None:
            raise KeyError(f"Execution not found: {execution_id}")
        return self._decode_execution(dict(row))

    def list_executions(self, *, work_item_id: Optional[str] = None, limit: int = 100) -> List[Dict[str, Any]]:
        sql = "SELECT * FROM orchestration_executions"
        params: List[Any] = []
        if work_item_id:
            sql += " WHERE work_item_id = ?"
            params.append(work_item_id)
        sql += " ORDER BY updated_ts DESC LIMIT ?"
        params.append(max(1, int(limit)))
        with self._conn() as conn:
            rows = conn.execute(sql, params).fetchall()
        return [self._decode_execution(dict(r)) for r in rows]

    def _decode_work_item(self, item: Dict[str, Any]) -> Dict[str, Any]:
        for key in (
            "analysis_json",
            "impacted_components_json",
            "changed_components_json",
            "deployment_result_json",
            "test_result_json",
            "debug_result_json",
        ):
            raw = item.get(key)
            if raw:
                try:
                    item[key] = json.loads(raw)
                except Exception:
                    item[key] = raw
            else:
                item[key] = None
        return item

    def _decode_execution(self, item: Dict[str, Any]) -> Dict[str, Any]:
        for key in ("request_json", "result_json"):
            raw = item.get(key)
            if raw:
                try:
                    item[key] = json.loads(raw)
                except Exception:
                    item[key] = raw
            else:
                item[key] = None
        return item
