from __future__ import annotations

import os
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from typing import Optional

import requests


SOAP_NS = "urn:partner.soap.sforce.com"
ENV_NS = "http://schemas.xmlsoap.org/soap/envelope/"


@dataclass
class SoapSession:
    session_id: str
    server_url: str
    instance_url: str


class SoapAuthError(RuntimeError):
    pass


def _instance_from_server_url(server_url: str) -> str:
    # Example: https://na123.salesforce.com/services/Soap/u/60.0/00D...
    parts = server_url.split("/services/")[0]
    return parts.rstrip("/")


def soap_login(
    *,
    login_url: Optional[str] = None,
    username: Optional[str] = None,
    password: Optional[str] = None,
    token: Optional[str] = None,
    api_version: str = "60.0",
    timeout: int = 30,
) -> SoapSession:
    """Authenticate using Salesforce SOAP login and return session details."""
    login_base = (login_url or os.getenv("SF_LOGIN_URL") or "https://login.salesforce.com").rstrip("/")
    user = username or os.getenv("SF_USERNAME")
    pwd = password or os.getenv("SF_PASSWORD")
    sec_token = token if token is not None else os.getenv("SF_SECURITY_TOKEN") or ""

    if not user or not pwd:
        raise SoapAuthError("Missing credentials: SF_USERNAME and SF_PASSWORD are required")

    combined_password = f"{pwd}{sec_token}"
    endpoint = f"{login_base}/services/Soap/u/{api_version}"

    envelope = f"""<?xml version=\"1.0\" encoding=\"utf-8\"?>
<env:Envelope xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\"
              xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"
              xmlns:env=\"{ENV_NS}\">
  <env:Body>
    <n1:login xmlns:n1=\"{SOAP_NS}\">
      <n1:username>{user}</n1:username>
      <n1:password>{combined_password}</n1:password>
    </n1:login>
  </env:Body>
</env:Envelope>
"""

    headers = {
        "Content-Type": "text/xml; charset=UTF-8",
        "SOAPAction": "login",
    }

    try:
        resp = requests.post(endpoint, data=envelope.encode("utf-8"), headers=headers, timeout=timeout)
        resp.raise_for_status()
    except Exception as exc:
        body = getattr(exc, "response", None)
        detail = body.text[:500] if body is not None and getattr(body, "text", None) else str(exc)
        raise SoapAuthError(f"SOAP login failed: {detail}") from exc

    try:
        root = ET.fromstring(resp.text)
        ns = {"env": ENV_NS, "sf": SOAP_NS}
        sid = root.findtext(".//sf:sessionId", namespaces=ns)
        surl = root.findtext(".//sf:serverUrl", namespaces=ns)
        if not sid or not surl:
            raise SoapAuthError("SOAP login response missing sessionId/serverUrl")
    except ET.ParseError as exc:
        raise SoapAuthError("Unable to parse SOAP login response") from exc

    return SoapSession(session_id=sid, server_url=surl, instance_url=_instance_from_server_url(surl))
