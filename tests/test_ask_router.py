from __future__ import annotations

import json
import os
import sqlite3
import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
_CANDIDATES = [
    (PROJECT_ROOT / "template_repo").resolve(),
    (PROJECT_ROOT / ".." / "template_repo").resolve(),
    (PROJECT_ROOT / "data" / "repo").resolve(),
]
DEFAULT_REPO = next((p for p in _CANDIDATES if p.exists()), _CANDIDATES[0])


def _run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, "-m", "sf_repo_ai.cli", *args],
        cwd=PROJECT_ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def _repo_root() -> Path:
    env = os.getenv("SF_REPO_ROOT")
    return Path(env).resolve() if env else DEFAULT_REPO


def _ensure_index() -> Path:
    db_path = PROJECT_ROOT / "data" / "index.sqlite"
    if db_path.exists():
        conn = sqlite3.connect(db_path)
        try:
            cnt = conn.execute("SELECT COUNT(*) FROM objects").fetchone()[0]
            if cnt > 0:
                return db_path
        except Exception:
            pass
        finally:
            conn.close()

    res = _run("index", "--repo", str(_repo_root()))
    assert res.returncode == 0, res.stderr
    return db_path


def test_ask_flows_on_first_three_objects_data_driven() -> None:
    db_path = _ensure_index()
    conn = sqlite3.connect(db_path)
    rows = conn.execute("SELECT object_name FROM objects ORDER BY object_name LIMIT 3").fetchall()
    conn.close()
    assert rows, "Expected at least one object in DB"

    out_file = PROJECT_ROOT / "data" / "ask_answer.json"
    for (obj,) in rows:
        res = _run("ask", "--question", f"how many flows on {obj}", "--json-out", str(out_file))
        assert res.returncode == 0, res.stderr
        payload = json.loads(out_file.read_text(encoding="utf-8"))
        assert payload["resolved"]["object_name"].lower() == obj.lower()
        assert payload["intent"] == "count_type_on_object"


def test_ask_approval_processes_list_if_available() -> None:
    db_path = _ensure_index()
    conn = sqlite3.connect(db_path)
    row = conn.execute(
        "SELECT object_name FROM approval_processes WHERE object_name IS NOT NULL AND object_name <> '' ORDER BY object_name LIMIT 1"
    ).fetchone()
    conn.close()
    if not row:
        return

    obj = row[0]
    out_file = PROJECT_ROOT / "data" / "ask_approval.json"
    res = _run("ask", "--question", f"list approval processes on {obj}", "--json-out", str(out_file))
    assert res.returncode == 0, res.stderr
    payload = json.loads(out_file.read_text(encoding="utf-8"))
    assert payload["resolved"]["metadata_type"] == "ApprovalProcess"
    assert payload["resolved"]["object_name"] is not None


def test_ask_unknown_object_safe_failure() -> None:
    _ensure_index()
    res = _run("ask", "--question", "how many flows on BlahBlahUnknownObject")
    assert res.returncode == 0, res.stderr
    assert "object not found in repo" in res.stdout.lower()


def test_ask_open_ended_routes_to_evidence() -> None:
    db_path = _ensure_index()
    conn = sqlite3.connect(db_path)
    row = conn.execute("SELECT object_name FROM objects ORDER BY object_name LIMIT 1").fetchone()
    conn.close()
    assert row, "Expected at least one object in DB"

    obj = row[0]
    out_file = PROJECT_ROOT / "data" / "ask_evidence.json"
    res = _run("ask", "--question", f"show everything touching {obj}", "--json-out", str(out_file))
    assert res.returncode == 0, res.stderr
    payload = json.loads(out_file.read_text(encoding="utf-8"))
    assert payload["resolved"]["target"] == obj
    assert payload["resolved"]["target_type"] in {"OBJECT", "FIELD", "FLOW", "APEX_CLASS", "TRIGGER", "ENDPOINT", "FILE"}
    assert "dossier" in payload


def test_ask_output_debug_routing_flag_controls_resolution_lines() -> None:
    _ensure_index()
    plain = _run("ask", "--question", "how many flows are there")
    assert plain.returncode == 0, plain.stderr
    assert "Resolved intent:" not in plain.stdout

    debug = _run("ask", "--question", "how many flows are there", "--debug-routing")
    assert debug.returncode == 0, debug.stderr
    assert "Resolved intent:" in debug.stdout


