from __future__ import annotations

from typing import Any

from sf_repo_ai.sf.tooling_api import ToolingAPIClient


def fetch_logs_for_window(
    client: ToolingAPIClient,
    *,
    user_id: str,
    start_ts: str,
    end_ts: str,
    filter_text: str | None = None,
    limit: int = 200,
) -> list[dict[str, Any]]:
    rows = client.list_apex_logs(user_id=user_id, start_ts=start_ts, end_ts=end_ts, limit=limit)
    out: list[dict[str, Any]] = []
    filter_low = (filter_text or "").lower().strip()

    for r in rows:
        log_id = str(r.get("Id") or "")
        if not log_id:
            continue
        body = client.get_log_body(log_id)
        if filter_low and filter_low not in body.lower():
            continue
        out.append(
            {
                "log": dict(r),
                "body": body,
            }
        )
    return out
