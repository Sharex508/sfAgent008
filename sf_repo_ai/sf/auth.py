from __future__ import annotations

from dataclasses import dataclass
from html import escape
from typing import Final
from urllib.parse import urlparse
import xml.etree.ElementTree as ET

import requests


DEFAULT_LOGIN_URL: Final[str] = "https://login.salesforce.com"
DEFAULT_API_VERSION: Final[str] = "60.0"


class SalesforceAuthError(RuntimeError):
    pass


@dataclass(slots=True)
class SfSession:
    instance_url: str
    access_token: str
    issued_at: str | None = None
    api_version: str = DEFAULT_API_VERSION


def _derive_instance_url(server_url: str) -> str:
    parsed = urlparse(server_url)
    if not parsed.scheme or not parsed.netloc:
        raise SalesforceAuthError("Invalid serverUrl in SOAP login response.")
    return f"{parsed.scheme}://{parsed.netloc}"


def login_with_username_password(
    *,
    login_url: str,
    username: str,
    password: str,
    token: str | None = None,
    api_version: str = DEFAULT_API_VERSION,
    timeout: int = 60,
) -> SfSession:
    real_password = f"{password}{token or ''}"
    endpoint = f"{login_url.rstrip('/')}/services/Soap/u/{api_version}"
    envelope = (
        '<?xml version="1.0" encoding="utf-8"?>'
        '<env:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">'
        "<env:Body>"
        '<n1:login xmlns:n1="urn:partner.soap.sforce.com">'
        f"<n1:username>{escape(username)}</n1:username>"
        f"<n1:password>{escape(real_password)}</n1:password>"
        "</n1:login>"
        "</env:Body>"
        "</env:Envelope>"
    )
    headers = {"Content-Type": "text/xml", "SOAPAction": "login"}
    resp = requests.post(endpoint, data=envelope.encode("utf-8"), headers=headers, timeout=timeout)
    if resp.status_code >= 400:
        raise SalesforceAuthError(f"SOAP login failed: HTTP {resp.status_code}: {resp.text[:500]}")

    try:
        root = ET.fromstring(resp.text)
    except ET.ParseError as exc:
        raise SalesforceAuthError(f"Failed to parse SOAP login response: {exc}") from exc

    ns = {
        "soapenv": "http://schemas.xmlsoap.org/soap/envelope/",
        "urn": "urn:partner.soap.sforce.com",
    }
    fault = root.find(".//soapenv:Fault", ns)
    if fault is not None:
        fault_text = "".join(fault.itertext()).strip()
        raise SalesforceAuthError(f"SOAP login fault: {fault_text}")

    session_id = root.findtext(".//urn:sessionId", default="", namespaces=ns).strip()
    server_url = root.findtext(".//urn:serverUrl", default="", namespaces=ns).strip()
    issued_at = root.findtext(".//urn:userInfo/urn:userFullName", default="", namespaces=ns).strip() or None
    if not session_id or not server_url:
        raise SalesforceAuthError("SOAP login succeeded but sessionId/serverUrl was missing.")

    return SfSession(
        instance_url=_derive_instance_url(server_url),
        access_token=session_id,
        issued_at=issued_at,
        api_version=api_version,
    )
