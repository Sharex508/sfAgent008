from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sqlite3
import time
from pathlib import Path
from typing import Any, Iterable

import requests
import yaml
from rapidfuzz import fuzz, process

from sf_repo_ai.config import AppConfig, load_config
from sf_repo_ai.access.schema import AccessBundle
from sf_repo_ai.access.evaluator import evaluate as evaluate_access
from sf_repo_ai.access.org_pull import build_access_bundle_from_org
from sf_repo_ai.ask_router import route_ask_question
from sf_repo_ai.db import connect, init_schema
from sf_repo_ai.entity_dict import build_entity_dictionary
from sf_repo_ai.evidence_engine import build_evidence
from sf_repo_ai.explainers.adapters import collect_snippets as collect_explainer_snippets
from sf_repo_ai.explainers.adapters import snippets_to_text
from sf_repo_ai.explainers.registry import get_explainer
from sf_repo_ai.graph import (
    build_dependency_graph,
    deps_for_class,
    deps_for_flow,
    impact_field_graph,
    impact_object_graph,
)
from sf_repo_ai.llm.evidence_pack import build_evidence_pack
from sf_repo_ai.llm.ollama_client import OllamaClientError, chat_completion
from sf_repo_ai.llm.prompts import (
    PLANNER_SYSTEM_PROMPT,
    SYSTEM_PROMPT,
    build_planner_prompt,
    build_user_prompt,
)
from sf_repo_ai.query_interpreter import (
    ParsedQuery,
    build_alias_maps,
    normalize,
    parse_question,
    resolve_field_phrase,
    resolve_object_phrase,
)
from sf_repo_ai.risk_tools import (
    build_blast_radius,
    build_test_checklist_markdown,
    detect_collisions,
    what_breaks,
    write_json,
)
from sf_repo_ai.logs.capture_store import (
    add_capture_log,
    close_capture,
    create_capture,
    ensure_tables as ensure_log_tables,
    get_capture,
    list_capture_logs,
    utc_now,
)
from sf_repo_ai.logs.fetcher import fetch_logs_for_window
from sf_repo_ai.logs.parser import parse_log_text
from sf_repo_ai.logs.analyzer import analyze_logs
from sf_repo_ai.logs.trace import disable_trace_flags, enable_trace_flag
from sf_repo_ai.sf.auth import DEFAULT_LOGIN_URL, SalesforceAuthError, login_with_username_password
from sf_repo_ai.sf.client import SalesforceClient, SalesforceClientError
from sf_repo_ai.sf.tooling_api import ToolingAPIClient, ToolingAPIError
from sf_repo_ai.repo_scan import index_repository
from sf_repo_ai.scanners.techdebt_apex import generate_apex_techdebt
from sf_repo_ai.scanners.techdebt_flows import generate_flow_techdebt
from sf_repo_ai.scanners.techdebt_security import generate_security_techdebt
from sf_repo_ai.util import read_text


def _conn_from_cfg(cfg: AppConfig, project_root: Path) -> sqlite3.Connection:
    conn = connect(cfg.resolve_sqlite_path(project_root))
    init_schema(conn)
    return conn


def _print_not_found() -> None:
    print("Not found in repo index")


def _print_resolution(parsed: ParsedQuery) -> None:
    print(f"Resolved intent: {parsed.intent}")
    entities = [
        f"object={parsed.object_name or ''}",
        f"field={parsed.field_name or ''}",
        f"full_field={parsed.full_field_name or ''}",
        f"endpoint={parsed.endpoint or ''}",
        f"contains={parsed.contains or ''}",
    ]
    print(f"Resolved entities: {' | '.join(entities)}")
    print(f"Confidence: {parsed.confidence:.2f}")


def _resolve_field_input(conn: sqlite3.Connection, phrase_or_field: str, *, intent_hint: str) -> ParsedQuery:
    value = (phrase_or_field or "").strip()
    parsed = ParsedQuery(intent=intent_hint, raw_question=value, confidence=0.0)

    if "." in value:
        row = conn.execute(
            "SELECT full_name FROM fields WHERE lower(full_name)=lower(?) LIMIT 1",
            (value,),
        ).fetchone()
        if row:
            full = row["full_name"]
            obj, fld = full.split(".", 1)
            return ParsedQuery(
                intent=intent_hint,
                object_name=obj,
                field_name=fld,
                full_field_name=full,
                raw_question=value,
                confidence=0.9,
            )

    synthetic = f"which flows update {value}" if intent_hint == "flows_update_field" else f"where {value} is used"
    parsed = parse_question(synthetic, conn)
    if parsed.full_field_name:
        parsed.intent = intent_hint
    return parsed


def _resolve_object_input(conn: sqlite3.Connection, phrase_or_object: str) -> ParsedQuery:
    value = (phrase_or_object or "").strip()
    if not value:
        return ParsedQuery(intent="unknown", raw_question=value, confidence=0.0)

    row = conn.execute(
        "SELECT object_name FROM objects WHERE lower(object_name)=lower(?) LIMIT 1",
        (value,),
    ).fetchone()
    if row:
        return ParsedQuery(intent="explain_object", object_name=row["object_name"], raw_question=value, confidence=0.9)

    field_alias_map, object_alias_map = build_alias_maps(conn)
    resolved = resolve_object_phrase(value, object_alias_map, score_cutoff=85)
    if resolved:
        obj, score = resolved
        confidence = 0.75 if score >= 92 else 0.6
        return ParsedQuery(intent="explain_object", object_name=obj, raw_question=value, confidence=confidence)

    # Fallback: maybe they passed a field-like phrase.
    field_guess = resolve_field_phrase(value, field_alias_map, score_cutoff=85)
    if field_guess:
        full, score = field_guess
        obj, fld = full.split(".", 1)
        confidence = 0.75 if score >= 92 else 0.6
        return ParsedQuery(
            intent="impact_field",
            object_name=obj,
            field_name=fld,
            full_field_name=full,
            raw_question=value,
            confidence=confidence,
        )

    return ParsedQuery(intent="unknown", raw_question=value, confidence=0.0)


def query_where_used(conn: sqlite3.Connection, field: str) -> list[sqlite3.Row]:
    field = field.strip()
    if "." in field:
        suffix = field.split(".", 1)[1]
        rows = conn.execute(
            """
            SELECT ref_type, ref_key, src_type, src_name, src_path, line_start, line_end, snippet, confidence
            FROM "references"
            WHERE ref_type = 'FIELD'
              AND (
                lower(ref_key) = lower(?)
                OR lower(ref_key) = lower(?)
              )
            ORDER BY confidence DESC, src_path, COALESCE(line_start, 0)
            """,
            (field, f"*.{suffix}"),
        ).fetchall()
    else:
        suffix = field
        rows = conn.execute(
            """
            SELECT ref_type, ref_key, src_type, src_name, src_path, line_start, line_end, snippet, confidence
            FROM "references"
            WHERE ref_type = 'FIELD'
              AND (
                lower(ref_key) = lower(?)
                OR lower(ref_key) = lower(?)
                OR lower(ref_key) LIKE lower(?)
              )
            ORDER BY confidence DESC, src_path, COALESCE(line_start, 0)
            """,
            (field, f"*.{suffix}", f"%.{suffix}"),
        ).fetchall()
    return rows


def cmd_where_used(conn: sqlite3.Connection, field: str) -> int:
    rows = query_where_used(conn, field)
    if not rows:
        _print_not_found()
        return 0

    for r in rows:
        line = ""
        if r["line_start"] is not None:
            line = f":{r['line_start']}"
            if r["line_end"] is not None and r["line_end"] != r["line_start"]:
                line += f"-{r['line_end']}"
        print(
            f"{r['src_path']}{line} | {r['src_type']}:{r['src_name']} | "
            f"{r['ref_key']} | confidence={r['confidence']:.2f}"
        )
        if r["snippet"]:
            print(f"  snippet: {r['snippet']}")
    return 0


def query_flows_update(conn: sqlite3.Connection, field: str) -> list[sqlite3.Row]:
    if "." in field:
        suffix = field.split(".", 1)[1]
        rows = conn.execute(
            """
            SELECT w.flow_name, w.field_full_name AS full_field_name, w.evidence_path AS path, w.confidence, f.trigger_object, f.status
            FROM flow_true_writes w
            LEFT JOIN flows f ON f.flow_name = w.flow_name
            WHERE w.write_kind='field_write'
              AND (
                lower(w.field_full_name) = lower(?)
                OR lower(w.field_full_name) = lower(?)
              )
            ORDER BY w.confidence DESC, w.flow_name
            """,
            (field, suffix),
        ).fetchall()
    else:
        rows = conn.execute(
            """
            SELECT w.flow_name, w.field_full_name AS full_field_name, w.evidence_path AS path, w.confidence, f.trigger_object, f.status
            FROM flow_true_writes w
            LEFT JOIN flows f ON f.flow_name = w.flow_name
            WHERE w.write_kind='field_write'
              AND (
                lower(w.field_full_name) = lower(?)
                OR lower(w.field_full_name) LIKE lower(?)
              )
            ORDER BY w.confidence DESC, w.flow_name
            """,
            (field, f"%.{field}"),
        ).fetchall()
    if rows:
        return rows
    # Backward-compatible fallback for pre-v2 indexes.
    if "." in field:
        suffix = field.split(".", 1)[1]
        return conn.execute(
            """
            SELECT w.flow_name, w.full_field_name, w.path, w.confidence, f.trigger_object, f.status
            FROM flow_field_writes w
            LEFT JOIN flows f ON f.flow_name = w.flow_name
            WHERE lower(w.full_field_name) = lower(?)
               OR lower(w.full_field_name) = lower(?)
            ORDER BY w.confidence DESC, w.flow_name
            """,
            (field, suffix),
        ).fetchall()
    return conn.execute(
        """
        SELECT w.flow_name, w.full_field_name, w.path, w.confidence, f.trigger_object, f.status
        FROM flow_field_writes w
        LEFT JOIN flows f ON f.flow_name = w.flow_name
        WHERE lower(w.full_field_name) = lower(?)
           OR lower(w.full_field_name) LIKE lower(?)
        ORDER BY w.confidence DESC, w.flow_name
        """,
        (field, f"%.{field}"),
    ).fetchall()


def cmd_flows_update(conn: sqlite3.Connection, field: str) -> int:
    rows = query_flows_update(conn, field)
    if not rows:
        _print_not_found()
        return 0
    for r in rows:
        print(
            f"{r['path']} | flow={r['flow_name']} | writes={r['full_field_name']} | "
            f"trigger_object={r['trigger_object']} | confidence={r['confidence']:.2f}"
        )
    return 0


def query_endpoint_callers(conn: sqlite3.Connection, endpoint: str) -> list[sqlite3.Row]:
    endpoint = endpoint.strip()
    if endpoint.endswith(":"):
        rows = conn.execute(
            """
            SELECT class_name, path, endpoint_value, endpoint_type, line_start, line_end
            FROM apex_endpoints
            WHERE lower(endpoint_value) LIKE lower(?)
            ORDER BY path, line_start
            """,
            (endpoint + "%",),
        ).fetchall()
    else:
        rows = conn.execute(
            """
            SELECT class_name, path, endpoint_value, endpoint_type, line_start, line_end
            FROM apex_endpoints
            WHERE lower(endpoint_value) = lower(?)
            ORDER BY path, line_start
            """,
            (endpoint,),
        ).fetchall()
    return rows


def cmd_endpoint_callers(conn: sqlite3.Connection, endpoint: str) -> int:
    rows = query_endpoint_callers(conn, endpoint)
    if not rows:
        _print_not_found()
        return 0

    for r in rows:
        line = ""
        if r["line_start"] is not None:
            line = f":{r['line_start']}"
            if r["line_end"] is not None and r["line_end"] != r["line_start"]:
                line += f"-{r['line_end']}"
        print(
            f"{r['path']}{line} | {r['class_name']} | {r['endpoint_type']} | {r['endpoint_value']}"
        )
    return 0


def query_validation_rules(conn: sqlite3.Connection, obj: str, contains: str | None = None) -> list[sqlite3.Row]:
    contains = contains or ""
    rows = conn.execute(
        """
        SELECT object_name, rule_name, active, error_condition, error_message, path
        FROM validation_rules
        WHERE lower(object_name) = lower(?)
          AND (
            ? = ''
            OR lower(rule_name) LIKE lower(?)
            OR lower(error_condition) LIKE lower(?)
            OR lower(error_message) LIKE lower(?)
          )
        ORDER BY rule_name
        """,
        (obj, contains, f"%{contains}%", f"%{contains}%", f"%{contains}%"),
    ).fetchall()
    return rows


def cmd_validation_rules(conn: sqlite3.Connection, obj: str, contains: str | None) -> int:
    rows = query_validation_rules(conn, obj, contains)
    if not rows:
        _print_not_found()
        return 0

    for r in rows:
        cond = (r["error_condition"] or "").replace("\n", " ")
        if len(cond) > 180:
            cond = cond[:177] + "..."
        print(
            f"{r['path']} | {r['object_name']}.{r['rule_name']} | active={r['active']} | condition={cond}"
        )
    return 0


def query_meta_files(
    conn: sqlite3.Connection,
    *,
    folder: str | None = None,
    type_guess: str | None = None,
) -> list[sqlite3.Row]:
    clauses: list[str] = []
    params: list[str] = []
    if folder:
        clauses.append("lower(folder)=lower(?)")
        params.append(folder)
    if type_guess:
        clauses.append("lower(type_guess)=lower(?)")
        params.append(type_guess)
    where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    return conn.execute(
        f"""
        SELECT path, folder, file_name, extension, type_guess, api_name, xml_root, active, sobject
        FROM meta_files
        {where}
        ORDER BY folder, file_name
        LIMIT 2000
        """,
        tuple(params),
    ).fetchall()


def cmd_list_meta(
    conn: sqlite3.Connection,
    *,
    folder: str | None,
    type_guess: str | None,
) -> int:
    rows = query_meta_files(conn, folder=folder, type_guess=type_guess)
    if not rows:
        _print_not_found()
        return 0
    for r in rows:
        print(
            f"{r['path']} | folder={r['folder']} | type={r['type_guess']} | "
            f"api={r['api_name']} | active={r['active']} | sobject={r['sobject'] or ''}"
        )
    return 0


def cmd_count_meta(
    conn: sqlite3.Connection,
    *,
    folder: str | None,
    type_guess: str | None,
) -> int:
    clauses: list[str] = []
    params: list[str] = []
    if folder:
        clauses.append("lower(folder)=lower(?)")
        params.append(folder)
    if type_guess:
        clauses.append("lower(type_guess)=lower(?)")
        params.append(type_guess)
    where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    row = conn.execute(
        f"SELECT COUNT(*) AS c FROM meta_files {where}",
        tuple(params),
    ).fetchone()
    print(int(row["c"]))
    return 0


def query_where_used_any(conn: sqlite3.Connection, token: str) -> list[sqlite3.Row]:
    token = token.strip()
    like = f"%{token}%"
    return conn.execute(
        """
        SELECT ref_kind, ref_value, src_path, src_folder, line_no, snippet, confidence
        FROM meta_refs
        WHERE lower(ref_value)=lower(?)
           OR lower(ref_value) LIKE lower(?)
           OR lower(snippet) LIKE lower(?)
        ORDER BY confidence DESC, src_path, COALESCE(line_no, 0)
        LIMIT 2000
        """,
        (token, like, like),
    ).fetchall()


def cmd_where_used_any(conn: sqlite3.Connection, token: str) -> int:
    rows = query_where_used_any(conn, token)
    if not rows:
        _print_not_found()
        return 0
    for r in rows:
        line = f":{r['line_no']}" if r["line_no"] is not None else ""
        print(
            f"{r['src_path']}{line} | {r['src_folder']} | {r['ref_kind']}={r['ref_value']} | "
            f"confidence={float(r['confidence'] or 0.0):.2f}"
        )
        if r["snippet"]:
            print(f"  snippet: {r['snippet']}")
    return 0


def query_approval_processes(
    conn: sqlite3.Connection,
    *,
    object_name: str | None = None,
    active_only: bool = False,
) -> list[sqlite3.Row]:
    clauses: list[str] = []
    params: list[str] = []
    if object_name:
        clauses.append("lower(object_name)=lower(?)")
        params.append(object_name)
    if active_only:
        clauses.append("active=1")
    where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    return conn.execute(
        f"""
        SELECT name, object_name, active, path
        FROM approval_processes
        {where}
        ORDER BY object_name, name
        """,
        tuple(params),
    ).fetchall()


def cmd_approval_processes(
    conn: sqlite3.Connection,
    *,
    object_name: str | None,
    active_only: bool,
    list_mode: bool,
) -> int:
    total = int(conn.execute("SELECT COUNT(*) AS c FROM approval_processes").fetchone()["c"])
    unknown_obj = int(
        conn.execute(
            "SELECT COUNT(*) AS c FROM approval_processes WHERE object_name IS NULL OR object_name=''"
        ).fetchone()["c"]
    )
    unknown_active = int(
        conn.execute("SELECT COUNT(*) AS c FROM approval_processes WHERE active IS NULL").fetchone()["c"]
    )
    rows = query_approval_processes(conn, object_name=object_name, active_only=active_only)
    used_object_fallback = False
    if object_name and not rows:
        used_object_fallback = True
        clauses = ["lower(object_name) LIKE lower(?)"]
        params: list[str | int] = [f"%{object_name}%"]
        if active_only:
            clauses.append("active=1")
        where = " AND ".join(clauses)
        rows = conn.execute(
            f"""
            SELECT name, object_name, active, path
            FROM approval_processes
            WHERE {where}
            ORDER BY object_name, name
            """,
            tuple(params),
        ).fetchall()

    print(f"Total approval process files: {total}")
    print(f"Matched approval processes: {len(rows)}")
    if used_object_fallback:
        print(f"Object fallback match used: %{object_name}%")
    if unknown_obj:
        print(f"Could not determine object for {unknown_obj} files")
    if unknown_active:
        print(f"Could not determine active status for {unknown_active} files")

    if not rows:
        _print_not_found()
        if unknown_obj or unknown_active:
            print("Not found in repo index — may not be source-tracked.")
        return 0

    if list_mode or object_name:
        for r in rows:
            print(
                f"{r['path']} | name={r['name']} | object={r['object_name'] or ''} | active={r['active']}"
            )
    return 0


def cmd_debug_approval(conn: sqlite3.Connection, *, object_name: str) -> int:
    obj = (object_name or "").strip()
    if not obj:
        print("Object is required")
        return 0

    meta_count = int(
        conn.execute(
            """
            SELECT COUNT(*) AS c
            FROM meta_files
            WHERE lower(folder)=lower('approvalProcesses')
              AND lower(path) LIKE lower(?)
            """,
            (f"%/approvalProcesses/{obj}.%",),
        ).fetchone()["c"]
    )
    adapter_count = int(
        conn.execute(
            """
            SELECT COUNT(*) AS c
            FROM approval_processes
            WHERE lower(object_name)=lower(?)
            """,
            (obj,),
        ).fetchone()["c"]
    )
    print(f"meta_files approvalProcesses for {obj}: {meta_count}")
    print(f"approval_processes rows for {obj}: {adapter_count}")

    print("Sample approval_processes rows:")
    rows = conn.execute(
        """
        SELECT name, object_name, active, path
        FROM approval_processes
        WHERE lower(object_name)=lower(?) OR lower(path) LIKE lower(?)
        ORDER BY path
        LIMIT 5
        """,
        (obj, f"%/approvalProcesses/{obj}.%"),
    ).fetchall()
    if not rows:
        print("- none")
    else:
        for r in rows:
            print(f"- {r['path']} | name={r['name']} | object={r['object_name']} | active={r['active']}")

    print("Sample meta_files rows:")
    mrows = conn.execute(
        """
        SELECT path, api_name, sobject, active
        FROM meta_files
        WHERE lower(folder)=lower('approvalProcesses')
          AND lower(path) LIKE lower(?)
        ORDER BY path
        LIMIT 5
        """,
        (f"%/approvalProcesses/{obj}.%",),
    ).fetchall()
    if not mrows:
        print("- none")
    else:
        for r in mrows:
            print(f"- {r['path']} | api={r['api_name']} | sobject={r['sobject']} | active={r['active']}")
    return 0


def _parse_filters(filters: list[str] | None) -> dict[str, str]:
    out: dict[str, str] = {}
    for f in filters or []:
        if "=" not in f:
            continue
        k, v = f.split("=", 1)
        key = k.strip().lower()
        value = v.strip()
        if key and value:
            out[key] = value
    return out


def _parse_bool_filter(value: str | None) -> int | None:
    if value is None:
        return None
    low = value.strip().lower()
    if low in {"1", "true", "yes", "y"}:
        return 1
    if low in {"0", "false", "no", "n"}:
        return 0
    return None


def _query_typed_records(
    conn: sqlite3.Connection,
    *,
    type_name: str,
    filters: dict[str, str],
) -> tuple[list[sqlite3.Row], dict[str, int], str]:
    tkey = type_name.strip().lower()
    obj_filter = filters.get("object")
    active_filter = _parse_bool_filter(filters.get("active"))
    access_filter = filters.get("access")

    if tkey in {"approvalprocess", "approvalprocesses"}:
        where: list[str] = []
        params: list[str | int] = []
        object_where = ""
        object_params: list[str] = []
        used_object_fallback = False
        if obj_filter:
            object_where = "lower(object_name)=lower(?)"
            object_params = [obj_filter]
            probe = conn.execute(
                "SELECT 1 FROM approval_processes WHERE lower(object_name)=lower(?) LIMIT 1",
                (obj_filter,),
            ).fetchone()
            if not probe:
                used_object_fallback = True
                object_where = "lower(object_name) LIKE lower(?)"
                object_params = [f"%{obj_filter}%"]

        if object_where:
            where.append(object_where)
            params.extend(object_params)
        if active_filter is not None:
            where.append("active=?")
            params.append(active_filter)
        where_sql = f"WHERE {' AND '.join(where)}" if where else ""
        rows = conn.execute(
            f"""
            SELECT name, object_name, active, path
            FROM approval_processes
            {where_sql}
            ORDER BY object_name, name
            """,
            tuple(params),
        ).fetchall()

        scope_where = f"WHERE {object_where}" if object_where else ""
        unknown_active = int(
            conn.execute(
                f"SELECT COUNT(*) AS c FROM approval_processes {scope_where} "
                + ("AND active IS NULL" if scope_where else "WHERE active IS NULL"),
                tuple(object_params),
            ).fetchone()["c"]
        )
        unknown_object = int(
            conn.execute(
                "SELECT COUNT(*) AS c FROM approval_processes WHERE object_name IS NULL OR object_name=''"
            ).fetchone()["c"]
        )
        if used_object_fallback:
            print(f"Object fallback match used: %{obj_filter}%")
        return rows, {"unknown_active": unknown_active, "unknown_object": unknown_object}, "approval_processes"

    if tkey in {"sharingrule", "sharingrules"}:
        where = []
        params: list[str | int] = []
        if obj_filter:
            where.append("lower(object_name) LIKE lower(?)")
            params.append(f"%{obj_filter}%")
        if active_filter is not None:
            where.append("active=?")
            params.append(active_filter)
        if access_filter:
            where.append("lower(access_level)=lower(?)")
            params.append(access_filter)
        where_sql = f"WHERE {' AND '.join(where)}" if where else ""
        rows = conn.execute(
            f"""
            SELECT name, object_name, rule_type, access_level, active, path
            FROM sharing_rules
            {where_sql}
            ORDER BY object_name, name
            """,
            tuple(params),
        ).fetchall()
        unknown_active = int(
            conn.execute("SELECT COUNT(*) AS c FROM sharing_rules WHERE active IS NULL").fetchone()["c"]
        )
        unknown_object = int(
            conn.execute("SELECT COUNT(*) AS c FROM sharing_rules WHERE object_name IS NULL OR object_name=''").fetchone()[
                "c"
            ]
        )
        return rows, {"unknown_active": unknown_active, "unknown_object": unknown_object}, "sharing_rules"

    where = ["(lower(type_guess)=lower(?) OR lower(folder)=lower(?))"]
    params = [type_name, type_name]
    if obj_filter:
        where.append("(lower(sobject)=lower(?) OR lower(sobject) LIKE lower(?))")
        params.extend([obj_filter, f"%{obj_filter}%"])
    if active_filter is not None:
        where.append("active=?")
        params.append(active_filter)
    if filters.get("folder"):
        where.append("lower(folder)=lower(?)")
        params.append(filters["folder"])
    where_sql = "WHERE " + " AND ".join(where)
    rows = conn.execute(
        f"""
        SELECT path, folder, file_name, extension, type_guess, api_name, xml_root, active, sobject
        FROM meta_files
        {where_sql}
        ORDER BY folder, file_name
        LIMIT 5000
        """,
        tuple(params),
    ).fetchall()

    unknown_active = int(
        conn.execute(
            """
            SELECT COUNT(*) AS c
            FROM meta_files
            WHERE (lower(type_guess)=lower(?) OR lower(folder)=lower(?))
              AND active IS NULL
            """,
            (type_name, type_name),
        ).fetchone()["c"]
    )
    unknown_object = int(
        conn.execute(
            """
            SELECT COUNT(*) AS c
            FROM meta_files
            WHERE (lower(type_guess)=lower(?) OR lower(folder)=lower(?))
              AND (sobject IS NULL OR sobject='')
            """,
            (type_name, type_name),
        ).fetchone()["c"]
    )
    return rows, {"unknown_active": unknown_active, "unknown_object": unknown_object}, "meta_files"


