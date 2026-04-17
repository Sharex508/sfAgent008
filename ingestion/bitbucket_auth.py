from __future__ import annotations

import json
import os
import secrets
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, Optional
from urllib.parse import quote, urlencode, urlsplit, urlunsplit

import requests

BITBUCKET_AUTH_URL = "https://bitbucket.org/site/oauth2/authorize"
BITBUCKET_TOKEN_URL = "https://bitbucket.org/site/oauth2/access_token"
STATE_PATH = Path("data/bitbucket_auth.json")
_EXPIRY_BUFFER_SECONDS = 120


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _now_iso() -> str:
    return _now().replace(microsecond=0).isoformat()


def _load_state() -> Dict[str, Any]:
    if not STATE_PATH.exists():
        return {}
    try:
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def _save_state(payload: Dict[str, Any]) -> Dict[str, Any]:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8")
    return payload


def _env(*names: str) -> str:
    for name in names:
        value = (os.getenv(name) or "").strip()
        if value:
            return value
    return ""


def _client_id() -> str:
    return _env("BITBUCKET_CLIENT_ID")


def _client_secret() -> str:
    return _env("BITBUCKET_CLIENT_SECRET")


def _redirect_uri() -> str:
    return _env("BITBUCKET_REDIRECT_URI")


def _custom_connect_url() -> str:
    return _env("BITBUCKET_CONNECT_URL")


def _state_has_valid_token(state: Dict[str, Any]) -> bool:
    access_token = str(state.get("access_token") or "").strip()
    expires_at = str(state.get("expires_at") or "").strip()
    if not access_token:
        return False
    if not expires_at:
        return True
    try:
        expiry = datetime.fromisoformat(expires_at.replace("Z", "+00:00"))
    except ValueError:
        return True
    return expiry > (_now() + timedelta(seconds=_EXPIRY_BUFFER_SECONDS))


def _build_status(*, connected: bool, status: str, auth_mode: str, login_url: Optional[str], message: str, has_client_config: bool) -> Dict[str, Any]:
    return {
        "provider": "bitbucket",
        "connected": connected,
        "status": status,
        "auth_mode": auth_mode,
        "login_url": login_url,
        "message": message,
        "has_client_config": has_client_config,
    }


def has_inline_credentials(clone_url: Optional[str]) -> bool:
    if not clone_url:
        return False
    lowered = clone_url.lower()
    return "@bitbucket.org" in lowered and "://" in lowered


def _insert_credentials(clone_url: str, username: str, secret: str) -> str:
    split = urlsplit(clone_url)
    if split.scheme not in {"http", "https"}:
        return clone_url
    host = split.netloc.split("@", 1)[-1]
    user_part = quote(username, safe="")
    secret_part = quote(secret, safe="")
    return urlunsplit((split.scheme, f"{user_part}:{secret_part}@{host}", split.path, split.query, split.fragment))


def _exchange_token(grant_type: str, payload: Dict[str, str]) -> Dict[str, Any]:
    client_id = _client_id()
    client_secret = _client_secret()
    if not client_id or not client_secret:
        raise RuntimeError("BITBUCKET_CLIENT_ID and BITBUCKET_CLIENT_SECRET are required for OAuth token exchange.")
    response = requests.post(
        BITBUCKET_TOKEN_URL,
        data={"grant_type": grant_type, **payload},
        auth=(client_id, client_secret),
        timeout=30,
    )
    response.raise_for_status()
    data = response.json()
    expires_in = int(data.get("expires_in") or 3600)
    data["expires_at"] = (_now() + timedelta(seconds=expires_in)).replace(microsecond=0).isoformat()
    return data


def refresh_oauth_token_if_needed() -> Optional[Dict[str, Any]]:
    state = _load_state()
    if _state_has_valid_token(state):
        return state
    refresh_token = str(state.get("refresh_token") or "").strip()
    if not refresh_token:
        return state if state else None
    try:
        data = _exchange_token("refresh_token", {"refresh_token": refresh_token})
    except Exception as exc:
        state["last_error"] = str(exc)
        state["status"] = "refresh_failed"
        _save_state(state)
        return state
    state.update({
        "access_token": data.get("access_token"),
        "refresh_token": data.get("refresh_token") or refresh_token,
        "token_type": data.get("token_type"),
        "scopes": data.get("scopes"),
        "expires_in": data.get("expires_in"),
        "expires_at": data.get("expires_at"),
        "connected_ts": _now_iso(),
        "auth_mode": "oauth",
        "status": "connected",
        "last_error": None,
    })
    _save_state(state)
    return state


