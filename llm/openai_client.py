from __future__ import annotations

from typing import Any, Dict, List

import os
import requests


class OpenAIResponsesClient:
    """Minimal OpenAI Responses API client."""

    def __init__(
        self,
        *,
        api_key: str,
        model: str,
        base_url: str = "https://api.openai.com/v1",
        timeout_seconds: int = 300,
    ):
        self.api_key = api_key
        self.model = model
        self.base_url = base_url.rstrip("/")
        self.timeout_seconds = timeout_seconds

    @staticmethod
    def _first_non_empty(*values: Any) -> str:
        for value in values:
            if isinstance(value, str) and value.strip():
                return value
        return ""

    def _extract_text(self, data: Dict[str, Any]) -> str:
        if not isinstance(data, dict):
            return ""

        output_text = self._first_non_empty(data.get("output_text"))
        if output_text:
            return output_text

        output = data.get("output")
        if not isinstance(output, list):
            return ""

        chunks: List[str] = []
        for item in output:
            if not isinstance(item, dict):
                continue
            content = item.get("content")
            if not isinstance(content, list):
                continue
            for part in content:
                if not isinstance(part, dict):
                    continue
                text = self._first_non_empty(
                    part.get("text"),
                    part.get("output_text"),
                )
                if text:
                    chunks.append(text)
        return "\n".join(chunks).strip()

    def chat(self, prompt: str) -> str:
        payload: Dict[str, Any] = {
            "model": self.model,
            "input": prompt,
        }
        reasoning_effort = os.getenv("OPENAI_REASONING_EFFORT", "").strip()
        if reasoning_effort and (self.model.startswith("gpt-5") or self.model.startswith("o")):
            payload["reasoning"] = {"effort": reasoning_effort}

        response = requests.post(
            f"{self.base_url}/responses",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=self.timeout_seconds,
        )
        response.raise_for_status()
        data = response.json()
        text = self._extract_text(data)
        return text or str(data)
