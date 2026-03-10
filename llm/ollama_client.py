from __future__ import annotations

import base64
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests


class OllamaClient:
    """Minimal Ollama chat client."""

    def __init__(self, host: str = "http://localhost:11434", model: str = "llama3.1:70b"):
        self.host = host.rstrip("/")
        self.model = model

    def chat(self, prompt: str) -> str:
        """Send a single-turn chat prompt and return the model response text."""
        url = f"{self.host}/api/chat"
        payload: Dict[str, Any] = {
            "model": self.model,
            "messages": [{"role": "user", "content": prompt}],
            "stream": False,
        }
        resp = requests.post(url, json=payload, timeout=120)
        resp.raise_for_status()
        data = resp.json()
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
        }
        resp = requests.post(url, json=payload, timeout=180)
        resp.raise_for_status()
        data = resp.json()
        if isinstance(data, dict):
            msg = data.get("message") or {}
            if isinstance(msg, dict):
                content = msg.get("content")
                if isinstance(content, str):
                    return content
        return str(data)
