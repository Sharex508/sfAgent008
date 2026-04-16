from __future__ import annotations

import hashlib
import sqlite3
from pathlib import Path

try:
    import chromadb
except Exception:  # pragma: no cover - optional dependency handling
    chromadb = None

from sf_repo_ai.rag.embed_ollama import embed_texts
from sf_repo_ai.util import read_text

COLLECTION_NAME = "sf_repo_ai"


def _client(chroma_dir: Path) -> chromadb.PersistentClient:
    if chromadb is None:
        raise RuntimeError("chromadb is not installed")
    chroma_dir.mkdir(parents=True, exist_ok=True)
    return chromadb.PersistentClient(path=str(chroma_dir))


def _chunk_id(path: str, idx: int) -> str:
    return hashlib.sha1(f"{path}:{idx}".encode("utf-8")).hexdigest()


def build_chunks_from_index(conn: sqlite3.Connection, repo_root: Path) -> list[dict]:
    chunks: list[dict] = []

    # Objects summary chunks
    obj_rows = conn.execute("SELECT object_name, path FROM objects ORDER BY object_name").fetchall()
    for obj in obj_rows:
        field_rows = conn.execute(
            "SELECT field_api, data_type FROM fields WHERE object_name = ? ORDER BY field_api LIMIT 200",
            (obj["object_name"],),
        ).fetchall()
        field_text = ", ".join(f"{r['field_api']}({r['data_type']})" for r in field_rows)
        text = f"Object {obj['object_name']}\nFields: {field_text}"
        chunks.append(
            {
                "id": _chunk_id(obj["path"], 0),
                "text": text,
                "metadata": {"path": obj["path"], "type": "OBJECT", "name": obj["object_name"]},
            }
        )

    # Flow summary chunks
    flow_rows = conn.execute("SELECT flow_name, status, trigger_object, trigger_type, path FROM flows").fetchall()
    for flow in flow_rows:
        writes = conn.execute(
            "SELECT full_field_name FROM flow_field_writes WHERE flow_name = ? ORDER BY confidence DESC LIMIT 50",
            (flow["flow_name"],),
        ).fetchall()
        reads = conn.execute(
            "SELECT full_field_name FROM flow_field_reads WHERE flow_name = ? ORDER BY confidence DESC LIMIT 50",
            (flow["flow_name"],),
        ).fetchall()
        text = (
            f"Flow {flow['flow_name']}\n"
            f"Status: {flow['status']}\n"
            f"Trigger Object: {flow['trigger_object']}\n"
            f"Trigger Type: {flow['trigger_type']}\n"
            f"Writes: {', '.join(r['full_field_name'] for r in writes)}\n"
            f"Reads: {', '.join(r['full_field_name'] for r in reads)}"
        )
        chunks.append(
            {
                "id": _chunk_id(flow["path"], 0),
                "text": text,
                "metadata": {"path": flow["path"], "type": "FLOW", "name": flow["flow_name"]},
            }
        )

    # Apex chunks
    apex_rows = conn.execute("SELECT name, path, type FROM components WHERE type IN ('APEX','TRIGGER')").fetchall()
    for row in apex_rows:
        full_path = repo_root / row["path"]
        text = read_text(full_path)
        if not text:
            continue
        lines = text.splitlines()
        if len(lines) > 2500:
            block_size = 300
            for i in range(0, len(lines), block_size):
                chunk_text = "\n".join(lines[i : i + block_size])
                idx = i // block_size
                chunks.append(
                    {
                        "id": _chunk_id(row["path"], idx),
                        "text": chunk_text,
                        "metadata": {
                            "path": row["path"],
                            "type": row["type"],
                            "name": row["name"],
                            "chunk": idx,
                        },
                    }
                )
        else:
            chunks.append(
                {
                    "id": _chunk_id(row["path"], 0),
                    "text": text,
                    "metadata": {"path": row["path"], "type": row["type"], "name": row["name"]},
                }
            )

    return chunks


def rebuild_store(
    *,
    conn: sqlite3.Connection,
    repo_root: Path,
    chroma_dir: Path,
    ollama_base_url: str,
    embed_model: str,
) -> int:
    chunks = build_chunks_from_index(conn, repo_root)
    client = _client(chroma_dir)

    try:
        client.delete_collection(COLLECTION_NAME)
    except Exception:
        pass

    col = client.get_or_create_collection(COLLECTION_NAME)
    if not chunks:
        return 0

    batch = 32
    for i in range(0, len(chunks), batch):
        items = chunks[i : i + batch]
        docs = [x["text"] for x in items]
        embs = embed_texts(ollama_base_url, embed_model, docs)
        col.upsert(
            ids=[x["id"] for x in items],
            documents=docs,
            metadatas=[x["metadata"] for x in items],
            embeddings=embs,
        )

    return len(chunks)


def query_store(
    *,
    chroma_dir: Path,
    ollama_base_url: str,
    embed_model: str,
    question: str,
    top_k: int,
) -> list[dict]:
    client = _client(chroma_dir)
    col = client.get_or_create_collection(COLLECTION_NAME)
    q_emb = embed_texts(ollama_base_url, embed_model, [question])[0]
    res = col.query(query_embeddings=[q_emb], n_results=top_k)

    out: list[dict] = []
    ids = res.get("ids", [[]])[0]
    docs = res.get("documents", [[]])[0]
    metas = res.get("metadatas", [[]])[0]
    dists = res.get("distances", [[]])[0]

    for i in range(len(ids)):
        out.append(
            {
                "id": ids[i],
                "document": docs[i] if i < len(docs) else "",
                "metadata": metas[i] if i < len(metas) else {},
                "distance": dists[i] if i < len(dists) else None,
            }
        )
    return out
