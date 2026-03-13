from __future__ import annotations

import base64
import os
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests


class OllamaClient:
    """Minimal Ollama chat client."""

    def __init__(self, host: str = "http://localhost:11434", model: str = "gpt-oss:20b"):
        self.host = host.rstrip("/")
        self.model = model
        # gpt-oss:20b can exceed 120s on multi-step prompts.
        self.chat_timeout_sec = int(os.getenv("OLLAMA_CHAT_TIMEOUT_SEC", "600"))
        self.vision_timeout_sec = int(os.getenv("OLLAMA_VISION_TIMEOUT_SEC", "900"))
        self.keep_alive = os.getenv("OLLAMA_KEEP_ALIVE", "30m")
        self.chat_retries = int(os.getenv("OLLAMA_CHAT_RETRIES", "2"))
        self.retry_backoff_sec = float(os.getenv("OLLAMA_RETRY_BACKOFF_SEC", "2"))

    def _post_json(self, url: str, payload: Dict[str, Any], timeout: int) -> Dict[str, Any]:
        retries = max(self.chat_retries, 0)
        last_exc: Optional[Exception] = None
        for attempt in range(retries + 1):
            try:
                resp = requests.post(url, json=payload, timeout=timeout)
                resp.raise_for_status()
                data = resp.json()
                return data if isinstance(data, dict) else {"raw": data}
            except (requests.exceptions.ReadTimeout, requests.exceptions.ConnectionError) as exc:
                last_exc = exc
                if attempt >= retries:
                    raise
                time.sleep(self.retry_backoff_sec * (attempt + 1))
        if last_exc:
            raise last_exc
        return {}

    def chat(self, prompt: str) -> str:
        """Send a single-turn chat prompt and return the model response text."""
        url = f"{self.host}/api/chat"
        payload: Dict[str, Any] = {
            "model": self.model,
            "messages": [{"role": "user", "content": prompt}],
            "stream": False,
            "keep_alive": self.keep_alive,
        }
        data = self._post_json(url, payload, self.chat_timeout_sec)
        # Ollama returns {"message": {"content": ...}} or stream events; here we handle the non-streaming case.
        if isinstance(data, dict):
            msg = data.get("message") or {}
            if isinstance(msg, dict):
                content = msg.get("content")
                if isinstance(content, str):
                    return content
        return str(data)

    def list_models(self) -> List[str]:
        url = f"{self.host}/api/tags"
        resp = requests.get(url, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        models = []
        for item in data.get("models", []):
            name = item.get("name")
            if isinstance(name, str):
                models.append(name)
        return models

    def chat_with_images(self, prompt: str, image_paths: List[str]) -> str:
        """Send a single-turn chat prompt with inline images for vision models."""
        url = f"{self.host}/api/chat"
        encoded_images: List[str] = []
        for p in image_paths:
            payload = Path(p).read_bytes()
            encoded_images.append(base64.b64encode(payload).decode("ascii"))

        payload: Dict[str, Any] = {
            "model": self.model,
            "messages": [
                {
                    "role": "user",
                    "content": prompt,
                    "images": encoded_images,
                }
            ],
            "stream": False,
            "keep_alive": self.keep_alive,
        }
        data = self._post_json(url, payload, self.vision_timeout_sec)
        if isinstance(data, dict):
            msg = data.get("message") or {}
            if isinstance(msg, dict):
                content = msg.get("content")
                if isinstance(content, str):
                    return content
        return str(data)
