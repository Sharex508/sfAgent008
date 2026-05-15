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

                CREATE TABLE IF NOT EXISTS ui_feature_definitions (
                    feature_id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    description TEXT,
                    status TEXT NOT NULL,
                    target_org_alias TEXT,
                    metadata_project_dir TEXT,
                    app_name TEXT,
                    page_context TEXT,
                    start_url TEXT,
                    login_mode TEXT,
                    steps_json TEXT NOT NULL,
                    expected_outcomes_json TEXT,
                    tags_json TEXT,
                    notes TEXT,
                    last_run_id TEXT,
                    last_run_status TEXT,
                    last_run_ts TEXT,
                    created_ts TEXT NOT NULL,
                    updated_ts TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS ui_feature_component_refs (
                    ref_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    feature_id TEXT NOT NULL,
                    component_type TEXT,
                    component_name TEXT,
                    path TEXT,
                    source TEXT,
                    metadata_json TEXT
                );

                CREATE TABLE IF NOT EXISTS ui_feature_runs (
                    run_id TEXT PRIMARY KEY,
                    feature_id TEXT NOT NULL,
                    status TEXT NOT NULL,
                    target_org_alias TEXT,
                    base_url TEXT,
                    start_url TEXT,
                    browser_name TEXT,
                    headless INTEGER,
                    storage_state_path TEXT,
                    artifact_root TEXT,
                    video_path TEXT,
                    trace_path TEXT,
                    request_json TEXT,
                    result_json TEXT,
                    error_text TEXT,
                    created_ts TEXT NOT NULL,
                    updated_ts TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS ui_feature_step_results (
                    row_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    run_id TEXT NOT NULL,
                    step_index INTEGER NOT NULL,
                    step_name TEXT,
                    action_type TEXT,
                    status TEXT NOT NULL,
                    selector TEXT,
                    expected_text TEXT,
                    actual_text TEXT,
                    screenshot_path TEXT,
                    error_text TEXT,
                    result_json TEXT,
                    started_ts TEXT,
                    finished_ts TEXT
                );
                """
            )

    def _decode_json_fields(self, item: Dict[str, Any], fields: List[str]) -> Dict[str, Any]:
        for key in fields:
            raw = item.get(key)
            if raw:
                try:
                    item[key] = json.loads(raw)
                except Exception:
                    item[key] = raw
            else:
                item[key] = None
        return item

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

    def create_ui_feature(
        self,
        *,
        name: str,
        description: Optional[str],
        target_org_alias: Optional[str],
        metadata_project_dir: Optional[str],
        app_name: Optional[str],
        page_context: Optional[str],
        start_url: Optional[str],
        login_mode: Optional[str],
        steps: List[Dict[str, Any]],
        expected_outcomes: Optional[List[str]],
        tags: Optional[List[str]],
        notes: Optional[str],
        component_refs: Optional[List[Dict[str, Any]]],
        created_ts: str,
    ) -> Dict[str, Any]:
        feature_id = str(uuid.uuid4())
        with self._conn() as conn:
            conn.execute(
                """
                INSERT INTO ui_feature_definitions (
                    feature_id, name, description, status, target_org_alias, metadata_project_dir,
                    app_name, page_context, start_url, login_mode, steps_json,
                    expected_outcomes_json, tags_json, notes, last_run_id, last_run_status,
                    last_run_ts, created_ts, updated_ts
                ) VALUES (?, ?, ?, 'ACTIVE', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, ?, ?)
                """,
                (
                    feature_id,
                    name,
                    description,
                    target_org_alias,
                    metadata_project_dir,
                    app_name,
                    page_context,
                    start_url,
                    login_mode,
                    json.dumps(steps, ensure_ascii=False),
                    json.dumps(expected_outcomes or [], ensure_ascii=False),
                    json.dumps(tags or [], ensure_ascii=False),
                    notes,
                    created_ts,
                    created_ts,
                ),
            )
            self._replace_ui_feature_component_refs(conn, feature_id=feature_id, refs=component_refs or [])
        return self.get_ui_feature(feature_id)

    def update_ui_feature(self, feature_id: str, *, updated_ts: str, component_refs: Optional[List[Dict[str, Any]]] = None, **fields: Any) -> Dict[str, Any]:
        encoded: Dict[str, Any] = {}
        json_fields = {"steps_json", "expected_outcomes_json", "tags_json"}
        for key, value in fields.items():
            if value is None:
                continue
            if key in json_fields:
                encoded[key] = json.dumps(value, ensure_ascii=False)
            else:
                encoded[key] = value

        with self._conn() as conn:
            if encoded:
                sets = [f"{key} = ?" for key in encoded.keys()]
                vals = list(encoded.values())
                sets.append("updated_ts = ?")
                vals.append(updated_ts)
                vals.append(feature_id)
                conn.execute(
                    f"UPDATE ui_feature_definitions SET {', '.join(sets)} WHERE feature_id = ?",
                    vals,
                )
            if component_refs is not None:
                self._replace_ui_feature_component_refs(conn, feature_id=feature_id, refs=component_refs)
        return self.get_ui_feature(feature_id)

    def get_ui_feature(self, feature_id: str) -> Dict[str, Any]:
        with self._conn() as conn:
            row = conn.execute("SELECT * FROM ui_feature_definitions WHERE feature_id = ?", (feature_id,)).fetchone()
            if row is None:
                raise KeyError(f"UI feature not found: {feature_id}")
            item = self._decode_ui_feature(dict(row))
            item["component_refs"] = self._list_ui_feature_component_refs(conn, feature_id)
            return item

    def list_ui_features(self, *, limit: int = 100) -> List[Dict[str, Any]]:
        with self._conn() as conn:
            rows = conn.execute(
                "SELECT * FROM ui_feature_definitions ORDER BY updated_ts DESC LIMIT ?",
                (max(1, int(limit)),),
            ).fetchall()
            out: List[Dict[str, Any]] = []
            for row in rows:
                item = self._decode_ui_feature(dict(row))
                item["component_refs"] = self._list_ui_feature_component_refs(conn, item["feature_id"])
                out.append(item)
        return out

    def create_ui_feature_run(
        self,
        *,
        feature_id: str,
        status: str,
        target_org_alias: Optional[str],
        base_url: Optional[str],
        start_url: Optional[str],
        browser_name: str,
        headless: bool,
        storage_state_path: Optional[str],
        artifact_root: Optional[str],
        request_payload: Optional[Dict[str, Any]],
        created_ts: str,
    ) -> Dict[str, Any]:
        run_id = str(uuid.uuid4())
        with self._conn() as conn:
            conn.execute(
                """
                INSERT INTO ui_feature_runs (
                    run_id, feature_id, status, target_org_alias, base_url, start_url,
                    browser_name, headless, storage_state_path, artifact_root, video_path, trace_path,
                    request_json, result_json, error_text, created_ts, updated_ts
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?, NULL, NULL, ?, ?)
                """,
                (
                    run_id,
                    feature_id,
                    status,
                    target_org_alias,
                    base_url,
                    start_url,
                    browser_name,
                    1 if headless else 0,
                    storage_state_path,
                    artifact_root,
                    json.dumps(request_payload or {}, ensure_ascii=False),
                    created_ts,
                    created_ts,
                ),
            )
        return self.get_ui_feature_run(run_id)

    def update_ui_feature_run(
        self,
        run_id: str,
        *,
        status: str,
        updated_ts: str,
        video_path: Optional[str] = None,
        trace_path: Optional[str] = None,
        result_payload: Optional[Dict[str, Any]] = None,
        error_text: Optional[str] = None,
        step_results: Optional[List[Dict[str, Any]]] = None,
    ) -> Dict[str, Any]:
        sets = ["status = ?", "updated_ts = ?"]
        vals: List[Any] = [status, updated_ts]
        if video_path is not None:
            sets.append("video_path = ?")
            vals.append(video_path)
        if trace_path is not None:
            sets.append("trace_path = ?")
            vals.append(trace_path)
        if result_payload is not None:
            sets.append("result_json = ?")
            vals.append(json.dumps(result_payload, ensure_ascii=False))
        if error_text is not None:
            sets.append("error_text = ?")
            vals.append(error_text)
        vals.append(run_id)

        with self._conn() as conn:
            conn.execute(f"UPDATE ui_feature_runs SET {', '.join(sets)} WHERE run_id = ?", vals)
            if step_results is not None:
                conn.execute("DELETE FROM ui_feature_step_results WHERE run_id = ?", (run_id,))
                for step in step_results:
                    result_payload_json = step.get("result")
                    actual_text = step.get("actual_text")
                    if actual_text is None and isinstance(result_payload_json, dict):
                        actual_text = result_payload_json.get("actual_text")
                    conn.execute(
                        """
                        INSERT INTO ui_feature_step_results (
                            run_id, step_index, step_name, action_type, status, selector,
                            expected_text, actual_text, screenshot_path, error_text, result_json,
                            started_ts, finished_ts
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            run_id,
                            int(step.get("step_index") or 0),
                            step.get("step_name"),
                            step.get("action_type"),
                            step.get("status"),
                            step.get("selector"),
                            step.get("expected_text"),
                            actual_text,
                            step.get("screenshot_path"),
                            step.get("error_text"),
                            json.dumps(result_payload_json, ensure_ascii=False) if result_payload_json is not None else None,
                            step.get("started_ts"),
                            step.get("finished_ts"),
                        ),
                    )
                feature_row = conn.execute("SELECT feature_id FROM ui_feature_runs WHERE run_id = ?", (run_id,)).fetchone()
                if feature_row:
                    feature_id = feature_row["feature_id"]
                    conn.execute(
                        """
                        UPDATE ui_feature_definitions
                           SET last_run_id = ?, last_run_status = ?, last_run_ts = ?, updated_ts = ?
                         WHERE feature_id = ?
                        """,
                        (run_id, status, updated_ts, updated_ts, feature_id),
                    )
        return self.get_ui_feature_run(run_id)

    def get_ui_feature_run(self, run_id: str) -> Dict[str, Any]:
        with self._conn() as conn:
            row = conn.execute("SELECT * FROM ui_feature_runs WHERE run_id = ?", (run_id,)).fetchone()
            if row is None:
                raise KeyError(f"UI feature run not found: {run_id}")
            item = self._decode_ui_feature_run(dict(row))
            item["step_results"] = self._list_ui_feature_step_results(conn, run_id)
            return item

    def list_ui_feature_runs(self, *, feature_id: str, limit: int = 50) -> List[Dict[str, Any]]:
        with self._conn() as conn:
            rows = conn.execute(
                "SELECT * FROM ui_feature_runs WHERE feature_id = ? ORDER BY updated_ts DESC LIMIT ?",
                (feature_id, max(1, int(limit))),
            ).fetchall()
            out: List[Dict[str, Any]] = []
            for row in rows:
                item = self._decode_ui_feature_run(dict(row))
                item["step_results"] = self._list_ui_feature_step_results(conn, item["run_id"])
                out.append(item)
        return out

    def _replace_ui_feature_component_refs(self, conn: sqlite3.Connection, *, feature_id: str, refs: List[Dict[str, Any]]) -> None:
        conn.execute("DELETE FROM ui_feature_component_refs WHERE feature_id = ?", (feature_id,))
        for ref in refs:
            conn.execute(
                """
                INSERT INTO ui_feature_component_refs (
                    feature_id, component_type, component_name, path, source, metadata_json
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    feature_id,
                    ref.get("component_type") or ref.get("kind"),
                    ref.get("component_name") or ref.get("name"),
                    ref.get("path"),
                    ref.get("source"),
                    json.dumps(ref.get("metadata"), ensure_ascii=False) if ref.get("metadata") is not None else None,
                ),
            )

    def _list_ui_feature_component_refs(self, conn: sqlite3.Connection, feature_id: str) -> List[Dict[str, Any]]:
        rows = conn.execute(
            """
            SELECT component_type, component_name, path, source, metadata_json
              FROM ui_feature_component_refs
             WHERE feature_id = ?
             ORDER BY ref_id ASC
            """,
            (feature_id,),
        ).fetchall()
        out: List[Dict[str, Any]] = []
        for row in rows:
            item = dict(row)
            metadata_raw = item.pop("metadata_json", None)
            item["metadata"] = json.loads(metadata_raw) if metadata_raw else None
            out.append(item)
        return out

    def _list_ui_feature_step_results(self, conn: sqlite3.Connection, run_id: str) -> List[Dict[str, Any]]:
        rows = conn.execute(
            """
            SELECT step_index, step_name, action_type, status, selector, expected_text,
                   actual_text, screenshot_path, error_text, result_json, started_ts, finished_ts
              FROM ui_feature_step_results
             WHERE run_id = ?
             ORDER BY step_index ASC
            """,
            (run_id,),
        ).fetchall()
        out: List[Dict[str, Any]] = []
        for row in rows:
            item = dict(row)
            raw = item.pop("result_json", None)
            item["result"] = json.loads(raw) if raw else None
            out.append(item)
        return out

    def _decode_work_item(self, item: Dict[str, Any]) -> Dict[str, Any]:
        return self._decode_json_fields(
            item,
            [
                "analysis_json",
                "impacted_components_json",
                "changed_components_json",
                "deployment_result_json",
                "test_result_json",
                "debug_result_json",
            ],
        )

    def _decode_execution(self, item: Dict[str, Any]) -> Dict[str, Any]:
        return self._decode_json_fields(item, ["request_json", "result_json"])

    def _decode_ui_feature(self, item: Dict[str, Any]) -> Dict[str, Any]:
        item = self._decode_json_fields(item, ["steps_json", "expected_outcomes_json", "tags_json"])
        item["steps"] = item.pop("steps_json") or []
        item["expected_outcomes"] = item.pop("expected_outcomes_json") or []
        item["tags"] = item.pop("tags_json") or []
        return item

    def _decode_ui_feature_run(self, item: Dict[str, Any]) -> Dict[str, Any]:
        item = self._decode_json_fields(item, ["request_json", "result_json"])
        item["headless"] = bool(item.get("headless"))
        item["request"] = item.pop("request_json")
        item["result"] = item.pop("result_json")
        return item
