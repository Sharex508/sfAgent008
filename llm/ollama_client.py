from __future__ import annotations

from typing import Any, Dict

import os
import requests


class OllamaClient:
    """Minimal Ollama chat client."""

    def __init__(self, host: str = "http://localhost:11434", model: str = "llama3.1:70b"):
        self.host = host.rstrip("/")
        self.model = model

    @staticmethod
    def _first_non_empty(*values: Any) -> str:
        for value in values:
            if isinstance(value, str) and value.strip():
                return value
        return ""

    def _extract_text(self, data: Dict[str, Any]) -> str:
        if not isinstance(data, dict):
            return ""

        msg = data.get("message")
        if isinstance(msg, dict):
            content = self._first_non_empty(
                msg.get("content"),
                msg.get("response"),
                msg.get("thinking"),
                msg.get("reasoning"),
            )
            if content:
                return content

        return self._first_non_empty(
            data.get("response"),
            data.get("content"),
            data.get("thinking"),
            data.get("reasoning"),
        )

    def chat(self, prompt: str) -> str:
        """Send a single-turn chat prompt and return the model response text."""
        chat_url = f"{self.host}/api/chat"
        chat_payload: Dict[str, Any] = {
            "model": self.model,
            "messages": [{"role": "user", "content": prompt}],
            "stream": False,
        }
        timeout_sec = int(os.getenv("OLLAMA_TIMEOUT_SECONDS", "300"))
        chat_resp = requests.post(chat_url, json=chat_payload, timeout=timeout_sec)
        chat_resp.raise_for_status()
        chat_data = chat_resp.json()
        chat_text = self._extract_text(chat_data)
        if chat_text:
            return chat_text

        # Some model/build combinations can return empty message.content in /api/chat.
        # Fallback to /api/generate to recover text for strict JSON workflows.
        generate_url = f"{self.host}/api/generate"
        generate_payload: Dict[str, Any] = {
            "model": self.model,
            "prompt": prompt,
            "stream": False,
        }
        generate_resp = requests.post(generate_url, json=generate_payload, timeout=timeout_sec)
        generate_resp.raise_for_status()
        generate_data = generate_resp.json()
        generate_text = self._extract_text(generate_data)
        if generate_text:
            return generate_text
        return str(generate_data)
