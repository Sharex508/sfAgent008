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


def test_index_build_and_counts() -> None:
    repo = _repo_root()
    if not repo.exists():
        raise AssertionError(f"Repo not found for test: {repo}")

    res = _run("index", "--repo", str(repo))
    assert res.returncode == 0, res.stderr

    db_path = PROJECT_ROOT / "data" / "index.sqlite"
    assert db_path.exists()

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    counts = {
        "objects": cur.execute("SELECT COUNT(*) FROM objects").fetchone()[0],
        "fields": cur.execute("SELECT COUNT(*) FROM fields").fetchone()[0],
        "flows": cur.execute("SELECT COUNT(*) FROM flows").fetchone()[0],
        "references": cur.execute("SELECT COUNT(*) FROM \"references\"").fetchone()[0],
        "meta_files": cur.execute("SELECT COUNT(*) FROM meta_files").fetchone()[0],
        "meta_refs": cur.execute("SELECT COUNT(*) FROM meta_refs").fetchone()[0],
    }
    conn.close()

    assert counts["objects"] > 0
    assert counts["fields"] > 0
    assert counts["flows"] > 0
    assert counts["references"] > 0
    assert counts["meta_files"] > 0
    assert counts["meta_refs"] > 0


def test_required_commands() -> None:
    where_used = _run("where-used", "--field", "Account.Name")
    assert where_used.returncode == 0
    assert where_used.stdout.strip() != ""

    flow_update = _run("flows-update", "--field", "Opportunity.StageName")
    assert flow_update.returncode == 0

    endpoint = _run("endpoint-callers", "--endpoint", "callout:")
    assert endpoint.returncode == 0

    explain = _run("explain-object", "--object", "Account")
    assert explain.returncode == 0
    out = explain.stdout
    assert "Field count:" in out
    assert "Top 20 fields:" in out
    assert "Number of references found:" in out

    count_meta = _run("count-meta", "--folder", "approvalProcesses")
    assert count_meta.returncode == 0
    assert count_meta.stdout.strip() != ""

    list_meta = _run("list-meta", "--folder", "approvalProcesses")
    assert list_meta.returncode == 0

    where_any = _run("where-used-any", "--token", "Quote")
    assert where_any.returncode == 0

    approval = _run("approval-processes", "--object", "Quote", "--active-only")
    assert approval.returncode == 0

    debug_approval = _run("debug-approval", "--object", "Case")
    assert debug_approval.returncode == 0
    assert "approval_processes rows for" in debug_approval.stdout

    coverage = _run("coverage", "--out", "data/coverage.json")
    assert coverage.returncode == 0
    coverage_path = PROJECT_ROOT / "data" / "coverage.json"
    payload = json.loads(coverage_path.read_text(encoding="utf-8"))
    assert "folder_coverage" in payload
    assert "unknowns" in payload

    org_summary = _run("org-summary", "--out", "data/org_summary.md")
    assert org_summary.returncode == 0
    org_summary_path = PROJECT_ROOT / "data" / "org_summary.md"
    assert org_summary_path.exists()
    text = org_summary_path.read_text(encoding="utf-8")
    assert "Org Summary" in text

    universal_count = _run("count", "--type", "ApprovalProcess", "--filter", "active=true", "--filter", "object=Quote")
    assert universal_count.returncode == 0

    universal_list = _run("list", "--type", "SharingRule", "--filter", "object=Case")
    assert universal_list.returncode == 0


def test_techdebt_json() -> None:
    out_file = PROJECT_ROOT / "data" / "tech_debt.json"
    res = _run("techdebt", "--out", str(out_file))
    assert res.returncode == 0, res.stderr
    payload = json.loads(out_file.read_text(encoding="utf-8"))
    assert set(payload.keys()) == {"apex", "flows", "security"}


def test_regress_command_smoke(tmp_path: Path) -> None:
    repo = _repo_root()
    if not repo.exists():
        raise AssertionError(f"Repo not found for test: {repo}")

    _run("index", "--repo", str(repo))
    db_path = PROJECT_ROOT / "data" / "index.sqlite"
    conn = sqlite3.connect(db_path)
    obj_row = conn.execute("SELECT object_name FROM objects ORDER BY object_name LIMIT 1").fetchone()
    conn.close()
    assert obj_row
    obj = obj_row[0]

    cfg = tmp_path / "regression_questions.yaml"
    cfg.write_text(
        f"""
tests:
  - name: basic
    question: "How many flows on {obj}?"
    expect:
      intent: "count_type_on_object"
      entity_object: "{obj}"
      min_count: 0
""".strip()
        + "\n",
        encoding="utf-8",
    )
    out = PROJECT_ROOT / "data" / "regress_smoke.json"
    res = _run("regress", "--file", str(cfg), "--json-out", str(out))
    assert res.returncode == 0, res.stderr
    payload = json.loads(out.read_text(encoding="utf-8"))
    assert payload["failed"] == 0
