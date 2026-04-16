from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.parse import quote

import requests


class ToolingAPIError(RuntimeError):
    pass


@dataclass
class OrgAuth:
    instance_url: str
    access_token: str
    username: str | None = None
    user_id: str | None = None


class ToolingAPIClient:
    def __init__(self, auth: OrgAuth):
        self.auth = auth

    @classmethod
    def from_org_alias(cls, org_alias: str) -> "ToolingAPIClient":
        proc = subprocess.run(
            ["sf", "org", "display", "--target-org", org_alias, "--json"],
            text=True,
            capture_output=True,
            check=False,
        )
        if proc.returncode != 0:
            raise ToolingAPIError(proc.stderr.strip() or proc.stdout.strip() or "sf org display failed")
        payload = json.loads(proc.stdout or "{}")
        result = payload.get("result") or {}
        token = result.get("accessToken")
        url = result.get("instanceUrl")
        if not token or not url:
            raise ToolingAPIError("Could not obtain access token/instance url from sf org display")
        auth = OrgAuth(
            instance_url=str(url).rstrip("/"),
            access_token=str(token),
            username=result.get("username"),
            user_id=result.get("id"),
        )
        return cls(auth)

    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.auth.access_token}",
            "Content-Type": "application/json",
        }

    def _req(self, method: str, path: str, *, params: dict[str, Any] | None = None, json_body: dict[str, Any] | None = None) -> Any:
        url = f"{self.auth.instance_url}/services/data/v60.0/{path.lstrip('/')}"
        resp = requests.request(method, url, headers=self._headers(), params=params, json=json_body, timeout=60)
        if resp.status_code >= 400:
            raise ToolingAPIError(f"{resp.status_code} {resp.text}")
        if not resp.text:
            return {}
        if "application/json" in (resp.headers.get("Content-Type") or ""):
            return resp.json()
        return resp.text

    def tooling_query(self, soql: str) -> list[dict[str, Any]]:
        data = self._req("GET", "/tooling/query", params={"q": soql})
        return list(data.get("records") or [])

    def tooling_create(self, sobject: str, body: dict[str, Any]) -> str:
        data = self._req("POST", f"/tooling/sobjects/{sobject}", json_body=body)
        if not data.get("success"):
            raise ToolingAPIError(str(data))
        return str(data.get("id"))

    def tooling_delete(self, sobject: str, record_id: str) -> None:
        self._req("DELETE", f"/tooling/sobjects/{sobject}/{record_id}")

    def _ensure_debug_level(self, level_name: str = "SF_REPO_AI_FINEST") -> str:
        rows = self.tooling_query(f"SELECT Id FROM DebugLevel WHERE DeveloperName='{level_name}' LIMIT 1")
        if rows:
            return str(rows[0]["Id"])
        body = {
            "DeveloperName": level_name,
            "MasterLabel": level_name,
            "ApexCode": "FINEST",
            "ApexProfiling": "FINEST",
            "Callout": "FINEST",
            "Database": "FINEST",
            "System": "FINEST",
            "Validation": "FINEST",
            "Visualforce": "FINEST",
            "Workflow": "FINEST",
        }
        return self.tooling_create("DebugLevel", body)

    def enable_trace(self, *, user_id: str, minutes: int = 30, level_name: str = "SF_REPO_AI_FINEST") -> dict[str, Any]:
        debug_level_id = self._ensure_debug_level(level_name)
        now = datetime.now(timezone.utc)
        start = now - timedelta(minutes=1)
        end = now + timedelta(minutes=max(1, minutes))
        body = {
            "TracedEntityId": user_id,
            "LogType": "USER_DEBUG",
            "DebugLevelId": debug_level_id,
            "StartDate": start.isoformat().replace("+00:00", "Z"),
            "ExpirationDate": end.isoformat().replace("+00:00", "Z"),
        }
        tf_id = self.tooling_create("TraceFlag", body)
        return {"trace_flag_id": tf_id, "debug_level_id": debug_level_id, "start": body["StartDate"], "end": body["ExpirationDate"]}

    def disable_trace(self, *, user_id: str) -> int:
        rows = self.tooling_query(
            "SELECT Id FROM TraceFlag "
            f"WHERE TracedEntityId='{user_id}' AND LogType='USER_DEBUG'"
        )
        count = 0
        for r in rows:
            self.tooling_delete("TraceFlag", str(r["Id"]))
            count += 1
        return count

    def list_apex_logs(self, *, user_id: str, start_ts: str, end_ts: str, limit: int = 200) -> list[dict[str, Any]]:
        def _fmt(ts: str) -> str:
            raw = (ts or "").strip()
            if raw.endswith("Z"):
                return raw
            if raw.endswith("+00:00"):
                return raw.replace("+00:00", "Z")
            return raw

        start_v = _fmt(start_ts)
        end_v = _fmt(end_ts)
        soql = (
            "SELECT Id, StartTime, Status, LogLength, Operation, Request, Location, DurationMilliseconds "
            "FROM ApexLog "
            f"WHERE LogUserId='{user_id}' AND StartTime >= {start_v} AND StartTime <= {end_v} "
            "ORDER BY StartTime ASC "
            f"LIMIT {int(limit)}"
        )
        return self.tooling_query(soql)

    def get_log_body(self, log_id: str) -> str:
        path = f"/tooling/sobjects/ApexLog/{quote(log_id)}/Body"
        body = self._req("GET", path)
        return str(body)
