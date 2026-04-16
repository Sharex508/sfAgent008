from __future__ import annotations

from pathlib import Path

from sf_repo_ai.rag.chroma_store import query_store


def retrieve_evidence(
    *,
    chroma_dir: Path,
    ollama_base_url: str,
    embed_model: str,
    question: str,
    top_k: int,
) -> list[dict]:
    return query_store(
        chroma_dir=chroma_dir,
        ollama_base_url=ollama_base_url,
        embed_model=embed_model,
        question=question,
        top_k=top_k,
    )
