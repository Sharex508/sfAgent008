from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict, Iterable, List, Tuple

import chromadb
from chromadb.errors import NotFoundError
from chromadb.utils.embedding_functions import SentenceTransformerEmbeddingFunction

from metadata.metadata_types import MetadataDoc

DEFAULT_DOCS = Path("./data/metadata/docs.jsonl")
DEFAULT_DB = Path("./data/chroma")
COLLECTION_NAME = "metadata"
EMBED_MODEL = "all-MiniLM-L6-v2"


def _load_docs(docs_path: Path) -> List[MetadataDoc]:
    docs: List[MetadataDoc] = []
    if not docs_path.exists():
        return docs
    with docs_path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            docs.append(MetadataDoc.model_validate_json(line))
    return docs


def _get_client(persist_dir: Path | str):
    persist_dir = Path(persist_dir)
    persist_dir.mkdir(parents=True, exist_ok=True)
    return chromadb.PersistentClient(path=str(persist_dir))


def _get_collection(client) -> chromadb.Collection:
    embed_fn = SentenceTransformerEmbeddingFunction(model_name=EMBED_MODEL)
    try:
        return client.get_collection(COLLECTION_NAME, embedding_function=embed_fn)
    except NotFoundError:
        return client.create_collection(COLLECTION_NAME, embedding_function=embed_fn)


def index_metadata(
    docs: Iterable[MetadataDoc] | None = None,
    docs_path: Path = DEFAULT_DOCS,
    persist_dir: Path = DEFAULT_DB,
) -> int:
    """
    Upsert all docs into Chroma.
    Returns the number of documents indexed.
    """
    if docs is None:
        docs = _load_docs(docs_path)

    docs_list = list(docs)
    if not docs_list:
        persist_dir = Path(persist_dir)
        persist_dir.mkdir(parents=True, exist_ok=True)
        return 0
    client = _get_client(persist_dir)
    collection = _get_collection(client)

    ids = [d.doc_id for d in docs_list]
    documents = [d.text for d in docs_list]
    metadatas = [{"kind": d.kind, "name": d.name, "path": d.path} for d in docs_list]

    max_batch = 5000
    get_batch = getattr(getattr(collection, "_client", None), "get_max_batch_size", None)
    if callable(get_batch):
        try:
            max_batch = int(get_batch())
        except Exception:
            max_batch = 5000

    for start in range(0, len(docs_list), max_batch):
        end = start + max_batch
        collection.upsert(
            ids=ids[start:end],
            documents=documents[start:end],
            metadatas=metadatas[start:end],
        )
    return len(docs_list)


def _vector_search(query: str, k: int, persist_dir: Path) -> List[MetadataDoc]:
    persist_dir = Path(persist_dir)
    if not persist_dir.exists():
        return []
    client = _get_client(persist_dir)
    collection = _get_collection(client)
    if collection.count() == 0:
        return []
    res = collection.query(query_texts=[query], n_results=k)

    results: List[MetadataDoc] = []
    ids = res.get("ids", [[]])[0]
    docs = res.get("documents", [[]])[0]
    metadatas = res.get("metadatas", [[]])[0]

    for idx, doc_id in enumerate(ids):
        meta = metadatas[idx] if idx < len(metadatas) else {}
        text = docs[idx] if idx < len(docs) else ""
        results.append(
            MetadataDoc(
                doc_id=doc_id,
                kind=meta.get("kind", ""),
                name=meta.get("name", ""),
                path=meta.get("path", ""),
                text=text or "",
                raw_snippet=None,
            )
        )
    return results


def _lexical_scores(query: str, docs: List[MetadataDoc], k: int) -> List[Tuple[MetadataDoc, float]]:
    """Simple lexical scorer: count token matches in name/path/text."""
    q_tokens = [t for t in query.lower().split() if t]
    scored: List[Tuple[MetadataDoc, float]] = []
    for d in docs:
        haystacks = [d.name.lower(), d.path.lower(), d.text.lower()]
        score = 0.0
        for t in q_tokens:
            for h in haystacks:
                if t in h:
                    score += 1.0
        if score > 0:
            scored.append((d, score))
    scored.sort(key=lambda x: x[1], reverse=True)
    return scored[:k]


def search_metadata(
    query: str,
    k: int = 8,
    persist_dir: Path = DEFAULT_DB,
    hybrid: bool = False,
    docs_path: Path = DEFAULT_DOCS,
    lexical_weight: float = 1.0,
    vector_weight: float = 1.0,
) -> List[MetadataDoc]:
    """
    Search over metadata.
    - If hybrid=False: vector only.
    - If hybrid=True: blend vector results with a simple lexical scorer over docs.jsonl.
    """
    if not hybrid:
        return _vector_search(query, k, persist_dir)

    vec_hits = _vector_search(query, k, persist_dir)
    vec_scores = {hit.doc_id: vector_weight * (k - idx) for idx, hit in enumerate(vec_hits)}

    docs = _load_docs(docs_path)
    lex_hits = _lexical_scores(query, docs, k)
    lex_scores = {d.doc_id: lexical_weight * s for d, s in lex_hits}

    merged: Dict[str, Dict[str, Any]] = {}
    for hit in vec_hits:
        merged[hit.doc_id] = {"doc": hit, "score": vec_scores.get(hit.doc_id, 0)}
    for d, s in lex_hits:
        if d.doc_id in merged:
            merged[d.doc_id]["score"] += s
        else:
            merged[d.doc_id] = {"doc": d, "score": s}

    ranked = sorted(merged.values(), key=lambda x: x["score"], reverse=True)
    return [item["doc"] for item in ranked[:k]]


def main():
    ap = argparse.ArgumentParser(description="Build/search Chroma vector store for metadata docs")
    ap.add_argument("--docs", type=Path, default=DEFAULT_DOCS, help="Docs JSONL path (for indexing)")
    ap.add_argument("--db", type=Path, default=DEFAULT_DB, help="Chroma persistence directory")
    ap.add_argument("--query", type=str, help="Optional search query; if omitted, only index is built")
    ap.add_argument("--k", type=int, default=8, help="Number of results to return for search")
    ap.add_argument("--hybrid", action="store_true", help="Use hybrid (vector + lexical) search")
    args = ap.parse_args()

    count = index_metadata(docs_path=args.docs, persist_dir=args.db)

    output = {"indexed": count, "db": str(args.db)}

    if args.query:
        hits = search_metadata(args.query, k=args.k, persist_dir=args.db, hybrid=args.hybrid, docs_path=args.docs)
        output["query"] = args.query
        output["k"] = args.k
        output["hybrid"] = args.hybrid
        output["results"] = [
            {"doc_id": h.doc_id, "kind": h.kind, "name": h.name, "path": h.path} for h in hits
        ]

    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
