from __future__ import annotations

import sys
from pathlib import Path

from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from retrieval.vector_store import search_metadata
from server.app import app


client = TestClient(app)


def test_search_metadata_blank_query_returns_empty_results():
    assert search_metadata("", k=8, hybrid=True) == []
    assert search_metadata("   ", k=8, hybrid=False) == []


def test_repo_search_explain_rejects_blank_query():
    response = client.post("/repo/search-explain", json={"query": "   "})
    assert response.status_code == 400
    assert response.json()["detail"] == "query is required"


def test_debug_analyze_rejects_blank_input_text():
    response = client.post("/sf-repo-ai/debug-analyze", json={"input_text": "   ", "logs": {}})
    assert response.status_code == 400
    assert response.json()["detail"] == "input_text is required"


def test_sf_repo_ask_rejects_blank_question():
    response = client.post("/sf-repo-ai/ask", json={"question": "   "})
    assert response.status_code == 400
    assert response.json()["detail"] == "question is required"
