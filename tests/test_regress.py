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


def test_regress_command_pass_and_json(tmp_path: Path) -> None:
    db_path = _ensure_index()
    conn = sqlite3.connect(db_path)
    row = conn.execute("SELECT object_name FROM objects ORDER BY object_name LIMIT 1").fetchone()
    conn.close()
    assert row
    obj = row[0]

    cfg = tmp_path / "regression_questions.yaml"
    cfg.write_text(
        f"""
tests:
  - name: flows on object
    question: "How many flows on {obj}?"
    expect:
      intent: "count_type_on_object"
      entity_object: "{obj}"
      min_count: 0
""".strip()
        + "\n",
        encoding="utf-8",
    )

    out_json = PROJECT_ROOT / "data" / "regress_report_test.json"
    res = _run("regress", "--file", str(cfg), "--json-out", str(out_json))
    assert res.returncode == 0, res.stderr
    report = json.loads(out_json.read_text(encoding="utf-8"))
    assert report["total"] == 1
    assert report["failed"] == 0


def test_regress_command_fail_exit_code(tmp_path: Path) -> None:
    _ensure_index()
    cfg = tmp_path / "regression_fail.yaml"
    cfg.write_text(
        """
tests:
  - name: wrong expectation
    question: "How many flows on Account?"
    expect:
      intent: "list_type"
      allow_not_found: true
""".strip()
        + "\n",
        encoding="utf-8",
    )

    res = _run("regress", "--file", str(cfg))
    assert res.returncode == 2
    assert "failed=1" in res.stdout
