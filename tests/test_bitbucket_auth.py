from __future__ import annotations

from pathlib import Path

import ingestion.bitbucket_auth as auth


def test_start_connect_flow_builds_oauth_url(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(auth, "STATE_PATH", tmp_path / "bitbucket_auth.json")
    monkeypatch.setenv("BITBUCKET_CLIENT_ID", "client-123")
    monkeypatch.setenv("BITBUCKET_CLIENT_SECRET", "secret-456")
    monkeypatch.setenv("BITBUCKET_REDIRECT_URI", "https://example.ngrok.io/sf-repo-ai/repos/connect/bitbucket/callback")
    monkeypatch.delenv("BITBUCKET_CONNECT_URL", raising=False)
    monkeypatch.delenv("BITBUCKET_ACCESS_TOKEN", raising=False)
    monkeypatch.delenv("BITBUCKET_TOKEN", raising=False)
    monkeypatch.delenv("BITBUCKET_OAUTH_TOKEN", raising=False)
    monkeypatch.delenv("BITBUCKET_USERNAME", raising=False)
    monkeypatch.delenv("BITBUCKET_APP_PASSWORD", raising=False)

    payload = auth.start_connect_flow()

    assert payload["status"] == "needs_auth"
    assert payload["login_url"].startswith("https://bitbucket.org/site/oauth2/authorize?")
    stored = auth._load_state()
    assert stored.get("pending_state")


def test_complete_connect_flow_persists_token(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(auth, "STATE_PATH", tmp_path / "bitbucket_auth.json")
    monkeypatch.setenv("BITBUCKET_CLIENT_ID", "client-123")
    monkeypatch.setenv("BITBUCKET_CLIENT_SECRET", "secret-456")
    monkeypatch.setenv("BITBUCKET_REDIRECT_URI", "https://example.ngrok.io/sf-repo-ai/repos/connect/bitbucket/callback")
    auth._save_state({"pending_state": "state-123"})

    class FakeResponse:
        def raise_for_status(self):
            return None

        def json(self):
            return {
                "access_token": "oauth-token",
                "refresh_token": "refresh-token",
                "expires_in": 3600,
                "token_type": "bearer",
            }

    def fake_post(*args, **kwargs):
        return FakeResponse()

    monkeypatch.setattr(auth.requests, "post", fake_post)

    payload = auth.complete_connect_flow("code-123", "state-123")

    assert payload["connected"] is True
    stored = auth._load_state()
    assert stored["access_token"] == "oauth-token"
    assert stored["refresh_token"] == "refresh-token"


def test_get_authenticated_clone_url_uses_persisted_oauth_token(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(auth, "STATE_PATH", tmp_path / "bitbucket_auth.json")
    monkeypatch.delenv("BITBUCKET_ACCESS_TOKEN", raising=False)
    monkeypatch.delenv("BITBUCKET_TOKEN", raising=False)
    monkeypatch.delenv("BITBUCKET_OAUTH_TOKEN", raising=False)
    monkeypatch.delenv("BITBUCKET_USERNAME", raising=False)
    monkeypatch.delenv("BITBUCKET_APP_PASSWORD", raising=False)
    auth._save_state({"access_token": "oauth-token", "expires_at": "2999-01-01T00:00:00+00:00"})

    clone_url = auth.get_authenticated_clone_url("https://bitbucket.org/workspace/demo.git", "bitbucket")

    assert clone_url.startswith("https://x-token-auth:oauth-token@bitbucket.org/")
