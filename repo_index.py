from __future__ import annotations

from pathlib import Path
from typing import Iterable, List, Optional, Tuple

from metadata.indexer import index_repo, write_jsonl
from metadata.metadata_types import MetadataDoc
from retrieval.vector_store import index_metadata, search_metadata
from repo_inventory import build_metadata_inventory, write_metadata_inventory
from repo_runtime import METADATA_INVENTORY_PATH, resolve_active_repo

DOCS_PATH = Path(__file__).resolve().parent / "data" / "metadata" / "docs.jsonl"
DB_PATH = Path(__file__).resolve().parent / "data" / "chroma"


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