def cmd_count_typed(conn: sqlite3.Connection, *, type_name: str, filters: list[str] | None) -> int:
    parsed_filters = _parse_filters(filters)
    rows, unknowns, backend = _query_typed_records(conn, type_name=type_name, filters=parsed_filters)
    print(f"type={type_name} backend={backend} count={len(rows)}")
    if "active" in parsed_filters:
        print(
            f"active={parsed_filters['active']} count = {len(rows)}, unknown status = {unknowns.get('unknown_active', 0)}"
        )
    if "object" in parsed_filters:
        print(f"object={parsed_filters['object']} unknown object = {unknowns.get('unknown_object', 0)}")
    return 0


def cmd_list_typed(conn: sqlite3.Connection, *, type_name: str, filters: list[str] | None) -> int:
    parsed_filters = _parse_filters(filters)
    rows, unknowns, backend = _query_typed_records(conn, type_name=type_name, filters=parsed_filters)
    if not rows:
        _print_not_found()
        return 0
    print(f"type={type_name} backend={backend} count={len(rows)}")
    if "active" in parsed_filters:
        print(
            f"active={parsed_filters['active']} count = {len(rows)}, unknown status = {unknowns.get('unknown_active', 0)}"
        )
    if "object" in parsed_filters:
        print(f"object={parsed_filters['object']} unknown object = {unknowns.get('unknown_object', 0)}")
    for r in rows[:200]:
        if backend == "approval_processes":
            print(
                f"{r['path']} | name={r['name']} | object={r['object_name'] or ''} | active={r['active']}"
            )
        elif backend == "sharing_rules":
            print(
                f"{r['path']} | name={r['name']} | object={r['object_name'] or ''} | "
                f"type={r['rule_type'] or ''} | access={r['access_level'] or ''} | active={r['active']}"
            )
        else:
            print(
                f"{r['path']} | folder={r['folder']} | type={r['type_guess']} | "
                f"api={r['api_name']} | active={r['active']} | sobject={r['sobject'] or ''}"
            )
    return 0


def build_coverage_report(conn: sqlite3.Connection) -> dict:
    meta_rows = conn.execute("SELECT path, folder FROM meta_files").fetchall()
    folder_total: dict[str, int] = {}
    folder_structured: dict[str, int] = {}

    structured_path_rows = conn.execute(
        """
        SELECT path FROM objects
        UNION SELECT path FROM fields
        UNION SELECT path FROM validation_rules
        UNION SELECT path FROM flows
        UNION SELECT path FROM apex_endpoints
        UNION SELECT path FROM approval_processes
        UNION SELECT path FROM sharing_rules
        UNION SELECT src_path AS path FROM "references"
        """
    ).fetchall()
    structured_paths = {r["path"] for r in structured_path_rows if r["path"]}

    for r in meta_rows:
        folder = r["folder"] or "UNKNOWN"
        path = r["path"]
        folder_total[folder] = folder_total.get(folder, 0) + 1
        if path in structured_paths:
            folder_structured[folder] = folder_structured.get(folder, 0) + 1

    parsed_coverage = []
    for folder in sorted(folder_total):
        total = folder_total[folder]
        structured = folder_structured.get(folder, 0)
        generic_only = max(0, total - structured)
        ratio = round((structured / total), 4) if total else 0.0
        parsed_coverage.append(
            {
                "folder": folder,
                "total_files": total,
                "structured_files": structured,
                "generic_only_files": generic_only,
                "structured_ratio": ratio,
            }
        )

    files_with_no_refs_count = int(
        conn.execute(
            """
            SELECT COUNT(*) AS c
            FROM meta_files mf
            LEFT JOIN (
              SELECT src_path, COUNT(*) AS c
              FROM meta_refs
              GROUP BY src_path
            ) mr ON mr.src_path = mf.path
            WHERE COALESCE(mr.c, 0) = 0
            """
        ).fetchone()["c"]
    )
    files_with_no_refs = conn.execute(
        """
        SELECT mf.path, mf.folder
        FROM meta_files mf
        LEFT JOIN (
          SELECT src_path, COUNT(*) AS c
          FROM meta_refs
          GROUP BY src_path
        ) mr ON mr.src_path = mf.path
        WHERE COALESCE(mr.c, 0) = 0
        ORDER BY mf.folder, mf.path
        LIMIT 500
        """
    ).fetchall()

    xml_parse_failures_count = int(
        conn.execute(
            """
            SELECT COUNT(*) AS c
            FROM meta_files
            WHERE extension='.xml' AND COALESCE(xml_parse_error, 0) = 1
            """
        ).fetchone()["c"]
    )
    xml_parse_failures = conn.execute(
        """
        SELECT path, folder
        FROM meta_files
        WHERE extension='.xml' AND COALESCE(xml_parse_error, 0) = 1
        ORDER BY folder, path
        LIMIT 500
        """
    ).fetchall()

    approval_unknown = conn.execute(
        """
        SELECT
          SUM(CASE WHEN object_name IS NULL OR object_name='' THEN 1 ELSE 0 END) AS unknown_object,
          SUM(CASE WHEN active IS NULL THEN 1 ELSE 0 END) AS unknown_active
        FROM approval_processes
        """
    ).fetchone()

    sharing_unknown = conn.execute(
        """
        SELECT
          SUM(CASE WHEN object_name IS NULL OR object_name='' THEN 1 ELSE 0 END) AS unknown_object,
          SUM(CASE WHEN access_level IS NULL OR access_level='' THEN 1 ELSE 0 END) AS unknown_access
        FROM sharing_rules
        """
    ).fetchone()

    importance = {
        "sharingRules": 5,
        "assignmentRules": 5,
        "workflows": 5,
        "escalationRules": 4,
        "autoResponseRules": 4,
        "duplicateRules": 4,
        "matchingRules": 4,
        "queues": 4,
        "groups": 4,
        "connectedApps": 5,
        "authproviders": 5,
        "cspTrustedSites": 4,
        "corsWhitelistOrigins": 4,
        "remoteSiteSettings": 5,
        "settings": 5,
    }

    missing_adapters = []
    for row in parsed_coverage:
        folder = row["folder"]
        total = row["total_files"]
        structured = row["structured_files"]
        if total < 1:
            continue
        if structured > 0:
            continue
        imp = importance.get(folder, 1)
        score = total * imp
        missing_adapters.append(
            {
                "folder": folder,
                "total_files": total,
                "structured_files": structured,
                "importance": imp,
                "score": score,
            }
        )
    missing_adapters.sort(key=lambda x: (x["score"], x["total_files"]), reverse=True)

    return {
        "folder_coverage": parsed_coverage,
        "parsed_coverage": parsed_coverage,
        "unknowns": {
            "files_with_no_refs_count": files_with_no_refs_count,
            "files_with_no_refs_samples": [dict(r) for r in files_with_no_refs[:100]],
            "xml_parse_failures_count": xml_parse_failures_count,
            "xml_parse_failure_samples": [dict(r) for r in xml_parse_failures[:100]],
            "approval_processes_unknown_object": int(approval_unknown["unknown_object"] or 0),
            "approval_processes_unknown_active": int(approval_unknown["unknown_active"] or 0),
            "sharing_rules_unknown_object": int(sharing_unknown["unknown_object"] or 0),
            "sharing_rules_unknown_access": int(sharing_unknown["unknown_access"] or 0),
        },
        "top_missing_adapters": missing_adapters[:20],
    }


def cmd_coverage(conn: sqlite3.Connection, project_root: Path, *, out_path: str) -> int:
    payload = build_coverage_report(conn)
    out = Path(out_path)
    if not out.is_absolute():
        out = project_root / out
    write_json(out, payload)

    print(f"folders: {len(payload.get('folder_coverage', []))}")
    print(f"files_with_no_refs: {payload['unknowns']['files_with_no_refs_count']}")
    print(f"xml_parse_failures: {payload['unknowns']['xml_parse_failures_count']}")
    print(out.as_posix())
    return 0


def cmd_org_summary(cfg: AppConfig, conn: sqlite3.Connection, project_root: Path, *, out_path: str) -> int:
    repo_root = cfg.resolve_repo_root(project_root)
    type_counts = conn.execute(
        """
        SELECT type_guess, COUNT(*) AS c
        FROM meta_files
        GROUP BY type_guess
        ORDER BY c DESC, type_guess
        """
    ).fetchall()
    folder_counts = conn.execute(
        """
        SELECT folder, COUNT(*) AS c
        FROM meta_files
        GROUP BY folder
        ORDER BY c DESC, folder
        """
    ).fetchall()

    flow_td = generate_flow_techdebt(repo_root, cfg.sfdx_root)
    apex_td = generate_apex_techdebt(repo_root, cfg.sfdx_root)
    sec_td = generate_security_techdebt(repo_root, cfg.sfdx_root)
    workflow_count = conn.execute(
        "SELECT COUNT(*) AS c FROM meta_files WHERE lower(folder)='workflows'"
    ).fetchone()["c"]

    approval_active = conn.execute(
        """
        SELECT object_name, COUNT(*) AS c
        FROM approval_processes
        WHERE active = 1
        GROUP BY object_name
        ORDER BY c DESC, object_name
        """
    ).fetchall()

    endpoint_counts = conn.execute(
        """
        SELECT endpoint_type, COUNT(*) AS c
        FROM apex_endpoints
        GROUP BY endpoint_type
        ORDER BY c DESC
        """
    ).fetchall()

    graph_exists = conn.execute("SELECT COUNT(*) AS c FROM graph_nodes").fetchone()["c"] > 0
    hotspots: list[sqlite3.Row] = []
    if graph_exists:
        hotspots = conn.execute(
            """
            SELECT n.node_type, n.name, n.path,
                   COALESCE(i.c, 0) AS in_degree,
                   COALESCE(o.c, 0) AS out_degree,
                   COALESCE(i.c, 0) + COALESCE(o.c, 0) AS degree
            FROM graph_nodes n
            LEFT JOIN (
              SELECT dst_node_id AS node_id, COUNT(*) AS c
              FROM graph_edges GROUP BY dst_node_id
            ) i ON i.node_id = n.node_id
            LEFT JOIN (
              SELECT src_node_id AS node_id, COUNT(*) AS c
              FROM graph_edges GROUP BY src_node_id
            ) o ON o.node_id = n.node_id
            ORDER BY degree DESC, n.name
            LIMIT 20
            """
        ).fetchall()

    findings = sec_td.get("findings", [])
    high_risk_system_perm_entries = sum(len(x.get("high_risk_system_permissions", [])) for x in findings)
    modify_view_all_entries = sum(len(x.get("modify_or_view_all", [])) for x in findings)

    lines: list[str] = []
    lines.append("# Org Summary")
    lines.append("")
    lines.append("## Metadata Counts by Type")
    for r in type_counts[:100]:
        lines.append(f"- {r['type_guess']}: {r['c']}")
    lines.append("")

    lines.append("## Automation Inventory")
    lines.append(f"- Flows indexed: {conn.execute('SELECT COUNT(*) AS c FROM flows').fetchone()['c']}")
    lines.append(f"- Workflow metadata files: {workflow_count}")
    lines.append(f"- Active approval processes: {sum(int(r['c']) for r in approval_active)}")
    lines.append("- Active approval processes by object:")
    for r in approval_active[:20]:
        lines.append(f"  - {r['object_name'] or 'UNKNOWN'}: {r['c']}")
    lines.append("- Top complex flows (element count):")
    for r in flow_td.get("top_20_by_element_count", [])[:10]:
        lines.append(f"  - {r['flow_name']}: elements={r['element_count']} decisions={r['decision_count']}")
    lines.append("")

    lines.append("## Integration Surface")
    lines.append(f"- Apex endpoints indexed: {conn.execute('SELECT COUNT(*) AS c FROM apex_endpoints').fetchone()['c']}")
    for r in endpoint_counts:
        lines.append(f"  - {r['endpoint_type']}: {r['c']}")
    for folder in ["connectedApps", "authproviders", "cspTrustedSites", "corsWhitelistOrigins", "remoteSiteSettings"]:
        c = conn.execute("SELECT COUNT(*) AS c FROM meta_files WHERE lower(folder)=lower(?)", (folder,)).fetchone()["c"]
        lines.append(f"- {folder}: {c}")
    lines.append("")

    lines.append("## Security Surface")
    prof_count = conn.execute("SELECT COUNT(*) AS c FROM meta_files WHERE lower(folder)='profiles'").fetchone()["c"]
    perm_count = conn.execute("SELECT COUNT(*) AS c FROM meta_files WHERE lower(folder)='permissionsets'").fetchone()[
        "c"
    ]
    lines.append(f"- Profiles: {prof_count}")
    lines.append(f"- Permission sets: {perm_count}")
    lines.append(f"- High-risk system permission entries: {high_risk_system_perm_entries}")
    lines.append(f"- ModifyAll/ViewAll object permission entries: {modify_view_all_entries}")
    lines.append("")

    lines.append("## Hotspots")
    if hotspots:
        for h in hotspots:
            lines.append(
                f"- {h['node_type']}:{h['name']} degree={h['degree']} in={h['in_degree']} out={h['out_degree']}"
            )
    else:
        lines.append("- Graph not built yet. Run `graph-build` first.")
    lines.append("")

    lines.append("## Folder Counts")
    for r in folder_counts[:40]:
        lines.append(f"- {r['folder']}: {r['c']}")
    lines.append("")
    lines.append("## Top Apex Smells")
    for r in apex_td.get("top_20_by_smell", [])[:10]:
        lines.append(f"- {r['class_name']}: smell={r['smell_score']} loc={r['loc']}")

    out = Path(out_path)
    if not out.is_absolute():
        out = project_root / out
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(out.as_posix())
    return 0


def _print_evidence_summary(payload: dict) -> None:
    target = payload.get("target", {})
    print(
        f"Resolved target: type={target.get('type')} name={target.get('name') or ''} path={target.get('path') or ''}"
    )
    if not target.get("found"):
        print("Target not found in repo index")
        suggestions = target.get("suggestions") or []
        if suggestions:
            print("Suggestions:")
            for s in suggestions[:5]:
                print(f"- {s}")
        return

    counts = payload.get("summary_counts", {})
    if counts:
        print("Summary counts:")
        for k in sorted(counts):
            print(f"- {k}: {counts[k]}")

    hotspots = payload.get("top_hotspots", [])[:5]
    if hotspots:
        print("Top hotspots:")
        for h in hotspots:
            print(
                f"- {h.get('node_type')}:{h.get('name')} | depth={h.get('depth')} | "
                f"degree={h.get('degree')} | {h.get('path') or ''}"
            )

    writers = payload.get("writers", [])[:5]
    if writers:
        print("Top writers:")
        for w in writers:
            print(
                f"- {w.get('type')}:{w.get('name')} | {w.get('edge_type')} | "
                f"confidence={float(w.get('confidence') or 0.0):.2f} | {w.get('path') or w.get('evidence_path') or ''}"
            )

    paths = payload.get("evidence_paths", [])[:5]
    if paths:
        print("Top evidence paths:")
        for p in paths:
            print(f"- {p}")

    unknowns = payload.get("unknowns", [])
    if unknowns:
        print("Unknowns:")
        for n in unknowns:
            print(f"- {n}")


def cmd_evidence(
    conn: sqlite3.Connection,
    project_root: Path,
    *,
    target: str,
    depth: int,
    top_n: int,
    json_out: str | None,
) -> int:
    payload = build_evidence(conn, target=target, depth=depth, top_n=top_n)
    _print_evidence_summary(payload)
    if json_out:
        out = Path(json_out)
        if not out.is_absolute():
            out = project_root / out
        write_json(out, payload)
        print(out.as_posix())
    return 0


def _build_snippet_bundle(payload: dict, max_chars: int = 25000) -> str:
    chunks: list[str] = []
    used = 0

    sections = [
        payload.get("writers", []),
        payload.get("readers", []),
        payload.get("automations", []),
        payload.get("security_surface", []),
        payload.get("integration_surface", []),
        payload.get("ui_surface", []),
        payload.get("refs", []),
    ]
    for sec in sections:
        for item in sec:
            path = item.get("path") or item.get("evidence_path") or item.get("src_path") or ""
            snippet = item.get("snippet") or item.get("evidence_snippet") or ""
            line = item.get("line_no") or item.get("line_start")
            prefix = f"{path}:{line}" if line else path
            if not prefix and not snippet:
                continue
            text = f"[{prefix}] {snippet}".strip()
            if used + len(text) + 1 > max_chars:
                return "\n".join(chunks)
            chunks.append(text)
            used += len(text) + 1
    return "\n".join(chunks)


def _facts_markdown(payload: dict) -> str:
    target = payload.get("target", {})
    lines = ["# Evidence Facts", ""]
    lines.append(
        f"Target: `{target.get('type')}` `{target.get('name') or target.get('path') or target.get('raw')}`"
    )
    lines.append("")
    lines.append("## Summary")
    for k, v in sorted((payload.get("summary_counts") or {}).items()):
        lines.append(f"- {k}: {v}")

    def add_section(title: str, rows: list[dict], max_items: int = 10) -> None:
        lines.append("")
        lines.append(f"## {title}")
        if not rows:
            lines.append("- none")
            return
        for r in rows[:max_items]:
            path = r.get("path") or r.get("evidence_path") or r.get("src_path") or ""
            name = r.get("name") or r.get("ref_value") or r.get("src_name") or ""
            extra = r.get("edge_type") or r.get("surface") or r.get("ref_kind") or ""
            lines.append(f"- {name} | {extra} | {path}")

    add_section("Hotspots", payload.get("top_hotspots", []))
    add_section("Writers", payload.get("writers", []))
    add_section("Readers", payload.get("readers", []))
    add_section("Automation Surface", payload.get("automations", []))
    add_section("Security Surface", payload.get("security_surface", []))
    add_section("Integration Surface", payload.get("integration_surface", []))
    add_section("UI Surface", payload.get("ui_surface", []))
    add_section("References", payload.get("refs", []))

    unknowns = payload.get("unknowns", [])
    lines.append("")
    lines.append("## Unknowns")
    if unknowns:
        for u in unknowns:
            lines.append(f"- {u}")
    else:
        lines.append("- none")
    return "\n".join(lines) + "\n"


def _advise_with_llm(cfg: AppConfig, target: str, payload: dict) -> str:
    evidence_json = json.dumps(payload, indent=2)
    snippets = _build_snippet_bundle(payload, max_chars=25000)
    prompt = (
        "You are a Salesforce architecture advisor.\n"
        "Use only the provided evidence. Do not invent component names.\n"
        "Cite component names and file paths.\n"
        "If a fact is missing, say unknown.\n\n"
        "Produce markdown with sections:\n"
        "1) Findings (facts)\n"
        "2) Risks\n"
        "3) Refactor options (2-3)\n"
        "4) Recommended path\n"
        "5) Affected components list\n"
        "6) Test plan\n\n"
        f"Target:\n{target}\n\n"
        f"Evidence JSON:\n{evidence_json}\n\n"
        f"Snippet bundle:\n{snippets}\n"
    )
    body = {
        "model": cfg.ollama.gen_model,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": cfg.ollama.temperature,
            "top_p": cfg.ollama.top_p,
        },
    }
    resp = requests.post(f"{cfg.ollama.base_url.rstrip('/')}/api/generate", json=body, timeout=180)
    resp.raise_for_status()
    data = resp.json()
    return (data.get("response") or "").strip()


def cmd_advise(
    cfg: AppConfig,
    conn: sqlite3.Connection,
    project_root: Path,
    *,
    target: str,
    depth: int,
    top_n: int,
    no_llm: bool,
    out_path: str,
) -> int:
    payload = build_evidence(conn, target=target, depth=depth, top_n=top_n)
    out = Path(out_path)
    if not out.is_absolute():
        out = project_root / out
    out.parent.mkdir(parents=True, exist_ok=True)

    text = _facts_markdown(payload)
    if not no_llm and payload.get("target", {}).get("found"):
        try:
            text = _advise_with_llm(cfg, target, payload)
        except Exception as exc:
            text = _facts_markdown(payload) + f"\n\nLLM advise skipped: {exc}\n"

    out.write_text(text, encoding="utf-8")
    print(out.as_posix())
    return 0


EXPLAIN_PREFIX_RE = re.compile(r"^\s*(?:please\s+)?(?:explain|describe|what does|how does)\s+(.+?)\s*$", re.IGNORECASE)
EXPLAIN_TAIL_CUT_RE = re.compile(
    r"\b(and|that|which|why|where|who|when|with|update|updates|call|calls)\b|\?",
    re.IGNORECASE,
)


def _extract_explain_target_from_question(question: str) -> str:
    q = (question or "").strip()
    m = EXPLAIN_PREFIX_RE.match(q)
    if m:
        return m.group(1).strip()
    return q


def _trim_component_tail(value: str) -> str:
    v = (value or "").strip()
    if not v:
        return v
    m = EXPLAIN_TAIL_CUT_RE.search(v)
    if m:
        v = v[: m.start()].strip()
    return v


def _extract_named(raw: str, keywords: list[str]) -> str | None:
    for kw in keywords:
        m = re.search(rf"\b{re.escape(kw)}\b\s+(.+)$", raw, re.IGNORECASE)
        if not m:
            continue
        name = _trim_component_tail(m.group(1))
        if name:
            return name
    return None


def _best_namespace_match(candidate: str, names: list[str], *, cutoff: int = 80) -> str | None:
    if not candidate:
        return None
    low_map = {n.lower(): n for n in names if n}
    if candidate.lower() in low_map:
        return low_map[candidate.lower()]
    m = process.extractOne(candidate, names, scorer=fuzz.WRatio, score_cutoff=cutoff)
    return m[0] if m else None


def _lwc_target_path(conn: sqlite3.Connection, lwc_name: str) -> str | None:
    rows = conn.execute(
        """
        SELECT path
        FROM meta_files
        WHERE lower(folder)=lower('lwc')
          AND lower(path) LIKE lower(?)
        ORDER BY
          CASE
            WHEN lower(path) LIKE lower(?) THEN 0
            WHEN lower(path) LIKE lower(?) THEN 1
            ELSE 2
          END,
          path
        LIMIT 1
        """,
        (
            f"%/lwc/{lwc_name}/%",
            f"%/lwc/{lwc_name}/{lwc_name}.js-meta.xml",
            f"%/lwc/{lwc_name}/{lwc_name}.js",
        ),
    ).fetchall()
    if not rows:
        return None
    return rows[0]["path"]


