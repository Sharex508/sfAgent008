from __future__ import annotations

from fastapi.testclient import TestClient

from orchestration.store import OrchestrationStore as RealStore
from server.app import app
import server.app as app_module


client = TestClient(app)


def _patch_store(monkeypatch, tmp_path):
    db_path = tmp_path / "ui-features.sqlite"

    def factory():
        return RealStore(db_path=db_path)

    monkeypatch.setattr(app_module, "OrchestrationStore", factory)
    monkeypatch.setattr(app_module, "default_project_dir", lambda: tmp_path)
    return db_path


def test_ui_feature_create_infers_components(monkeypatch, tmp_path):
    _patch_store(monkeypatch, tmp_path)
    monkeypatch.setattr(
        app_module,
        "_retrieve_components",
        lambda query_text, k, hybrid: [
            {
                "kind": "Profile",
                "name": "System Administrator",
                "path": "force-app/main/default/profiles/System Administrator.profile-meta.xml",
                "doc_id": "doc-0",
                "snippet": "noise",
            },
            {
                "kind": "Flow",
                "name": "Response_Customer_Feedback_Followup_NPS",
                "path": "force-app/main/default/flows/Response_Customer_Feedback_Followup_NPS.flow-meta.xml",
                "doc_id": "doc-1",
                "snippet": "creates follow-up case",
            }
        ],
    )

    response = client.post(
        "/sf-repo-ai/ui-features",
        json={
            "name": "NPS Feedback Regression",
            "description": "Runs the detractor case-creation scenario in Lightning.",
            "target_org_alias": "ATT Dev",
            "page_context": "Account record page",
            "metadata_project_dir": str(tmp_path),
            "steps": [
                {"name": "Open account", "action": "goto", "url": "/lightning/r/Account/001/view"},
                {"name": "Verify score", "action": "expect_text", "selector": "body", "text": "Account"},
            ],
            "infer_related_components": True,
        },
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["name"] == "NPS Feedback Regression"
    assert len(payload["related_components"]) == 1
    assert payload["related_components"][0]["component_type"] == "Flow"
    assert payload["related_components"][0]["component_name"] == "Response_Customer_Feedback_Followup_NPS"

    listed = client.get("/sf-repo-ai/ui-features")
    assert listed.status_code == 200
    assert len(listed.json()["items"]) == 1


def test_ui_feature_run_persists_results(monkeypatch, tmp_path):
    _patch_store(monkeypatch, tmp_path)

    create = client.post(
        "/sf-repo-ai/ui-features",
        json={
            "name": "NPS Feedback Regression",
            "target_org_alias": "ATT Dev",
            "metadata_project_dir": str(tmp_path),
            "steps": [
                {"name": "Open account", "action": "goto", "url": "/lightning/r/Account/001/view"},
                {"name": "Check card", "action": "expect_visible", "selector": "[data-id='nps-card']"},
            ],
        },
    )
    assert create.status_code == 200
    feature_id = create.json()["feature_id"]

    def fake_run_ui_feature_session(**kwargs):
        return {
            "status": "PASSED",
            "artifacts": {
                "video_path": str(tmp_path / "run.webm"),
                "trace_path": str(tmp_path / "trace.zip"),
                "artifact_root": str(tmp_path / "artifacts"),
            },
            "step_results": [
                {
                    "step_index": 0,
                    "step_name": "Open account",
                    "action_type": "goto",
                    "status": "PASSED",
                    "selector": None,
                    "expected_text": None,
                    "actual_text": None,
                    "screenshot_path": str(tmp_path / "shot-1.png"),
                    "error_text": None,
                    "result": {"url": "https://example.com/lightning/r/Account/001/view"},
                    "started_ts": "2026-04-30T00:00:00Z",
                    "finished_ts": "2026-04-30T00:00:01Z",
                }
            ],
        }

    monkeypatch.setattr(app_module, "run_ui_feature_session", fake_run_ui_feature_session)

    run_response = client.post(
        f"/sf-repo-ai/ui-features/{feature_id}/run",
        json={"base_url": "https://carrier.example.com", "headless": True},
    )
    assert run_response.status_code == 200
    run_payload = run_response.json()
    assert run_payload["status"] == "PASSED"
    assert run_payload["video_path"] == str(tmp_path / "run.webm")
    assert len(run_payload["step_results"]) == 1

    feature_response = client.get(f"/sf-repo-ai/ui-features/{feature_id}")
    assert feature_response.status_code == 200
    feature_payload = feature_response.json()
    assert feature_payload["last_run_status"] == "PASSED"
    assert feature_payload["last_run_id"] == run_payload["run_id"]

    runs_response = client.get(f"/sf-repo-ai/ui-features/{feature_id}/runs")
    assert runs_response.status_code == 200
    assert len(runs_response.json()["runs"]) == 1

    run_get = client.get(f"/sf-repo-ai/ui-features/{feature_id}/runs/{run_payload['run_id']}")
    assert run_get.status_code == 200
    assert run_get.json()["run_id"] == run_payload["run_id"]

    artifacts_response = client.get(f"/sf-repo-ai/ui-features/{feature_id}/runs/{run_payload['run_id']}/artifacts")
    assert artifacts_response.status_code == 200
    artifacts_payload = artifacts_response.json()
    assert artifacts_payload["run_id"] == run_payload["run_id"]
    assert artifacts_payload["video_path"] == str(tmp_path / "run.webm")
    assert artifacts_payload["trace_path"] == str(tmp_path / "trace.zip")


def test_ui_feature_run_resolves_base_url_from_org(monkeypatch, tmp_path):
    _patch_store(monkeypatch, tmp_path)

    create = client.post(
        "/sf-repo-ai/ui-features",
        json={
            "name": "NPS Feedback Regression",
            "target_org_alias": "ATT Dev",
            "metadata_project_dir": str(tmp_path),
            "steps": [
                {"name": "Open account", "action": "goto", "url": "/lightning/r/Account/001/view"},
            ],
        },
    )
    assert create.status_code == 200
    feature_id = create.json()["feature_id"]

    monkeypatch.setattr(
        app_module,
        "org_display",
        lambda **kwargs: type(
            "CliResult",
            (),
            {
                "exit_code": 0,
                "data": {"result": {"instanceUrl": "https://carrier.example.com"}},
            },
        )(),
    )

    def fake_run_ui_feature_session(**kwargs):
        assert kwargs["target_org_alias"] == "ATT Dev"
        assert kwargs["base_url"] == "https://carrier.example.com"
        return {
            "status": "PASSED",
            "artifacts": {
                "video_path": None,
                "trace_path": None,
                "artifact_root": str(tmp_path / "artifacts"),
            },
            "step_results": [],
        }

    monkeypatch.setattr(app_module, "run_ui_feature_session", fake_run_ui_feature_session)

    run_response = client.post(f"/sf-repo-ai/ui-features/{feature_id}/run", json={})
    assert run_response.status_code == 200
    assert run_response.json()["base_url"] == "https://carrier.example.com"


def test_ui_feature_run_uses_cli_frontdoor_login(monkeypatch, tmp_path):
    _patch_store(monkeypatch, tmp_path)

    create = client.post(
        "/sf-repo-ai/ui-features",
        json={
            "name": "NPS Feedback Regression",
            "target_org_alias": "ATT Dev",
            "metadata_project_dir": str(tmp_path),
            "login_mode": "cli_access_token",
            "start_url": "/lightning/o/nps_Feedback__c/list",
            "steps": [
                {"name": "Open response list", "action": "goto", "url": "/lightning/o/nps_Feedback__c/list"},
            ],
        },
    )
    assert create.status_code == 200
    feature_id = create.json()["feature_id"]

    monkeypatch.setattr(
        app_module,
        "org_display",
        lambda **kwargs: type(
            "CliResult",
            (),
            {
                "exit_code": 0,
                "data": {
                    "result": {
                        "instanceUrl": "https://carrier.example.com",
                        "accessToken": "00Dxx!token value",
                    }
                },
            },
        )(),
    )

    def fake_run_ui_feature_session(**kwargs):
        assert kwargs["target_org_alias"] == "ATT Dev"
        assert kwargs["base_url"] == "https://carrier.example.com"
        assert kwargs["start_url"].startswith("https://carrier.example.com/secur/frontdoor.jsp?sid=")
        assert "retURL=/lightning/o/nps_Feedback__c/list" in kwargs["start_url"]
        return {
            "status": "PASSED",
            "artifacts": {
                "video_path": None,
                "trace_path": None,
                "artifact_root": str(tmp_path / "artifacts"),
            },
            "step_results": [],
        }

    monkeypatch.setattr(app_module, "run_ui_feature_session", fake_run_ui_feature_session)

    run_response = client.post(f"/sf-repo-ai/ui-features/{feature_id}/run", json={})
    assert run_response.status_code == 200
    assert run_response.json()["start_url"].startswith("https://carrier.example.com/secur/frontdoor.jsp?sid=")
