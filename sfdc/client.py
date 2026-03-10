from __future__ import annotations

import os
from dataclasses import dataclass, field
from typing import Any, Dict, Iterable, List, Optional, Set

from simple_salesforce import Salesforce, SalesforceGeneralError, SalesforceMalformedRequest

from sfdc.auth import SalesforceSessionProvider


DEFAULT_WRITE_ALLOWLIST: Set[str] = {
    "Account",
    "Contact",
    "Opportunity",
    "Case",
    "Lead",
    "Task",
    "OpportunityLineItem",
    "Quote",
    "QuoteLineItem",
}


class SalesforceAuthError(RuntimeError):
    """Raised when we cannot authenticate to Salesforce."""


def _normalize_object_api(object_api: str) -> str:
    return object_api.strip()


def _coerce_list(val: Any) -> List[Any]:
    if val is None:
        return []
    if isinstance(val, list):
        return val
    if isinstance(val, (set, tuple)):
        return list(val)
    return [val]


@dataclass
class SalesforceClient:
    """Thin wrapper around simple_salesforce with guardrails for writes."""

    sf: Salesforce
    dry_run: bool = True
    write_allowlist: Set[str] = field(default_factory=lambda: set(DEFAULT_WRITE_ALLOWLIST))

    @classmethod
    def from_env(
        cls,
        *,
        dry_run: bool = True,
        write_allowlist: Optional[Iterable[str]] = None,
    ) -> "SalesforceClient":
        """Create a client using environment variables."""
        # Session-based auth (preferred when available)
        session_id = os.getenv("SF_SESSION_ID")
        instance_url = os.getenv("SF_INSTANCE_URL")
        domain = os.getenv("SF_DOMAIN", "login")
        auth_flow = (os.getenv("SF_AUTH_FLOW", "") or "").lower()

        try:
            if session_id and instance_url:
                sf = Salesforce(session_id=session_id, instance_url=instance_url, domain=domain)
            else:
                username = os.getenv("SF_USERNAME")
                password = os.getenv("SF_PASSWORD")
                security_token = os.getenv("SF_SECURITY_TOKEN")
                client_id = os.getenv("SF_CLIENT_ID")
                client_secret = os.getenv("SF_CLIENT_SECRET")

                if client_id and client_secret and (auth_flow == "client_credentials" or not username):
                    # OAuth client_credentials flow
                    sess = SalesforceSessionProvider(
                        client_id=client_id,
                        client_secret=client_secret,
                        domain=domain,
                        auth_flow="client_credentials",
                    ).fetch()
                    sf = Salesforce(session_id=sess.access_token, instance_url=sess.instance_url, domain=domain)
                elif client_id and client_secret and username and password:
                    # OAuth password flow
                    sess = SalesforceSessionProvider(
                        username=username,
                        password=password,
                        client_id=client_id,
                        client_secret=client_secret,
                        security_token=security_token,
                        domain=domain,
                        auth_flow="password",
                    ).fetch()
                    sf = Salesforce(session_id=sess.access_token, instance_url=sess.instance_url, domain=domain)
                else:
                    if not all([username, password, security_token]):
                        raise SalesforceAuthError(
                            "Missing credentials: set SF_SESSION_ID + SF_INSTANCE_URL, "
                            "or SF_CLIENT_ID + SF_CLIENT_SECRET (+ optional SF_SCOPE / SF_AUTH_FLOW), "
                            "or SF_USERNAME + SF_PASSWORD + SF_SECURITY_TOKEN"
                        )
                    sf = Salesforce(
                        username=username,
                        password=password,
                        security_token=security_token,
                        domain=domain,
                    )
        except Exception as exc:  # pragma: no cover - simple-salesforce raises custom exceptions
            raise SalesforceAuthError(f"Failed to authenticate to Salesforce: {exc}") from exc

        return cls(
            sf=sf,
            dry_run=dry_run,
            write_allowlist=set(write_allowlist) if write_allowlist else set(DEFAULT_WRITE_ALLOWLIST),
        )

    # ---- READ TOOLS ----
    def tool_soql(self, query: str) -> Dict[str, Any]:
        """Run a SOQL query."""
        return self.sf.query(query)

    def tool_get_record(self, object_api: str, record_id: str, fields: Optional[Iterable[str]] = None) -> Dict[str, Any]:
        """Fetch a record; optional fields to limit payload."""
        obj = getattr(self.sf, _normalize_object_api(object_api))
        params = {}
        if fields:
            params["fields"] = ",".join(fields)
        return obj.get(record_id, **params)

    # ---- WRITE TOOLS ----
    def _ensure_write_allowed(self, object_api: str):
        if _normalize_object_api(object_api) not in self.write_allowlist:
            raise PermissionError(f"Writes to {object_api} are not allowed (allowlist enforced)")

    def tool_create_record(self, object_api: str, payload: Dict[str, Any], dry_run: Optional[bool] = None) -> Dict[str, Any]:
        """Create a record with guardrails."""
        self._ensure_write_allowed(object_api)
        effective_dry_run = self.dry_run if dry_run is None else dry_run
        if effective_dry_run:
            return {
                "dry_run": True,
                "object": object_api,
                "payload": payload,
                "message": "Dry run: not created",
            }
        obj = getattr(self.sf, _normalize_object_api(object_api))
        try:
            return obj.create(payload)
        except (SalesforceMalformedRequest, SalesforceGeneralError) as exc:
            return {"error": str(exc), "payload": payload}

    def tool_update_record(
        self,
        object_api: str,
        record_id: str,
        payload: Dict[str, Any],
        dry_run: Optional[bool] = None,
    ) -> Dict[str, Any]:
        """Update a record with guardrails."""
        self._ensure_write_allowed(object_api)
        effective_dry_run = self.dry_run if dry_run is None else dry_run
        if effective_dry_run:
            return {
                "dry_run": True,
                "object": object_api,
                "record_id": record_id,
                "payload": payload,
                "message": "Dry run: not updated",
            }
        obj = getattr(self.sf, _normalize_object_api(object_api))
        try:
            success = obj.update(record_id, payload)
            return {"success": bool(success), "id": record_id, "object": object_api}
        except (SalesforceMalformedRequest, SalesforceGeneralError) as exc:
            return {"error": str(exc), "payload": payload, "id": record_id, "object": object_api}

    # ---- BULK / EMAIL TOOLS ----
    def tool_bulk_emailmessages(self, case_ids: Iterable[str]) -> List[Dict[str, Any]]:
        """Fetch EmailMessage records for a list of Case Ids (read-only)."""
        case_ids_list = [cid for cid in _coerce_list(case_ids) if cid]
        if not case_ids_list:
            return []

        # Build SOQL IN clause safely
        ids_clause = ",".join([f"'{cid}'" for cid in case_ids_list])
        soql = (
            "SELECT Id, Subject, TextBody, HtmlBody, ParentId, FromAddress, ToAddress, CreatedDate "
            f"FROM EmailMessage WHERE ParentId IN ({ids_clause})"
        )
        res = self.sf.query(soql)
        return res.get("records", [])


