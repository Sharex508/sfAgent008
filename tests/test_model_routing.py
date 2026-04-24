from fastapi.testclient import TestClient

from server.app import app, _get_supported_models, _is_openai_model, _normalize_model_name, get_llm_client
from llm.ollama_client import OllamaClient
from llm.openai_client import OpenAIResponsesClient


def test_model_alias_and_provider_selection_for_ollama(monkeypatch):
    monkeypatch.delenv('OPENAI_API_KEY', raising=False)
    client = get_llm_client('gpt-oss:20b')
    assert isinstance(client, OllamaClient)
    assert client.model == 'gpt-oss:20b'


def test_model_alias_and_provider_selection_for_codex(monkeypatch):
    monkeypatch.setenv('OPENAI_API_KEY', 'test-key')
    client = get_llm_client('codex')
    assert isinstance(client, OpenAIResponsesClient)
    assert client.model == 'gpt-5.1-codex'


def test_openai_model_detection():
    assert _is_openai_model('gpt-5.4-mini') is True
    assert _is_openai_model('gpt-4.1') is True
    assert _is_openai_model('gpt-oss:20b') is False


def test_normalize_model_name():
    assert _normalize_model_name('codex') == 'gpt-5.1-codex'
    assert _normalize_model_name('gpt-5.1-mini') == 'gpt-5-mini'


def test_supported_models_marks_openai_unavailable_without_key(monkeypatch):
    monkeypatch.delenv('OPENAI_API_KEY', raising=False)
    monkeypatch.setattr('server.app._probe_ollama_models', lambda: {'reachable': False, 'names': set(), 'reason': 'offline'})
    models = _get_supported_models()
    by_value = {entry.value: entry for entry in models}
    assert by_value['gpt-5.1-codex'].available is False
    assert by_value['gpt-5.1-codex'].reason == 'OPENAI_API_KEY is not configured.'
    assert by_value['gpt-oss:20b'].available is False
    assert by_value['gpt-oss:20b'].reason == 'Ollama is not reachable.'


def test_supported_models_endpoint(monkeypatch):
    monkeypatch.delenv('AGENT_API_KEY', raising=False)
    monkeypatch.setenv('OPENAI_API_KEY', 'test-key')
    monkeypatch.setattr('server.app._probe_ollama_models', lambda: {'reachable': True, 'names': {'gpt-oss:20b'}, 'reason': None})
    client = TestClient(app)
    response = client.get('/sf-repo-ai/models')
    assert response.status_code == 200
    payload = response.json()
    assert 'models' in payload
    by_value = {item['value']: item for item in payload['models']}
    assert by_value['gpt-oss:20b']['available'] is True
    assert by_value['gpt-5.1-codex']['available'] is True
