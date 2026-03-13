from __future__ import annotations

import argparse
import json
import re
from functools import lru_cache
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


@lru_cache(maxsize=4)
def _load_docs_cached(path_str: str, mtime_ns: int) -> List[MetadataDoc]:
    docs_path = Path(path_str)
    docs: List[MetadataDoc] = []
    with docs_path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            docs.append(MetadataDoc.model_validate_json(line))
    return docs


def _load_docs(docs_path: Path) -> List[MetadataDoc]:
    docs_path = Path(docs_path)
    stat = docs_path.stat()
    return _load_docs_cached(str(docs_path.resolve()), int(stat.st_mtime_ns))


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
    client = _get_client(persist_dir)
    collection = _get_collection(client)

    ids = [d.doc_id for d in docs_list]
    documents = [d.text for d in docs_list]
    metadatas = [{"kind": d.kind, "name": d.name, "path": d.path} for d in docs_list]

    collection.upsert(ids=ids, documents=documents, metadatas=metadatas)
    return len(docs_list)


def _vector_search(query: str, k: int, persist_dir: Path) -> List[MetadataDoc]:
    client = _get_client(persist_dir)
    collection = _get_collection(client)
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
    """Lexical scorer with light kind-aware weighting to reduce noisy matches."""
    q_tokens = re.findall(r"[A-Za-z0-9_.$]+", query.lower())
    if not q_tokens:
        return []
    q_set = set(q_tokens)
    scored: List[Tuple[MetadataDoc, float]] = []
    for d in docs:
        name_l = d.name.lower()
        path_l = d.path.lower()
        text_l = d.text.lower()
        score = 0.0
        for t in q_set:
            # Prioritize precise matches in name/path over broad text matches.
            if t in name_l:
                score += 3.0
            if t in path_l:
                score += 2.0
            if t in text_l:
                score += 0.25

        # Penalize broad security docs that often match many unrelated tokens.
        if d.kind in {"Profile", "PermSet"}:
            score *= 0.35

        # Boost likely intent-specific kinds.
        if any(t.startswith("approv") for t in q_set) and d.kind == "ApprovalProcess":
            score *= 2.0
        if "flow" in q_set and d.kind == "Flow":
            score *= 1.3
        if ("trigger" in q_set or "triggers" in q_set) and d.kind == "ApexTrigger":
            score *= 1.3
        if ("class" in q_set or "classes" in q_set) and d.kind == "ApexClass":
            score *= 1.2
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
    lexical_weight: float = 0.7,
    vector_weight: float = 1.0,
) -> List[MetadataDoc]:
    """
    Search over metadata.
    - If hybrid=False: vector only.
    - If hybrid=True: blend vector results with a simple lexical scorer over docs.jsonl.
    """
    if not hybrid:
        return _vector_search(query, k, persist_dir)

    # Retrieve deeper candidate sets and fuse by rank to avoid score-scale skew.
    vec_k = max(k * 3, 16)
    lex_k = max(k * 8, 64)
    vec_hits = _vector_search(query, vec_k, persist_dir)

    docs = _load_docs(docs_path)
    lex_hits = _lexical_scores(query, docs, lex_k)

    merged: Dict[str, Dict[str, Any]] = {}
    for hit in vec_hits:
        merged[hit.doc_id] = {"doc": hit, "score": 0.0}
    for d, _ in lex_hits:
        if d.doc_id in merged:
            continue
        else:
            merged[d.doc_id] = {"doc": d, "score": 0.0}

    # Reciprocal rank fusion (RRF)
    rrf_k = 60.0
    vec_rank = {d.doc_id: idx + 1 for idx, d in enumerate(vec_hits)}
    lex_rank = {d.doc_id: idx + 1 for idx, (d, _) in enumerate(lex_hits)}
    for doc_id, item in merged.items():
        score = 0.0
        vr = vec_rank.get(doc_id)
        lr = lex_rank.get(doc_id)
        if vr is not None:
            score += vector_weight * (1.0 / (rrf_k + vr))
        if lr is not None:
            score += lexical_weight * (1.0 / (rrf_k + lr))
        item["score"] = score

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