# Convenience top-level helpers for agent tool wiring
def _get_client(dry_run: bool = True, write_allowlist: Optional[Iterable[str]] = None) -> SalesforceClient:
    return SalesforceClient.from_env(dry_run=dry_run, write_allowlist=write_allowlist)


def tool_soql(query: str, *, client: Optional[SalesforceClient] = None) -> Dict[str, Any]:
    client = client or _get_client(dry_run=True)
    return client.tool_soql(query)


def tool_get_record(
    object_api: str,
    record_id: str,
    fields: Optional[Iterable[str]] = None,
    *,
    client: Optional[SalesforceClient] = None,
) -> Dict[str, Any]:
    client = client or _get_client(dry_run=True)
    return client.tool_get_record(object_api, record_id, fields)


def tool_create_record(
    object_api: str,
    payload: Dict[str, Any],
    *,
    dry_run: bool = True,
    client: Optional[SalesforceClient] = None,
) -> Dict[str, Any]:
    client = client or _get_client(dry_run=dry_run)
    return client.tool_create_record(object_api, payload, dry_run=dry_run)


def tool_update_record(
    object_api: str,
    record_id: str,
    payload: Dict[str, Any],
    *,
    dry_run: bool = True,
    client: Optional[SalesforceClient] = None,
) -> Dict[str, Any]:
    client = client or _get_client(dry_run=dry_run)
    return client.tool_update_record(object_api, record_id, payload, dry_run=dry_run)


def tool_bulk_emailmessages(
    case_ids: Iterable[str],
    *,
    client: Optional[SalesforceClient] = None,
) -> List[Dict[str, Any]]:
    client = client or _get_client(dry_run=True)
    return client.tool_bulk_emailmessages(case_ids)
