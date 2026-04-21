from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import Any, Iterable, List, Optional, Tuple

from metadata.indexer import index_repo, write_jsonl
from metadata.metadata_types import MetadataDoc
from retrieval.vector_store import index_metadata, search_metadata
from repo_inventory import build_metadata_inventory, write_metadata_inventory
from repo_runtime import METADATA_INVENTORY_PATH, ROOT, resolve_active_repo
from sf_repo_ai.config import AppConfig
from sf_repo_ai.db import connect as connect_sqlite, init_schema
from sf_repo_ai.graph import build_dependency_graph
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


def _sqlite_table_count(conn: sqlite3.Connection, table: str) -> int:
    return int(conn.execute(f"SELECT COUNT(*) AS c FROM {table}").fetchone()["c"])


def _docs_count(docs_path: Path) -> int:
    if not docs_path.exists():
        return 0
    with docs_path.open("r", encoding="utf-8") as handle:
        return sum(1 for line in handle if line.strip())


def ensure_runtime_indexes(
    *,
    repo_path: Optional[Path] = None,
    docs_path: Path = DOCS_PATH,
    db_path: Path = DB_PATH,
    sqlite_path: Path = SQLITE_PATH,
    rebuild: bool = False,
) -> dict[str, Any]:
    """Ensure JSONL/vector indexes plus deterministic SQLite and graph indexes exist."""
    repo_path = Path(repo_path).resolve() if repo_path else resolve_active_repo()
    docs_path, db_path = ensure_indexes(
        repo_path=repo_path,
        docs_path=docs_path,
        db_path=db_path,
        rebuild=rebuild,
    )

    cfg = AppConfig(repo_root=str(repo_path), sqlite_path=str(sqlite_path))
    conn = connect_sqlite(sqlite_path)
    init_schema(conn)
    try:
        meta_files = _sqlite_table_count(conn, "meta_files")
        graph_nodes = _sqlite_table_count(conn, "graph_nodes")
        graph_edges = _sqlite_table_count(conn, "graph_edges")
    finally:
        conn.close()

    if rebuild or meta_files == 0:
        index_repository(cfg, project_root=ROOT, rebuild_rag=False)
        conn = connect_sqlite(sqlite_path)
        init_schema(conn)
        try:
            meta_files = _sqlite_table_count(conn, "meta_files")
            graph_nodes = _sqlite_table_count(conn, "graph_nodes")
            graph_edges = _sqlite_table_count(conn, "graph_edges")
        finally:
            conn.close()

    if rebuild or graph_nodes == 0 or graph_edges == 0:
        conn = connect_sqlite(sqlite_path)
        init_schema(conn)
        try:
            build_dependency_graph(conn, repo_root=repo_path, sfdx_root=cfg.sfdx_root)
            graph_nodes = _sqlite_table_count(conn, "graph_nodes")
            graph_edges = _sqlite_table_count(conn, "graph_edges")
        finally:
            conn.close()

    return {
        "docs_path": docs_path,
        "db_path": db_path,
        "sqlite_path": sqlite_path,
        "docs_count": _docs_count(docs_path),
        "meta_files": meta_files,
        "graph_nodes": graph_nodes,
        "graph_edges": graph_edges,
    }


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
