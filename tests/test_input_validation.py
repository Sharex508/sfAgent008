from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from server.app import app


client = TestClient(app)


@pytest.mark.parametrize(
    ("path", "payload", "field_name"),
    [
        ("/agent", {"user_prompt": "   "}, "user_prompt"),
        ("/repo/search-explain", {"query": "   "}, "query"),
        ("/repo/user-story", {"story": "   "}, "story"),
        ("/repo/data-prompt", {"data": "sample", "prompt": "   "}, "prompt"),
        ("/sf-repo-ai/feature-explain", {"prompt": "   ", "data": {"foo": "bar"}}, "prompt"),
        ("/sf-repo-ai/user-story-analyze", {"story": "   "}, "story"),
        ("/sf-repo-ai/debug-analyze", {"input_text": "   ", "logs": "sample-log"}, "input_text"),
        ("/sf-repo-ai/development/analyze", {"story": "   "}, "story"),
        ("/sf-repo-ai/development/plan", {"story": "   "}, "story"),
        ("/sf-repo-ai/development/run", {"story": "   "}, "story"),
        ("/sf-repo-ai/ask", {"question": "   "}, "question"),
    ],
)
def test_blank_input_returns_clean_400(path: str, payload: dict, field_name: str):
    response = client.post(path, json=payload)
    assert response.status_code == 400
    assert response.json()["detail"] == f"{field_name} must not be blank."