def _resolve_explain_target(conn: sqlite3.Connection, target: str) -> dict[str, Any]:
    raw = (target or "").strip()
    out: dict[str, Any] = {
        "raw_target": raw,
        "target_for_evidence": raw,
        "resolved_type": "UNKNOWN",
        "resolved_name": raw,
        "resolved_path": None,
        "suggestions": [],
    }
    if not raw:
        return out

    # Natural typed forms with namespace locking.
    flow_name = _extract_named(raw, ["flow"])
    if flow_name:
        names = [r["flow_name"] for r in conn.execute("SELECT flow_name FROM flows").fetchall()]
        canonical = _best_namespace_match(flow_name, names, cutoff=82)
        if canonical:
            row = conn.execute("SELECT flow_name, path FROM flows WHERE lower(flow_name)=lower(?) LIMIT 1", (canonical,)).fetchone()
            if row:
                out.update(
                    {
                        "target_for_evidence": f"Flow:{row['flow_name']}",
                        "resolved_type": "Flow",
                        "resolved_name": row["flow_name"],
                        "resolved_path": row["path"],
                    }
                )
                return out

    class_name = _extract_named(raw, ["apex class", "class"])
    if class_name:
        names = [r["name"] for r in conn.execute("SELECT name FROM components WHERE type='APEX'").fetchall()]
        canonical = _best_namespace_match(class_name, names, cutoff=82)
        if canonical:
            row = conn.execute(
                "SELECT name, path FROM components WHERE type='APEX' AND lower(name)=lower(?) LIMIT 1",
                (canonical,),
            ).fetchone()
            if row:
                out.update(
                    {
                        "target_for_evidence": f"Class:{row['name']}",
                        "resolved_type": "ApexClass",
                        "resolved_name": row["name"],
                        "resolved_path": row["path"],
                    }
                )
                return out

    trigger_name = _extract_named(raw, ["trigger"])
    if trigger_name:
        names = [r["name"] for r in conn.execute("SELECT name FROM components WHERE type='TRIGGER'").fetchall()]
        canonical = _best_namespace_match(trigger_name, names, cutoff=82)
        if canonical:
            row = conn.execute(
                "SELECT name, path FROM components WHERE type='TRIGGER' AND lower(name)=lower(?) LIMIT 1",
                (canonical,),
            ).fetchone()
            if row:
                out.update(
                    {
                        "target_for_evidence": f"Trigger:{row['name']}",
                        "resolved_type": "Trigger",
                        "resolved_name": row["name"],
                        "resolved_path": row["path"],
                    }
                )
                return out

    vr_name = _extract_named(raw, ["validation rule"])
    if vr_name:
        names = [r["rule_name"] for r in conn.execute("SELECT rule_name FROM validation_rules").fetchall()]
        canonical = _best_namespace_match(vr_name, names, cutoff=80)
        if canonical:
            row = conn.execute(
                "SELECT rule_name, object_name, path FROM validation_rules WHERE lower(rule_name)=lower(?) LIMIT 1",
                (canonical,),
            ).fetchone()
            if row:
                out.update(
                    {
                        "target_for_evidence": f"path:{row['path']}",
                        "resolved_type": "ValidationRule",
                        "resolved_name": row["rule_name"],
                        "resolved_path": row["path"],
                    }
                )
                return out

    perm_name = _extract_named(raw, ["permission set", "permset"])
    if perm_name:
        names = [r["api_name"] for r in conn.execute("SELECT api_name FROM meta_files WHERE lower(folder)='permissionsets'").fetchall()]
        canonical = _best_namespace_match(perm_name, names, cutoff=80)
        if canonical:
            row = conn.execute(
                "SELECT path, api_name FROM meta_files WHERE lower(folder)='permissionsets' AND lower(api_name)=lower(?) LIMIT 1",
                (canonical,),
            ).fetchone()
            if row:
                out.update(
                    {
                        "target_for_evidence": f"path:{row['path']}",
                        "resolved_type": "PermissionSet",
                        "resolved_name": row["api_name"],
                        "resolved_path": row["path"],
                    }
                )
                return out

    connected_name = _extract_named(raw, ["connected app"])
    if connected_name:
        names = [r["api_name"] for r in conn.execute("SELECT api_name FROM meta_files WHERE lower(folder)='connectedapps'").fetchall()]
        canonical = _best_namespace_match(connected_name, names, cutoff=75)
        if canonical:
            row = conn.execute(
                "SELECT path, api_name FROM meta_files WHERE lower(folder)='connectedapps' AND lower(api_name)=lower(?) LIMIT 1",
                (canonical,),
            ).fetchone()
            if row:
                out.update(
                    {
                        "target_for_evidence": f"path:{row['path']}",
                        "resolved_type": "ConnectedApp",
                        "resolved_name": row["api_name"],
                        "resolved_path": row["path"],
                    }
                )
                return out

    layout_name = _extract_named(raw, ["layout"])
    if layout_name:
        names = [r["api_name"] for r in conn.execute("SELECT api_name FROM meta_files WHERE lower(folder)='layouts'").fetchall()]
        canonical = _best_namespace_match(layout_name, names, cutoff=75)
        if canonical:
            row = conn.execute(
                "SELECT path, api_name FROM meta_files WHERE lower(folder)='layouts' AND lower(api_name)=lower(?) LIMIT 1",
                (canonical,),
            ).fetchone()
            if row:
                out.update(
                    {
                        "target_for_evidence": f"path:{row['path']}",
                        "resolved_type": "Layout",
                        "resolved_name": row["api_name"],
                        "resolved_path": row["path"],
                    }
                )
                return out

    lwc_name = _extract_named(raw, ["lwc", "lightning web component"])
    if lwc_name:
        path = _lwc_target_path(conn, lwc_name)
        if path:
            out.update(
                {
                    "target_for_evidence": f"path:{path}",
                    "resolved_type": "LWC",
                    "resolved_name": lwc_name,
                    "resolved_path": path,
                }
            )
            return out

    # Explicit prefixes first.
    if ":" in raw and not raw.lower().startswith(("http://", "https://", "callout:")):
        prefix, value = raw.split(":", 1)
        p = normalize(prefix)
        value = value.strip()
        if p in {"flow"}:
            row = conn.execute("SELECT flow_name, path FROM flows WHERE lower(flow_name)=lower(?) LIMIT 1", (value,)).fetchone()
            if row:
                out.update(
                    {
                        "target_for_evidence": f"Flow:{row['flow_name']}",
                        "resolved_type": "Flow",
                        "resolved_name": row["flow_name"],
                        "resolved_path": row["path"],
                    }
                )
                return out
        if p in {"class", "apex class", "apex"}:
            row = conn.execute(
                "SELECT name, path FROM components WHERE type='APEX' AND lower(name)=lower(?) LIMIT 1",
                (value,),
            ).fetchone()
            if row:
                out.update(
                    {
                        "target_for_evidence": f"Class:{row['name']}",
                        "resolved_type": "ApexClass",
                        "resolved_name": row["name"],
                        "resolved_path": row["path"],
                    }
                )
                return out
        if p in {"lwc"}:
            path = _lwc_target_path(conn, value)
            if path:
                out.update(
                    {
                        "target_for_evidence": f"path:{path}",
                        "resolved_type": "LWC",
                        "resolved_name": value,
                        "resolved_path": path,
                    }
                )
                return out
        if p in {"approvalprocess", "approval process"}:
            row = conn.execute(
                "SELECT name, object_name, path FROM approval_processes WHERE lower(name)=lower(?) LIMIT 1",
                (value,),
            ).fetchone()
            if row:
                out.update(
                    {
                        "target_for_evidence": f"path:{row['path']}",
                        "resolved_type": "ApprovalProcess",
                        "resolved_name": row["name"],
                        "resolved_path": row["path"],
                    }
                )
                return out
        if p in {"path", "file"}:
            row = conn.execute(
                "SELECT path, api_name, type_guess FROM meta_files WHERE path=? OR lower(path)=lower(?) LIMIT 1",
                (value, value),
            ).fetchone()
            if row:
                out.update(
                    {
                        "target_for_evidence": f"path:{row['path']}",
                        "resolved_type": row["type_guess"] or "File",
                        "resolved_name": row["api_name"] or row["path"],
                        "resolved_path": row["path"],
                    }
                )
                return out

    # Approval process natural format.
    if "approval process" in normalize(raw):
        m = re.search(r"([A-Za-z][A-Za-z0-9_]*(?:__c)?)\.([A-Za-z][A-Za-z0-9_]+)", raw)
        if m:
            full = f"{m.group(1)}.{m.group(2)}"
            row = conn.execute(
                "SELECT name, path FROM approval_processes WHERE lower(name)=lower(?) LIMIT 1",
                (full,),
            ).fetchone()
            if row:
                out.update(
                    {
                        "target_for_evidence": f"path:{row['path']}",
                        "resolved_type": "ApprovalProcess",
                        "resolved_name": row["name"],
                        "resolved_path": row["path"],
                    }
                )
                return out

    # Exact file path.
    row = conn.execute(
        "SELECT path, api_name, type_guess FROM meta_files WHERE path=? OR lower(path)=lower(?) LIMIT 1",
        (raw, raw),
    ).fetchone()
    if row:
        out.update(
            {
                "target_for_evidence": f"path:{row['path']}",
                "resolved_type": row["type_guess"] or "File",
                "resolved_name": row["api_name"] or row["path"],
                "resolved_path": row["path"],
            }
        )
        return out

    # Exact component names.
    flow_row = conn.execute("SELECT flow_name, path FROM flows WHERE lower(flow_name)=lower(?) LIMIT 1", (raw,)).fetchone()
    if flow_row:
        out.update(
            {
                "target_for_evidence": f"Flow:{flow_row['flow_name']}",
                "resolved_type": "Flow",
                "resolved_name": flow_row["flow_name"],
                "resolved_path": flow_row["path"],
            }
        )
        return out

    apex_row = conn.execute(
        "SELECT name, path FROM components WHERE type='APEX' AND lower(name)=lower(?) LIMIT 1",
        (raw,),
    ).fetchone()
    if apex_row:
        out.update(
            {
                "target_for_evidence": f"Class:{apex_row['name']}",
                "resolved_type": "ApexClass",
                "resolved_name": apex_row["name"],
                "resolved_path": apex_row["path"],
            }
        )
        return out

    # LWC by bundle name.
    lwc_path = _lwc_target_path(conn, raw)
    if lwc_path:
        out.update(
            {
                "target_for_evidence": f"path:{lwc_path}",
                "resolved_type": "LWC",
                "resolved_name": raw,
                "resolved_path": lwc_path,
            }
        )
        return out

    # Permission set / profile by api name.
    sec_row = conn.execute(
        """
        SELECT path, api_name, folder
        FROM meta_files
        WHERE lower(folder) IN ('permissionsets','profiles')
          AND lower(api_name)=lower(?)
        LIMIT 1
        """,
        (raw,),
    ).fetchone()
    if sec_row:
        out.update(
            {
                "target_for_evidence": f"path:{sec_row['path']}",
                "resolved_type": "PermissionSet/Profile",
                "resolved_name": sec_row["api_name"],
                "resolved_path": sec_row["path"],
            }
        )
        return out

    # Sharing rules for object.
    m_share = re.search(r"sharing rules?\s+(?:for|on)\s+([A-Za-z0-9_]+)", normalize(raw))
    if m_share:
        obj = m_share.group(1)
        obj_row = conn.execute(
            "SELECT object_name FROM objects WHERE lower(object_name)=lower(?) LIMIT 1",
            (obj,),
        ).fetchone()
        canonical_obj = obj_row["object_name"] if obj_row else obj
        sr_row = conn.execute(
            """
            SELECT path
            FROM sharing_rules
            WHERE lower(object_name)=lower(?)
            ORDER BY name
            LIMIT 1
            """,
            (canonical_obj,),
        ).fetchone()
        out.update(
            {
                "target_for_evidence": f"path:{sr_row['path']}" if sr_row else canonical_obj,
                "resolved_type": "SharingRule",
                "resolved_name": canonical_obj,
                "resolved_path": sr_row["path"] if sr_row else None,
            }
        )
        return out

    # Fall back to raw target and provide fuzzy suggestions.
    d = build_entity_dictionary(conn)
    candidates = []
    candidates.extend(d.objects[:1000])
    candidates.extend(d.fields[:1000])
    candidates.extend(d.flows[:1000])
    candidates.extend(d.apex_classes[:1000])
    candidates.extend([r["name"] for r in conn.execute("SELECT name FROM approval_processes LIMIT 1000").fetchall()])
    candidates.extend([r["api_name"] for r in conn.execute("SELECT api_name FROM meta_files WHERE api_name IS NOT NULL LIMIT 2000").fetchall()])
    seen: set[str] = set()
    uniq: list[str] = []
    for c in candidates:
        if not c or c in seen:
            continue
        seen.add(c)
        uniq.append(c)
    for match in process.extract(raw, uniq, scorer=fuzz.WRatio, limit=5):
        if int(match[1]) >= 70:
            out["suggestions"].append(match[0])
    return out


def _snippet_from_lines(lines: list[str], line_no: int, radius: int = 2) -> str:
    if line_no < 1 or line_no > len(lines):
        return ""
    start = max(1, line_no - radius)
    end = min(len(lines), line_no + radius)
    out = []
    for i in range(start, end + 1):
        out.append(f"{i}: {lines[i-1]}")
    return "\n".join(out)


def _collect_snippets(
    conn: sqlite3.Connection,
    repo_root: Path,
    *,
    paths: list[str],
    tokens: list[str],
    max_chars: int = 25000,
) -> str:
    chunks: list[str] = []
    used = 0
    seen: set[str] = set()
    lowered_tokens = [t.lower() for t in tokens if t]

    for rel in paths:
        if rel in seen:
            continue
        seen.add(rel)
        full = repo_root / rel
        if not full.exists() or not full.is_file():
            continue
        text = read_text(full)
        if not text:
            continue
        lines = text.splitlines()

        ref_rows = conn.execute(
            """
            SELECT line_no, snippet, confidence
            FROM meta_refs
            WHERE src_path=?
            ORDER BY confidence DESC, COALESCE(line_no, 0)
            LIMIT 60
            """,
            (rel,),
        ).fetchall()
        evidence_rows = conn.execute(
            """
            SELECT line_start AS line_no, snippet, confidence
            FROM "references"
            WHERE src_path=?
            ORDER BY confidence DESC, COALESCE(line_start, 0)
            LIMIT 60
            """,
            (rel,),
        ).fetchall()
        merged = list(ref_rows) + list(evidence_rows)
        if not merged:
            merged = [{"line_no": 1, "snippet": "", "confidence": 0.0}]

        for row in merged:
            line_no = int(row["line_no"] or 1)
            snippet = (row["snippet"] or "").lower()
            if lowered_tokens and snippet:
                if not any(tok in snippet for tok in lowered_tokens):
                    continue
            block = _snippet_from_lines(lines, line_no, radius=3)
            if not block:
                continue
            chunk = f"### {rel}:{line_no}\n{block}\n"
            if used + len(chunk) > max_chars:
                return "\n".join(chunks)
            chunks.append(chunk)
            used += len(chunk)
            if len(chunks) >= 60:
                return "\n".join(chunks)
    return "\n".join(chunks)


def _read_repo_relative_text(repo_root: Path, rel_path: str | None) -> str:
    if not rel_path:
        return ""
    p = Path(rel_path)
    if p.is_absolute() and p.exists() and p.is_file():
        return read_text(p)
    full = repo_root / rel_path
    if full.exists() and full.is_file():
        return read_text(full)
    return ""


def _not_found_section() -> str:
    return "Not found in repo evidence."


def _structured_details(conn: sqlite3.Connection, target_info: dict[str, Any], repo_root: Path) -> list[str]:
    t = (target_info.get("resolved_type") or "").lower()
    name = target_info.get("resolved_name") or ""
    path = target_info.get("resolved_path") or ""
    lines: list[str] = []

    if t == "approvalprocess":
        row = conn.execute(
            """
            SELECT name, object_name, active, path
            FROM approval_processes
            WHERE lower(path)=lower(?) OR lower(name)=lower(?)
            LIMIT 1
            """,
            (path, name),
        ).fetchone()
        if row:
            lines.append(f"- Object: {row['object_name'] or 'Not specified'}")
            if row["active"] in (0, 1):
                lines.append(f"- Active: {'true' if int(row['active']) == 1 else 'false'}")
            else:
                lines.append("- Active: Not specified in repo evidence.")
            xml = _read_repo_relative_text(repo_root, row["path"])
            if xml:
                step_names = re.findall(r"<steps>.*?<name>([^<]+)</name>", xml, flags=re.DOTALL)
                approvers = re.findall(r"<approver>\s*([^<]+)\s*</approver>", xml, flags=re.DOTALL)
                has_entry = bool(re.search(r"<entryCriteria>|<formula>", xml))
                lines.append(f"- Entry criteria present: {'yes' if has_entry else 'no'}")
                lines.append(f"- Steps: {len(step_names)}")
                if step_names:
                    lines.append(f"- Step names: {', '.join(step_names[:5])}")
                if approvers:
                    lines.append(f"- Approver types/tokens: {', '.join(sorted(set(approvers))[:5])}")
                fa = len(re.findall(r"<finalApprovalActions>", xml))
                ia = len(re.findall(r"<initialSubmissionActions>", xml))
                lines.append(f"- Initial actions blocks: {ia}")
                lines.append(f"- Final approval action blocks: {fa}")
    elif t == "flow":
        row = conn.execute(
            "SELECT flow_name, trigger_object, trigger_type, status, path FROM flows WHERE lower(flow_name)=lower(?) LIMIT 1",
            (name,),
        ).fetchone()
        if row:
            lines.append(f"- Trigger object: {row['trigger_object'] or 'Not specified'}")
            lines.append(f"- Trigger type: {row['trigger_type'] or 'Not specified'}")
            lines.append(f"- Status: {row['status'] or 'Not specified'}")
            writes = conn.execute(
                """
                SELECT field_full_name
                FROM flow_true_writes
                WHERE lower(flow_name)=lower(?) AND write_kind='field_write'
                ORDER BY field_full_name
                LIMIT 20
                """,
                (row["flow_name"],),
            ).fetchall()
            lines.append(f"- True field writes: {len(writes)}")
            if writes:
                lines.append(f"- Written fields: {', '.join([w['field_full_name'] for w in writes[:8]])}")
            reads = int(
                conn.execute(
                    "SELECT COUNT(*) AS c FROM flow_field_reads WHERE lower(flow_name)=lower(?)",
                    (row["flow_name"],),
                ).fetchone()["c"]
            )
            lines.append(f"- Field reads: {reads}")
            action_edges = conn.execute(
                """
                SELECT edge_type, COUNT(*) AS c
                FROM graph_edges e
                JOIN graph_nodes s ON s.node_id=e.src_node_id
                WHERE s.node_type='FLOW'
                  AND lower(s.name)=lower(?)
                  AND e.edge_type IN ('FLOW_CALLS_SUBFLOW','FLOW_CALLS_APEX_ACTION')
                GROUP BY edge_type
                """,
                (row["flow_name"],),
            ).fetchall()
            for ae in action_edges:
                lines.append(f"- {ae['edge_type']}: {ae['c']}")
            xml = _read_repo_relative_text(repo_root, row["path"])
            if xml:
                fault_paths = len(re.findall(r"faultConnector", xml))
                upd = len(re.findall(r"UpdateRecords|RecordUpdate", xml))
                lines.append(f"- Fault connectors: {fault_paths}")
                lines.append(f"- Update-like elements: {upd}")
    elif t in {"apexclass", "apex"}:
        row = conn.execute(
            """
            SELECT loc, soql_count, dml_count, has_dynamic_soql, has_callout
            FROM apex_class_stats
            WHERE lower(class_name)=lower(?)
            LIMIT 1
            """,
            (name,),
        ).fetchone()
        if row:
            lines.append(f"- LOC: {row['loc']}")
            lines.append(f"- SOQL count: {row['soql_count']}")
            lines.append(f"- DML count: {row['dml_count']}")
            lines.append(f"- Dynamic SOQL: {'yes' if int(row['has_dynamic_soql'] or 0) else 'no'}")
            lines.append(f"- Callout usage: {'yes' if int(row['has_callout'] or 0) else 'no'}")
        path_row = conn.execute(
            "SELECT path FROM components WHERE type='APEX' AND lower(name)=lower(?) LIMIT 1",
            (name,),
        ).fetchone()
        apex_path = path_row["path"] if path_row else None
        cls_text = _read_repo_relative_text(repo_root, apex_path)
        if cls_text:
            methods = re.findall(
                r"\b(?:public|private|global|protected)\s+(?:static\s+)?[A-Za-z0-9_<>,\\[\\]]+\s+([A-Za-z0-9_]+)\s*\(",
                cls_text,
            )
            lines.append(f"- Public/protected/private/global methods: {len(methods)}")
            if methods:
                lines.append(f"- Method names: {', '.join(methods[:10])}")
        rw = conn.execute(
            """
            SELECT rw, COUNT(*) AS c
            FROM apex_rw
            WHERE lower(class_name)=lower(?)
            GROUP BY rw
            """,
            (name,),
        ).fetchall()
        for r in rw:
            lines.append(f"- Field/object {r['rw']} refs: {r['c']}")
        ep = conn.execute(
            "SELECT endpoint_value FROM apex_endpoints WHERE lower(class_name)=lower(?) ORDER BY endpoint_value LIMIT 10",
            (name,),
        ).fetchall()
        if ep:
            lines.append(f"- Endpoints: {', '.join([x['endpoint_value'] for x in ep])}")
    elif t == "trigger":
        row = conn.execute(
            "SELECT path FROM components WHERE type='TRIGGER' AND lower(name)=lower(?) LIMIT 1",
            (name,),
        ).fetchone()
        trig_path = row["path"] if row else path
        trg_text = _read_repo_relative_text(repo_root, trig_path)
        if trg_text:
            m = re.search(r"trigger\s+[A-Za-z0-9_]+\s+on\s+([A-Za-z0-9_]+)\s*\(([^)]+)\)", trg_text, flags=re.IGNORECASE)
            if m:
                lines.append(f"- Trigger object: {m.group(1)}")
                lines.append(f"- Events: {m.group(2).strip()}")
        deps = conn.execute(
            """
            SELECT DISTINCT d.name AS class_name
            FROM graph_edges e
            JOIN graph_nodes s ON s.node_id=e.src_node_id
            JOIN graph_nodes d ON d.node_id=e.dst_node_id
            WHERE s.node_type='TRIGGER' AND lower(s.name)=lower(?) AND e.edge_type='TRIGGER_CALLS_CLASS'
            ORDER BY class_name
            LIMIT 20
            """,
            (name,),
        ).fetchall()
        lines.append(f"- Handler/dependency classes: {len(deps)}")
        if deps:
            lines.append(f"- Classes: {', '.join([d['class_name'] for d in deps[:10]])}")
    elif t == "validationrule":
        row = conn.execute(
            """
            SELECT object_name, rule_name, active, error_condition, error_message, path
            FROM validation_rules
            WHERE lower(path)=lower(?) OR lower(rule_name)=lower(?)
            LIMIT 1
            """,
            (path, name),
        ).fetchone()
        if row:
            lines.append(f"- Object: {row['object_name']}")
            lines.append(f"- Active: {'true' if int(row['active'] or 0)==1 else 'false'}")
            lines.append(f"- Error condition: {row['error_condition'] or 'Not specified in repo evidence.'}")
            lines.append(f"- Error message: {row['error_message'] or 'Not specified in repo evidence.'}")
    elif t == "lwc":
        if path:
            m = re.search(r"/lwc/([^/]+)/", path)
            bundle = m.group(1) if m else name
            rows = conn.execute(
                """
                SELECT path
                FROM meta_files
                WHERE lower(folder)=lower('lwc')
                  AND lower(path) LIKE lower(?)
                ORDER BY path
                LIMIT 50
                """,
                (f"%/lwc/{bundle}/%",),
            ).fetchall()
            lines.append(f"- Bundle: {bundle}")
            lines.append(f"- Files indexed: {len(rows)}")
            apex_calls: set[str] = set()
            schema_refs: set[str] = set()
            for r in rows[:100]:
                txt = _read_repo_relative_text(repo_root, r["path"])
                for mm in re.finditer(r"@salesforce/apex/([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)", txt):
                    apex_calls.add(f"{mm.group(1)}.{mm.group(2)}")
                for mm in re.finditer(r"@salesforce/schema/([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)", txt):
                    schema_refs.add(f"{mm.group(1)}.{mm.group(2)}")
            lines.append(f"- Apex imports: {len(apex_calls)}")
            if apex_calls:
                lines.append(f"- Apex methods: {', '.join(sorted(apex_calls)[:8])}")
            lines.append(f"- Schema field refs: {len(schema_refs)}")
            if schema_refs:
                lines.append(f"- Schema fields: {', '.join(sorted(schema_refs)[:8])}")
    elif t in {"permissionset/profile", "permissionset", "profile"}:
        if path:
            obj_count = int(
                conn.execute(
                    """
                    SELECT COUNT(*) AS c
                    FROM "references"
                    WHERE src_type='PERMISSION' AND src_path=? AND ref_type='OBJECT'
                    """,
                    (path,),
                ).fetchone()["c"]
            )
            fld_count = int(
                conn.execute(
                    """
                    SELECT COUNT(*) AS c
                    FROM "references"
                    WHERE src_type='PERMISSION' AND src_path=? AND ref_type='FIELD'
                    """,
                    (path,),
                ).fetchone()["c"]
            )
            lines.append(f"- Object permission references: {obj_count}")
            lines.append(f"- Field permission references: {fld_count}")
            txt = _read_repo_relative_text(repo_root, path)
            if txt:
                lines.append(f"- ViewAllData: {'yes' if '<viewAllData>true</viewAllData>' in txt else 'no'}")
                lines.append(f"- ModifyAllData: {'yes' if '<modifyAllData>true</modifyAllData>' in txt else 'no'}")
                top_objs = conn.execute(
                    """
                    SELECT ref_key, COUNT(*) AS c
                    FROM "references"
                    WHERE src_type='PERMISSION' AND src_path=? AND ref_type='OBJECT'
                    GROUP BY ref_key
                    ORDER BY c DESC, ref_key
                    LIMIT 10
                    """,
                    (path,),
                ).fetchall()
                if top_objs:
                    lines.append("- Top object permission refs: " + ", ".join([r["ref_key"] for r in top_objs[:10]]))
    elif t == "sharingrule":
        rows = conn.execute(
            """
            SELECT name, object_name, rule_type, access_level, active, path
            FROM sharing_rules
            WHERE lower(object_name)=lower(?) OR lower(path)=lower(?)
            ORDER BY name
            LIMIT 10
            """,
            (name, path),
        ).fetchall()
        if rows:
            lines.append(f"- Sharing rules indexed: {len(rows)}")
            for r in rows[:5]:
                lines.append(f"  - {r['name']} ({r['object_name']}) access={r['access_level'] or 'n/a'}")
    elif t == "connectedapp":
        txt = _read_repo_relative_text(repo_root, path)
        if txt:
            callbacks = re.findall(r"<callbackUrl>([^<]+)</callbackUrl>", txt)
            scopes = re.findall(r"<scope>([^<]+)</scope>", txt)
            lines.append(f"- OAuth scopes: {len(scopes)}")
            if scopes:
                lines.append(f"- Scope values: {', '.join(scopes[:10])}")
            lines.append(f"- Callback URLs: {len(callbacks)}")
            if callbacks:
                lines.append(f"- Callback examples: {', '.join(callbacks[:5])}")
    elif t == "layout":
        txt = _read_repo_relative_text(repo_root, path)
        if txt:
            sections = len(re.findall(r"<layoutSections>", txt))
            fields = re.findall(r"<field>([^<]+)</field>", txt)
            related = len(re.findall(r"<relatedLists>", txt))
            quick = len(re.findall(r"quickAction", txt, flags=re.IGNORECASE))
            lines.append(f"- Sections: {sections}")
            lines.append(f"- Fields: {len(fields)}")
            if fields:
                lines.append(f"- Sample fields: {', '.join(fields[:10])}")
            lines.append(f"- Related lists: {related}")
            lines.append(f"- Quick action entries: {quick}")

    return lines


