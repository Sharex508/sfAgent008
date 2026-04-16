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


def _ensure_index_and_graph() -> Path:
    db_path = PROJECT_ROOT / "data" / "index.sqlite"
    needs_index = True
    needs_graph = True
    if db_path.exists():
        conn = sqlite3.connect(db_path)
        try:
            obj_count = conn.execute("SELECT COUNT(*) FROM objects").fetchone()[0]
            graph_count = conn.execute("SELECT COUNT(*) FROM graph_nodes").fetchone()[0]
            needs_index = obj_count <= 0
            needs_graph = graph_count <= 0
        except Exception:
            pass
        finally:
            conn.close()

    if needs_index:
        res = _run("index", "--repo", str(_repo_root()))
        assert res.returncode == 0, res.stderr
    if needs_graph:
        res = _run("graph-build", "--repo", str(_repo_root()))
        assert res.returncode == 0, res.stderr
    return db_path


def test_evidence_object_and_paths_exist() -> None:
    db_path = _ensure_index_and_graph()
    conn = sqlite3.connect(db_path)
    row = conn.execute(
        """
        SELECT o.object_name
        FROM objects o
        WHERE EXISTS (
          SELECT 1
          FROM "references" r
          WHERE (r.ref_type='OBJECT' AND lower(r.ref_key)=lower(o.object_name))
             OR (r.ref_type='FIELD' AND lower(r.ref_key) LIKE lower(o.object_name || '.%'))
        )
        ORDER BY o.object_name
        LIMIT 1
        """
    ).fetchone()
    conn.close()
    assert row is not None
    obj = row[0]

    out_file = PROJECT_ROOT / "data" / "evidence_object.json"
    res = _run("evidence", "--target", obj, "--depth", "2", "--top", "20", "--json-out", str(out_file))
    assert res.returncode == 0, res.stderr
    payload = json.loads(out_file.read_text(encoding="utf-8"))
    assert payload["target"]["type"] == "OBJECT"
    assert payload["target"]["found"] is True
    assert payload["summary_counts"]
    assert len(payload.get("evidence_paths") or []) > 0

    conn = sqlite3.connect(db_path)
    valid_paths = {r[0] for r in conn.execute("SELECT path FROM meta_files").fetchall()}
    conn.close()
    for p in payload.get("evidence_paths", []):
        assert p in valid_paths


def test_evidence_field_and_endpoint_safe_absent() -> None:
    db_path = _ensure_index_and_graph()
    conn = sqlite3.connect(db_path)
    row = conn.execute("SELECT full_name FROM fields ORDER BY full_name LIMIT 1").fetchone()
    conn.close()
    assert row is not None
    field = row[0]

    out_field = PROJECT_ROOT / "data" / "evidence_field.json"
    res_field = _run("evidence", "--target", field, "--json-out", str(out_field))
    assert res_field.returncode == 0, res_field.stderr
    payload_field = json.loads(out_field.read_text(encoding="utf-8"))
    assert payload_field["target"]["type"] == "FIELD"

    out_ep = PROJECT_ROOT / "data" / "evidence_endpoint_absent.json"
    res_ep = _run("evidence", "--target", "callout:DefinitelyMissingEndpoint123", "--json-out", str(out_ep))
    assert res_ep.returncode == 0, res_ep.stderr
    payload_ep = json.loads(out_ep.read_text(encoding="utf-8"))
    assert payload_ep["target"]["type"] == "ENDPOINT"
    # Safe "not found" means no crashes and no evidence rows when endpoint is absent.
    assert payload_ep["summary_counts"]["refs"] == 0


def test_evidence_cache_hit() -> None:
    _ensure_index_and_graph()
    out_file = PROJECT_ROOT / "data" / "evidence_cache_test.json"
    _run("evidence", "--target", "Account", "--depth", "2", "--top", "20", "--json-out", str(out_file))
    res = _run("evidence", "--target", "Account", "--depth", "2", "--top", "20", "--json-out", str(out_file))
    assert res.returncode == 0, res.stderr
    payload = json.loads(out_file.read_text(encoding="utf-8"))
    assert payload.get("cache_hit") is True

