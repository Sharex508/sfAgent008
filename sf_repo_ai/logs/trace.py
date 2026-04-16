from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any


def _soql_escape(value: str) -> str:
    return (value or "").replace("\\", "\\\\").replace("'", "\\'")


def _query_tooling(client: Any, soql: str) -> list[dict[str, Any]]:
    if hasattr(client, "tooling_query"):
        return list(client.tooling_query(soql))
    return list(client.query(soql, tooling=True))


def _create_tooling(client: Any, sobject: str, body: dict[str, Any]) -> str:
    if hasattr(client, "tooling_create"):
        return str(client.tooling_create(sobject, body))
    resp = client.post(f"sobjects/{sobject}", payload=body, tooling=True)
    if not resp.get("success"):
        raise RuntimeError(str(resp))
    return str(resp.get("id"))


def _delete_tooling(client: Any, sobject: str, record_id: str) -> None:
    if hasattr(client, "tooling_delete"):
        client.tooling_delete(sobject, record_id)
        return
    client.delete(f"sobjects/{sobject}/{record_id}", tooling=True)


def ensure_debug_level(client: Any, *, level_name: str = "SF_REPO_AI_FINEST", level: str = "FINEST") -> str:
    dn = _soql_escape(level_name)
    rows = _query_tooling(client, f"SELECT Id FROM DebugLevel WHERE DeveloperName='{dn}' LIMIT 1")
    if rows:
        return str(rows[0]["Id"])
    body = {
        "DeveloperName": level_name,
        "MasterLabel": level_name,
        "ApexCode": level,
        "ApexProfiling": level,
        "Callout": level,
        "Database": level,
        "System": level,
        "Validation": level,
        "Visualforce": level,
        "Workflow": level,
    }
    return _create_tooling(client, "DebugLevel", body)


def disable_trace_flags(client: Any, *, user_id: str) -> int:
    uid = _soql_escape(user_id)
    rows = _query_tooling(
        client,
        "SELECT Id FROM TraceFlag "
        f"WHERE TracedEntityId='{uid}' AND LogType='USER_DEBUG'",
    )
    count = 0
    for row in rows:
        _delete_tooling(client, "TraceFlag", str(row["Id"]))
        count += 1
    return count


def enable_trace_flag(
    client: Any,
    *,
    user_id: str,
    minutes: int = 30,
    level_name: str = "SF_REPO_AI_FINEST",
    level: str = "FINEST",
) -> dict[str, Any]:
    debug_level_id = ensure_debug_level(client, level_name=level_name, level=level)
    disable_trace_flags(client, user_id=user_id)
    now = datetime.now(timezone.utc)
    start = (now - timedelta(minutes=1)).isoformat().replace("+00:00", "Z")
    end = (now + timedelta(minutes=max(1, minutes))).isoformat().replace("+00:00", "Z")
    body = {
        "TracedEntityId": user_id,
        "LogType": "USER_DEBUG",
        "DebugLevelId": debug_level_id,
        "StartDate": start,
        "ExpirationDate": end,
    }
    trace_flag_id = _create_tooling(client, "TraceFlag", body)
    return {
        "trace_flag_id": trace_flag_id,
        "debug_level_id": debug_level_id,
        "start": start,
        "end": end,
    }
