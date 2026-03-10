from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Optional

import requests
from requests.auth import HTTPBasicAuth


@dataclass
class SalesforceSession:
    access_token: str
    instance_url: str
    token_type: str = "Bearer"


class SalesforceSessionProvider:
    """Utility to fetch a Salesforce session via OAuth client_credentials or password flows."""

    def __init__(
        self,
        *,
        username: Optional[str] = None,
        password: Optional[str] = None,
        client_id: Optional[str] = None,
        client_secret: Optional[str] = None,
        security_token: Optional[str] = None,
        domain: Optional[str] = None,
        scope: Optional[str] = None,
        auth_flow: Optional[str] = None,
    ):
        self.username = username or os.getenv("SF_USERNAME")
        self.password = password or os.getenv("SF_PASSWORD")
        self.client_id = client_id or os.getenv("SF_CLIENT_ID")
        self.client_secret = client_secret or os.getenv("SF_CLIENT_SECRET")
        self.security_token = security_token or os.getenv("SF_SECURITY_TOKEN")
        self.domain = (domain or os.getenv("SF_DOMAIN") or "login")
        self.scope = scope or os.getenv("SF_SCOPE")
        self.auth_flow = (auth_flow or os.getenv("SF_AUTH_FLOW", "")).lower() or None
        self.debug = os.getenv("SF_AUTH_DEBUG", "").lower() in {"1", "true", "yes"}
        self.use_basic = os.getenv("SF_AUTH_BASIC", "").lower() in {"1", "true", "yes"}

    def _debug_log(self, token_url: str, payload: dict):
        if not self.debug:
            return
        safe_payload = dict(payload)
        # Never print secrets
        if "client_id" in safe_payload:
            cid = safe_payload["client_id"]
            safe_payload["client_id"] = f"...{cid[-6:]}" if cid else ""
        if "client_secret" in safe_payload:
            safe_payload["client_secret"] = "***redacted***"
        if "password" in safe_payload:
            safe_payload["password"] = "***redacted***"
        print({"token_url": token_url, "payload": safe_payload})

    def _token_url(self) -> str:
        """Build the token URL handling short domains and full hostnames."""
        domain = (self.domain or "login").strip()
        if domain.startswith("http://") or domain.startswith("https://"):
            base = domain.rstrip("/")
        elif domain.endswith(".salesforce.com") or domain.endswith(".force.com"):
            base = f"https://{domain}"
        else:
            base = f"https://{domain}.salesforce.com"
        return f"{base}/services/oauth2/token"

    def fetch_client_credentials(self) -> SalesforceSession:
        if not all([self.client_id, self.client_secret]):
            raise RuntimeError("Missing credentials: need SF_CLIENT_ID and SF_CLIENT_SECRET for client_credentials flow")
        data = {
            "grant_type": "client_credentials",
        }
        if self.scope:
            data["scope"] = self.scope
        token_url = self._token_url()
        # Prefer HTTP Basic when requested (client_id/secret in Authorization header)
        auth = None
        if self.use_basic:
            auth = HTTPBasicAuth(self.client_id, self.client_secret)
        else:
            data["client_id"] = self.client_id
            data["client_secret"] = self.client_secret

        self._debug_log(token_url, data)
        resp = requests.post(token_url, data=data, auth=auth, timeout=30)
        try:
            resp.raise_for_status()
        except Exception as exc:
            raise RuntimeError(f"Failed to obtain Salesforce session (client_credentials): {resp.text}") from exc
        payload = resp.json()
        return SalesforceSession(
            access_token=payload["access_token"],
            instance_url=payload["instance_url"],
            token_type=payload.get("token_type", "Bearer"),
        )

    def fetch_password(self) -> SalesforceSession:
        if not all([self.username, self.password, self.client_id, self.client_secret]):
            raise RuntimeError(
                "Missing credentials: need SF_USERNAME, SF_PASSWORD, SF_CLIENT_ID, SF_CLIENT_SECRET "
                "(and optionally SF_SECURITY_TOKEN, SF_DOMAIN) for password flow"
            )
        password_full = f"{self.password}{self.security_token or ''}"
        data = {
            "grant_type": "password",
            "client_id": self.client_id,
            "client_secret": self.client_secret,
            "username": self.username,
            "password": password_full,
        }
        token_url = self._token_url()
        self._debug_log(token_url, data)
        resp = requests.post(token_url, data=data, timeout=30)
        try:
            resp.raise_for_status()
        except Exception as exc:
            raise RuntimeError(f"Failed to obtain Salesforce session (password flow): {resp.text}") from exc
        payload = resp.json()
        return SalesforceSession(
            access_token=payload["access_token"],
            instance_url=payload["instance_url"],
            token_type=payload.get("token_type", "Bearer"),
        )

    def fetch(self) -> SalesforceSession:
        # Explicitly force client_credentials if requested.
        if self.auth_flow == "client_credentials":
            return self.fetch_client_credentials()

        # Auto-select: if username is absent but client id/secret exist, try client_credentials.
        if self.client_id and self.client_secret and not self.username:
            return self.fetch_client_credentials()

        # Otherwise use password flow.
        return self.fetch_password()
