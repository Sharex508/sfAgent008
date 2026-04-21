from server.app import _is_openai_model, _normalize_model_name, get_llm_client
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
