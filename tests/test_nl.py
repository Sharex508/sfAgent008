from __future__ import annotations

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


def _ensure_index() -> None:
    db_path = PROJECT_ROOT / "data" / "index.sqlite"
    if db_path.exists():
        conn = sqlite3.connect(db_path)
        try:
            cnt = conn.execute("SELECT COUNT(*) FROM fields").fetchone()[0]
            if cnt > 0:
                return
        except Exception:
            pass
        finally:
            conn.close()

    repo = _repo_root()
    res = _run("index", "--repo", str(repo))
    assert res.returncode == 0, res.stderr


def test_nl_command_paths() -> None:
    _ensure_index()

    questions = [
        "where account name is used",
        "which flows update opportunity stage",
        "show validation rules on case that block status changes",
        "what apex calls callout:",
        "how many approval processes are active on quote",
    ]

    for q in questions:
        res = _run("nl", "--question", q)
        assert res.returncode == 0, res.stderr
        out = res.stdout
        assert "Resolved intent:" in out
        assert "Resolved entities:" in out
        assert "Confidence:" in out


def test_natural_language_in_existing_commands() -> None:
    _ensure_index()

    where_used = _run("where-used", "--field", "account name")
    assert where_used.returncode == 0
    assert "Resolved intent:" in where_used.stdout or "Not found in repo index" in where_used.stdout or where_used.stdout.strip() != ""

    flow_update = _run("flows-update", "--field", "opportunity stage")
    assert flow_update.returncode == 0

    vr = _run("validation-rules", "--object", "case", "--contains", "status")
    assert vr.returncode == 0


def test_impact_and_selftest_nl() -> None:
    _ensure_index()

    impact_field = _run("impact", "--target", "account name")
    assert impact_field.returncode == 0
    assert "Resolved intent:" in impact_field.stdout

    impact_obj = _run("impact", "--target", "Account")
    assert impact_obj.returncode == 0
    assert "Resolved intent:" in impact_obj.stdout

    selftest_nl = _run("selftest-nl", "--repo", str(_repo_root()))
    assert selftest_nl.returncode == 0, selftest_nl.stderr
    assert "selftest_nl passed" in selftest_nl.stdout
