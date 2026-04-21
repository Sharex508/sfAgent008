from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import Any, Iterable, List, Optional, Tuple

from metadata.indexer import index_repo, write_jsonl
from metadata.metadata_types import MetadataDoc
from retrieval.vector_store import index_metadata, search_metadata
from repo_inventory import build_metadata_inventory, write_metadata_inventory
from repo_runtime import METADATA_INVENTORY_PATH, resolve_active_repo
from sf_repo_ai.config import load_config
from sf_repo_ai.db import connect, init_schema
from sf_repo_ai.graph import GraphBuildStats, build_dependency_graph
from sf_repo_ai.repo_scan import index_repository

DOCS_PATH = Path(__file__).resolve().parent / "data" / "metadata" / "docs.jsonl"
DB_PATH = Path(__file__).resolve().parent / "data" / "chroma"
SQLITE_PATH = Path(__file__).resolve().parent / "data" / "index.sqlite"


def ensure_indexes(
    *,
    repo_path: Optional[Path] = None,
    docs_path: Path = DOCS_PATH,
    db_path: Path = DB_PATH,
    rebuild: bool = False,
) -> Tuple[Path, Path]:
    """Ensure docs.jsonl and vector DB exist, rebuilding if requested."""
    repo_path = Path(repo_path).resolve() if repo_path else resolve_active_repo()
    if rebuild or not docs_path.exists():
        docs = index_repo(repo_path)
        write_jsonl(docs, docs_path)
    inventory = build_metadata_inventory(repo_path)
    write_metadata_inventory(inventory, METADATA_INVENTORY_PATH)
    if rebuild or not (db_path.exists() and any(db_path.iterdir())):
        index_metadata(docs_path=docs_path, persist_dir=db_path)
    return docs_path, db_path


def _count_jsonl_lines(path: Path) -> int:
    if not path.exists():
        return 0
    with path.open("r", encoding="utf-8") as handle:
        return sum(1 for line in handle if line.strip())


def _count_rows(conn: sqlite3.Connection, table: str) -> int:
    row = conn.execute(f"SELECT COUNT(*) AS c FROM {table}").fetchone()
    return int(row["c"]) if row else 0


def _graph_counts(stats: GraphBuildStats) -> dict[str, int]:
    return {
        "graph_nodes": int(stats.nodes),
        "graph_edges": int(stats.edges),
    }


def ensure_runtime_indexes(
    *,
    repo_path: Optional[Path] = None,
    project_root: Optional[Path] = None,
    docs_path: Path = DOCS_PATH,
    db_path: Path = DB_PATH,
    sqlite_path: Path = SQLITE_PATH,
    rebuild: bool = False,
    rebuild_rag: bool = False,
) -> dict[str, Any]:
    """Ensure docs, Chroma, SQLite metadata index, and dependency graph exist."""
    project_root = Path(project_root).resolve() if project_root else Path(__file__).resolve().parent
    repo_path = Path(repo_path).resolve() if repo_path else resolve_active_repo()

    docs_path, db_path = ensure_indexes(
        repo_path=repo_path,
        docs_path=docs_path,
        db_path=db_path,
        rebuild=rebuild,
    )

    cfg = load_config(project_root=project_root)
    cfg.repo_root = str(repo_path)
    cfg.sqlite_path = str(sqlite_path)
    index_repository(cfg, project_root=project_root, rebuild_rag=rebuild_rag)

    conn = connect(sqlite_path)
    init_schema(conn)
    graph_stats = build_dependency_graph(conn, repo_root=repo_path, sfdx_root=cfg.sfdx_root)
    meta_files = _count_rows(conn, "meta_files")
    counts = {
        "docs_path": str(docs_path),
        "db_path": str(db_path),
        "sqlite_path": str(sqlite_path),
        "docs_count": _count_jsonl_lines(docs_path),
        "meta_files": meta_files,
        **_graph_counts(graph_stats),
    }
    conn.close()
    return counts


def retrieve_docs(
    query: str,
    *,
    k: int = 8,
    hybrid: bool = True,
    docs_path: Path = DOCS_PATH,
    db_path: Path = DB_PATH,
) -> List[MetadataDoc]:
    """Retrieve docs using vector search (optionally hybrid)."""
    return search_metadata(
        query,
        k=k,
        persist_dir=db_path,
        hybrid=hybrid,
        docs_path=docs_path,
    )


def build_context(docs: Iterable[MetadataDoc], max_lines: int) -> List[str]:
    """Format retrieved docs into a line-limited context block."""
    lines: List[str] = []
    for d in docs:
        header = f"[{d.kind}] {d.name} :: {d.path}"
        lines.append(header)
        for line in (d.text or "").splitlines():
            lines.append(line.rstrip())
            if len(lines) >= max_lines:
                return lines
        lines.append("---")
        if len(lines) >= max_lines:
            return lines
    return lines
