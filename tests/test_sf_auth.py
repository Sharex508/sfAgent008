from __future__ import annotations

from types import SimpleNamespace

import pytest

from sf_repo_ai.sf.auth import SalesforceAuthError, login_with_username_password


def test_soap_login_parses_session(monkeypatch: pytest.MonkeyPatch) -> None:
    xml = """<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns="urn:partner.soap.sforce.com">
  <soapenv:Body>
    <loginResponse>
      <result>
        <serverUrl>https://example.my.salesforce.com/services/Soap/u/60.0/00Dxx0000000001</serverUrl>
        <sessionId>00Dxx!AQ0AQFaketoken</sessionId>
      </result>
    </loginResponse>
  </soapenv:Body>
</soapenv:Envelope>"""

    def _fake_post(url: str, data: bytes, headers: dict, timeout: int) -> SimpleNamespace:  # noqa: ANN001
        assert "/services/Soap/u/60.0" in url
        assert b"<n1:username>u@example.com</n1:username>" in data
        return SimpleNamespace(status_code=200, text=xml, headers={"Content-Type": "text/xml"})

    monkeypatch.setattr("requests.post", _fake_post)
    session = login_with_username_password(
        login_url="https://login.salesforce.com",
        username="u@example.com",
        password="pass",
        token="tok",
    )
    assert session.instance_url == "https://example.my.salesforce.com"
    assert session.access_token == "00Dxx!AQ0AQFaketoken"


def test_soap_login_fault_raises(monkeypatch: pytest.MonkeyPatch) -> None:
    xml = """<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
  <soapenv:Body>
    <soapenv:Fault><faultstring>INVALID_LOGIN</faultstring></soapenv:Fault>
  </soapenv:Body>
</soapenv:Envelope>"""

    def _fake_post(url: str, data: bytes, headers: dict, timeout: int) -> SimpleNamespace:  # noqa: ANN001
        return SimpleNamespace(status_code=200, text=xml, headers={"Content-Type": "text/xml"})

    monkeypatch.setattr("requests.post", _fake_post)
    with pytest.raises(SalesforceAuthError):
        login_with_username_password(
            login_url="https://login.salesforce.com",
            username="u@example.com",
            password="pass",
        )

