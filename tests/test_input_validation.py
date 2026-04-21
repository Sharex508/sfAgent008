from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from server.app import app
import server.app as app_module


client = TestClient(app)


@pytest.mark.parametrize(
    ("path", "payload", "field_name"),
    [
        ("/agent", {"user_prompt": "   "}, "user_prompt"),
        ("/repo/search-explain", {"query": "   "}, "query"),
        ("/repo/user-story", {"story": "   "}, "story"),
        ("/repo/data-prompt", {"data": "sample", "prompt": "   "}, "prompt"),
        ("/sf-repo-ai/feature-explain", {"prompt": "   ", "data": {"foo": "bar"}}, "prompt"),
        ("/sf-repo-ai/user-story-analyze", {"story": "   "}, "story"),
        ("/sf-repo-ai/debug-analyze", {"input_text": "   ", "logs": "sample-log"}, "input_text"),
        ("/sf-repo-ai/development/analyze", {"story": "   "}, "story"),
        ("/sf-repo-ai/development/plan", {"story": "   "}, "story"),
        ("/sf-repo-ai/development/run", {"story": "   "}, "story"),
        ("/sf-repo-ai/ask", {"question": "   "}, "question"),
    ],
)
def test_blank_input_returns_clean_400(path: str, payload: dict, field_name: str):
    response = client.post(path, json=payload)
    assert response.status_code == 400
    assert response.json()["detail"] == f"{field_name} must not be blank."


def test_sf_repo_ai_ask_flow_inventory_is_deterministic(tmp_path, monkeypatch):
    flows_dir = tmp_path / "force-app" / "main" / "default" / "flows"
    flows_dir.mkdir(parents=True)

    active_flow = flows_dir / "Account_Active.flow-meta.xml"
    active_flow.write_text(
        """<?xml version="1.0" encoding="UTF-8"?>
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Account Active Flow</label>
    <processType>AutoLaunchedFlow</processType>
    <start>
        <object>Account</object>
        <recordTriggerType>CreateAndUpdate</recordTriggerType>
        <triggerType>RecordAfterSave</triggerType>
    </start>
    <status>Active</status>
</Flow>
""",
        encoding="utf-8",
    )

    draft_flow = flows_dir / "Account_Draft.flow-meta.xml"
    draft_flow.write_text(
        """<?xml version="1.0" encoding="UTF-8"?>
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Account Draft Flow</label>
    <processType>AutoLaunchedFlow</processType>
    <start>
        <object>Account</object>
        <recordTriggerType>CreateAndUpdate</recordTriggerType>
        <triggerType>RecordAfterSave</triggerType>
    </start>
    <status>Draft</status>
</Flow>
""",
        encoding="utf-8",
    )

    other_flow = flows_dir / "Case_Active.flow-meta.xml"
    other_flow.write_text(
        """<?xml version="1.0" encoding="UTF-8"?>
<Flow xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Case Active Flow</label>
    <processType>AutoLaunchedFlow</processType>
    <start>
        <object>Case</object>
        <recordTriggerType>CreateAndUpdate</recordTriggerType>
        <triggerType>RecordAfterSave</triggerType>
    </start>
    <status>Active</status>
</Flow>
""",
        encoding="utf-8",
    )

    monkeypatch.setattr(app_module, "_default_meta_root", lambda: tmp_path / "force-app" / "main" / "default")

    response = client.post("/sf-repo-ai/ask", json={"question": "give list of all active flows on the Account object"})
    assert response.status_code == 200
    payload = response.json()
    assert payload["intent"] == "FLOW_INVENTORY"
    assert "1 active record-triggered flow(s) found in repo metadata for object Account:" in payload["final_answer"]
    assert "Account Active Flow" in payload["final_answer"]
    assert "Account Draft Flow" not in payload["final_answer"]
    assert payload["tool_results"][0]["tool"] == "flow_inventory"
    assert len(payload["tool_results"][0]["result"]["items"]) == 1