def _render_explain_facts(
    conn: sqlite3.Connection,
    *,
    target_info: dict[str, Any],
    evidence: dict[str, Any],
    snippet_bundle: str,
    repo_root: Path,
    adapter_result: dict[str, Any] | None = None,
) -> str:
    target = evidence.get("target", {}) or {}
    paths = list(evidence.get("evidence_paths", []) or [])
    refs = list(evidence.get("refs", []) or [])
    automations = list(evidence.get("automations", []) or [])
    ui = list(evidence.get("ui_surface", []) or [])
    sec = list(evidence.get("security_surface", []) or [])
    integ = list(evidence.get("integration_surface", []) or [])

    adapter = adapter_result or {}
    facts = adapter.get("facts") or {}
    deps = adapter.get("deps") or {}
    dep_calls = list(deps.get("calls") or [])
    dep_called_by = list(deps.get("called_by") or [])
    dep_reads = list(deps.get("reads") or [])
    dep_writes = list(deps.get("writes") or [])
    dep_touches = list(deps.get("touches") or [])
    risk_lines = list(adapter.get("risks") or [])
    test_lines = list(adapter.get("tests") or [])
    adapter_evidence = list(adapter.get("evidence") or [])

    if not risk_lines and target_info.get("resolved_type") == "ApexClass":
        stats = conn.execute(
            """
            SELECT has_dynamic_soql, has_callout
            FROM apex_class_stats
            WHERE lower(class_name)=lower(?)
            LIMIT 1
            """,
            (target_info.get("resolved_name"),),
        ).fetchone()
        if stats:
            if int(stats["has_dynamic_soql"] or 0) == 1:
                risk_lines.append("Dynamic SOQL detected.")
            if int(stats["has_callout"] or 0) == 1:
                risk_lines.append("Callout usage detected.")

    if not test_lines:
        if target_info.get("resolved_type") in {"Flow"}:
            test_lines = [
                "Validate entry criteria, branching, and downstream record updates.",
                "Verify all fault/error branches in flow runtime.",
            ]
        elif target_info.get("resolved_type") in {"ApexClass", "Trigger"}:
            test_lines = [
                "Add/update unit tests for happy path and negative path behavior.",
                "Validate dependency interactions and governor-safe behavior.",
            ]
        else:
            test_lines = ["Run smoke tests on impacted components listed in Evidence."]

    affected: list[tuple[str, str]] = []
    for row in dep_reads + dep_writes + dep_touches:
        nm = row.get("name")
        typ = row.get("type") or row.get("node_type") or row.get("edge_type") or "REF"
        if isinstance(nm, str) and nm:
            affected.append((str(typ), nm))
    if not affected:
        for row in (evidence.get("writers") or []) + (evidence.get("readers") or []):
            nm = row.get("field") or row.get("name")
            typ = row.get("type") or "REF"
            if isinstance(nm, str) and nm:
                affected.append((str(typ), nm))

    def _fmt_dep(rows: list[dict[str, Any]], limit: int = 20) -> list[str]:
        out: list[str] = []
        for r in rows[:limit]:
            nm = r.get("name") or r.get("field") or r.get("ref_value") or ""
            typ = r.get("type") or r.get("node_type") or r.get("edge_type") or ""
            p = r.get("path") or r.get("evidence_path") or ""
            conf = r.get("confidence")
            conf_s = f" ({float(conf):.2f})" if isinstance(conf, (int, float)) else ""
            out.append(f"- {typ} {nm}{conf_s} | {p}".rstrip())
        return out

    # Merge evidence rows from adapter + graph refs + paths.
    merged_evidence: list[dict[str, Any]] = []
    seen: set[tuple[str, int | None, str]] = set()
    for row in adapter_evidence + refs:
        p = row.get("path") or row.get("src_path")
        ln = row.get("line_no") or row.get("line_start")
        sn = row.get("snippet") or row.get("ref_value") or ""
        if not p:
            continue
        key = (str(p), int(ln) if isinstance(ln, int) else None, str(sn))
        if key in seen:
            continue
        seen.add(key)
        merged_evidence.append({"path": p, "line_no": ln if isinstance(ln, int) else None, "snippet": sn, "confidence": row.get("confidence")})
    for p in paths:
        key = (str(p), None, "")
        if key in seen:
            continue
        seen.add(key)
        merged_evidence.append({"path": p, "line_no": None, "snippet": "", "confidence": None})

    lines: list[str] = []
    lines.append("# Explain")
    lines.append("")
    lines.append("## What It Is")
    lines.append(f"- Type: {adapter.get('type') or target_info.get('resolved_type') or target.get('type') or _not_found_section()}")
    lines.append(f"- Name: {adapter.get('name') or target_info.get('resolved_name') or target.get('name') or target_info.get('raw_target')}")
    lines.append("")

    lines.append("## Structured Details")
    if facts:
        for k, v in facts.items():
            key = str(k).replace("_", " ").capitalize()
            if isinstance(v, list):
                if not v:
                    continue
                if v and isinstance(v[0], dict):
                    preview = ", ".join(str(x.get("name") or x.get("tag") or x) for x in v[:10])
                else:
                    preview = ", ".join(str(x) for x in v[:10])
                lines.append(f"- {key}: {preview}")
            elif isinstance(v, dict):
                if v:
                    preview = ", ".join(f"{ik}={iv}" for ik, iv in list(v.items())[:10])
                    lines.append(f"- {key}: {preview}")
            elif v is not None and v != "":
                lines.append(f"- {key}: {v}")
    else:
        structured = _structured_details(conn, target_info, repo_root)
        if structured:
            lines.extend(structured)
        else:
            lines.append(f"- {_not_found_section()}")
    lines.append("")

    lines.append("## Where It Lives")
    out_paths = []
    if adapter.get("path"):
        out_paths.append(str(adapter["path"]))
    out_paths.extend([str(p) for p in paths if p not in out_paths])
    if target_info.get("resolved_path") and str(target_info["resolved_path"]) not in out_paths:
        out_paths.append(str(target_info["resolved_path"]))
    if out_paths:
        for p in out_paths[:20]:
            lines.append(f"- {p}")
    else:
        lines.append(f"- {_not_found_section()}")
    lines.append("")

    lines.append("## What It Affects")
    if affected:
        by_type: dict[str, list[str]] = {}
        for t, n in affected:
            by_type.setdefault(t, [])
            if n not in by_type[t]:
                by_type[t].append(n)
        for t in sorted(by_type.keys()):
            lines.append(f"- {t}: {', '.join(by_type[t][:20])}")
    else:
        lines.append(f"- {_not_found_section()}")
    lines.append("")

    lines.append("## Dependencies")
    dep_lines = _fmt_dep(dep_calls) + _fmt_dep(dep_called_by) + _fmt_dep(dep_reads) + _fmt_dep(dep_writes) + _fmt_dep(dep_touches)
    if dep_lines:
        lines.extend(dep_lines[:30])
    else:
        lines.append(f"- {_not_found_section()}")
    lines.append("")

    lines.append("## Automation / UI / Security Impact")
    if automations:
        lines.append(f"- Automation items: {len(automations)}")
    if ui:
        lines.append(f"- UI references: {len(ui)}")
    if sec:
        lines.append(f"- Security references: {len(sec)}")
    if integ:
        lines.append(f"- Integration references: {len(integ)}")
    if not (automations or ui or sec or integ):
        lines.append(f"- {_not_found_section()}")
    lines.append("")

    lines.append("## Risks / Tech Debt Signals")
    if risk_lines:
        for r in risk_lines:
            lines.append(f"- {r}")
    else:
        lines.append(f"- {_not_found_section()}")
    lines.append("")

    lines.append("## How To Test")
    for r in test_lines:
        lines.append(f"- {r}")
    lines.append("")

    lines.append("## Evidence")
    if merged_evidence:
        for r in merged_evidence[:30]:
            p = r.get("path") or ""
            ln = r.get("line_no")
            loc = f":{ln}" if isinstance(ln, int) else ""
            sn = r.get("snippet") or ""
            lines.append(f"- {p}{loc}")
            if sn:
                lines.append(f"  snippet: {sn}")
    else:
        lines.append(f"- {_not_found_section()}")

    if snippet_bundle:
        lines.append("")
        lines.append("## Snippets")
        lines.append("```text")
        lines.append(snippet_bundle[:25000])
        lines.append("```")
    return "\n".join(lines) + "\n"


