from __future__ import annotations

from typing import Iterable

import requests


def embed_texts(base_url: str, model: str, texts: Iterable[str], timeout: int = 120) -> list[list[float]]:
    vectors: list[list[float]] = []
    base = base_url.rstrip("/")
    for text in texts:
        payload = {"model": model, "input": text}
        try:
            resp = requests.post(f"{base}/api/embed", json=payload, timeout=timeout)
            resp.raise_for_status()
            data = resp.json()
        except Exception:
            # Compatibility fallback for older Ollama embedding endpoint.
            payload_old = {"model": model, "prompt": text}
            resp = requests.post(f"{base}/api/embeddings", json=payload_old, timeout=timeout)
            resp.raise_for_status()
            data = resp.json()
        emb = data.get("embeddings") or data.get("embedding")
        if isinstance(emb, list) and emb and isinstance(emb[0], (int, float)):
            vectors.append([float(x) for x in emb])
        elif isinstance(emb, list) and emb and isinstance(emb[0], list):
            vectors.append([float(x) for x in emb[0]])
        else:
            raise RuntimeError("Invalid embedding response from Ollama")
    return vectors
