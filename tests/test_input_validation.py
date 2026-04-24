from __future__ import annotations

import json

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


def test_sf_repo_ai_ask_flow_inventory_handles_lowercase_object_reference(tmp_path, monkeypatch):
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

    monkeypatch.setattr(app_module, "_default_meta_root", lambda: tmp_path / "force-app" / "main" / "default")

    response = client.post("/sf-repo-ai/ask", json={"question": "Can you give list of all active flows on account"})
    assert response.status_code == 200
    payload = response.json()
    assert payload["intent"] == "FLOW_INVENTORY"
    assert "1 active record-triggered flow(s) found in repo metadata for object Account:" in payload["final_answer"]
    assert "Account Active Flow" in payload["final_answer"]
    assert payload["tool_results"][0]["tool"] == "flow_inventory"
    assert len(payload["tool_results"][0]["result"]["items"]) == 1


def test_sf_repo_ai_ask_uses_deterministic_router_for_generic_metadata(monkeypatch):
    monkeypatch.setattr(
        app_module,
        "_deterministic_router_response",
        lambda question: app_module.AskResponse(
            intent="META_INVENTORY_LIST",
            needs_approval=False,
            tool_results=[
                {
                    "tool": "deterministic_router",
                    "args": {"question": question},
                    "result": {"ok": True, "routing_family": "meta_inventory", "handler": "GenericMetaHandler"},
                }
            ],
            final_answer="QuickAction on Account: 3",
        ),
    )
    monkeypatch.setattr(app_module, "_approval_process_inventory_response", lambda question, object_hint=None: None)
    monkeypatch.setattr(app_module, "_flow_inventory_response", lambda question, object_hint=None: None)

    response = client.post("/sf-repo-ai/ask", json={"question": "List quick actions on Account"})
    assert response.status_code == 200
    payload = response.json()
    assert payload["intent"] == "META_INVENTORY_LIST"
    assert payload["final_answer"] == "QuickAction on Account: 3"
    assert payload["tool_results"][0]["tool"] == "deterministic_router"


def test_sf_repo_ai_ask_approval_process_inventory_handles_lowercase_namespaced_object(tmp_path, monkeypatch):
    approval_dir = tmp_path / "force-app" / "main" / "default" / "approvalProcesses"
    approval_dir.mkdir(parents=True)

    approval_file = approval_dir / "SBQQ__Quote__c.NATT_Test_Approval.approvalProcess-meta.xml"
    approval_file.write_text(
        """<?xml version="1.0" encoding="UTF-8"?>
<ApprovalProcess xmlns="http://soap.sforce.com/2006/04/metadata">
    <active>true</active>
</ApprovalProcess>
""",
        encoding="utf-8",
    )

    monkeypatch.setattr(app_module, "_default_meta_root", lambda: tmp_path / "force-app" / "main" / "default")

    response = client.post("/sf-repo-ai/ask", json={"question": "list of approval process on sbqq_quote__c"})
    assert response.status_code == 200
    payload = response.json()
    assert payload["intent"] == "APPROVAL_PROCESS_INVENTORY"
    assert "Approval processes on SBQQ__Quote__c: 1" in payload["final_answer"]
    assert "SBQQ__Quote__c.NATT_Test_Approval (active=true)" in payload["final_answer"]
    assert payload["tool_results"][0]["tool"] == "approval_process_inventory"
    assert len(payload["tool_results"][0]["result"]["items"]) == 1


def test_default_target_org_alias_for_project_reads_sf_config(tmp_path):
    config_dir = tmp_path / ".sf"
    config_dir.mkdir(parents=True)
    (config_dir / "config.json").write_text(json.dumps({"target-org": "NATTQA"}), encoding="utf-8")

    assert app_module._default_target_org_alias_for_project(tmp_path) == "NATTQA"


def test_work_item_repo_file_preview_returns_content(tmp_path, monkeypatch):
    project_dir = tmp_path / "repo"
    file_path = project_dir / "force-app" / "main" / "default" / "classes" / "PromptRunnerService.cls"
    file_path.parent.mkdir(parents=True)
    file_path.write_text("public class PromptRunnerService {}", encoding="utf-8")

    class FakeStore:
        def get_work_item(self, work_item_id):
            assert work_item_id == "WI-123"
            return {
                "work_item_id": work_item_id,
                "metadata_project_dir": str(project_dir),
            }

    monkeypatch.setattr(app_module, "OrchestrationStore", lambda: FakeStore())
    response = client.get(
        "/sf-repo-ai/work-items/WI-123/repo-file",
        params={"path": "force-app/main/default/classes/PromptRunnerService.cls"},
    )
    assert response.status_code == 200
    assert "PromptRunnerService" in response.text


def test_development_run_uses_existing_plan_execution(monkeypatch):
    class FakeStore:
        def __init__(self):
            self.rows = {
                "WI-123": {
                    "work_item_id": "WI-123",
                    "story": "As a user, I want prompt rules applied.",
                    "status": "AWAITING_APPROVAL",
                    "llm_model": "gpt-oss:20b",
                    "metadata_project_dir": "/tmp/project",
                    "target_org_alias": "NATTQA",
                    "analysis_json": {"final_answer": "analysis"},
                    "impacted_components_json": [],
                    "changed_components_json": [],
                    "deployment_result_json": None,
                    "test_result_json": None,
                    "debug_result_json": None,
                    "final_summary": None,
                    "title": "Prompt Story",
                    "created_ts": "2026-04-22T00:00:00Z",
                    "updated_ts": "2026-04-22T00:00:00Z",
                }
            }

        def get_work_item(self, work_item_id):
            return self.rows[work_item_id]

        def list_executions(self, work_item_id, limit=100):
            return [
                {
                    "execution_id": "EX-PLAN",
                    "operation_type": "generate_or_update_components",
                    "status": "AWAITING_APPROVAL",
                    "request_json": {"mode": "plan_only"},
                    "result_json": {"plan": {"changes": []}},
                }
            ]

    fake_store = FakeStore()
    captured = {}

    monkeypatch.setattr(app_module, "OrchestrationStore", lambda: fake_store)
    def fake_approve_generation(work_item_id, req, api_key=""):
        captured["execution_id"] = req.execution_id
        return app_module.WorkItemGenerateResponse(
            execution_id="EX-APPLY",
            work_item_id=work_item_id,
            status="GENERATED",
            model="gpt-oss:20b",
            generation_summary="Applied changes",
            changed_components=[{"kind": "ApexClass", "name": "PromptRunnerService", "path": "force-app/main/default/classes/PromptRunnerService.cls"}],
            artifacts={"patch_summary_path": "data/work_items/WI-123/patch_summary.md"},
            validation={"status": "SUCCEEDED"},
            plan={"changes": []},
            updated_work_item=app_module._work_item_response(fake_store.get_work_item(work_item_id)),
        )

    monkeypatch.setattr(app_module, "sf_repo_ai_work_item_approve_generation", fake_approve_generation)

    response = client.post("/sf-repo-ai/development/run", json={"work_item_id": "WI-123"})
    assert response.status_code == 200
    payload = response.json()
    assert payload["generation"]["execution_id"] == "EX-APPLY"
    assert captured["execution_id"] == "EX-PLAN"