def test_ask_explain_approval_process_disambiguates_from_field() -> None:
    db_path = _ensure_index()
    conn = sqlite3.connect(db_path)
    row = conn.execute(
        "SELECT name, path FROM approval_processes WHERE object_name='Case' ORDER BY name LIMIT 1"
    ).fetchone()
    conn.close()
    if not row:
        return

    out_file = PROJECT_ROOT / "data" / "ask_explain_approval.json"
    res = _run("ask", "--question", f"explain approval process {row[0]}", "--json-out", str(out_file))
    assert res.returncode == 0, res.stderr
    payload = json.loads(out_file.read_text(encoding="utf-8"))
    assert payload["intent"] == "explain_component"
    assert payload["resolved"]["metadata_type"] == "ApprovalProcess"
    assert payload["resolved"]["full_field_name"] in {None, ""}
    assert any((e.get("path") or "").lower() == row[1].lower() for e in payload.get("evidence", []))


def test_ask_record_types_on_opportunity_uses_meta_inventory() -> None:
    db_path = _ensure_index()
    conn = sqlite3.connect(db_path)
    exists = conn.execute(
        """
        SELECT 1
        FROM meta_files
        WHERE lower(path) LIKE '%/objects/opportunity/recordtypes/%.recordtype-meta.xml'
        LIMIT 1
        """
    ).fetchone()
    conn.close()
    if not exists:
        return

    out_file = PROJECT_ROOT / "data" / "ask_recordtypes.json"
    res = _run("ask", "--question", "How many recordtypes are available on Opportunity", "--json-out", str(out_file))
    assert res.returncode == 0, res.stderr
    payload = json.loads(out_file.read_text(encoding="utf-8"))
    assert payload["routing_family"] == "meta_inventory"
    assert payload["intent"] == "meta_inventory_count"
    assert str(payload["resolved"].get("metadata_type", "")).lower() == "recordtype"
    assert payload.get("count", 0) >= 1


def test_ask_list_record_types_on_opportunity_lists_paths() -> None:
    db_path = _ensure_index()
    conn = sqlite3.connect(db_path)
    exists = conn.execute(
        """
        SELECT 1
        FROM meta_files
        WHERE lower(path) LIKE '%/objects/opportunity/recordtypes/%.recordtype-meta.xml'
        LIMIT 1
        """
    ).fetchone()
    conn.close()
    if not exists:
        return

    out_file = PROJECT_ROOT / "data" / "ask_recordtypes_list.json"
    res = _run("ask", "--question", "List record types on Opportunity", "--json-out", str(out_file))
    assert res.returncode == 0, res.stderr
    payload = json.loads(out_file.read_text(encoding="utf-8"))
    assert payload["routing_family"] == "meta_inventory"
    assert payload["intent"] == "meta_inventory_list"
    assert payload["items"], "Expected record type list items"
    assert any("/objects/Opportunity/recordTypes/" in str(i.get("path")) for i in payload["items"])
    assert not any("/flows/" in str(e.get("path") or "") for e in payload.get("evidence", []))
    assert len(payload.get("answer_lines", [])) > 1
    assert any(f"- {str(i.get('name'))}" in payload["answer_lines"] for i in payload["items"][:3])


def test_ask_validation_rules_names_on_object_lists_rule_names() -> None:
    db_path = _ensure_index()
    conn = sqlite3.connect(db_path)
    row = conn.execute(
        """
        SELECT object_name, rule_name
        FROM validation_rules
        WHERE object_name IS NOT NULL AND object_name <> ''
        ORDER BY object_name, rule_name
        LIMIT 1
        """
    ).fetchone()
    conn.close()
    if not row:
        return

    obj, rule_name = row
    out_file = PROJECT_ROOT / "data" / "ask_validation_rules_names.json"
    res = _run("ask", "--question", f"give me the names of validation rules on {obj}", "--json-out", str(out_file))
    assert res.returncode == 0, res.stderr
    payload = json.loads(out_file.read_text(encoding="utf-8"))
    assert payload["intent"] in {"meta_inventory_list", "validation_rule_list"}
    assert payload["count"] >= 1
    assert any(str(line).strip() == f"- {rule_name}" for line in payload.get("answer_lines", []))


def test_ask_layout_names_on_account_lists_layout_names() -> None:
    db_path = _ensure_index()
    conn = sqlite3.connect(db_path)
    row = conn.execute(
        """
        SELECT api_name
        FROM meta_files
        WHERE lower(folder)='layouts'
          AND lower(path) LIKE '%/layouts/account-%'
        ORDER BY api_name
        LIMIT 1
        """
    ).fetchone()
    conn.close()
    if not row:
        return

    layout_name = row[0]
    out_file = PROJECT_ROOT / "data" / "ask_layout_names.json"
    res = _run("ask", "--question", "give me the names of layouts on account", "--json-out", str(out_file))
    assert res.returncode == 0, res.stderr
    payload = json.loads(out_file.read_text(encoding="utf-8"))
    assert payload["intent"] == "list_type_on_object"
    assert payload["count"] >= 1
    assert any(str(line).strip() == f"- {layout_name}" for line in payload.get("answer_lines", []))


