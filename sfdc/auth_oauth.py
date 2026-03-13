from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Optional

import requests


@dataclass
class OauthSession:
    access_token: str
    instance_url: str


class OauthAuthError(RuntimeError):
    pass


def _token_endpoint(login_url: Optional[str]) -> str:
    base = (login_url or os.getenv("SF_LOGIN_URL") or "https://login.salesforce.com").rstrip("/")
    return f"{base}/services/oauth2/token"


def oauth_password_login(
    *,
    login_url: Optional[str] = None,
    client_id: Optional[str] = None,
    client_secret: Optional[str] = None,
    username: Optional[str] = None,
    password: Optional[str] = None,
    token: Optional[str] = None,
    timeout: int = 30,
) -> OauthSession:
    cid = client_id or os.getenv("SF_CLIENT_ID")
    csec = client_secret or os.getenv("SF_CLIENT_SECRET")
    user = username or os.getenv("SF_USERNAME")
    pwd = password or os.getenv("SF_PASSWORD")
    sec_token = token if token is not None else os.getenv("SF_SECURITY_TOKEN") or ""
    if not cid or not csec or not user or not pwd:
        raise OauthAuthError("Missing credentials for OAuth password grant (client_id/client_secret/username/password).")

    endpoint = _token_endpoint(login_url)
    payload = {
        "grant_type": "password",
        "client_id": cid,
        "client_secret": csec,
        "username": user,
        "password": f"{pwd}{sec_token}",
    }
    try:
        resp = requests.post(endpoint, data=payload, timeout=timeout)
        resp.raise_for_status()
    except Exception as exc:
        body = getattr(exc, "response", None)
        detail = body.text[:500] if body is not None and getattr(body, "text", None) else str(exc)
        raise OauthAuthError(f"OAuth password login failed: {detail}") from exc

    data = resp.json()
    at = data.get("access_token")
    instance = data.get("instance_url")
    if not at or not instance:
        raise OauthAuthError("OAuth password login response missing access_token/instance_url")
    return OauthSession(access_token=str(at), instance_url=str(instance).rstrip("/"))


def oauth_client_credentials_login(
    *,
    login_url: Optional[str] = None,
    client_id: Optional[str] = None,
    client_secret: Optional[str] = None,
    timeout: int = 30,
) -> OauthSession:
    cid = client_id or os.getenv("SF_CLIENT_ID")
    csec = client_secret or os.getenv("SF_CLIENT_SECRET")
    if not cid or not csec:
        raise OauthAuthError("Missing credentials for OAuth client_credentials grant (client_id/client_secret).")

    endpoint = _token_endpoint(login_url)
    payload = {
        "grant_type": "client_credentials",
        "client_id": cid,
        "client_secret": csec,
    }
    try:
        resp = requests.post(endpoint, data=payload, timeout=timeout)
        resp.raise_for_status()
    except Exception as exc:
        body = getattr(exc, "response", None)
        detail = body.text[:500] if body is not None and getattr(body, "text", None) else str(exc)
        raise OauthAuthError(f"OAuth client_credentials login failed: {detail}") from exc

    data = resp.json()
    at = data.get("access_token")
    instance = data.get("instance_url")
    if not at or not instance:
        raise OauthAuthError("OAuth client_credentials response missing access_token/instance_url")
    return OauthSession(access_token=str(at), instance_url=str(instance).rstrip("/"))

