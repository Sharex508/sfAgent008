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
            counts = conn.execute(
                "SELECT (SELECT COUNT(*) FROM fields), (SELECT COUNT(*) FROM flows), (SELECT COUNT(*) FROM components)"
            ).fetchone()
            if counts and counts[0] > 0 and counts[1] > 0 and counts[2] > 0:
                return
        except Exception:
            pass
        finally:
            conn.close()

    res = _run("index", "--repo", str(_repo_root()))
    assert res.returncode == 0, res.stderr


def test_graph_build_and_edges() -> None:
    _ensure_index()

    res = _run("graph-build", "--repo", str(_repo_root()))
    assert res.returncode == 0, res.stderr

    db_path = PROJECT_ROOT / "data" / "index.sqlite"
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    node_count = cur.execute("SELECT COUNT(*) FROM graph_nodes").fetchone()[0]
    edge_count = cur.execute("SELECT COUNT(*) FROM graph_edges").fetchone()[0]
    assert node_count > 0
    assert edge_count > 0

    flow_field_writes = cur.execute("SELECT COUNT(*) FROM flow_field_writes").fetchone()[0]
    if flow_field_writes > 0:
        flow_write_edges = cur.execute(
            "SELECT COUNT(*) FROM graph_edges WHERE edge_type='FLOW_WRITES_FIELD'"
        ).fetchone()[0]
        assert flow_write_edges > 0

    flow_true_writes = cur.execute("SELECT COUNT(*) FROM flow_true_writes").fetchone()[0]
    if flow_true_writes > 0:
        flow_write_edges_v2 = cur.execute(
            "SELECT COUNT(*) FROM graph_edges WHERE edge_type='FLOW_WRITES_FIELD'"
        ).fetchone()[0]
        flow_obj_edges_v2 = cur.execute(
            "SELECT COUNT(*) FROM graph_edges WHERE edge_type='FLOW_UPDATES_OBJECT'"
        ).fetchone()[0]
        assert flow_write_edges_v2 > 0 or flow_obj_edges_v2 > 0

    apex_endpoints = cur.execute("SELECT COUNT(*) FROM apex_endpoints").fetchone()[0]
    if apex_endpoints > 0:
        endpoint_edges = cur.execute(
            "SELECT COUNT(*) FROM graph_edges WHERE edge_type='CLASS_CALLS_ENDPOINT'"
        ).fetchone()[0]
        assert endpoint_edges > 0

    apex_rw = cur.execute("SELECT COUNT(*) FROM apex_rw").fetchone()[0]
    if apex_rw > 0:
        rw_edges = cur.execute(
            "SELECT COUNT(*) FROM graph_edges WHERE edge_type IN ('CLASS_READS_FIELD','CLASS_WRITES_FIELD','CLASS_QUERIES_OBJECT')"
        ).fetchone()[0]
        assert rw_edges > 0

    conn.close()


def test_deps_and_impact_do_not_crash() -> None:
    _ensure_index()
    _run("graph-build", "--repo", str(_repo_root()))

    flow_name = ""
    class_name = ""

    db_path = PROJECT_ROOT / "data" / "index.sqlite"
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    row_flow = cur.execute("SELECT flow_name FROM flows ORDER BY flow_name LIMIT 1").fetchone()
    row_cls = cur.execute("SELECT name FROM components WHERE type='APEX' ORDER BY name LIMIT 1").fetchone()
    if row_flow:
        flow_name = row_flow[0]
    if row_cls:
        class_name = row_cls[0]
    conn.close()

    if flow_name:
        deps_flow = _run("deps", "--flow", flow_name)
        assert deps_flow.returncode == 0

    if class_name:
        deps_class = _run("deps", "--class", class_name)
        assert deps_class.returncode == 0

    impact = _run("impact", "--target", "Account.Name")
    assert impact.returncode == 0
    assert ("Resolved intent:" in impact.stdout) or ("Not found in repo index" in impact.stdout)


def test_selftest_graph() -> None:
    res = _run("selftest-graph", "--repo", str(_repo_root()))
    assert res.returncode == 0, res.stderr
    assert "selftest_graph passed" in res.stdout
