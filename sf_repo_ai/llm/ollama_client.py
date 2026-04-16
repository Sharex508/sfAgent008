from __future__ import annotations

import time
from typing import Any

import requests


class OllamaClientError(RuntimeError):
    pass


def chat_completion(
    *,
    ollama_url: str,
    model: str,
    system_prompt: str,
    user_prompt: str,
    timeout: int = 180,
) -> dict[str, Any]:
    url = f"{ollama_url.rstrip('/')}/api/chat"
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "stream": False,
    }
    started = time.perf_counter()
    try:
        resp = requests.post(url, json=payload, timeout=timeout)
        resp.raise_for_status()
        data = resp.json()
    except Exception as exc:
        raise OllamaClientError(str(exc)) from exc
    latency_ms = int((time.perf_counter() - started) * 1000)
    msg = data.get("message") or {}
    text = (msg.get("content") or data.get("response") or "").strip()
    if not text:
        raise OllamaClientError("Empty Ollama response")
    return {
        "text": text,
        "latency_ms": latency_ms,
        "raw": data,
    }

