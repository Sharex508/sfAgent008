from __future__ import annotations

import json
import os
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


def _ensure_graph() -> None:
    idx = _run("index", "--repo", str(_repo_root()))
    assert idx.returncode == 0, idx.stderr
    graph = _run("graph-build", "--repo", str(_repo_root()))
    assert graph.returncode == 0, graph.stderr


def test_blast_radius_safe_output() -> None:
    _ensure_graph()

    out = PROJECT_ROOT / "data" / "blast_radius_test.json"
    res = _run("blast-radius", "--from", "HEAD~1", "--to", "HEAD", "--depth", "2", "--out", str(out))
    assert res.returncode == 0, res.stderr
    payload = json.loads(out.read_text(encoding="utf-8"))
    assert "changed" in payload
    assert "impacted" in payload
    assert "hotspots" in payload


def test_collisions_and_what_breaks() -> None:
    _ensure_graph()

    out_col = PROJECT_ROOT / "data" / "collisions_test.json"
    res_col = _run("collisions", "--field", "Opportunity.StageName", "--out", str(out_col))
    assert res_col.returncode == 0, res_col.stderr
    payload = json.loads(out_col.read_text(encoding="utf-8"))
    assert "scope" in payload
    assert "collisions" in payload

    res_wb = _run("what-breaks", "--target", "Opportunity.StageName", "--depth", "2")
    assert res_wb.returncode == 0, res_wb.stderr


def test_test_checklist_output() -> None:
    _ensure_graph()

    out_md = PROJECT_ROOT / "data" / "test_checklist_test.md"
    res = _run("test-checklist", "--target", "Opportunity.StageName", "--out", str(out_md))
    assert res.returncode == 0, res.stderr
    assert out_md.exists()
    text = out_md.read_text(encoding="utf-8")
    assert "# Test Checklist:" in text
