from __future__ import annotations

import datetime as dt
import os
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

import requests

from sfdc.auth_oauth import oauth_client_credentials_login, oauth_password_login
from sfdc.auth_soap import SoapSession, soap_login


@dataclass
class SalesforceApiConfig:
    instance_url: str
    session_id: str
    api_version: str = "60.0"


class SalesforceToolingClient:
    def __init__(self, cfg: SalesforceApiConfig, timeout: int = 30):
        self.cfg = cfg
        self.timeout = timeout

    @classmethod
    def from_soap_login(
        cls,
        *,
        login_url: Optional[str] = None,
        username: Optional[str] = None,
        password: Optional[str] = None,
        token: Optional[str] = None,
        api_version: Optional[str] = None,
    ) -> "SalesforceToolingClient":
        ver = api_version or os.getenv("SF_API_VERSION") or "60.0"
        sess: SoapSession = soap_login(
            login_url=login_url,
            username=username,
            password=password,
            token=token,
            api_version=ver,
        )
        return cls(SalesforceApiConfig(instance_url=sess.instance_url, session_id=sess.session_id, api_version=ver))

    @classmethod
    def from_oauth_password(
        cls,
        *,
        login_url: Optional[str] = None,
        client_id: Optional[str] = None,
        client_secret: Optional[str] = None,
        username: Optional[str] = None,
        password: Optional[str] = None,
        token: Optional[str] = None,
        api_version: Optional[str] = None,
    ) -> "SalesforceToolingClient":
        ver = api_version or os.getenv("SF_API_VERSION") or "60.0"
        sess = oauth_password_login(
            login_url=login_url,
            client_id=client_id,
            client_secret=client_secret,
            username=username,
            password=password,
            token=token,
        )
        return cls(SalesforceApiConfig(instance_url=sess.instance_url, session_id=sess.access_token, api_version=ver))

    @classmethod
    def from_oauth_client_credentials(
        cls,
        *,
        login_url: Optional[str] = None,
        client_id: Optional[str] = None,
        client_secret: Optional[str] = None,
        api_version: Optional[str] = None,
    ) -> "SalesforceToolingClient":
        ver = api_version or os.getenv("SF_API_VERSION") or "60.0"
        sess = oauth_client_credentials_login(
            login_url=login_url,
            client_id=client_id,
            client_secret=client_secret,
        )
        return cls(SalesforceApiConfig(instance_url=sess.instance_url, session_id=sess.access_token, api_version=ver))

    @property
    def _headers(self) -> Dict[str, str]:
        return {
            "Authorization": f"Bearer {self.cfg.session_id}",
            "Content-Type": "application/json",
        }

    def _url(self, path: str, *, tooling: bool = False) -> str:
        base = f"{self.cfg.instance_url}/services/data/v{self.cfg.api_version}"
        if tooling:
            base += "/tooling"
        if not path.startswith("/"):
            path = "/" + path
        return base + path

    def get(self, path: str, *, tooling: bool = False, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        url = self._url(path, tooling=tooling)
        resp = requests.get(url, headers=self._headers, params=params, timeout=self.timeout)
        if resp.status_code >= 400:
            raise RuntimeError(f"GET {url} failed: HTTP {resp.status_code} {resp.text[:500]}")
        return resp.json()

    def post(self, path: str, payload: Dict[str, Any], *, tooling: bool = False) -> Dict[str, Any]:
        url = self._url(path, tooling=tooling)
        resp = requests.post(url, headers=self._headers, json=payload, timeout=self.timeout)
        if resp.status_code >= 400:
            raise RuntimeError(f"POST {url} failed: HTTP {resp.status_code} {resp.text[:500]}")
        if resp.text:
            return resp.json()
        return {}

    def patch(self, path: str, payload: Dict[str, Any], *, tooling: bool = False) -> None:
        url = self._url(path, tooling=tooling)
        resp = requests.patch(url, headers=self._headers, json=payload, timeout=self.timeout)
        if resp.status_code >= 400:
            raise RuntimeError(f"PATCH {url} failed: HTTP {resp.status_code} {resp.text[:500]}")

    def query(self, soql: str, *, tooling: bool = False) -> List[Dict[str, Any]]:
        first = self.get("/query", tooling=tooling, params={"q": soql})
        records = list(first.get("records", []))
        next_url = first.get("nextRecordsUrl")
        while next_url:
            url = self.cfg.instance_url + next_url
            resp = requests.get(url, headers=self._headers, timeout=self.timeout)
            if resp.status_code >= 400:
                raise RuntimeError(f"GET {url} failed: HTTP {resp.status_code} {resp.text[:500]}")
            payload = resp.json()
            records.extend(payload.get("records", []))
            next_url = payload.get("nextRecordsUrl")
        return records

    def resolve_user_id(self, user: str) -> str:
        if user.startswith("005") and len(user) in {15, 18}:
            return user
        safe = user.replace("'", "\\'")
        rows = self.query(
            f"SELECT Id, Username FROM User WHERE Username = '{safe}' LIMIT 1",
            tooling=False,
        )
        if not rows:
            raise RuntimeError(f"User not found: {user}")
        return rows[0]["Id"]

    def upsert_debug_level(self, developer_name: str = "SF_REPO_AI_FINEST") -> str:
        rows = self.query(
            "SELECT Id, DeveloperName FROM DebugLevel "
            f"WHERE DeveloperName = '{developer_name}' LIMIT 1",
            tooling=True,
        )
        payload = {
            "DeveloperName": developer_name,
            "MasterLabel": developer_name,
            "ApexCode": "FINEST",
            "ApexProfiling": "FINEST",
            "Callout": "FINEST",
            "Database": "FINEST",
            "System": "FINEST",
            "Validation": "FINEST",
            "Visualforce": "INFO",
            "Workflow": "FINEST",
        }
        if rows:
            debug_id = rows[0]["Id"]
            self.patch(f"/sobjects/DebugLevel/{debug_id}", payload, tooling=True)
            return debug_id
        created = self.post("/sobjects/DebugLevel", payload, tooling=True)
        return created["id"]

    def upsert_trace_flag(self, user_id: str, debug_level_id: str, minutes: int = 30) -> str:
        now = dt.datetime.utcnow().replace(microsecond=0)
        start = now - dt.timedelta(minutes=1)
        end = now + dt.timedelta(minutes=max(1, minutes))
        start_s = start.isoformat() + "Z"
        end_s = end.isoformat() + "Z"

        rows = self.query(
            "SELECT Id, TracedEntityId, ExpirationDate FROM TraceFlag "
            f"WHERE TracedEntityId = '{user_id}' ORDER BY ExpirationDate DESC LIMIT 1",
            tooling=True,
        )
        payload = {
            "TracedEntityId": user_id,
            "LogType": "USER_DEBUG",
            "DebugLevelId": debug_level_id,
            "StartDate": start_s,
            "ExpirationDate": end_s,
        }
        if rows:
            trace_id = rows[0]["Id"]
            # TracedEntityId/LogType are not writable on update in many orgs.
            self.patch(
                f"/sobjects/TraceFlag/{trace_id}",
                {
                    "DebugLevelId": debug_level_id,
                    "StartDate": start_s,
                    "ExpirationDate": end_s,
                },
                tooling=True,
            )
            return trace_id
        created = self.post("/sobjects/TraceFlag", payload, tooling=True)
        return created["id"]

    def disable_trace_flag(self, user_id: str) -> int:
        rows = self.query(
            "SELECT Id FROM TraceFlag "
            f"WHERE TracedEntityId = '{user_id}'",
            tooling=True,
        )
        count = 0
        expired = (dt.datetime.utcnow() - dt.timedelta(minutes=1)).replace(microsecond=0).isoformat() + "Z"
        for row in rows:
            self.patch(f"/sobjects/TraceFlag/{row['Id']}", {"ExpirationDate": expired}, tooling=True)
            count += 1
        return count

    def execute_anonymous(self, anonymous_body: str) -> Dict[str, Any]:
        return self.get(
            "/executeAnonymous",
            tooling=True,
            params={"anonymousBody": anonymous_body},
        )

    def query_apex_logs(self, start_iso: str, end_iso: str, user_id: str, limit: int = 200) -> List[Dict[str, Any]]:
        soql = (
            "SELECT Id, StartTime, LogUserId, Operation, Status, Location, LogLength "
            "FROM ApexLog "
            f"WHERE LogUserId = '{user_id}' "
            f"AND StartTime >= {start_iso} "
            f"AND StartTime <= {end_iso} "
            "ORDER BY StartTime DESC "
            f"LIMIT {max(1, limit)}"
        )
        return self.query(soql, tooling=True)

    def get_apex_log_body(self, log_id: str) -> str:
        url = self._url(f"/sobjects/ApexLog/{log_id}/Body", tooling=True)
        resp = requests.get(url, headers={"Authorization": f"Bearer {self.cfg.session_id}"}, timeout=self.timeout)
        if resp.status_code >= 400:
            raise RuntimeError(f"GET {url} failed: HTTP {resp.status_code} {resp.text[:500]}")
        return resp.text

    def get_current_user(self) -> Dict[str, str]:
        # Preferred path: Chatter "me" endpoint usually resolves to the authenticated user.
        try:
            me = self.get("/chatter/users/me", tooling=False)
            uid = str(me.get("id") or "").strip()
            uname = str(me.get("username") or me.get("email") or "").strip()
            if uid:
                return {"id": uid, "username": uname}
        except Exception:
            pass

        # Fallback path: OAuth userinfo endpoint.
        try:
            url = f"{self.cfg.instance_url}/services/oauth2/userinfo"
            resp = requests.get(
                url,
                headers={"Authorization": f"Bearer {self.cfg.session_id}"},
                timeout=self.timeout,
            )
            if resp.status_code < 400:
                data = resp.json()
                uid = str(data.get("user_id") or "").strip()
                uname = str(data.get("preferred_username") or data.get("email") or "").strip()
                if uid:
                    return {"id": uid, "username": uname}
        except Exception:
            pass

        raise RuntimeError("Unable to resolve current Salesforce user from session token.")