def _explain_with_llm(
    cfg: AppConfig,
    *,
    target: str,
    evidence: dict[str, Any],
    snippet_bundle: str,
    debug_llm: bool,
) -> dict[str, Any]:
    prompt = (
        "You are a Salesforce architect.\n"
        "Use only provided evidence and snippets. Do not invent facts.\n"
        "If evidence is missing, write: Not specified in repo evidence.\n"
        "Cite file paths in each section.\n\n"
        "Return markdown with sections exactly:\n"
        "What it is\n"
        "Where it lives\n"
        "What it affects\n"
        "Dependencies\n"
        "Automation / UI / Security impact\n"
        "Risks / tech debt signals\n"
        "How to test\n"
        "Evidence\n\n"
        f"Target: {target}\n\n"
        f"Evidence JSON:\n{json.dumps(evidence, indent=2)}\n\n"
        f"Snippet bundle:\n{snippet_bundle}\n"
    )
    body = {
        "model": cfg.ollama.gen_model,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": cfg.ollama.temperature, "top_p": cfg.ollama.top_p},
    }
    prompt_tokens_est = max(1, len(prompt) // 4)
    if debug_llm:
        print(
            f"CALLING OLLAMA model={cfg.ollama.gen_model} "
            f"endpoint={cfg.ollama.base_url.rstrip('/')}/api/generate mode=narrate_only"
        )
        print(f"LLM debug: prompt_chars={len(prompt)} prompt_tokens_est={prompt_tokens_est} snippet_chars={len(snippet_bundle)}")
    started = time.perf_counter()
    resp = requests.post(f"{cfg.ollama.base_url.rstrip('/')}/api/generate", json=body, timeout=180)
    resp.raise_for_status()
    data = resp.json()
    latency_ms = int((time.perf_counter() - started) * 1000)
    return {
        "markdown": (data.get("response") or "").strip(),
        "llm_prompt_tokens_est": prompt_tokens_est,
        "llm_latency_ms": latency_ms,
    }


def build_explain_payload(
    conn: sqlite3.Connection,
    *,
    target: str,
    project_root: Path,
    repo_root: Path | None,
    cfg: AppConfig | None,
    use_llm: bool,
    debug_llm: bool,
    depth: int = 2,
    top_n: int = 20,
) -> dict[str, Any]:
    target_info = _resolve_explain_target(conn, target)
    resolved_rel_path = str(target_info.get("resolved_path") or "")
    if resolved_rel_path:
        mf = conn.execute(
            """
            SELECT folder, type_guess, api_name
            FROM meta_files
            WHERE lower(path)=lower(?)
            LIMIT 1
            """,
            (resolved_rel_path,),
        ).fetchone()
        if mf:
            target_info["metadata_folder"] = mf["folder"]
            if (not target_info.get("resolved_type") or str(target_info.get("resolved_type")).lower() in {"unknown", "file"}) and mf["type_guess"]:
                target_info["resolved_type"] = mf["type_guess"]
            if not target_info.get("resolved_name") and mf["api_name"]:
                target_info["resolved_name"] = mf["api_name"]

    evidence = build_evidence(conn, target=target_info["target_for_evidence"], depth=depth, top_n=top_n)
    candidate_repo = project_root / "template_repo"
    if not repo_root or not repo_root.exists():
        if candidate_repo.exists():
            repo_root = candidate_repo
        else:
            repo_root = project_root

    if resolved_rel_path:
        p = repo_root / resolved_rel_path
        if not p.exists() and candidate_repo.exists() and (candidate_repo / resolved_rel_path).exists():
            repo_root = candidate_repo
        elif not p.exists() and (project_root / resolved_rel_path).exists():
            repo_root = project_root

    adapter = get_explainer(target_info)
    adapter_result = adapter.explain(target_info, repo_root, conn)

    tokens = [
        str(target_info.get("resolved_name") or ""),
        str((evidence.get("target") or {}).get("name") or ""),
        str(target),
    ]
    snippet_rows: list[dict[str, Any]] = []
    snippet_rows.extend(adapter_result.get("evidence") or [])
    for p in (evidence.get("evidence_paths") or [])[:60]:
        snippet_rows.append({"path": p, "line_no": None, "snippet": ""})
    snippets = collect_explainer_snippets(
        repo_root,
        snippet_rows,
        tokens,
        max_snippets=12,
        max_chars=25000,
    )
    snippet_bundle = snippets_to_text(snippets, max_chars=25000)

    markdown = _render_explain_facts(
        conn,
        target_info=target_info,
        evidence=evidence,
        snippet_bundle=snippet_bundle,
        repo_root=repo_root,
        adapter_result=adapter_result,
    )
    llm_used = False
    llm_error = None
    llm_calls = 0
    llm_prompt_tokens_est = None
    llm_latency_ms = None
    llm_mode = "narrate_only"
    llm_model = cfg.ollama.gen_model if cfg else None
    target_found = bool((evidence.get("target") or {}).get("found")) or bool(adapter_result.get("path"))
    if use_llm and cfg and target_found:
        try:
            llm_calls = 1
            llm_result = _explain_with_llm(
                cfg,
                target=target_info.get("target_for_evidence") or target,
                evidence=evidence,
                snippet_bundle=snippet_bundle,
                debug_llm=debug_llm,
            )
            markdown = llm_result.get("markdown") or markdown
            llm_prompt_tokens_est = llm_result.get("llm_prompt_tokens_est")
            llm_latency_ms = llm_result.get("llm_latency_ms")
            llm_used = True
        except Exception as exc:
            llm_error = str(exc)
            markdown = markdown + f"\n\nLLM explain skipped: {exc}\n"

    return {
        "target_input": target,
        "resolved": target_info,
        "evidence": evidence,
        "adapter_result": adapter_result,
        "adapter_name": adapter.adapter_name,
        "snippets": snippets,
        "snippet_bundle": snippet_bundle,
        "markdown": markdown,
        "llm_used": llm_used,
        "llm_model": llm_model,
        "llm_calls": llm_calls,
        "llm_mode": llm_mode,
        "llm_prompt_tokens_est": llm_prompt_tokens_est,
        "llm_latency_ms": llm_latency_ms,
        "llm_error": llm_error,
    }


def cmd_explain(
    cfg: AppConfig,
    conn: sqlite3.Connection,
    project_root: Path,
    *,
    target: str,
    out_path: str | None,
    use_llm: bool,
    debug_llm: bool,
) -> int:
    repo_root = cfg.resolve_repo_root(project_root)
    payload = build_explain_payload(
        conn,
        target=target,
        project_root=project_root,
        repo_root=repo_root,
        cfg=cfg,
        use_llm=use_llm,
        debug_llm=debug_llm,
    )
    md = payload["markdown"]
    if out_path:
        out = Path(out_path)
        if not out.is_absolute():
            out = project_root / out
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(md, encoding="utf-8")
        print(out.as_posix())
    else:
        print(md.rstrip())
    return 0


def build_object_explain(conn: sqlite3.Connection, obj: str) -> dict:
    fields = conn.execute(
        "SELECT field_api, data_type, path FROM fields WHERE lower(object_name)=lower(?) ORDER BY field_api",
        (obj,),
    ).fetchall()

    ref_count = conn.execute(
        """
        SELECT COUNT(*) AS c
        FROM "references"
        WHERE (ref_type='OBJECT' AND lower(ref_key)=lower(?))
           OR (ref_type='FIELD' AND lower(ref_key) LIKE lower(?))
        """,
        (obj, f"{obj}.%"),
    ).fetchone()["c"]

    flows = conn.execute(
        """
        SELECT DISTINCT f.flow_name, f.path
        FROM flows f
        LEFT JOIN flow_field_reads r ON r.flow_name = f.flow_name
        LEFT JOIN flow_field_writes w ON w.flow_name = f.flow_name
        LEFT JOIN flow_true_writes tw ON tw.flow_name = f.flow_name
        WHERE lower(f.trigger_object)=lower(?)
           OR lower(r.full_field_name) LIKE lower(?)
           OR lower(w.full_field_name) LIKE lower(?)
           OR (tw.write_kind='field_write' AND lower(tw.field_full_name) LIKE lower(?))
        ORDER BY f.flow_name
        LIMIT 100
        """,
        (obj, f"{obj}.%", f"{obj}.%", f"{obj}.%"),
    ).fetchall()

    apex = conn.execute(
        """
        SELECT DISTINCT src_name, src_path
        FROM "references"
        WHERE src_type='APEX'
          AND (
            (ref_type='OBJECT' AND lower(ref_key)=lower(?))
            OR (ref_type='FIELD' AND lower(ref_key) LIKE lower(?))
          )
        ORDER BY src_name
        LIMIT 100
        """,
        (obj, f"{obj}.%"),
    ).fetchall()

    sec = conn.execute(
        """
        SELECT ref_type, ref_key, src_name, src_path, snippet
        FROM "references"
        WHERE src_type='PERMISSION'
          AND (
            (ref_type='OBJECT' AND lower(ref_key)=lower(?))
            OR (ref_type='FIELD' AND lower(ref_key) LIKE lower(?))
          )
        ORDER BY src_name
        """,
        (obj, f"{obj}.%"),
    ).fetchall()

    return {
        "object": obj,
        "field_count": len(fields),
        "top_fields": fields[:20],
        "reference_count": int(ref_count),
        "flows": flows,
        "apex": apex,
        "security": sec,
    }


def cmd_explain_object(conn: sqlite3.Connection, obj: str) -> int:
    data = build_object_explain(conn, obj)
    if data["field_count"] == 0 and data["reference_count"] == 0:
        _print_not_found()
        return 0

    print(f"Object: {data['object']}")
    print(f"Field count: {data['field_count']}")
    print("Top 20 fields:")
    for row in data["top_fields"]:
        print(f"- {row['field_api']} ({row['data_type']}) [{row['path']}]")
    print(f"Number of references found: {data['reference_count']}")
    print(f"Flows touching {obj}: {len(data['flows'])}")
    for r in data["flows"][:20]:
        print(f"- {r['flow_name']} [{r['path']}]")
    print(f"Apex touching {obj}: {len(data['apex'])}")
    for r in data["apex"][:20]:
        print(f"- {r['src_name']} [{r['src_path']}]")

    sec_files = sorted({r["src_path"] for r in data["security"]})
    print(f"Security/FLS references: {len(data['security'])} entries across {len(sec_files)} files")
    for p in sec_files[:20]:
        print(f"- {p}")

    return 0


def cmd_graph_build(cfg: AppConfig, project_root: Path, repo_override: str | None) -> int:
    if repo_override:
        cfg.repo_root = repo_override
    repo_root = cfg.resolve_repo_root(project_root)
    conn = _conn_from_cfg(cfg, project_root)
    try:
        stats = build_dependency_graph(conn, repo_root=repo_root, sfdx_root=cfg.sfdx_root)
    finally:
        conn.close()
    print(
        f"graph build complete: nodes={stats.nodes} edges={stats.edges} "
        f"flow_edges={stats.flow_edges} trigger_edges={stats.trigger_edges} apex_edges={stats.apex_edges} metadata_edges={stats.metadata_edges}"
    )
    return 0


def cmd_blast_radius(
    cfg: AppConfig,
    project_root: Path,
    *,
    base_ref: str,
    head_ref: str,
    depth: int,
    out_path: str,
) -> int:
    conn = _conn_from_cfg(cfg, project_root)
    try:
        repo_root = cfg.resolve_repo_root(project_root)
        payload = build_blast_radius(
            conn,
            repo_root=repo_root,
            sfdx_root=cfg.sfdx_root,
            base_ref=base_ref,
            head_ref=head_ref,
            depth=depth,
        )
    finally:
        conn.close()

    out = Path(out_path)
    if not out.is_absolute():
        out = project_root / out
    write_json(out, payload)

    print(f"base_ref={base_ref} head_ref={head_ref} depth={depth}")
    changed = payload.get("changed", {})
    for k in ["FLOW", "APEX_CLASS", "TRIGGER", "FIELD", "OBJECT"]:
        print(f"changed {k}: {len(changed.get(k, []))}")
    impacted = payload.get("impacted", {})
    for k in ["FLOW", "APEX_CLASS", "TRIGGER", "FIELD", "OBJECT", "ENDPOINT"]:
        print(f"impacted {k}: {len(impacted.get(k, []))}")
    print("Top hotspots:")
    for h in payload.get("hotspots", [])[:10]:
        path = h.get("path") or ""
        print(
            f"- {h['node_type']}:{h['name']} | in={h['in_degree']} out={h['out_degree']} | {path}"
        )
    for n in payload.get("notes", [])[:20]:
        print(f"note: {n}")
    print(out.as_posix())
    return 0


def _fmt_line_range(line_start: int | None, line_end: int | None) -> str:
    if line_start is None:
        return ""
    if line_end is None or line_end == line_start:
        return f":{line_start}"
    return f":{line_start}-{line_end}"


def cmd_deps_flow(conn: sqlite3.Connection, flow_name: str) -> int:
    data = deps_for_flow(conn, flow_name)
    node = data.get("node")
    if not node:
        _print_not_found()
        return 0

    print(f"Flow: {node['name']}")
    groups: dict[str, list[sqlite3.Row]] = data.get("groups", {})
    edge_order = [
        "FLOW_READS_FIELD",
        "FLOW_WRITES_FIELD",
        "FLOW_UPDATES_OBJECT",
        "FLOW_CREATES_OBJECT",
        "FLOW_CALLS_APEX_ACTION",
        "FLOW_CALLS_SUBFLOW",
    ]
    for edge_type in edge_order:
        rows = groups.get(edge_type, [])
        print(f"{edge_type}: {len(rows)}")
        for r in rows[:100]:
            loc = _fmt_line_range(r["evidence_line_start"], r["evidence_line_end"])
            print(
                f"- {r['dst_name']} | confidence={r['confidence']:.2f} | "
                f"path={r['evidence_path'] or ''}{loc}"
            )
            if r["evidence_snippet"]:
                print(f"  snippet: {r['evidence_snippet']}")
    return 0


def cmd_deps_class(conn: sqlite3.Connection, class_name: str) -> int:
    data = deps_for_class(conn, class_name)
    node = data.get("node")
    if not node:
        _print_not_found()
        return 0

    print(f"Class: {node['name']}")
    outgoing: dict[str, list[sqlite3.Row]] = data.get("outgoing", {})
    inbound: dict[str, list[sqlite3.Row]] = data.get("inbound", {})

    out_order = [
        "CLASS_CALLS_ENDPOINT",
        "CLASS_QUERIES_OBJECT",
        "CLASS_READS_FIELD",
        "CLASS_WRITES_FIELD",
        "CLASS_CALLS_CLASS",
    ]
    for edge_type in out_order:
        rows = outgoing.get(edge_type, [])
        print(f"{edge_type}: {len(rows)}")
        for r in rows[:100]:
            loc = _fmt_line_range(r["evidence_line_start"], r["evidence_line_end"])
            print(
                f"- {r['dst_name']} | confidence={r['confidence']:.2f} | "
                f"path={r['evidence_path'] or ''}{loc}"
            )
            if r["evidence_snippet"]:
                print(f"  snippet: {r['evidence_snippet']}")

    in_order = ["TRIGGER_CALLS_CLASS", "FLOW_CALLS_APEX_ACTION"]
    for edge_type in in_order:
        rows = inbound.get(edge_type, [])
        print(f"inbound {edge_type}: {len(rows)}")
        for r in rows[:100]:
            loc = _fmt_line_range(r["evidence_line_start"], r["evidence_line_end"])
            print(
                f"- {r['src_name']} | confidence={r['confidence']:.2f} | "
                f"path={r['evidence_path'] or ''}{loc}"
            )
            if r["evidence_snippet"]:
                print(f"  snippet: {r['evidence_snippet']}")

    return 0


def cmd_collisions(
    conn: sqlite3.Connection,
    project_root: Path,
    *,
    object_name: str | None,
    field_name: str | None,
    out_path: str,
) -> int:
    payload = detect_collisions(conn, object_name=object_name, field_name=field_name)

    out = Path(out_path)
    if not out.is_absolute():
        out = project_root / out
    write_json(out, payload)

    print(f"scope: {payload.get('scope')}")
    collisions = payload.get("collisions", [])
    print(f"collision clusters: {len(collisions)}")
    for c in collisions[:20]:
        print(f"- field={c['field']} | writers={len(c.get('writers', []))} | risk={c.get('risk')}")
        for w in c.get("writers", [])[:10]:
            print(
                f"  - {w['type']}:{w['name']} | confidence={w.get('confidence', 0.0):.2f} | "
                f"path={w.get('path') or ''}"
            )
    print(out.as_posix())
    return 0


def cmd_what_breaks(
    conn: sqlite3.Connection,
    project_root: Path,
    *,
    target: str,
    depth: int,
    out_path: str | None,
) -> int:
    payload = what_breaks(conn, target=target, depth=depth)
    resolved = payload.get("resolved", {})
    print(f"Resolved target type: {resolved.get('node_type')}")
    print(f"Resolved target name: {resolved.get('name')}")
    print(f"Confidence: {float(resolved.get('confidence') or 0.0):.2f}")

    counts = payload.get("counts", {})
    for k in ["FLOW", "APEX_CLASS", "TRIGGER", "FIELD", "OBJECT", "ENDPOINT"]:
        print(f"{k}: {counts.get(k, 0)}")

    dependents = payload.get("dependents", [])
    if not dependents:
        _print_not_found()
    else:
        print("Top dependents:")
        for d in dependents[:50]:
            loc = _fmt_line_range(d.get("evidence_line_start"), d.get("evidence_line_end"))
            print(
                f"- {d.get('node_type')}:{d.get('name')} | via {d.get('edge_type')} | "
                f"confidence={float(d.get('confidence') or 0.0):.2f} | {d.get('evidence_path') or d.get('path') or ''}{loc}"
            )
            if d.get("evidence_snippet"):
                print(f"  snippet: {d['evidence_snippet']}")

    for n in payload.get("notes", []):
        print(f"note: {n}")

    if out_path:
        out = Path(out_path)
        if not out.is_absolute():
            out = project_root / out
        write_json(out, payload)
        print(out.as_posix())

    return 0


def cmd_test_checklist(
    conn: sqlite3.Connection,
    project_root: Path,
    *,
    target: str,
    out_path: str,
) -> int:
    report = what_breaks(conn, target=target, depth=2)
    markdown = build_test_checklist_markdown(report)

    out = Path(out_path)
    if not out.is_absolute():
        out = project_root / out
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(markdown, encoding="utf-8")
    print(out.as_posix())
    return 0


def cmd_impact_field_graph(conn: sqlite3.Connection, full_field_name: str, *, confidence: float = 0.0) -> int:
    data = impact_field_graph(conn, full_field_name)
    if not data.get("node"):
        _print_not_found()
        return 0

    field = data["node"]["name"]
    obj, fld = field.split(".", 1) if "." in field else ("", field)
    print("Resolved intent: impact_field")
    print(f"Resolved entities: object={obj} | field={fld} | full_field={field}")
    print(f"Confidence: {confidence:.2f}")

    counts: dict[str, int] = data.get("counts", {})
    print(f"FLOW_READS_FIELD: {counts.get('FLOW_READS_FIELD', 0)}")
    print(f"FLOW_WRITES_FIELD: {counts.get('FLOW_WRITES_FIELD', 0)}")
    print(f"CLASS_READS_FIELD: {counts.get('CLASS_READS_FIELD', 0)}")
    print(f"CLASS_WRITES_FIELD: {counts.get('CLASS_WRITES_FIELD', 0)}")

    inbound: list[sqlite3.Row] = data.get("inbound", [])
    if inbound:
        print("Top inbound edges:")
        for r in inbound[:20]:
            loc = _fmt_line_range(r["evidence_line_start"], r["evidence_line_end"])
            print(
                f"- {r['edge_type']} | {r['src_type']}:{r['src_name']} | "
                f"confidence={r['confidence']:.2f} | {r['evidence_path'] or ''}{loc}"
            )
            if r["evidence_snippet"]:
                print(f"  snippet: {r['evidence_snippet']}")
    else:
        _print_not_found()
        return 0

    context: list[sqlite3.Row] = data.get("context", [])
    if context:
        print("Second-hop context (top 10):")
        for r in context:
            print(
                f"- {r['edge_type']} -> {r['dst_type']}:{r['dst_name']} | confidence={r['confidence']:.2f}"
            )
    return 0


def cmd_impact_object_graph(conn: sqlite3.Connection, object_name: str, *, confidence: float = 0.0) -> int:
    data = impact_object_graph(conn, object_name)
    if not data.get("node"):
        _print_not_found()
        return 0

    obj = data["node"]["name"]
    print("Resolved intent: impact_object")
    print(f"Resolved entities: object={obj}")
    print(f"Confidence: {confidence:.2f}")

    counts: dict[str, int] = data.get("counts", {})
    print(f"CLASS_QUERIES_OBJECT: {counts.get('CLASS_QUERIES_OBJECT', 0)}")
    print(f"FLOW_UPDATES_OBJECT: {counts.get('FLOW_UPDATES_OBJECT', 0)}")
    print(f"FLOW_CREATES_OBJECT: {counts.get('FLOW_CREATES_OBJECT', 0)}")
    print(f"Total fields: {data.get('fields_count', 0)}")

    inbound: list[sqlite3.Row] = data.get("inbound", [])
    if inbound:
        print("Top inbound edges:")
        for r in inbound[:20]:
            loc = _fmt_line_range(r["evidence_line_start"], r["evidence_line_end"])
            print(
                f"- {r['edge_type']} | {r['src_type']}:{r['src_name']} | "
                f"confidence={r['confidence']:.2f} | {r['evidence_path'] or ''}{loc}"
            )
            if r["evidence_snippet"]:
                print(f"  snippet: {r['evidence_snippet']}")
    else:
        _print_not_found()
        return 0

    touched = data.get("touched_fields", [])
    if touched:
        print("Most touched fields:")
        for r in touched:
            print(f"- {r['field_name']}: {r['c']}")
    return 0


def _field_match_params(field: str) -> tuple[str, str, str]:
    suffix = field.split(".", 1)[1] if "." in field else field
    return field, f"*.{suffix}", suffix


def cmd_impact_field(conn: sqlite3.Connection, full_field_name: str, *, confidence: float = 0.0) -> int:
    field, wildcard, suffix = _field_match_params(full_field_name)
    print("Resolved intent: impact_field")
    print(f"Resolved entities: object={field.split('.', 1)[0]} | field={field.split('.', 1)[1]} | full_field={field}")
    print(f"Confidence: {confidence:.2f}")

    flow_reads = conn.execute(
        """
        SELECT COUNT(*) AS c
        FROM flow_field_reads
        WHERE lower(full_field_name)=lower(?) OR lower(full_field_name)=lower(?)
        """,
        (field, suffix),
    ).fetchone()["c"]
    flow_writes = conn.execute(
        """
        SELECT COUNT(*) AS c FROM (
          SELECT flow_name
          FROM flow_true_writes
          WHERE write_kind='field_write'
            AND (lower(field_full_name)=lower(?) OR lower(field_full_name)=lower(?))
          UNION
          SELECT flow_name
          FROM flow_field_writes
          WHERE lower(full_field_name)=lower(?) OR lower(full_field_name)=lower(?)
        )
        """,
        (field, suffix, field, suffix),
    ).fetchone()["c"]

    grouped = conn.execute(
        """
        SELECT src_type, COUNT(*) AS c
        FROM "references"
        WHERE ref_type='FIELD'
          AND (lower(ref_key)=lower(?) OR lower(ref_key)=lower(?))
        GROUP BY src_type
        ORDER BY c DESC, src_type
        """,
        (field, wildcard),
    ).fetchall()

    top_refs = conn.execute(
        """
        SELECT src_type, src_name, src_path, line_start, line_end, snippet, confidence, ref_key
        FROM "references"
        WHERE ref_type='FIELD'
          AND (lower(ref_key)=lower(?) OR lower(ref_key)=lower(?))
        ORDER BY confidence DESC, src_path, COALESCE(line_start, 0)
        LIMIT 20
        """,
        (field, wildcard),
    ).fetchall()

    print(f"Flow reads: {flow_reads}")
    print(f"Flow writes: {flow_writes}")
    print("References by source type:")
    for row in grouped:
        print(f"- {row['src_type']}: {row['c']}")

    if not top_refs:
        _print_not_found()
        return 0

    print("Top 20 references:")
    for row in top_refs:
        line = ""
        if row["line_start"] is not None:
            line = f":{row['line_start']}"
            if row["line_end"] is not None and row["line_end"] != row["line_start"]:
                line += f"-{row['line_end']}"
        print(
            f"- {row['src_path']}{line} | {row['src_type']}:{row['src_name']} | "
            f"{row['ref_key']} | confidence={row['confidence']:.2f}"
        )
        if row["snippet"]:
            print(f"  snippet: {row['snippet']}")
    return 0


def cmd_impact_object(conn: sqlite3.Connection, object_name: str, *, confidence: float = 0.0) -> int:
    print("Resolved intent: impact_object")
    print(f"Resolved entities: object={object_name}")
    print(f"Confidence: {confidence:.2f}")

    field_count = conn.execute(
        "SELECT COUNT(*) AS c FROM fields WHERE lower(object_name)=lower(?)",
        (object_name,),
    ).fetchone()["c"]
    vr_count = conn.execute(
        "SELECT COUNT(*) AS c FROM validation_rules WHERE lower(object_name)=lower(?)",
        (object_name,),
    ).fetchone()["c"]
    perm_count = conn.execute(
        """
        SELECT COUNT(*) AS c
        FROM "references"
        WHERE src_type='PERMISSION'
          AND ((ref_type='OBJECT' AND lower(ref_key)=lower(?))
            OR (ref_type='FIELD' AND lower(ref_key) LIKE lower(?)))
        """,
        (object_name, f"{object_name}.%"),
    ).fetchone()["c"]

    flows_count = conn.execute(
        """
        SELECT COUNT(*) AS c FROM (
          SELECT flow_name FROM flow_field_reads WHERE lower(full_field_name) LIKE lower(?)
          UNION
          SELECT flow_name
          FROM flow_true_writes
          WHERE write_kind='field_write'
            AND lower(field_full_name) LIKE lower(?)
          UNION
          SELECT flow_name FROM flow_field_writes WHERE lower(full_field_name) LIKE lower(?)
          UNION
          SELECT flow_name FROM flows WHERE lower(trigger_object)=lower(?)
        )
        """,
        (f"{object_name}.%", f"{object_name}.%", f"{object_name}.%", object_name),
    ).fetchone()["c"]

    apex_count = conn.execute(
        """
        SELECT COUNT(DISTINCT src_name) AS c
        FROM "references"
        WHERE src_type='APEX'
          AND ((ref_type='OBJECT' AND lower(ref_key)=lower(?))
            OR (ref_type='FIELD' AND lower(ref_key) LIKE lower(?)))
        """,
        (object_name, f"{object_name}.%"),
    ).fetchone()["c"]

    top_refs = conn.execute(
        """
        SELECT src_type, src_name, src_path, line_start, line_end, snippet, confidence, ref_type, ref_key
        FROM "references"
        WHERE (ref_type='OBJECT' AND lower(ref_key)=lower(?))
           OR (ref_type='FIELD' AND lower(ref_key) LIKE lower(?))
        ORDER BY confidence DESC, src_path, COALESCE(line_start, 0)
        LIMIT 20
        """,
        (object_name, f"{object_name}.%"),
    ).fetchall()

    print(f"Total fields: {field_count}")
    print(f"Flows referencing/writing fields: {flows_count}")
    print(f"Apex referencing/querying object: {apex_count}")
    print(f"Validation rules on object: {vr_count}")
    print(f"Permission entries: {perm_count}")

    if not top_refs:
        _print_not_found()
        return 0

    print("Top 20 references:")
    for row in top_refs:
        line = ""
        if row["line_start"] is not None:
            line = f":{row['line_start']}"
            if row["line_end"] is not None and row["line_end"] != row["line_start"]:
                line += f"-{row['line_end']}"
        print(
            f"- {row['src_path']}{line} | {row['src_type']}:{row['src_name']} | "
            f"{row['ref_type']}={row['ref_key']} | confidence={row['confidence']:.2f}"
        )
        if row["snippet"]:
            print(f"  snippet: {row['snippet']}")
    return 0


def cmd_impact(conn: sqlite3.Connection, target: str) -> int:
    parsed = parse_question(f"impact of {target}", conn)
    if parsed.full_field_name:
        if impact_field_graph(conn, parsed.full_field_name).get("node"):
            return cmd_impact_field_graph(conn, parsed.full_field_name, confidence=parsed.confidence)
        return cmd_impact_field(conn, parsed.full_field_name, confidence=parsed.confidence)
    if parsed.object_name:
        if impact_object_graph(conn, parsed.object_name).get("node"):
            return cmd_impact_object_graph(conn, parsed.object_name, confidence=parsed.confidence)
        return cmd_impact_object(conn, parsed.object_name, confidence=parsed.confidence)
    print("Resolved intent: unknown")
    print("Resolved entities: object= | field= | full_field= | endpoint= | contains=")
    print("Confidence: 0.00")
    print("Could not resolve intent/entities")
    return 0


def cmd_techdebt(cfg: AppConfig, project_root: Path, out_path: str) -> int:
    repo_root = cfg.resolve_repo_root(project_root)
    out = Path(out_path)
    if not out.is_absolute():
        out = project_root / out
    out.parent.mkdir(parents=True, exist_ok=True)

    result = {
        "apex": generate_apex_techdebt(repo_root, cfg.sfdx_root),
        "flows": generate_flow_techdebt(repo_root, cfg.sfdx_root),
        "security": generate_security_techdebt(repo_root, cfg.sfdx_root),
    }

    out.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(out.as_posix())
    return 0


def _deterministic_hits_for_question(conn: sqlite3.Connection, question: str) -> list[sqlite3.Row]:
    terms = [t for t in re.findall(r"[A-Za-z0-9_:.]+", question) if len(t) >= 4]
    if not terms:
        return []

    where = " OR ".join(["lower(ref_key) LIKE lower(?) OR lower(src_name) LIKE lower(?) OR lower(snippet) LIKE lower(?)" for _ in terms])
    params: list[str] = []
    for t in terms[:8]:
        like = f"%{t}%"
        params.extend([like, like, like])

    sql = f"""
        SELECT ref_type, ref_key, src_type, src_name, src_path, line_start, line_end, snippet, confidence
        FROM "references"
        WHERE {where}
        ORDER BY confidence DESC, src_path
        LIMIT 120
    """
    return conn.execute(sql, tuple(params)).fetchall()


def _format_evidence(rows: Iterable[sqlite3.Row], max_chars: int) -> str:
    parts: list[str] = []
    total = 0
    for r in rows:
        line = ""
        if r["line_start"] is not None:
            line = f":{r['line_start']}"
            if r["line_end"] is not None and r["line_end"] != r["line_start"]:
                line += f"-{r['line_end']}"
        text = (
            f"[{r['src_type']}] {r['src_path']}{line} | {r['src_name']} | "
            f"{r['ref_type']}={r['ref_key']} | confidence={r['confidence']:.2f}"
        )
        if r["snippet"]:
            text += f" | snippet={r['snippet']}"
        if total + len(text) > max_chars:
            break
        parts.append(text)
        total += len(text)
    return "\n".join(parts)


def _ask_payload_from_explain(
    conn: sqlite3.Connection,
    *,
    question: str,
    explain_payload: dict[str, Any],
) -> dict[str, Any]:
    resolved = (explain_payload.get("resolved") or {}).copy()
    dossier = explain_payload.get("evidence") or {}
    target_meta = dossier.get("target") or {}
    resolved_type = str(resolved.get("resolved_type") or "")
    resolved_name = str(resolved.get("resolved_name") or "")
    resolved_path = resolved.get("resolved_path")

    metadata_type = resolved_type or target_meta.get("type")
    metadata_folder = None
    if resolved_path:
        row = conn.execute(
            "SELECT folder, type_guess FROM meta_files WHERE lower(path)=lower(?) LIMIT 1",
            (str(resolved_path),),
        ).fetchone()
        if row:
            metadata_folder = row["folder"]
            if not metadata_type:
                metadata_type = row["type_guess"] or metadata_type

    object_name = None
    approval_process_name = None
    approval_process_full_name = None
    if str(metadata_type or "").lower() == "approvalprocess":
        ap_row = conn.execute(
            "SELECT object_name, name FROM approval_processes WHERE lower(path)=lower(?) OR lower(name)=lower(?) LIMIT 1",
            (str(resolved_path or ""), resolved_name),
        ).fetchone()
        if ap_row:
            object_name = ap_row["object_name"]
            approval_process_full_name = ap_row["name"]
            if approval_process_full_name and "." in approval_process_full_name:
                approval_process_name = approval_process_full_name.split(".", 1)[1]
            else:
                approval_process_name = approval_process_full_name
        elif resolved_name and "." in resolved_name:
            object_name, approval_process_name = resolved_name.split(".", 1)
            approval_process_full_name = resolved_name
    elif str(metadata_type or "").lower() == "sharingrule":
        object_name = resolved_name or None

    full_field_name = None
    field_name = None
    target_type = str(target_meta.get("type") or "").upper()
    target_name = target_meta.get("name")
    if target_type == "FIELD" and isinstance(target_name, str) and "." in target_name:
        full_field_name = target_name
        field_name = target_name.split(".", 1)[1]
        object_name = target_name.split(".", 1)[0]

    evidence_rows: list[dict[str, Any]] = []
    seen: set[tuple[str, int | None, str]] = set()

    def add_evidence_row(path: str | None, line_no: int | None, snippet: str | None, confidence: Any) -> None:
        if not path:
            return
        key = (path, line_no, snippet or "")
        if key in seen:
            return
        seen.add(key)
        evidence_rows.append(
            {
                "path": path,
                "line_no": line_no,
                "snippet": snippet or "",
                "confidence": confidence,
            }
        )

    for path in dossier.get("evidence_paths", []) or []:
        add_evidence_row(path, None, "", None)

    for section in ("refs", "writers", "readers", "automations", "ui_surface", "security_surface", "integration_surface"):
        for row in dossier.get(section, []) or []:
            path = row.get("path") or row.get("src_path") or row.get("evidence_path")
            line_no = row.get("line_no")
            if line_no is None:
                line_no = row.get("line_start")
            snippet = row.get("snippet") or row.get("evidence_snippet") or row.get("name") or row.get("ref_value")
            add_evidence_row(path, line_no, snippet, row.get("confidence"))
            if len(evidence_rows) >= 50:
                break
        if len(evidence_rows) >= 50:
            break

    resolved_type_lower = str(metadata_type or "").lower()
    display_target = target_name or resolved_name or resolved.get("raw_target", "")
    if resolved_type_lower == "sharingrule" and object_name:
        display_target = f"sharing rules for {object_name}"
    elif resolved_type_lower == "lwc" and resolved_name:
        display_target = f"lwc {resolved_name}"

    if resolved_type_lower == "sharingrule" and object_name:
        sr_rows = conn.execute(
            """
            SELECT name, path, access_level, rule_type
            FROM sharing_rules
            WHERE lower(object_name)=lower(?)
            ORDER BY name
            LIMIT 50
            """,
            (object_name,),
        ).fetchall()
        for r in sr_rows:
            add_evidence_row(r["path"], None, f"{r['name']} access={r['access_level'] or 'n/a'}", 1.0)

    if resolved_type_lower == "lwc":
        bundle = resolved_name
        if not bundle and resolved_path:
            m = re.search(r"/lwc/([^/]+)/", str(resolved_path))
            bundle = m.group(1) if m else None
        if bundle:
            lwc_rows = conn.execute(
                """
                SELECT path
                FROM meta_files
                WHERE lower(folder)='lwc' AND lower(path) LIKE lower(?)
                ORDER BY path
                LIMIT 50
                """,
                (f"%/lwc/{bundle}/%",),
            ).fetchall()
            for r in lwc_rows:
                add_evidence_row(r["path"], None, bundle, 1.0)

    answer_lines = _build_explain_answer_lines(
        display_target=display_target,
        metadata_type=metadata_type,
        target_meta=target_meta,
        dossier=dossier,
        evidence_rows=evidence_rows,
        adapter_result=explain_payload.get("adapter_result") or {},
    )

    payload: dict[str, Any] = {
        "question": question,
        "intent": "explain_component",
        "routing_family": "explain_component",
        "handler": "universal_explain",
        "resolved": {
            "object_name": object_name,
            "field_name": field_name,
            "full_field_name": full_field_name,
            "metadata_type": metadata_type,
            "metadata_folder": metadata_folder,
            "resolved_path": resolved_path,
            "endpoint": target_name if target_type == "ENDPOINT" else None,
            "token": None,
            "approval_process_name": approval_process_name,
            "approval_process_full_name": approval_process_full_name,
            "confidence": 1.0 if target_meta.get("found") else 0.0,
            "target": display_target,
            "target_type": target_meta.get("type"),
            "target_found": bool(target_meta.get("found")),
        },
        "answer_lines": answer_lines,
        "evidence": evidence_rows,
        "items": [],
        "count": len(evidence_rows),
        "error": None,
        "dossier": dossier,
        "markdown": explain_payload.get("markdown") or "",
        "explain": explain_payload,
        "adapter_name": explain_payload.get("adapter_name"),
        "llm_used": bool(explain_payload.get("llm_used")),
        "llm_model": explain_payload.get("llm_model"),
        "llm_calls": int(explain_payload.get("llm_calls") or 0),
        "llm_mode": explain_payload.get("llm_mode"),
        "llm_prompt_tokens_est": explain_payload.get("llm_prompt_tokens_est"),
        "llm_latency_ms": explain_payload.get("llm_latency_ms"),
        "ollama_latency_ms": explain_payload.get("llm_latency_ms"),
        "llm_error": explain_payload.get("llm_error"),
        "ollama_error": explain_payload.get("llm_error"),
        "evidence_pack_stats": explain_payload.get("evidence_pack_stats"),
    }
    return payload


def _format_item_for_display(item: dict[str, Any]) -> tuple[str, str]:
    label_keys = [
        "name",
        "api_name",
        "flow_name",
        "class_name",
        "rule_name",
        "bundle",
        "field_full_name",
        "endpoint",
        "src_name",
    ]
    label = ""
    for k in label_keys:
        v = item.get(k)
        if isinstance(v, str) and v.strip():
            label = v.strip()
            break
    if not label:
        if item.get("object_name") and item.get("approval_process_name"):
            label = f"{item['object_name']}.{item['approval_process_name']}"
        elif item.get("object_name") and item.get("name"):
            label = f"{item['object_name']}.{item['name']}"
        elif item.get("writer_name"):
            label = str(item["writer_name"])
        else:
            label = json.dumps({k: v for k, v in item.items() if k in {"object_name", "type", "writer_count"}}, ensure_ascii=True)
    path = str(item.get("path") or item.get("src_path") or item.get("sample_path") or "")
    return label, path


def _build_explain_answer_lines(
    *,
    display_target: str,
    metadata_type: str | None,
    target_meta: dict[str, Any],
    dossier: dict[str, Any],
    evidence_rows: list[dict[str, Any]],
    adapter_result: dict[str, Any] | None = None,
) -> list[str]:
    counts = dossier.get("summary_counts") or {}
    paths = dossier.get("evidence_paths") or []
    found = bool(target_meta.get("found"))
    adapter = adapter_result or {}
    facts = adapter.get("facts") or {}
    deps = adapter.get("deps") or {}
    dep_count = sum(len(deps.get(k) or []) for k in ("calls", "called_by", "reads", "writes", "touches"))
    path_count = len(paths) + (1 if adapter.get("path") and adapter.get("path") not in paths else 0)
    key_fact_parts: list[str] = []
    for k, v in list(facts.items())[:5]:
        if isinstance(v, (str, int, float, bool)):
            key_fact_parts.append(f"{k}={v}")
    what_touches = dep_count if dep_count else int(counts.get("writers", 0)) + int(counts.get("readers", 0))
    lines = [
        f"What it is: {(adapter.get('type') or metadata_type or target_meta.get('type') or 'UNKNOWN')} {display_target}",
        f"Where it lives: {path_count} indexed path(s)",
        f"What it touches: {what_touches} linked dependency item(s)",
        f"Dependencies: {dep_count} adapter dependency edge(s)",
        f"Key facts: {', '.join(key_fact_parts) if key_fact_parts else 'Not found in repo evidence.'}",
        f"Evidence entries: {len(evidence_rows)}",
    ]
    if not found:
        lines = ["Not found in repo index"]
    return lines


def _pick_repo_root_for_ask(project_root: Path, cfg: AppConfig | None, resolved_path: str | None) -> Path:
    candidate_repo = project_root / "template_repo"
    repo_root = cfg.resolve_repo_root(project_root) if cfg else candidate_repo
    if not repo_root.exists():
        repo_root = candidate_repo if candidate_repo.exists() else project_root
    if resolved_path:
        rel = str(resolved_path)
        if not (repo_root / rel).exists():
            if (candidate_repo / rel).exists():
                repo_root = candidate_repo
            elif (project_root / rel).exists():
                repo_root = project_root
    return repo_root


def _evidence_paths_markdown(payload: dict[str, Any], limit: int = 25) -> str:
    paths: list[str] = []
    seen: set[str] = set()
    for e in payload.get("evidence", []) or []:
        if not isinstance(e, dict):
            continue
        p = e.get("path") or e.get("src_path")
        if p and p not in seen:
            seen.add(p)
            paths.append(str(p))
    for p in (payload.get("dossier") or {}).get("evidence_paths", []) or []:
        if p and p not in seen:
            seen.add(p)
            paths.append(str(p))
    if not paths:
        return ""
    body = "\n".join(f"- {p}" for p in paths[:limit])
    return f"\n\n## Evidence Paths\n{body}\n"


def _print_list_items(question: str, payload: dict[str, Any], max_items: int = 50) -> None:
    q_norm = normalize(question)
    starts_list = bool(re.match(r"^\s*(list|show|which|give me)\b", q_norm))
    if not starts_list:
        return
    items = payload.get("items")
    if not isinstance(items, list) or not items:
        return
    print("Items:")
    for item in items[:max_items]:
        if not isinstance(item, dict):
            print(f"- {item}")
            continue
        label, path = _format_item_for_display(item)
        if path:
            print(f"- {label} — {path}")
        else:
            print(f"- {label}")


def _print_where_used_grouped(payload: dict[str, Any]) -> bool:
    if str(payload.get("intent")) != "where_used_any":
        return False
    items = payload.get("items")
    if not isinstance(items, list) or not items:
        return False

    grouped: dict[str, list[dict[str, Any]]] = {}
    for item in items:
        if not isinstance(item, dict):
            continue
        src_type = str(item.get("src_type") or "META").upper()
        grouped.setdefault(src_type, []).append(item)

    if not grouped:
        return False

    preferred_order = ["APEX", "FLOW", "TRIGGER", "LAYOUT", "FLEXIPAGE", "PERMISSION", "VR", "META"]
    type_order = [t for t in preferred_order if t in grouped]
    type_order.extend(sorted(t for t in grouped.keys() if t not in preferred_order))

    print("All references (grouped by source type):")
    for src_type in type_order:
        rows = grouped[src_type]
        print(f"{src_type} ({len(rows)}):")
        for row in rows:
            path = str(row.get("path") or row.get("src_path") or "")
            line_no = row.get("line_no")
            loc = f":{line_no}" if isinstance(line_no, int) else ""
            snippet = str(row.get("snippet") or row.get("ref_value") or "").strip()
            print(f"- {path}{loc}")
            if snippet:
                print(f"  {snippet}")
    return True


def _split_llm_answer_lines(text: str) -> list[str]:
    if not isinstance(text, str):
        return []
    lines = [ln.rstrip() for ln in text.splitlines() if ln.strip()]
    return lines


def _repo_summary_for_planner(conn: sqlite3.Connection) -> dict[str, Any]:
    def cnt(sql: str) -> int:
        try:
            row = conn.execute(sql).fetchone()
            return int(row[0]) if row else 0
        except Exception:
            return 0

    return {
        "objects": cnt("SELECT COUNT(*) FROM objects"),
        "fields": cnt("SELECT COUNT(*) FROM fields"),
        "flows": cnt("SELECT COUNT(*) FROM flows"),
        "apex_classes": cnt("SELECT COUNT(*) FROM components WHERE type='APEX'"),
        "triggers": cnt("SELECT COUNT(*) FROM components WHERE type='TRIGGER'"),
        "meta_files": cnt("SELECT COUNT(*) FROM meta_files"),
        "references": cnt('SELECT COUNT(*) FROM "references"'),
        "meta_refs": cnt("SELECT COUNT(*) FROM meta_refs"),
        "graph_nodes": cnt("SELECT COUNT(*) FROM graph_nodes"),
        "graph_edges": cnt("SELECT COUNT(*) FROM graph_edges"),
    }


def _extract_first_json(text: str) -> dict[str, Any] | None:
    if not text:
        return None
    raw = text.strip()
    try:
        obj = json.loads(raw)
        if isinstance(obj, dict):
            return obj
    except Exception:
        pass

    m = re.search(r"\{[\s\S]*\}", raw)
    if not m:
        return None
    blob = m.group(0)
    try:
        obj = json.loads(blob)
        if isinstance(obj, dict):
            return obj
    except Exception:
        return None
    return None


def _plan_item_to_question(intent: str, args: dict[str, Any]) -> str | None:
    field = str(args.get("field") or args.get("full_field_name") or "").strip()
    obj = str(args.get("object") or args.get("object_name") or "").strip()
    cls = str(args.get("class") or args.get("class_name") or "").strip()
    flow = str(args.get("flow") or args.get("flow_name") or "").strip()
    token = str(args.get("token") or "").strip()
    endpoint = str(args.get("endpoint") or "").strip()
    target = str(args.get("target") or "").strip()
    q = str(args.get("question") or "").strip()

    if q:
        return q
    if intent in {"class_callers"} and cls:
        return f"what calls apex class {cls}"
    if intent in {"flows_write_field", "flows_update_field"} and field:
        return f"which flows write {field}"
    if intent in {"apex_write_field"} and field:
        return f"which apex classes write {field}"
    if intent in {"writers_for_field"} and field:
        return f"show me the writers for {field} (flows + apex)"
    if intent in {"collisions_for_field", "collisions_query"} and field:
        return f"are there collisions on {field}"
    if intent in {"class_endpoints"} and cls:
        return f"what endpoints does {cls} call"
    if intent in {"trigger_deps"} and cls:
        return f"what classes does trigger {cls} call"
    if intent in {"trigger_deps", "trigger_explain"} and target:
        return f"what classes does trigger {target} call"
    if intent in {"flow_apex_actions"} and flow:
        return f"what apex actions does flow {flow} call"
    if intent in {"where_used_any"} and token:
        return f"where is {token} used"
    if intent in {"endpoint_callers"} and endpoint:
        return f"which classes call {endpoint}"
    if intent in {"impact_object"} and obj:
        return f"what breaks if I change {obj}"
    if intent in {"impact_field"} and field:
        return f"what breaks if I change {field}"
    if intent in {"explain_component"} and target:
        return f"explain {target}"
    return None


def _payload_class_callers(conn: sqlite3.Connection, class_name: str) -> dict[str, Any]:
    rows = conn.execute(
        """
        SELECT s.node_type AS caller_type, s.name AS caller_name, COALESCE(s.path, e.evidence_path) AS path,
               e.edge_type, e.confidence, e.evidence_line_start, e.evidence_snippet
        FROM graph_edges e
        JOIN graph_nodes s ON s.node_id=e.src_node_id
        JOIN graph_nodes d ON d.node_id=e.dst_node_id
        WHERE d.node_type='APEX_CLASS' AND lower(d.name)=lower(?)
          AND e.edge_type IN ('CLASS_CALLS_CLASS', 'TRIGGER_CALLS_CLASS', 'FLOW_CALLS_APEX_ACTION')
        ORDER BY e.confidence DESC, caller_type, caller_name
        LIMIT 500
        """,
        (class_name,),
    ).fetchall()
    items = [dict(r) for r in rows]
    lines = [f"Callers of apex class {class_name}: {len(items)}"]
    evidence = [
        {
            "path": r["path"],
            "line_no": r["evidence_line_start"],
            "snippet": f"{r['caller_type']} {r['caller_name']} via {r['edge_type']}",
            "confidence": r["confidence"],
        }
        for r in rows[:50]
    ]
    return {"answer_lines": lines, "items": items, "evidence": evidence, "count": len(items), "error": None}


def _payload_flow_apex_actions(conn: sqlite3.Connection, flow_name: str) -> dict[str, Any]:
    rows = conn.execute(
        """
        SELECT d.name AS apex_class, COALESCE(d.path, e.evidence_path) AS path,
               e.confidence, e.evidence_line_start, e.evidence_snippet
        FROM graph_edges e
        JOIN graph_nodes s ON s.node_id=e.src_node_id
        JOIN graph_nodes d ON d.node_id=e.dst_node_id
        WHERE s.node_type='FLOW' AND lower(s.name)=lower(?)
          AND e.edge_type='FLOW_CALLS_APEX_ACTION'
        ORDER BY e.confidence DESC, apex_class
        LIMIT 500
        """,
        (flow_name,),
    ).fetchall()
    items = [dict(r) for r in rows]
    lines = [f"Apex actions called by flow {flow_name}: {len(items)}"]
    evidence = [
        {
            "path": r["path"],
            "line_no": r["evidence_line_start"],
            "snippet": r["apex_class"],
            "confidence": r["confidence"],
        }
        for r in rows[:50]
    ]
    return {"answer_lines": lines, "items": items, "evidence": evidence, "count": len(items), "error": None}


def _run_ask_internal(conn: sqlite3.Connection, intent: str, args: dict[str, Any]) -> tuple[str | None, dict[str, Any]]:
    cls = str(args.get("class") or args.get("class_name") or "").strip()
    flow = str(args.get("flow") or args.get("flow_name") or "").strip()
    if intent == "class_callers" and cls:
        return f"what calls apex class {cls}", _payload_class_callers(conn, cls)
    if intent == "flow_apex_actions" and flow:
        return f"what apex actions does flow {flow} call", _payload_flow_apex_actions(conn, flow)
    q = _plan_item_to_question(intent, args)
    if not q:
        return None, {}
    return q, route_ask_question(conn, q)


def _forced_planner_subqueries(question: str) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    q = question or ""
    qn = normalize(q)
    m_cls = re.search(r"apex class\s+([A-Za-z_][A-Za-z0-9_]*)", q, flags=re.IGNORECASE)
    if m_cls and ("what calls" in qn or "who calls" in qn):
        out.append({"tool": "ask_internal", "intent": "class_callers", "args": {"class_name": m_cls.group(1)}})
    m_flow = re.search(r"flow\s+([A-Za-z_][A-Za-z0-9_]*)", q, flags=re.IGNORECASE)
    if m_flow and ("apex action" in qn or ("flow" in qn and "call" in qn and "apex" in qn)):
        out.append({"tool": "ask_internal", "intent": "flow_apex_actions", "args": {"flow_name": m_flow.group(1)}})
    return out


def _run_planner_subqueries(
    conn: sqlite3.Connection,
    subqueries: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for sq in subqueries[:8]:
        if not isinstance(sq, dict):
            continue
        if str(sq.get("tool") or "") != "ask_internal":
            continue
        intent = str(sq.get("intent") or "").strip()
        args = sq.get("args") if isinstance(sq.get("args"), dict) else {}
        q, payload = _run_ask_internal(conn, intent, args)
        if not q or not payload:
            continue
        results.append(
            {
                "intent": intent,
                "question": q,
                "args": args,
                "result": payload,
            }
        )
    return results


def _merge_payloads_for_narration(base_payload: dict[str, Any], planner_results: list[dict[str, Any]]) -> dict[str, Any]:
    merged = dict(base_payload)
    merged_items: list[Any] = list(base_payload.get("items") or [])
    merged_evidence: list[dict[str, Any]] = list(base_payload.get("evidence") or [])
    merged_answer_lines: list[str] = list(base_payload.get("answer_lines") or [])

    seen_ev: set[tuple[str, int | None, str]] = set()
    for e in merged_evidence:
        p = e.get("path") or e.get("src_path") or ""
        ln = e.get("line_no") if isinstance(e.get("line_no"), int) else None
        sn = str(e.get("snippet") or "")
        seen_ev.add((str(p), ln, sn))

    for item in planner_results:
        res = item.get("result") or {}
        q = item.get("question") or ""
        merged_answer_lines.append(f"Planner subquery: {q}")
        merged_answer_lines.extend([str(x) for x in (res.get("answer_lines") or [])[:5]])
        merged_items.extend(res.get("items") or [])
        for e in res.get("evidence") or []:
            p = e.get("path") or e.get("src_path") or ""
            ln = e.get("line_no") if isinstance(e.get("line_no"), int) else None
            sn = str(e.get("snippet") or "")
            key = (str(p), ln, sn)
            if not p or key in seen_ev:
                continue
            seen_ev.add(key)
            merged_evidence.append(e)

    merged["answer_lines"] = merged_answer_lines
    merged["items"] = merged_items[:1000]
    merged["evidence"] = merged_evidence[:300]
    merged["planner_subquery_count"] = len(planner_results)
    return merged


def cmd_ask(
    conn: sqlite3.Connection,
    project_root: Path,
    question: str,
    *,
    json_out: str | None = None,
    debug_routing: bool = False,
    use_llm: bool = False,
    llm_mode: str = "narrate_only",
    llm_full: bool = False,
    llm_model: str | None = None,
    ollama_url: str | None = None,
    llm_max_chars: int = 120000,
    llm_primary_max_chars: int = 80000,
    debug_llm: bool = False,
    cfg: AppConfig | None = None,
) -> int:
    q_norm = normalize(question)
    payload = route_ask_question(conn, question)

    payload.setdefault("llm_used", False)
    payload.setdefault("llm_model", None)
    payload.setdefault("llm_calls", 0)
    payload.setdefault("llm_mode", "disabled")
    payload.setdefault("llm_mode_requested", "disabled")
    payload.setdefault("llm_mode_used", "disabled")
    payload.setdefault("llm_prompt_tokens_est", None)
    payload.setdefault("llm_latency_ms", None)
    payload.setdefault("ollama_latency_ms", None)
    payload.setdefault("llm_error", None)
    payload.setdefault("ollama_error", None)
    payload.setdefault("evidence_pack_stats", None)
    payload.setdefault("llm_answer", None)
    payload.setdefault("llm_answer_lines", [])
    payload["deterministic_answer_lines"] = list(payload.get("answer_lines") or [])

    if llm_full and llm_mode == "narrate_only":
        llm_mode = "full_primary"

    mode_requested = llm_mode if use_llm else "disabled"
    mode_used = mode_requested
    model = llm_model or (cfg.ollama.gen_model if cfg else "gpt-oss:20b")
    base_url = ollama_url or (cfg.ollama.base_url if cfg else "http://localhost:11434")

    planner_plan: dict[str, Any] | None = None
    planner_results: list[dict[str, Any]] = []
    planner_note: str | None = None
    total_llm_latency = 0
    prompt_tokens_est = 0
    llm_calls = 0
    llm_error: str | None = None

    if use_llm:
        resolved = payload.get("resolved", {}) or {}
        repo_root = _pick_repo_root_for_ask(project_root, cfg, resolved.get("resolved_path"))
        payload_for_evidence = payload

        if mode_requested == "full_primary" and str(payload.get("intent")) != "explain_component":
            mode_used = "narrate_only"

        if mode_requested == "planner_then_narrate":
            repo_summary = _repo_summary_for_planner(conn)
            planner_prompt = build_planner_prompt(question=question, resolved=resolved, repo_summary=repo_summary)
            planner_hash = hashlib.sha1(planner_prompt.encode("utf-8")).hexdigest()[:16]
            if debug_llm:
                print(f"CALLING OLLAMA model={model} mode=planner chars={len(planner_prompt)} files=0 snippets=0")
                print(f"LLM planner_prompt_hash={planner_hash}")
            try:
                llm_calls += 1
                plan_resp = chat_completion(
                    ollama_url=base_url,
                    model=model,
                    system_prompt=PLANNER_SYSTEM_PROMPT,
                    user_prompt=planner_prompt,
                    timeout=180,
                )
                total_llm_latency += int(plan_resp.get("latency_ms") or 0)
                prompt_tokens_est += max(1, len(planner_prompt) // 4)
                planner_plan = _extract_first_json(str(plan_resp.get("text") or ""))
                if not planner_plan:
                    mode_used = "narrate_only"
                    planner_note = "Planner output was not valid JSON; fell back to narrate_only."
                else:
                    subqueries = planner_plan.get("subqueries")
                    if not isinstance(subqueries, list):
                        subqueries = []
                    merged_subqueries = list(subqueries)
                    forced = _forced_planner_subqueries(question)
                    for sq in forced:
                        if sq not in merged_subqueries:
                            merged_subqueries.append(sq)
                    planner_results = _run_planner_subqueries(conn, merged_subqueries)
                    payload_for_evidence = _merge_payloads_for_narration(payload, planner_results)
                    if debug_llm:
                        print("LLM planner JSON:")
                        print(json.dumps(planner_plan, indent=2))
                        print(f"Executed planner subqueries: {len(planner_results)}")
                        for sq in planner_results[:8]:
                            print(f"- {sq.get('intent')} => {sq.get('question')}")
            except OllamaClientError as exc:
                planner_note = f"Planner call failed; fell back to narrate_only: {exc}"
                mode_used = "narrate_only"

        pack_mode = "rag_snippets"
        if mode_used == "full_primary":
            pack_mode = "full_primary"

        evidence_pack = build_evidence_pack(
            question=question,
            resolved=payload.get("resolved", {}) or {},
            deterministic_payload=payload_for_evidence,
            repo_root=repo_root,
            mode=pack_mode,
            max_chars=llm_max_chars,
            primary_max_chars=llm_primary_max_chars,
        )
        stats = evidence_pack.get("evidence_pack_stats") or {}
        pack_mode_used = str(evidence_pack.get("mode_used") or pack_mode)
        if mode_used == "full_primary" and pack_mode_used == "rag_snippets_fallback":
            mode_used = "rag_snippets_fallback"

        user_prompt = build_user_prompt(question=question, evidence_pack=evidence_pack)
        prompt_hash = hashlib.sha1(user_prompt.encode("utf-8")).hexdigest()[:16]
        if debug_llm:
            print(
                f"CALLING OLLAMA model={model} mode={mode_used} "
                f"chars={stats.get('total_chars', 0)} files={stats.get('file_count', 0)} "
                f"snippets={stats.get('snippet_count', 0)}"
            )
            print(f"LLM prompt_hash={prompt_hash}")
        try:
            llm_calls += 1
            narrate_resp = chat_completion(
                ollama_url=base_url,
                model=model,
                system_prompt=SYSTEM_PROMPT,
                user_prompt=user_prompt,
                timeout=180,
            )
            total_llm_latency += int(narrate_resp.get("latency_ms") or 0)
            prompt_tokens_est += max(1, len(user_prompt) // 4)
            llm_answer = str(narrate_resp.get("text") or "").strip()
            if llm_answer:
                payload["llm_used"] = True
                payload["llm_answer"] = llm_answer
                payload["llm_answer_lines"] = _split_llm_answer_lines(llm_answer)
                payload["answer_lines"] = list(payload["llm_answer_lines"])
                payload["markdown"] = llm_answer + _evidence_paths_markdown(payload)
            else:
                payload["llm_used"] = False
        except OllamaClientError as exc:
            if not llm_error:
                llm_error = str(exc)
            payload["llm_used"] = False

        payload["llm_model"] = model
        payload["llm_calls"] = llm_calls
        payload["llm_mode_requested"] = mode_requested
        payload["llm_mode_used"] = mode_used
        payload["llm_mode"] = mode_used
        payload["llm_prompt_tokens_est"] = prompt_tokens_est or None
        payload["llm_latency_ms"] = total_llm_latency or None
        payload["ollama_latency_ms"] = total_llm_latency or None
        payload["llm_error"] = llm_error
        payload["ollama_error"] = llm_error
        payload["evidence_pack_stats"] = stats
        if planner_plan is not None:
            payload["planner_plan"] = planner_plan
        if planner_results:
            payload["subquery_results"] = [
                {
                    "intent": r.get("intent"),
                    "question": r.get("question"),
                    "answer_lines": ((r.get("result") or {}).get("answer_lines") or [])[:8],
                    "count": (r.get("result") or {}).get("count"),
                    "error": (r.get("result") or {}).get("error"),
                }
                for r in planner_results[:8]
            ]
        if planner_note:
            payload["planner_note"] = planner_note
    else:
        payload["llm_used"] = False
        payload["llm_calls"] = 0
        payload["llm_mode"] = "disabled"
        payload["llm_mode_requested"] = "disabled"
        payload["llm_mode_used"] = "disabled"

    resolved = payload.get("resolved", {}) or {}

    if debug_routing:
        print(f"Resolved intent: {payload.get('intent')}")
        if payload.get("routing_family"):
            print(f"Routing family: {payload.get('routing_family')}")
        if payload.get("handler"):
            print(f"Handler: {payload.get('handler')}")
        canonical_bits: list[str] = []
        for k in (
            "target",
            "full_field_name",
            "object_name",
            "endpoint",
            "metadata_type",
            "approval_process_name",
            "approval_process_full_name",
        ):
            v = resolved.get(k)
            if v:
                canonical_bits.append(f"{k}={v}")
        if canonical_bits:
            print("Resolved canonical: " + ", ".join(canonical_bits))
        conf = resolved.get("confidence")
        if conf is not None:
            try:
                print(f"Confidence: {float(conf):.2f}")
            except Exception:
                print(f"Confidence: {conf}")

    if payload.get("llm_used") and payload.get("llm_answer"):
        print(str(payload.get("llm_answer")).rstrip())
    elif str(payload.get("intent")) == "explain_component" and payload.get("markdown"):
        print(str(payload.get("markdown")).rstrip())
    elif payload.get("error"):
        print(payload["error"])
    else:
        for line in payload.get("answer_lines", []):
            print(line)
        _print_list_items(question, payload)

    printed_grouped_where_used = _print_where_used_grouped(payload)
    evidence = payload.get("evidence", []) or []
    if evidence and not printed_grouped_where_used:
        print("Evidence:")
        for e in evidence[:5]:
            path = e.get("path") or e.get("src_path") or ""
            line = e.get("line")
            if line is None:
                line = e.get("line_no")
            loc = f":{line}" if line is not None else ""
            snippet = e.get("snippet") or e.get("name") or e.get("ref_value") or ""
            print(f"- {path}{loc}")
            if snippet:
                print(f"  {snippet}")

    if json_out:
        out = Path(json_out)
        if not out.is_absolute():
            out = project_root / out
        write_json(out, payload)
        print(out.as_posix())
    else:
        print("Use --json-out to export full list")
    return 0


def _payload_count(payload: dict[str, Any]) -> int:
    raw_count = payload.get("count")
    if isinstance(raw_count, int):
        return raw_count
    items = payload.get("items")
    if isinstance(items, list):
        return len(items)
    evidence = payload.get("evidence")
    if isinstance(evidence, list):
        return len(evidence)
    answer_lines = payload.get("answer_lines") or []
    best = 0
    for line in answer_lines:
        nums = re.findall(r"\b\d+\b", str(line))
        for n in nums:
            best = max(best, int(n))
    return best


def _payload_paths(payload: dict[str, Any]) -> list[str]:
    paths: list[str] = []
    seen: set[str] = set()
    for row in payload.get("evidence", []) or []:
        p = row.get("path") or row.get("src_path")
        if p and p not in seen:
            seen.add(p)
            paths.append(p)
    dossier = payload.get("dossier") or {}
    for p in dossier.get("evidence_paths", []) or []:
        if p and p not in seen:
            seen.add(p)
            paths.append(p)
    return paths


def cmd_regress(
    conn: sqlite3.Connection,
    project_root: Path,
    *,
    file_path: str,
    json_out: str | None,
) -> int:
    cfg_path = Path(file_path)
    if not cfg_path.is_absolute():
        cfg_path = project_root / cfg_path
    if not cfg_path.exists():
        print(f"Regression file not found: {cfg_path.as_posix()}")
        return 2

    payload = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
    tests = payload.get("tests") or []
    if not isinstance(tests, list) or not tests:
        print("No tests found in regression file")
        return 2

    results: list[dict[str, Any]] = []
    passed = 0
    failed = 0

    for idx, test in enumerate(tests, start=1):
        name = str(test.get("name") or f"test_{idx}")
        question = str(test.get("question") or "").strip()
        expect = test.get("expect") or {}
        if not question:
            failed += 1
            results.append(
                {
                    "name": name,
                    "question": question,
                    "passed": False,
                    "failures": ["missing question"],
                }
            )
            print(f"FAIL [{idx}] {name}: missing question")
            continue

        answer = route_ask_question(conn, question)
        resolved = answer.get("resolved", {}) or {}
        failures: list[str] = []

        exp_intent = expect.get("intent")
        if exp_intent and str(answer.get("intent")) != str(exp_intent):
            failures.append(f"intent mismatch expected={exp_intent} actual={answer.get('intent')}")

        exp_obj = expect.get("entity_object")
        if exp_obj:
            actual_obj = str(resolved.get("object_name") or "")
            if actual_obj.lower() != str(exp_obj).lower():
                failures.append(f"entity_object mismatch expected={exp_obj} actual={actual_obj}")

        exp_field = expect.get("entity_field")
        if exp_field:
            actual_field = str(resolved.get("full_field_name") or "")
            if actual_field.lower() != str(exp_field).lower():
                failures.append(f"entity_field mismatch expected={exp_field} actual={actual_field}")

        allow_not_found = bool(expect.get("allow_not_found", False))
        answer_lines = " ".join(str(x) for x in (answer.get("answer_lines") or []))
        error_text = str(answer.get("error") or "")
        is_not_found = ("not found" in answer_lines.lower()) or ("not found" in error_text.lower())
        if is_not_found and not allow_not_found:
            failures.append("not_found returned but allow_not_found=false")

        if "min_count" in expect:
            min_count = int(expect.get("min_count") or 0)
            actual_count = _payload_count(answer)
            if actual_count < min_count:
                failures.append(f"min_count failed expected>={min_count} actual={actual_count}")

        required_paths = expect.get("must_contain_paths") or []
        if isinstance(required_paths, str):
            required_paths = [required_paths]
        if isinstance(required_paths, list) and required_paths:
            actual_paths = _payload_paths(answer)
            lowered_paths = [p.lower() for p in actual_paths]
            for pat in required_paths:
                p = str(pat).lower()
                if not any(p in ap for ap in lowered_paths):
                    failures.append(f"path pattern not found: {pat}")

        ok = len(failures) == 0
        if ok:
            passed += 1
            print(f"PASS [{idx}] {name}")
        else:
            failed += 1
            print(f"FAIL [{idx}] {name}")
            for msg in failures:
                print(f"- {msg}")

        results.append(
            {
                "name": name,
                "question": question,
                "passed": ok,
                "failures": failures,
                "expect": expect,
                "actual": {
                    "intent": answer.get("intent"),
                    "resolved": resolved,
                    "count": _payload_count(answer),
                    "error": answer.get("error"),
                },
            }
        )

    report = {
        "total": len(tests),
        "passed": passed,
        "failed": failed,
        "results": results,
    }
    print(f"summary: total={len(tests)} passed={passed} failed={failed}")

    if json_out:
        out = Path(json_out)
        if not out.is_absolute():
            out = project_root / out
        write_json(out, report)
        print(out.as_posix())

    return 0 if failed == 0 else 2


def _llm_narrate_report(
    *,
    cfg: AppConfig,
    question: str,
    report: dict[str, Any],
    llm: bool,
    llm_model: str | None,
    ollama_url: str | None,
) -> dict[str, Any]:
    out = {
        "llm_used": False,
        "llm_model": llm_model or cfg.ollama.gen_model,
        "llm_mode": "disabled",
        "ollama_latency_ms": None,
        "ollama_error": None,
        "llm_answer": None,
        "llm_answer_lines": [],
        "evidence_pack_stats": None,
    }
    if not llm:
        return out
    model = llm_model or cfg.ollama.gen_model
    base_url = ollama_url or cfg.ollama.base_url
    user_prompt = (
        "Explain this deterministic report in clear steps.\n"
        "Use only provided evidence. If missing, say Not found in repo evidence.\n\n"
        f"Question: {question}\n\n"
        f"{json.dumps(report, indent=2)}"
    )
    try:
        resp = chat_completion(
            ollama_url=base_url,
            model=model,
            system_prompt=SYSTEM_PROMPT,
            user_prompt=user_prompt,
            timeout=180,
        )
        ans = str(resp.get("text") or "").strip()
        out.update(
            {
                "llm_used": bool(ans),
                "llm_mode": "narrate_only",
                "ollama_latency_ms": int(resp.get("latency_ms") or 0),
                "llm_answer": ans,
                "llm_answer_lines": _split_llm_answer_lines(ans),
                "evidence_pack_stats": {
                    "total_chars": len(user_prompt),
                    "file_count": len(report.get("evidence_paths") or []),
                    "snippet_count": len(report.get("evidence_snippets") or []),
                },
            }
        )
    except Exception as exc:
        out["ollama_error"] = str(exc)
    return out


def cmd_access_why(
    cfg: AppConfig,
    conn: sqlite3.Connection,
    project_root: Path,
    *,
    bundle_path: str | None,
    sf_login_url: str | None,
    sf_username: str | None,
    sf_password: str | None,
    sf_token: str | None,
    user: str | None,
    record: str | None,
    llm: bool,
    llm_model: str | None,
    ollama_url: str | None,
    json_out: str | None,
) -> int:
    bundle: AccessBundle
    bundle_source: str
    if bundle_path:
        p = Path(bundle_path)
        if not p.is_absolute():
            p = project_root / p
        if not p.exists():
            print(f"Bundle not found: {p.as_posix()}")
            return 1
        data = json.loads(p.read_text(encoding="utf-8"))
        bundle = AccessBundle.from_dict(data)
        bundle_source = p.as_posix()
    else:
        if not user or not record:
            print("Provide either --bundle OR --user and --record with Salesforce credentials.")
            return 1
        try:
            sf_client = _build_salesforce_client(
                login_url=sf_login_url,
                username=sf_username,
                password=sf_password,
                token=sf_token,
            )
            bundle = build_access_bundle_from_org(sf_client, user_input=user, record_id=record)
            bundle_source = "runtime_org_pull"
        except (SalesforceAuthError, SalesforceClientError, ValueError, RuntimeError) as exc:
            print(f"Failed to build access bundle from org: {exc}")
            return 1

    report_obj = evaluate_access(bundle, conn=conn)
    report = {
        "decision": report_obj.decision,
        "object_gate": report_obj.object_gate,
        "record_gate": report_obj.record_gate,
        "reasons": report_obj.reasons,
        "suggested_fixes": report_obj.suggested_fixes,
        "evidence_used": report_obj.evidence_used,
        "metadata_context": report_obj.metadata_context,
        "bundle_source": bundle_source,
        "bundle_summary": {
            "user_id": bundle.user.user_id,
            "object_name": bundle.object_access.object_name,
            "record_id": bundle.record.record_id,
            "share_count": len(bundle.shares),
            "team_count": len(bundle.teams),
        },
    }

    llm_info = _llm_narrate_report(
        cfg=cfg,
        question=f"Why can user {bundle.user.user_id} access record {bundle.record.record_id}?",
        report=report,
        llm=llm,
        llm_model=llm_model,
        ollama_url=ollama_url,
    )
    report.update(llm_info)

    if llm_info.get("llm_used") and llm_info.get("llm_answer"):
        print(llm_info["llm_answer"])
    else:
        print(f"Decision: {report['decision']}")
        print(f"Object gate: {report['object_gate']}")
        print(f"Record gate: {report['record_gate']}")
        print("Reasons:")
        for r in report["reasons"]:
            print(f"- {r}")
        if report["suggested_fixes"]:
            print("Suggested fixes:")
            for fix in report["suggested_fixes"]:
                print(f"- [{fix.get('risk')}] {fix.get('title')}: {fix.get('why')}")

    if json_out:
        out = Path(json_out)
        if not out.is_absolute():
            out = project_root / out
        write_json(out, report)
        print(out.as_posix())
    return 0


def _resolve_sf_auth_inputs(
    *,
    login_url: str | None,
    username: str | None,
    password: str | None,
    token: str | None,
) -> tuple[str, str, str, str | None]:
    resolved_login_url = (login_url or os.getenv("SF_LOGIN_URL") or DEFAULT_LOGIN_URL).strip()
    resolved_username = (username or os.getenv("SF_USERNAME") or "").strip()
    resolved_password = (password or os.getenv("SF_PASSWORD") or "").strip()
    resolved_token = (token or os.getenv("SF_TOKEN") or "").strip() or None
    if not resolved_username or not resolved_password:
        raise ValueError("Salesforce credentials required: provide --username/--password (or SF_USERNAME/SF_PASSWORD).")
    return resolved_login_url, resolved_username, resolved_password, resolved_token


def _build_salesforce_client(
    *,
    login_url: str | None,
    username: str | None,
    password: str | None,
    token: str | None,
) -> SalesforceClient:
    resolved_login_url, resolved_username, resolved_password, resolved_token = _resolve_sf_auth_inputs(
        login_url=login_url,
        username=username,
        password=password,
        token=token,
    )
    session = login_with_username_password(
        login_url=resolved_login_url,
        username=resolved_username,
        password=resolved_password,
        token=resolved_token,
    )
    return SalesforceClient(session)


def _resolve_sf_user_id(client: Any, user_input: str) -> str:
    raw = (user_input or "").strip()
    if len(raw) in {15, 18} and raw.isalnum():
        return raw
    safe = raw.replace("'", "\\'")
    if hasattr(client, "tooling_query"):
        rows = client.tooling_query(f"SELECT Id, Username FROM User WHERE Username='{safe}' LIMIT 1")
    else:
        rows = client.query(f"SELECT Id, Username FROM User WHERE Username='{safe}' LIMIT 1")
    if not rows:
        raise ToolingAPIError(f"User not found: {user_input}")
    return str(rows[0]["Id"])


def _build_runtime_sf_client(
    *,
    org_alias: str | None,
    login_url: str | None,
    username: str | None,
    password: str | None,
    token: str | None,
) -> tuple[Any, dict[str, Any]]:
    if org_alias:
        return ToolingAPIClient.from_org_alias(org_alias), {"org_alias": org_alias}
    client = _build_salesforce_client(
        login_url=login_url,
        username=username,
        password=password,
        token=token,
    )
    return client, {
        "org_alias": "",
        "login_url": (login_url or os.getenv("SF_LOGIN_URL") or DEFAULT_LOGIN_URL),
        "sf_username": username or os.getenv("SF_USERNAME"),
        "sf_password": password or os.getenv("SF_PASSWORD"),
        "sf_token": token or os.getenv("SF_TOKEN"),
    }


def cmd_logs_trace_enable(
    *,
    org_alias: str | None,
    login_url: str | None,
    username: str | None,
    password: str | None,
    token: str | None,
    user: str,
    minutes: int,
    level: str,
) -> int:
    try:
        client, _ = _build_runtime_sf_client(
            org_alias=org_alias,
            login_url=login_url,
            username=username,
            password=password,
            token=token,
        )
        user_id = _resolve_sf_user_id(client, user)
        info = enable_trace_flag(client, user_id=user_id, minutes=minutes, level=level)
    except (SalesforceAuthError, SalesforceClientError, ToolingAPIError, ValueError, RuntimeError) as exc:
        print(f"Failed to enable trace: {exc}")
        return 1
    print(f"Trace enabled for {user_id}: {info['trace_flag_id']}")
    print(f"Window: {info['start']} .. {info['end']}")
    return 0


def cmd_logs_trace_disable(
    *,
    org_alias: str | None,
    login_url: str | None,
    username: str | None,
    password: str | None,
    token: str | None,
    user: str,
) -> int:
    try:
        client, _ = _build_runtime_sf_client(
            org_alias=org_alias,
            login_url=login_url,
            username=username,
            password=password,
            token=token,
        )
        user_id = _resolve_sf_user_id(client, user)
        n = disable_trace_flags(client, user_id=user_id)
    except (SalesforceAuthError, SalesforceClientError, ToolingAPIError, ValueError, RuntimeError) as exc:
        print(f"Failed to disable trace: {exc}")
        return 1
    print(f"Trace flags removed: {n}")
    return 0


def cmd_logs_capture_start(
    conn: sqlite3.Connection,
    *,
    org_alias: str | None,
    login_url: str | None,
    username: str | None,
    password: str | None,
    token: str | None,
    user: str,
    minutes: int,
    filter_text: str | None,
    level: str,
) -> int:
    ensure_log_tables(conn)
    try:
        client, auth_info = _build_runtime_sf_client(
            org_alias=org_alias,
            login_url=login_url,
            username=username,
            password=password,
            token=token,
        )
        user_id = _resolve_sf_user_id(client, user)
        trace = enable_trace_flag(client, user_id=user_id, minutes=minutes, level=level)
    except (SalesforceAuthError, SalesforceClientError, ToolingAPIError, ValueError, RuntimeError) as exc:
        print(f"Failed to start capture: {exc}")
        return 1

    capture_id = create_capture(
        conn,
        org_alias=str(auth_info.get("org_alias") or ""),
        user_id=user_id,
        filter_text=filter_text,
        login_url=str(auth_info.get("login_url") or "") or None,
        sf_username=str(auth_info.get("sf_username") or "") or None,
        sf_password=str(auth_info.get("sf_password") or "") or None,
        sf_token=str(auth_info.get("sf_token") or "") or None,
        start_ts=utc_now(),
    )
    print(f"capture_id: {capture_id}")
    print(f"start_time: {get_capture(conn, capture_id)['start_ts']}")
    print(f"trace_flag_id: {trace['trace_flag_id']}")
    print("Reproduce now, then run: logs capture stop --capture-id <id>")
    return 0


def cmd_logs_capture_stop(
    cfg: AppConfig,
    conn: sqlite3.Connection,
    project_root: Path,
    *,
    capture_id: int,
    org_alias: str | None,
    login_url: str | None,
    username: str | None,
    password: str | None,
    token: str | None,
    llm: bool,
    llm_model: str | None,
    ollama_url: str | None,
    json_out: str | None,
) -> int:
    ensure_log_tables(conn)
    cap = get_capture(conn, capture_id)
    if not cap:
        print(f"Capture not found: {capture_id}")
        return 1

    end_ts = utc_now()
    close_capture(conn, capture_id, end_ts=end_ts, status="completed")
    cap = get_capture(conn, capture_id) or cap

    try:
        cap_org = str(cap.get("org_alias") or "") or org_alias
        cap_login = str(cap.get("login_url") or "") or login_url
        cap_user = str(cap.get("sf_username") or "") or username
        cap_pass = str(cap.get("sf_password") or "") or password
        cap_token = str(cap.get("sf_token") or "") or token
        client, _ = _build_runtime_sf_client(
            org_alias=cap_org,
            login_url=cap_login,
            username=cap_user,
            password=cap_pass,
            token=cap_token,
        )
    except (SalesforceAuthError, SalesforceClientError, ToolingAPIError, ValueError, RuntimeError) as exc:
        print(f"Failed to connect for capture stop: {exc}")
        return 1

    logs = fetch_logs_for_window(
        client,
        user_id=str(cap["user_id"]),
        start_ts=str(cap["start_ts"]),
        end_ts=str(cap["end_ts"] or end_ts),
        filter_text=cap.get("filter_text"),
        limit=200,
    )
    parsed_logs: list[dict[str, Any]] = []
    for item in logs:
        lg = item.get("log") or {}
        body = str(item.get("body") or "")
        parsed = parse_log_text(body)
        parsed_logs.append({"log": lg, "parsed": parsed, "body": body})
        add_capture_log(
            conn,
            capture_id=capture_id,
            log_id=str(lg.get("Id") or ""),
            start_ts=lg.get("StartTime"),
            length=lg.get("LogLength"),
            status=str(lg.get("Status") or "Unknown"),
            error=None,
        )

    repo_root = cfg.resolve_repo_root(project_root)
    analysis = analyze_logs(parsed_logs, repo_root=repo_root)
    report = {
        "capture": cap,
        "log_count": len(parsed_logs),
        "stored_logs": list_capture_logs(conn, capture_id),
        "analysis": analysis,
        "evidence_paths": [x.get("repo_path") for x in analysis.get("top_stack_frames", []) if x.get("repo_path")],
        "evidence_snippets": [x.get("snippet") for x in analysis.get("top_stack_frames", []) if x.get("snippet")],
    }

    llm_info = _llm_narrate_report(
        cfg=cfg,
        question="Analyze this Salesforce log capture and explain root cause, fixes, and tests.",
        report=report,
        llm=llm,
        llm_model=llm_model,
        ollama_url=ollama_url,
    )
    report.update(llm_info)

    if llm_info.get("llm_used") and llm_info.get("llm_answer"):
        print(llm_info["llm_answer"])
    else:
        pf = analysis.get("primary_failure") or {}
        print(f"Primary failure: {pf.get('type') or 'Unknown'} {pf.get('message') or ''}".strip())
        print(f"Likely cause: {analysis.get('likely_cause')}")
        print("Top stack frames:")
        for fr in analysis.get("top_stack_frames", [])[:5]:
            frame = fr.get("frame") or {}
            print(f"- {frame.get('raw')}")
            if fr.get("repo_path"):
                print(f"  path: {fr['repo_path']}")

    if json_out:
        out = Path(json_out)
        if not out.is_absolute():
            out = project_root / out
        write_json(out, report)
        print(out.as_posix())
    return 0


def cmd_logs_explain(
    cfg: AppConfig,
    project_root: Path,
    *,
    org_alias: str | None,
    login_url: str | None,
    username: str | None,
    password: str | None,
    token: str | None,
    log_id: str,
    llm: bool,
    llm_model: str | None,
    ollama_url: str | None,
    json_out: str | None,
) -> int:
    try:
        client, _ = _build_runtime_sf_client(
            org_alias=org_alias,
            login_url=login_url,
            username=username,
            password=password,
            token=token,
        )
        body = client.get_log_body(log_id)
    except (SalesforceAuthError, SalesforceClientError, ToolingAPIError, ValueError, RuntimeError) as exc:
        print(f"Failed to fetch log body: {exc}")
        return 1

    parsed = parse_log_text(str(body))
    analysis = analyze_logs([{"parsed": parsed, "body": body}], repo_root=cfg.resolve_repo_root(project_root))
    report = {
        "log_id": log_id,
        "analysis": analysis,
        "evidence_paths": [x.get("repo_path") for x in analysis.get("top_stack_frames", []) if x.get("repo_path")],
        "evidence_snippets": [x.get("snippet") for x in analysis.get("top_stack_frames", []) if x.get("snippet")],
    }
    llm_info = _llm_narrate_report(
        cfg=cfg,
        question=f"Explain Salesforce ApexLog {log_id}: root cause, fixes, tests.",
        report=report,
        llm=llm,
        llm_model=llm_model,
        ollama_url=ollama_url,
    )
    report.update(llm_info)
    if llm_info.get("llm_used") and llm_info.get("llm_answer"):
        print(llm_info["llm_answer"])
    else:
        pf = analysis.get("primary_failure") or {}
        print(f"Primary failure: {pf.get('type') or 'Unknown'} {pf.get('message') or ''}".strip())
        print(f"Likely cause: {analysis.get('likely_cause')}")
    if json_out:
        out = Path(json_out)
        if not out.is_absolute():
            out = project_root / out
        write_json(out, report)
        print(out.as_posix())
    return 0


def cmd_nl(cfg: AppConfig, conn: sqlite3.Connection, project_root: Path, question: str) -> int:
    q_norm = normalize(question)
    if "approval process" in q_norm:
        object_name: str | None = None
        m = re.search(r"\bon\s+([A-Za-z0-9_ ]+)", question, flags=re.IGNORECASE)
        if m:
            maybe_obj = _resolve_object_input(conn, m.group(1).strip())
            object_name = maybe_obj.object_name
        if not object_name:
            maybe_obj = _resolve_object_input(conn, question)
            object_name = maybe_obj.object_name
        active_only = "active" in q_norm
        list_mode = ("list" in q_norm) or ("show" in q_norm)
        parsed = ParsedQuery(
            intent="approval_processes",
            object_name=object_name,
            contains="active" if active_only else None,
            raw_question=question,
            confidence=0.75 if object_name else 0.60,
        )
        _print_resolution(parsed)
        return cmd_approval_processes(
            conn,
            object_name=object_name,
            active_only=active_only,
            list_mode=list_mode,
        )

    parsed = parse_question(question, conn)
    _print_resolution(parsed)

    if parsed.intent == "field_where_used":
        if not parsed.full_field_name:
            print("Could not resolve intent/entities")
            return 0
        return cmd_where_used(conn, parsed.full_field_name)

    if parsed.intent == "flows_update_field":
        if not parsed.full_field_name:
            print("Could not resolve intent/entities")
            return 0
        return cmd_flows_update(conn, parsed.full_field_name)

    if parsed.intent == "endpoint_callers":
        if not parsed.endpoint:
            print("Could not resolve intent/entities")
            return 0
        return cmd_endpoint_callers(conn, parsed.endpoint)

    if parsed.intent == "validation_rules":
        if not parsed.object_name:
            print("Could not resolve intent/entities")
            return 0
        return cmd_validation_rules(conn, parsed.object_name, parsed.contains)

    if parsed.intent == "explain_object":
        if not parsed.object_name:
            print("Could not resolve intent/entities")
            return 0
        return cmd_explain_object(conn, parsed.object_name)

    if parsed.intent == "impact_field":
        if not parsed.full_field_name:
            print("Could not resolve intent/entities")
            return 0
        if impact_field_graph(conn, parsed.full_field_name).get("node"):
            return cmd_impact_field_graph(conn, parsed.full_field_name, confidence=parsed.confidence)
        return cmd_impact_field(conn, parsed.full_field_name, confidence=parsed.confidence)

    if parsed.intent == "impact_object":
        if not parsed.object_name:
            print("Could not resolve intent/entities")
            return 0
        if impact_object_graph(conn, parsed.object_name).get("node"):
            return cmd_impact_object_graph(conn, parsed.object_name, confidence=parsed.confidence)
        return cmd_impact_object(conn, parsed.object_name, confidence=parsed.confidence)

    print("Could not resolve intent/entities")
    return 0


def cmd_selftest(cfg: AppConfig, project_root: Path, repo_override: str | None) -> int:
    if repo_override:
        cfg.repo_root = repo_override

    stats = index_repository(cfg, project_root=project_root, rebuild_rag=False)
    print(
        f"index complete: total={stats.total_files} indexed={stats.indexed_files} "
        f"skipped={stats.skipped_files} deleted={stats.deleted_files} errors={stats.errors}"
    )

    conn = _conn_from_cfg(cfg, project_root)

    counts = {
        "objects": conn.execute("SELECT COUNT(*) AS c FROM objects").fetchone()["c"],
        "fields": conn.execute("SELECT COUNT(*) AS c FROM fields").fetchone()["c"],
        "flows": conn.execute("SELECT COUNT(*) AS c FROM flows").fetchone()["c"],
        "references": conn.execute("SELECT COUNT(*) AS c FROM \"references\"").fetchone()["c"],
        "meta_files": conn.execute("SELECT COUNT(*) AS c FROM meta_files").fetchone()["c"],
        "meta_refs": conn.execute("SELECT COUNT(*) AS c FROM meta_refs").fetchone()["c"],
    }
    print("counts:", counts)

    assert counts["objects"] > 0, "objects should be non-zero"
    assert counts["fields"] > 0, "fields should be non-zero"
    assert counts["flows"] > 0, "flows should be non-zero"
    assert counts["references"] > 0, "references should be non-zero"
    assert counts["meta_files"] > 0, "meta_files should be non-zero"
    assert counts["meta_refs"] > 0, "meta_refs should be non-zero"

    _ = query_where_used(conn, "Account.Name")
    _ = query_flows_update(conn, "Opportunity.StageName")
    _ = query_endpoint_callers(conn, "callout:")
    _ = query_where_used_any(conn, "Quote")

    explain = build_object_explain(conn, "Account")
    assert "field_count" in explain
    assert "top_fields" in explain
    assert "reference_count" in explain

    out = project_root / "data" / "tech_debt.json"
    cmd_techdebt(cfg, project_root, out.as_posix())
    payload = json.loads(out.read_text(encoding="utf-8"))
    assert set(payload.keys()) == {"apex", "flows", "security"}

    conn.close()
    print("selftest passed")
    return 0


def cmd_selftest_nl(cfg: AppConfig, project_root: Path, repo_override: str | None) -> int:
    if repo_override:
        cfg.repo_root = repo_override

    stats = index_repository(cfg, project_root=project_root, rebuild_rag=False)
    print(
        f"index complete: total={stats.total_files} indexed={stats.indexed_files} "
        f"skipped={stats.skipped_files} deleted={stats.deleted_files} errors={stats.errors}"
    )

    conn = _conn_from_cfg(cfg, project_root)
    try:
        samples = [
            "where account name is used",
            "which flows update opportunity stage",
            "show validation rules on case that block status changes",
            "what apex calls callout:",
            "how many approval processes are active on quote",
        ]

        p1 = parse_question(samples[0], conn)
        acc_exists = conn.execute(
            "SELECT 1 FROM fields WHERE lower(full_name)=lower('Account.Name') LIMIT 1"
        ).fetchone()
        if acc_exists:
            assert p1.full_field_name == "Account.Name"

        p2 = parse_question(samples[1], conn)
        stg_exists = conn.execute(
            "SELECT 1 FROM fields WHERE lower(full_name)=lower('Opportunity.StageName') LIMIT 1"
        ).fetchone()
        if stg_exists:
            assert p2.full_field_name == "Opportunity.StageName"

        p3 = parse_question(samples[2], conn)
        case_exists = conn.execute(
            "SELECT 1 FROM objects WHERE lower(object_name)=lower('Case') LIMIT 1"
        ).fetchone()
        if case_exists:
            assert (p3.object_name or "").lower() == "case"
            assert (p3.contains or "").lower() in {"status", ""}

        p4 = parse_question(samples[3], conn)
        assert p4.intent == "endpoint_callers" or p4.intent == "unknown"
        if p4.intent == "endpoint_callers":
            assert (p4.endpoint or "").startswith("callout:") or (p4.endpoint or "").startswith("http")

        for q in samples:
            rc = cmd_nl(cfg, conn, project_root, q)
            assert rc == 0

        print("selftest_nl passed")
        return 0
    finally:
        conn.close()


def cmd_selftest_graph(cfg: AppConfig, project_root: Path, repo_override: str | None) -> int:
    if repo_override:
        cfg.repo_root = repo_override

    stats = index_repository(cfg, project_root=project_root, rebuild_rag=False)
    print(
        f"index complete: total={stats.total_files} indexed={stats.indexed_files} "
        f"skipped={stats.skipped_files} deleted={stats.deleted_files} errors={stats.errors}"
    )

    conn = _conn_from_cfg(cfg, project_root)
    try:
        repo_root = cfg.resolve_repo_root(project_root)
        gstats = build_dependency_graph(conn, repo_root=repo_root, sfdx_root=cfg.sfdx_root)
        print(
            f"graph build complete: nodes={gstats.nodes} edges={gstats.edges} "
            f"flow_edges={gstats.flow_edges} trigger_edges={gstats.trigger_edges} apex_edges={gstats.apex_edges} metadata_edges={gstats.metadata_edges}"
        )

        node_count = int(conn.execute("SELECT COUNT(*) AS c FROM graph_nodes").fetchone()["c"])
        assert node_count > 0, "graph_nodes should be non-zero"

        flow_count = int(conn.execute("SELECT COUNT(*) AS c FROM flows").fetchone()["c"])
        flow_nodes = int(conn.execute("SELECT COUNT(*) AS c FROM graph_nodes WHERE node_type='FLOW'").fetchone()["c"])
        if flow_count > 0:
            assert flow_nodes > 0, "FLOW nodes expected when flows exist"

        ffw_count = int(conn.execute("SELECT COUNT(*) AS c FROM flow_field_writes").fetchone()["c"])
        fwe_count = int(
            conn.execute("SELECT COUNT(*) AS c FROM graph_edges WHERE edge_type='FLOW_WRITES_FIELD'").fetchone()["c"]
        )
        if ffw_count > 0:
            assert fwe_count > 0, "FLOW_WRITES_FIELD edges expected when flow_field_writes exists"

        ap_end_count = int(conn.execute("SELECT COUNT(*) AS c FROM apex_endpoints").fetchone()["c"])
        ep_edge_count = int(
            conn.execute("SELECT COUNT(*) AS c FROM graph_edges WHERE edge_type='CLASS_CALLS_ENDPOINT'").fetchone()["c"]
        )
        if ap_end_count > 0:
            assert ep_edge_count > 0, "CLASS_CALLS_ENDPOINT edges expected when apex_endpoints exists"

        sample_flow = conn.execute("SELECT flow_name FROM flows ORDER BY flow_name LIMIT 1").fetchone()
        if sample_flow:
            rc = cmd_deps_flow(conn, sample_flow["flow_name"])
            assert rc == 0

        sample_class = conn.execute("SELECT name FROM components WHERE type='APEX' ORDER BY name LIMIT 1").fetchone()
        if sample_class:
            rc = cmd_deps_class(conn, sample_class["name"])
            assert rc == 0

        _ = cmd_impact(conn, "Account.Name")
        print("selftest_graph passed")
        return 0
    finally:
        conn.close()


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Salesforce repo intelligence CLI")
    p.add_argument("--config", default="config.yaml", help="Path to config YAML")

    sub = p.add_subparsers(dest="cmd", required=True)

    p_index = sub.add_parser("index", help="Build deterministic indexes")
    p_index.add_argument("--repo", help="Repo root override")
    p_index.add_argument("--rebuild-rag", action="store_true", help="Force RAG rebuild")

    p_graph = sub.add_parser("graph-build", help="Build dependency graph")
    p_graph.add_argument("--repo", help="Repo root override")

    p_evidence = sub.add_parser("evidence", help="Build deterministic universal evidence dossier")
    p_evidence.add_argument("--target", required=True)
    p_evidence.add_argument("--depth", type=int, default=2)
    p_evidence.add_argument("--top", dest="top_n", type=int, default=20)
    p_evidence.add_argument("--json-out", required=False)

    p_advise = sub.add_parser("advise", help="Grounded recommendations from evidence")
    p_advise.add_argument("--target", required=True)
    p_advise.add_argument("--depth", type=int, default=2)
    p_advise.add_argument("--top", dest="top_n", type=int, default=20)
    p_advise.add_argument("--no-llm", action="store_true")
    p_advise.add_argument("--out", required=True)

    p_coverage = sub.add_parser("coverage", help="Coverage and extraction quality report")
    p_coverage.add_argument("--out", required=True)

    p_org_summary = sub.add_parser("org-summary", help="Org surface area markdown summary")
    p_org_summary.add_argument("--out", required=True)

    p_count = sub.add_parser("count", help="Universal count for any metadata type")
    p_count.add_argument("--type", required=True)
    p_count.add_argument("--filter", action="append", required=False)

    p_list = sub.add_parser("list", help="Universal list for any metadata type")
    p_list.add_argument("--type", required=True)
    p_list.add_argument("--filter", action="append", required=False)

    p_list_meta = sub.add_parser("list-meta", help="List indexed metadata files")
    p_list_meta.add_argument("--folder", required=False)
    p_list_meta.add_argument("--type", dest="type_guess", required=False)

    p_count_meta = sub.add_parser("count-meta", help="Count indexed metadata files")
    p_count_meta.add_argument("--folder", required=False)
    p_count_meta.add_argument("--type", dest="type_guess", required=False)

    p_where_any = sub.add_parser("where-used-any", help="Universal token lookup across metadata")
    p_where_any.add_argument("--token", required=True)

    p_approval = sub.add_parser("approval-processes", help="Query approval process metadata")
    p_approval.add_argument("--object", required=False)
    p_approval.add_argument("--active-only", action="store_true")
    p_approval.add_argument("--list", action="store_true")

    p_debug_approval = sub.add_parser("debug-approval", help="Debug approval process adapter indexing")
    p_debug_approval.add_argument("--object", required=True)

    p_blast = sub.add_parser("blast-radius", help="Blast radius from git diff refs")
    p_blast.add_argument("--from", dest="base_ref", required=True)
    p_blast.add_argument("--to", dest="head_ref", required=True)
    p_blast.add_argument("--depth", type=int, default=2)
    p_blast.add_argument("--out", required=True)

    p_where = sub.add_parser("where-used", help="Find field references")
    p_where.add_argument("--field", required=True)

    p_flow = sub.add_parser("flows-update", help="Find flows that write a field")
    p_flow.add_argument("--field", required=True)

    p_end = sub.add_parser("endpoint-callers", help="Find Apex endpoint callers")
    p_end.add_argument("--endpoint", required=True)

    p_explain = sub.add_parser("explain", help="Universal explain for any target")
    p_explain.add_argument("--target", required=True)
    p_explain.add_argument("--out", required=False)
    p_explain.add_argument("--no-llm", action="store_true")
    p_explain.add_argument("--llm", action="store_true")
    p_explain.add_argument("--debug-llm", action="store_true")

    p_vr = sub.add_parser("validation-rules", help="Find validation rules")
    p_vr.add_argument("--object", required=True)
    p_vr.add_argument("--contains", required=False)

    p_exp = sub.add_parser("explain-object", help="Explain object usage and security")
    p_exp.add_argument("--object", required=True)

    p_td = sub.add_parser("techdebt", help="Generate tech debt report")
    p_td.add_argument("--out", required=True)

    p_impact = sub.add_parser("impact", help="Impact report for object/field target")
    p_impact.add_argument("--target", required=True)

    p_deps = sub.add_parser("deps", help="Dependency lookup for flow or class")
    deps_group = p_deps.add_mutually_exclusive_group(required=True)
    deps_group.add_argument("--flow")
    deps_group.add_argument("--class", dest="class_name")

    p_collisions = sub.add_parser("collisions", help="Detect automation write collisions")
    col_group = p_collisions.add_mutually_exclusive_group(required=True)
    col_group.add_argument("--object")
    col_group.add_argument("--field")
    p_collisions.add_argument("--out", required=True)

    p_breaks = sub.add_parser("what-breaks", help="Scenario engine for dependency breakage")
    p_breaks.add_argument("--target", required=True)
    p_breaks.add_argument("--depth", type=int, default=2)
    p_breaks.add_argument("--out", required=False)

    p_checklist = sub.add_parser("test-checklist", help="Generate deterministic test checklist markdown")
    p_checklist.add_argument("--target", required=True)
    p_checklist.add_argument("--out", required=True)

    p_ask = sub.add_parser("ask", help="Ask evidence-based question")
    p_ask.add_argument("--question", required=True)
    p_ask.add_argument("--json-out", required=False)
    p_ask.add_argument("--debug-routing", action="store_true")
    p_ask.add_argument("--llm", dest="ask_llm", action="store_true")
    p_ask.add_argument("--no-llm", dest="ask_llm", action="store_false")
    p_ask.set_defaults(ask_llm=False)
    p_ask.add_argument(
        "--llm-mode",
        choices=["narrate_only", "planner_then_narrate", "full_primary"],
        default="narrate_only",
    )
    p_ask.add_argument("--llm-full", action="store_true")
    p_ask.add_argument("--llm-model", default="gpt-oss:20b")
    p_ask.add_argument("--ollama-url", default="http://localhost:11434")
    p_ask.add_argument("--llm-max-chars", type=int, default=120000)
    p_ask.add_argument("--llm-primary-max-chars", type=int, default=80000)
    p_ask.add_argument("--debug-llm", action="store_true")

    p_access = sub.add_parser("access", help="Record access diagnostics")
    access_sub = p_access.add_subparsers(dest="access_cmd", required=True)
    p_access_why = access_sub.add_parser("why", help="Explain why user can/cannot access a record from bundle")
    p_access_why.add_argument("--bundle", required=False, help="Path to AccessBundle JSON")
    p_access_why.add_argument("--sf-login-url", "--org-login-url", dest="sf_login_url", default=None)
    p_access_why.add_argument("--username", dest="sf_username", default=None)
    p_access_why.add_argument("--password", dest="sf_password", default=None)
    p_access_why.add_argument("--token", dest="sf_token", default=None)
    p_access_why.add_argument("--user", required=False, help="Salesforce user id/username to diagnose")
    p_access_why.add_argument("--record", required=False, help="Salesforce record Id")
    p_access_why.add_argument("--llm", action="store_true")
    p_access_why.add_argument("--llm-model", default="gpt-oss:20b")
    p_access_why.add_argument("--ollama-url", default="http://localhost:11434")
    p_access_why.add_argument("--json-out", required=False)

    p_access_why_flat = sub.add_parser("access-why", help="Explain why user can/cannot access a specific record")
    p_access_why_flat.add_argument("--bundle", required=False, help="Path to AccessBundle JSON")
    p_access_why_flat.add_argument("--sf-login-url", "--org-login-url", dest="sf_login_url", default=None)
    p_access_why_flat.add_argument("--username", dest="sf_username", default=None)
    p_access_why_flat.add_argument("--password", dest="sf_password", default=None)
    p_access_why_flat.add_argument("--token", dest="sf_token", default=None)
    p_access_why_flat.add_argument("--user", required=False, help="Salesforce user id/username to diagnose")
    p_access_why_flat.add_argument("--record", required=False, help="Salesforce record Id")
    p_access_why_flat.add_argument("--llm", action="store_true")
    p_access_why_flat.add_argument("--llm-model", default="gpt-oss:20b")
    p_access_why_flat.add_argument("--ollama-url", default="http://localhost:11434")
    p_access_why_flat.add_argument("--json-out", required=False)

    p_logs = sub.add_parser("logs", help="Salesforce debug log capture utilities")
    logs_sub = p_logs.add_subparsers(dest="logs_cmd", required=True)

    p_logs_trace = logs_sub.add_parser("trace", help="Manage trace flags")
    logs_trace_sub = p_logs_trace.add_subparsers(dest="logs_trace_cmd", required=True)
    p_logs_trace_enable = logs_trace_sub.add_parser("enable", help="Enable trace flag for user")
    p_logs_trace_enable.add_argument("--org", required=False)
    p_logs_trace_enable.add_argument("--sf-login-url", "--org-login-url", dest="sf_login_url", default=None)
    p_logs_trace_enable.add_argument("--username", default=None)
    p_logs_trace_enable.add_argument("--password", default=None)
    p_logs_trace_enable.add_argument("--token", default=None)
    p_logs_trace_enable.add_argument("--user", required=True)
    p_logs_trace_enable.add_argument("--minutes", type=int, default=30)
    p_logs_trace_enable.add_argument("--level", default="FINEST")
    p_logs_trace_disable = logs_trace_sub.add_parser("disable", help="Disable trace flags for user")
    p_logs_trace_disable.add_argument("--org", required=False)
    p_logs_trace_disable.add_argument("--sf-login-url", "--org-login-url", dest="sf_login_url", default=None)
    p_logs_trace_disable.add_argument("--username", default=None)
    p_logs_trace_disable.add_argument("--password", default=None)
    p_logs_trace_disable.add_argument("--token", default=None)
    p_logs_trace_disable.add_argument("--user", required=True)

    p_logs_capture = logs_sub.add_parser("capture", help="Capture and analyze logs")
    logs_capture_sub = p_logs_capture.add_subparsers(dest="logs_capture_cmd", required=True)
    p_logs_capture_start = logs_capture_sub.add_parser("start", help="Start capture session")
    p_logs_capture_start.add_argument("--org", required=False)
    p_logs_capture_start.add_argument("--sf-login-url", "--org-login-url", dest="sf_login_url", default=None)
    p_logs_capture_start.add_argument("--username", default=None)
    p_logs_capture_start.add_argument("--password", default=None)
    p_logs_capture_start.add_argument("--token", default=None)
    p_logs_capture_start.add_argument("--user", required=True)
    p_logs_capture_start.add_argument("--minutes", type=int, default=10)
    p_logs_capture_start.add_argument("--filter", required=False)
    p_logs_capture_start.add_argument("--filter-text", dest="filter", required=False)
    p_logs_capture_start.add_argument("--level", default="FINEST")
    p_logs_capture_stop = logs_capture_sub.add_parser("stop", help="Stop capture and analyze")
    p_logs_capture_stop.add_argument("--capture-id", type=int, required=True)
    p_logs_capture_stop.add_argument("--org", required=False)
    p_logs_capture_stop.add_argument("--sf-login-url", "--org-login-url", dest="sf_login_url", default=None)
    p_logs_capture_stop.add_argument("--username", default=None)
    p_logs_capture_stop.add_argument("--password", default=None)
    p_logs_capture_stop.add_argument("--token", default=None)
    p_logs_capture_stop.add_argument("--llm", action="store_true")
    p_logs_capture_stop.add_argument("--llm-model", default="gpt-oss:20b")
    p_logs_capture_stop.add_argument("--ollama-url", default="http://localhost:11434")
    p_logs_capture_stop.add_argument("--json-out", required=False)
    p_logs_explain = logs_sub.add_parser("explain", help="Explain a single ApexLog by id")
    p_logs_explain.add_argument("--log-id", required=True)
    p_logs_explain.add_argument("--org", required=False)
    p_logs_explain.add_argument("--sf-login-url", "--org-login-url", dest="sf_login_url", default=None)
    p_logs_explain.add_argument("--username", default=None)
    p_logs_explain.add_argument("--password", default=None)
    p_logs_explain.add_argument("--token", default=None)
    p_logs_explain.add_argument("--llm", action="store_true")
    p_logs_explain.add_argument("--llm-model", default="gpt-oss:20b")
    p_logs_explain.add_argument("--ollama-url", default="http://localhost:11434")
    p_logs_explain.add_argument("--json-out", required=False)

    p_nl = sub.add_parser("nl", help="Natural language query interpreter")
    p_nl.add_argument("--question", required=True)

    p_self = sub.add_parser("selftest", help="Run acceptance self test")
    p_self.add_argument("--repo", required=False)

    p_self_nl = sub.add_parser("selftest-nl", help="Run natural-language regression self test")
    p_self_nl.add_argument("--repo", required=False)

    p_self_graph = sub.add_parser("selftest-graph", help="Run graph dependency self test")
    p_self_graph.add_argument("--repo", required=False)

    p_regress = sub.add_parser("regress", help="Run YAML-driven regression harness")
    p_regress.add_argument("--file", required=True)
    p_regress.add_argument("--json-out", required=False)

    return p


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    project_root = Path.cwd()
    cfg = load_config(args.config, project_root=project_root)

    if args.cmd == "index":
        if args.repo:
            cfg.repo_root = args.repo
        stats = index_repository(cfg, project_root=project_root, rebuild_rag=args.rebuild_rag)
        print(
            f"index complete: total={stats.total_files} indexed={stats.indexed_files} "
            f"skipped={stats.skipped_files} deleted={stats.deleted_files} errors={stats.errors}"
        )
        return 0

    if args.cmd == "graph-build":
        return cmd_graph_build(cfg, project_root, args.repo)

    if args.cmd == "org-summary":
        conn = _conn_from_cfg(cfg, project_root)
        try:
            return cmd_org_summary(cfg, conn, project_root, out_path=args.out)
        finally:
            conn.close()

    if args.cmd == "blast-radius":
        return cmd_blast_radius(
            cfg,
            project_root,
            base_ref=args.base_ref,
            head_ref=args.head_ref,
            depth=args.depth,
            out_path=args.out,
        )

    if args.cmd == "techdebt":
        return cmd_techdebt(cfg, project_root, args.out)

    if args.cmd == "selftest":
        return cmd_selftest(cfg, project_root, args.repo)

    if args.cmd == "selftest-nl":
        return cmd_selftest_nl(cfg, project_root, args.repo)

    if args.cmd == "selftest-graph":
        return cmd_selftest_graph(cfg, project_root, args.repo)

    conn = _conn_from_cfg(cfg, project_root)
    try:
        if args.cmd == "access":
            if args.access_cmd == "why":
                return cmd_access_why(
                    cfg,
                    conn,
                    project_root,
                    bundle_path=args.bundle,
                    sf_login_url=args.sf_login_url,
                    sf_username=args.sf_username,
                    sf_password=args.sf_password,
                    sf_token=args.sf_token,
                    user=args.user,
                    record=args.record,
                    llm=bool(args.llm),
                    llm_model=args.llm_model,
                    ollama_url=args.ollama_url,
                    json_out=args.json_out,
                )
            parser.error(f"Unsupported access subcommand: {args.access_cmd}")

        if args.cmd == "access-why":
            return cmd_access_why(
                cfg,
                conn,
                project_root,
                bundle_path=args.bundle,
                sf_login_url=args.sf_login_url,
                sf_username=args.sf_username,
                sf_password=args.sf_password,
                sf_token=args.sf_token,
                user=args.user,
                record=args.record,
                llm=bool(args.llm),
                llm_model=args.llm_model,
                ollama_url=args.ollama_url,
                json_out=args.json_out,
            )

        if args.cmd == "logs":
            if args.logs_cmd == "trace":
                if args.logs_trace_cmd == "enable":
                    return cmd_logs_trace_enable(
                        org_alias=args.org,
                        login_url=args.sf_login_url,
                        username=args.username,
                        password=args.password,
                        token=args.token,
                        user=args.user,
                        minutes=args.minutes,
                        level=args.level,
                    )
                if args.logs_trace_cmd == "disable":
                    return cmd_logs_trace_disable(
                        org_alias=args.org,
                        login_url=args.sf_login_url,
                        username=args.username,
                        password=args.password,
                        token=args.token,
                        user=args.user,
                    )
                parser.error(f"Unsupported logs trace subcommand: {args.logs_trace_cmd}")
            if args.logs_cmd == "capture":
                if args.logs_capture_cmd == "start":
                    return cmd_logs_capture_start(
                        conn,
                        org_alias=args.org,
                        login_url=args.sf_login_url,
                        username=args.username,
                        password=args.password,
                        token=args.token,
                        user=args.user,
                        minutes=args.minutes,
                        filter_text=args.filter,
                        level=args.level,
                    )
                if args.logs_capture_cmd == "stop":
                    return cmd_logs_capture_stop(
                        cfg,
                        conn,
                        project_root,
                        capture_id=args.capture_id,
                        org_alias=args.org,
                        login_url=args.sf_login_url,
                        username=args.username,
                        password=args.password,
                        token=args.token,
                        llm=bool(args.llm),
                        llm_model=args.llm_model,
                        ollama_url=args.ollama_url,
                        json_out=args.json_out,
                    )
                parser.error(f"Unsupported logs capture subcommand: {args.logs_capture_cmd}")
            if args.logs_cmd == "explain":
                return cmd_logs_explain(
                    cfg,
                    project_root,
                    org_alias=args.org,
                    login_url=args.sf_login_url,
                    username=args.username,
                    password=args.password,
                    token=args.token,
                    log_id=args.log_id,
                    llm=bool(args.llm),
                    llm_model=args.llm_model,
                    ollama_url=args.ollama_url,
                    json_out=args.json_out,
                )
            parser.error(f"Unsupported logs subcommand: {args.logs_cmd}")

        if args.cmd == "where-used":
            field_value = args.field.strip()
            if "." not in field_value:
                parsed = _resolve_field_input(conn, field_value, intent_hint="field_where_used")
                _print_resolution(parsed)
                if not parsed.full_field_name:
                    print("Could not resolve intent/entities")
                    return 0
                field_value = parsed.full_field_name
            return cmd_where_used(conn, field_value)
        if args.cmd == "flows-update":
            field_value = args.field.strip()
            if "." not in field_value:
                parsed = _resolve_field_input(conn, field_value, intent_hint="flows_update_field")
                _print_resolution(parsed)
                if not parsed.full_field_name:
                    print("Could not resolve intent/entities")
                    return 0
                field_value = parsed.full_field_name
            return cmd_flows_update(conn, field_value)
        if args.cmd == "evidence":
            return cmd_evidence(
                conn,
                project_root,
                target=args.target,
                depth=args.depth,
                top_n=args.top_n,
                json_out=args.json_out,
            )
        if args.cmd == "advise":
            return cmd_advise(
                cfg,
                conn,
                project_root,
                target=args.target,
                depth=args.depth,
                top_n=args.top_n,
                no_llm=args.no_llm,
                out_path=args.out,
            )
        if args.cmd == "coverage":
            return cmd_coverage(conn, project_root, out_path=args.out)
        if args.cmd == "count":
            return cmd_count_typed(conn, type_name=args.type, filters=args.filter)
        if args.cmd == "list":
            return cmd_list_typed(conn, type_name=args.type, filters=args.filter)
        if args.cmd == "list-meta":
            return cmd_list_meta(conn, folder=args.folder, type_guess=args.type_guess)
        if args.cmd == "count-meta":
            return cmd_count_meta(conn, folder=args.folder, type_guess=args.type_guess)
        if args.cmd == "where-used-any":
            return cmd_where_used_any(conn, args.token)
        if args.cmd == "approval-processes":
            obj = args.object
            if obj:
                parsed = _resolve_object_input(conn, obj)
                obj = parsed.object_name or obj
            return cmd_approval_processes(
                conn,
                object_name=obj,
                active_only=args.active_only,
                list_mode=args.list,
            )
        if args.cmd == "debug-approval":
            obj = args.object
            parsed = _resolve_object_input(conn, obj)
            obj = parsed.object_name or obj
            return cmd_debug_approval(conn, object_name=obj)
        if args.cmd == "endpoint-callers":
            return cmd_endpoint_callers(conn, args.endpoint)
        if args.cmd == "explain":
            use_llm = args.llm or (not args.no_llm)
            return cmd_explain(
                cfg,
                conn,
                project_root,
                target=args.target,
                out_path=args.out,
                use_llm=use_llm,
                debug_llm=args.debug_llm,
            )
        if args.cmd == "validation-rules":
            obj_value = args.object.strip()
            parsed_obj = _resolve_object_input(conn, obj_value)
            obj_value = parsed_obj.object_name or obj_value
            contains = args.contains
            if contains is None:
                q = f"show validation rules on {obj_value}"
                parsed_q = parse_question(q, conn)
                contains = parsed_q.contains
            return cmd_validation_rules(conn, obj_value, contains)
        if args.cmd == "explain-object":
            parsed = _resolve_object_input(conn, args.object)
            _print_resolution(parsed)
            if parsed.full_field_name:
                return cmd_impact_field(conn, parsed.full_field_name, confidence=parsed.confidence)
            if parsed.object_name:
                return cmd_explain_object(conn, parsed.object_name)
            print("Could not resolve intent/entities")
            return 0
        if args.cmd == "impact":
            return cmd_impact(conn, args.target)
        if args.cmd == "deps":
            if args.flow:
                return cmd_deps_flow(conn, args.flow)
            return cmd_deps_class(conn, args.class_name)
        if args.cmd == "collisions":
            return cmd_collisions(
                conn,
                project_root,
                object_name=args.object,
                field_name=args.field,
                out_path=args.out,
            )
        if args.cmd == "what-breaks":
            return cmd_what_breaks(
                conn,
                project_root,
                target=args.target,
                depth=args.depth,
                out_path=args.out,
            )
        if args.cmd == "test-checklist":
            return cmd_test_checklist(
                conn,
                project_root,
                target=args.target,
                out_path=args.out,
            )
        if args.cmd == "ask":
            return cmd_ask(
                conn,
                project_root,
                args.question,
                json_out=args.json_out,
                debug_routing=args.debug_routing,
                use_llm=args.ask_llm,
                llm_mode=args.llm_mode,
                llm_full=args.llm_full,
                llm_model=args.llm_model,
                ollama_url=args.ollama_url,
                llm_max_chars=args.llm_max_chars,
                llm_primary_max_chars=args.llm_primary_max_chars,
                debug_llm=args.debug_llm,
                cfg=cfg,
            )
        if args.cmd == "nl":
            return cmd_nl(cfg, conn, project_root, args.question)
        if args.cmd == "regress":
            return cmd_regress(
                conn,
                project_root,
                file_path=args.file,
                json_out=args.json_out,
            )
        parser.error(f"Unsupported command: {args.cmd}")
    finally:
        conn.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
