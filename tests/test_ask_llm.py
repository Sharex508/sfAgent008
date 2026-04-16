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


def test_ask_no_llm_fields_present_and_disabled() -> None:
    _ensure_index()
    out = PROJECT_ROOT / "data" / "_ask_llm_disabled.json"
    res = _run(
        "ask",
        "--question",
        "explain flow Add_to_stock_button_flow",
        "--no-llm",
        "--json-out",
        str(out),
    )
    assert res.returncode == 0, res.stderr
    payload = json.loads(out.read_text(encoding="utf-8"))
    assert payload.get("llm_used") is False
    assert payload.get("llm_calls") == 0
    assert payload.get("llm_mode") == "disabled"
    assert payload.get("llm_mode_requested") == "disabled"
    assert payload.get("llm_mode_used") == "disabled"
    assert isinstance(payload.get("deterministic_answer_lines"), list)
    assert payload.get("answer_lines") == payload.get("deterministic_answer_lines")
    assert payload.get("ollama_error") in {None, ""}


def test_ask_llm_unavailable_falls_back_with_error() -> None:
    _ensure_index()
    out = PROJECT_ROOT / "data" / "_ask_llm_unavailable.json"
    res = _run(
        "ask",
        "--question",
        "explain flow Add_to_stock_button_flow",
        "--llm",
        "--ollama-url",
        "http://127.0.0.1:1",
        "--llm-max-chars",
        "5000",
        "--json-out",
        str(out),
    )
    assert res.returncode == 0, res.stderr
    payload = json.loads(out.read_text(encoding="utf-8"))
    assert payload.get("llm_used") is False
    assert payload.get("llm_calls") == 1
    assert payload.get("ollama_error")
    assert payload.get("llm_mode_requested") == "narrate_only"
    assert payload.get("llm_mode_used") in {"narrate_only", "rag_snippets_fallback"}
    assert isinstance(payload.get("deterministic_answer_lines"), list)
    stats = payload.get("evidence_pack_stats") or {}
    assert int(stats.get("total_chars", 0)) <= 5000


def test_ask_llm_planner_mode_fallback_when_unavailable() -> None:
    _ensure_index()
    out = PROJECT_ROOT / "data" / "_ask_llm_planner_unavailable.json"
    res = _run(
        "ask",
        "--question",
        "what calls apex class SyncACRBatchCallout",
        "--llm",
        "--llm-mode",
        "planner_then_narrate",
        "--ollama-url",
        "http://127.0.0.1:1",
        "--json-out",
        str(out),
    )
    assert res.returncode == 0, res.stderr
    payload = json.loads(out.read_text(encoding="utf-8"))
    assert payload.get("llm_used") is False
    assert payload.get("llm_mode_requested") == "planner_then_narrate"
    assert payload.get("llm_mode_used") in {"planner_then_narrate", "narrate_only"}
    assert isinstance(payload.get("deterministic_answer_lines"), list)


def test_ask_llm_full_primary_falls_back_for_non_explain() -> None:
    _ensure_index()
    out = PROJECT_ROOT / "data" / "_ask_llm_full_primary_non_explain.json"
    res = _run(
        "ask",
        "--question",
        "which flows write Opportunity.StageName",
        "--llm",
        "--llm-mode",
        "full_primary",
        "--ollama-url",
        "http://127.0.0.1:1",
        "--json-out",
        str(out),
    )
    assert res.returncode == 0, res.stderr
    payload = json.loads(out.read_text(encoding="utf-8"))
    assert payload.get("llm_mode_requested") == "full_primary"
    assert payload.get("llm_mode_used") in {"narrate_only", "rag_snippets_fallback"}
