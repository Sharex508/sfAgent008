from __future__ import annotations

import os
import json
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
            cnt = conn.execute("SELECT COUNT(*) FROM meta_files").fetchone()[0]
            if cnt > 0:
                return db_path
        except Exception:
            pass
        finally:
            conn.close()
    res = _run("index", "--repo", str(_repo_root()))
    assert res.returncode == 0, res.stderr
    return db_path


def _assert_sections(out: str) -> None:
    for section in [
        "## What It Is",
        "## Where It Lives",
        "## What It Affects",
        "## Dependencies",
        "## Automation / UI / Security Impact",
        "## Risks / Tech Debt Signals",
        "## How To Test",
        "## Evidence",
    ]:
        assert section in out


def test_explain_command_flow_and_apex_and_lwc() -> None:
    db_path = _ensure_index()
    conn = sqlite3.connect(db_path)
    flow = conn.execute("SELECT flow_name FROM flows ORDER BY flow_name LIMIT 1").fetchone()
    apex = conn.execute("SELECT name FROM components WHERE type='APEX' ORDER BY name LIMIT 1").fetchone()
    lwc_path = conn.execute(
        "SELECT path FROM meta_files WHERE lower(folder)='lwc' AND path LIKE '%/lwc/%/%' ORDER BY path LIMIT 1"
    ).fetchone()
    conn.close()

    assert flow and apex and lwc_path
    lwc_bundle = Path(lwc_path[0]).parts[-2]

    r_flow = _run("explain", "--target", f"Flow:{flow[0]}", "--no-llm")
    assert r_flow.returncode == 0, r_flow.stderr
    _assert_sections(r_flow.stdout)

    r_apex = _run("explain", "--target", f"Class:{apex[0]}", "--no-llm")
    assert r_apex.returncode == 0, r_apex.stderr
    _assert_sections(r_apex.stdout)

    r_lwc = _run("explain", "--target", f"LWC:{lwc_bundle}", "--no-llm")
    assert r_lwc.returncode == 0, r_lwc.stderr
    _assert_sections(r_lwc.stdout)


def test_ask_explain_routes_to_universal_explain() -> None:
    _ensure_index()
    out_file = PROJECT_ROOT / "data" / "ask_explain_approval_router.json"
    res = _run(
        "ask",
        "--question",
        "explain approval process Case.CONTAINER_Service_Case_Approval_Process",
        "--json-out",
        str(out_file),
    )
    assert res.returncode == 0, res.stderr
    payload = json.loads(out_file.read_text(encoding="utf-8"))
    assert payload.get("routing_family") == "explain_component"
    assert payload.get("intent") == "explain_component"
    assert payload.get("handler") == "explain_component"
    assert any(
        "approvalProcesses/Case.CONTAINER_Service_Case_Approval_Process.approvalProcess-meta.xml"
        in str((e or {}).get("path") or "")
        for e in (payload.get("evidence") or [])
    )


def test_explain_non_existent_safe() -> None:
    _ensure_index()
    res = _run("explain", "--target", "Case.FAKE_PROCESS", "--no-llm")
    assert res.returncode == 0, res.stderr
    assert "Not found in repo evidence" in res.stdout or "Target not found in repo index" in res.stdout


def test_ask_explain_json_has_adapter_payload() -> None:
    db_path = _ensure_index()
    conn = sqlite3.connect(db_path)
    flow = conn.execute("SELECT flow_name FROM flows ORDER BY flow_name LIMIT 1").fetchone()
    conn.close()
    assert flow

    out_file = PROJECT_ROOT / "data" / "ask_explain_adapter.json"
    res = _run("ask", "--question", f"explain flow {flow[0]}", "--json-out", str(out_file))
    assert res.returncode == 0, res.stderr
    payload = json.loads(out_file.read_text(encoding="utf-8"))
    assert payload.get("routing_family") == "explain_component"
    assert payload.get("intent") == "explain_component"
    assert payload.get("handler") == "explain_component"
    assert isinstance(payload.get("answer_lines"), list)
    assert payload.get("count", 0) >= 0
