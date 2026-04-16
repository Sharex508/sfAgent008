from __future__ import annotations

from dataclasses import dataclass
from typing import Any
from urllib.parse import quote

import requests

from .auth import SfSession


class SalesforceClientError(RuntimeError):
    pass


@dataclass(slots=True)
class SalesforceClient:
    session: SfSession
    timeout: int = 60

    def _base_path(self, tooling: bool = False) -> str:
        root = f"/services/data/v{self.session.api_version}"
        return f"{root}/tooling" if tooling else root

    def _headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.session.access_token}",
            "Content-Type": "application/json",
        }

    def _to_url(self, path: str, tooling: bool = False) -> str:
        p = (path or "").strip()
        if p.startswith("http://") or p.startswith("https://"):
            return p
        if p.startswith("/services/data/"):
            return f"{self.session.instance_url}{p}"
        if p.startswith("/"):
            return f"{self.session.instance_url}{p}"
        return f"{self.session.instance_url}{self._base_path(tooling)}/{p}"

    def request(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        json_body: dict[str, Any] | None = None,
        tooling: bool = False,
    ) -> Any:
        url = self._to_url(path, tooling=tooling)
        resp = requests.request(
            method,
            url,
            headers=self._headers(),
            params=params,
            json=json_body,
            timeout=self.timeout,
        )
        if resp.status_code >= 400:
            raise SalesforceClientError(f"{resp.status_code} {resp.text}")
        if not resp.text:
            return {}
        if "application/json" in (resp.headers.get("Content-Type") or ""):
            return resp.json()
        return resp.text

    def get(self, path: str, *, params: dict[str, Any] | None = None, tooling: bool = False) -> Any:
        return self.request("GET", path, params=params, tooling=tooling)

    def post(self, path: str, *, payload: dict[str, Any], tooling: bool = False) -> Any:
        return self.request("POST", path, json_body=payload, tooling=tooling)

    def patch(self, path: str, *, payload: dict[str, Any], tooling: bool = False) -> Any:
        return self.request("PATCH", path, json_body=payload, tooling=tooling)

    def delete(self, path: str, *, tooling: bool = False) -> Any:
        return self.request("DELETE", path, tooling=tooling)

    def query(self, soql: str, *, tooling: bool = False) -> list[dict[str, Any]]:
        start = "query" if not tooling else "query"
        data = self.get(start, params={"q": soql}, tooling=tooling)
        records: list[dict[str, Any]] = list(data.get("records") or [])
        next_url = data.get("nextRecordsUrl")
        while next_url:
            page = self.get(str(next_url), tooling=False)
            records.extend(list(page.get("records") or []))
            next_url = page.get("nextRecordsUrl")
        return records

    def query_one(self, soql: str, *, tooling: bool = False) -> dict[str, Any] | None:
        rows = self.query(soql, tooling=tooling)
        return rows[0] if rows else None

    # Convenience methods for log capture flow.
    def list_apex_logs(self, *, user_id: str, start_ts: str, end_ts: str, limit: int = 200) -> list[dict[str, Any]]:
        def _fmt(ts: str) -> str:
            raw = (ts or "").strip()
            if raw.endswith("+00:00"):
                return raw.replace("+00:00", "Z")
            return raw

        start_v = _fmt(start_ts)
        end_v = _fmt(end_ts)
        soql = (
            "SELECT Id, StartTime, Status, LogLength, Operation, Request, Location, DurationMilliseconds, LastModifiedDate "
            "FROM ApexLog "
            f"WHERE LogUserId='{user_id}' AND StartTime >= {start_v} AND StartTime <= {end_v} "
            "ORDER BY StartTime ASC "
            f"LIMIT {int(limit)}"
        )
        return self.query(soql, tooling=True)

    def get_log_body(self, log_id: str) -> str:
        body = self.get(f"sobjects/ApexLog/{quote(log_id)}/Body", tooling=True)
        return str(body)