def connection_status() -> Dict[str, Any]:
    access_token = _env("BITBUCKET_ACCESS_TOKEN", "BITBUCKET_TOKEN", "BITBUCKET_OAUTH_TOKEN")
    username = _env("BITBUCKET_USERNAME")
    app_password = _env("BITBUCKET_APP_PASSWORD")
    client_id = _client_id()
    client_secret = _client_secret()
    redirect_uri = _redirect_uri()
    connect_url = _custom_connect_url()
    state = refresh_oauth_token_if_needed() or _load_state()

    if access_token:
        return _build_status(
            connected=True,
            status="connected",
            auth_mode="token",
            login_url=None,
            message="Bitbucket access token is available on the backend.",
            has_client_config=bool(client_id and client_secret and redirect_uri) or bool(connect_url),
        )
    if username and app_password:
        return _build_status(
            connected=True,
            status="connected",
            auth_mode="app_password",
            login_url=None,
            message="Bitbucket app password credentials are available on the backend.",
            has_client_config=bool(client_id and client_secret and redirect_uri) or bool(connect_url),
        )
    if _state_has_valid_token(state):
        return _build_status(
            connected=True,
            status="connected",
            auth_mode=str(state.get("auth_mode") or "oauth"),
            login_url=None,
            message="Bitbucket OAuth session is active on the backend.",
            has_client_config=bool(client_id and client_secret and redirect_uri) or bool(connect_url),
        )
    if connect_url:
        return _build_status(
            connected=False,
            status="needs_auth",
            auth_mode="oauth",
            login_url=connect_url,
            message="Bitbucket authentication is not active yet. Start the connect flow before initializing a private repo.",
            has_client_config=True,
        )
    if client_id and client_secret and redirect_uri:
        return _build_status(
            connected=False,
            status="needs_auth",
            auth_mode="oauth",
            login_url=None,
            message="Bitbucket OAuth is configured but not connected yet.",
            has_client_config=True,
        )
    return _build_status(
        connected=False,
        status="not_configured",
        auth_mode="none",
        login_url=None,
        message="Bitbucket connect is not configured on the backend yet. Set OAuth or credential environment variables.",
        has_client_config=False,
    )


def start_connect_flow() -> Dict[str, Any]:
    status = connection_status()
    if status["connected"]:
        return status
    custom_url = _custom_connect_url()
    if custom_url:
        status["login_url"] = custom_url
        return status
    client_id = _client_id()
    client_secret = _client_secret()
    redirect_uri = _redirect_uri()
    if not (client_id and client_secret and redirect_uri):
        return status
    pending_state = secrets.token_urlsafe(24)
    stored = _load_state()
    stored.update({
        "pending_state": pending_state,
        "pending_created_ts": _now_iso(),
    })
    _save_state(stored)
    login_url = BITBUCKET_AUTH_URL + "?" + urlencode({
        "client_id": client_id,
        "response_type": "code",
        "redirect_uri": redirect_uri,
        "state": pending_state,
    })
    return _build_status(
        connected=False,
        status="needs_auth",
        auth_mode="oauth",
        login_url=login_url,
        message="Open the Bitbucket sign-in flow and finish authentication in the callback window.",
        has_client_config=True,
    )


def complete_connect_flow(code: str, state_value: Optional[str]) -> Dict[str, Any]:
    if not code:
        raise RuntimeError("Bitbucket OAuth callback requires a code.")
    stored = _load_state()
    expected_state = str(stored.get("pending_state") or "").strip()
    if expected_state and state_value != expected_state:
        raise RuntimeError("Bitbucket OAuth state validation failed.")
    redirect_uri = _redirect_uri()
    if not redirect_uri:
        raise RuntimeError("BITBUCKET_REDIRECT_URI is required to complete Bitbucket OAuth.")
    data = _exchange_token("authorization_code", {"code": code, "redirect_uri": redirect_uri})
    stored.update({
        "access_token": data.get("access_token"),
        "refresh_token": data.get("refresh_token"),
        "token_type": data.get("token_type"),
        "scopes": data.get("scopes"),
        "expires_in": data.get("expires_in"),
        "expires_at": data.get("expires_at"),
        "connected_ts": _now_iso(),
        "auth_mode": "oauth",
        "status": "connected",
        "last_error": None,
    })
    stored.pop("pending_state", None)
    stored.pop("pending_created_ts", None)
    _save_state(stored)
    return connection_status()


def get_authenticated_clone_url(clone_url: str, provider: Optional[str] = None) -> str:
    provider_name = (provider or "").lower()
    lowered = clone_url.lower()
    if provider_name not in {"", "bitbucket"} and provider_name != "bitbucket":
        return clone_url
    if "bitbucket" not in lowered or has_inline_credentials(clone_url):
        return clone_url

    access_token = _env("BITBUCKET_ACCESS_TOKEN", "BITBUCKET_TOKEN", "BITBUCKET_OAUTH_TOKEN")
    if access_token:
        return _insert_credentials(clone_url, "x-token-auth", access_token)

    username = _env("BITBUCKET_USERNAME")
    app_password = _env("BITBUCKET_APP_PASSWORD")
    if username and app_password:
        return _insert_credentials(clone_url, username, app_password)

    state = refresh_oauth_token_if_needed() or _load_state()
    oauth_token = str(state.get("access_token") or "").strip()
    if oauth_token:
        return _insert_credentials(clone_url, "x-token-auth", oauth_token)
    return clone_url