def test_ask_field_names_on_account_lists_field_names() -> None:
    db_path = _ensure_index()
    conn = sqlite3.connect(db_path)
    row = conn.execute(
        """
        SELECT api_name
        FROM meta_files
        WHERE lower(folder)='fields'
          AND lower(path) LIKE '%/objects/account/fields/%'
        ORDER BY api_name
        LIMIT 1
        """
    ).fetchone()
    conn.close()
    if not row:
        return

    field_name = row[0]
    out_file = PROJECT_ROOT / "data" / "ask_field_names.json"
    res = _run("ask", "--question", "give me the names of fields on account", "--json-out", str(out_file))
    assert res.returncode == 0, res.stderr
    payload = json.loads(out_file.read_text(encoding="utf-8"))
    assert payload["intent"] == "meta_inventory_list"
    assert payload["count"] >= 1
    assert any(str(line).strip() == f"- {field_name}" for line in payload.get("answer_lines", []))


def test_ask_explain_record_type_on_opportunity() -> None:
    db_path = _ensure_index()
    conn = sqlite3.connect(db_path)
    row = conn.execute(
        """
        SELECT replace(replace(path, 'force-app/main/default/objects/Opportunity/recordTypes/', ''), '.recordType-meta.xml', '') AS name, path
        FROM meta_files
        WHERE lower(path) LIKE '%/objects/opportunity/recordtypes/%.recordtype-meta.xml'
        ORDER BY path
        LIMIT 1
        """
    ).fetchone()
    conn.close()
    if not row:
        return

    out_file = PROJECT_ROOT / "data" / "ask_recordtype_explain.json"
    res = _run("ask", "--question", f"Explain record type Opportunity.{row[0]}", "--json-out", str(out_file))
    assert res.returncode == 0, res.stderr
    payload = json.loads(out_file.read_text(encoding="utf-8"))
    assert payload["routing_family"] == "meta_inventory"
    assert payload["intent"] == "meta_inventory_explain"
    assert any((e.get("path") or "").lower() == str(row[1]).lower() for e in payload.get("evidence", []))


def test_ask_explain_record_type_on_opportunity_has_no_flow_evidence() -> None:
    db_path = _ensure_index()
    conn = sqlite3.connect(db_path)
    row = conn.execute(
        """
        SELECT replace(replace(path, 'force-app/main/default/objects/Opportunity/recordTypes/', ''), '.recordType-meta.xml', '') AS name, path
        FROM meta_files
        WHERE lower(path) LIKE '%/objects/opportunity/recordtypes/%.recordtype-meta.xml'
        ORDER BY path
        LIMIT 1
        """
    ).fetchone()
    conn.close()
    if not row:
        return

    out_file = PROJECT_ROOT / "data" / "ask_recordtype_explain_no_flows.json"
    res = _run("ask", "--question", f"Explain record type Opportunity.{row[0]}", "--json-out", str(out_file))
    assert res.returncode == 0, res.stderr
    payload = json.loads(out_file.read_text(encoding="utf-8"))
    assert payload["routing_family"] == "meta_inventory"
    assert payload["intent"] == "meta_inventory_explain"
    assert any((e.get("path") or "").lower() == str(row[1]).lower() for e in payload.get("evidence", []))
    assert not any("/flows/" in str((e.get("path") or "")).lower() for e in payload.get("evidence", []))


def test_ask_where_used_includes_apex_references_when_available() -> None:
    db_path = _ensure_index()
    conn = sqlite3.connect(db_path)
    row = conn.execute(
        """
        SELECT ref_key
        FROM "references"
        WHERE ref_type='FIELD'
          AND ref_key LIKE '%.%__c'
        GROUP BY ref_key
        HAVING SUM(CASE WHEN src_type='APEX' AND lower(src_path) LIKE '%/classes/%' THEN 1 ELSE 0 END) > 0
           AND COUNT(DISTINCT src_type) >= 2
        ORDER BY COUNT(*) DESC
        LIMIT 1
        """
    ).fetchone()
    conn.close()
    if not row or not row[0]:
        return

    token = row[0]
    out_file = PROJECT_ROOT / "data" / "ask_where_used_full_refs.json"
    res = _run("ask", "--question", f"where is this field used {token}", "--json-out", str(out_file))
    assert res.returncode == 0, res.stderr
    payload = json.loads(out_file.read_text(encoding="utf-8"))
    assert payload["intent"] == "where_used_any"
    assert payload.get("count", 0) > 0
    # Ensure merged evidence contains at least one Apex path when deterministic references have Apex hits.
    assert any("/classes/" in str((e.get("path") or "")).lower() for e in payload.get("evidence", []))
