from __future__ import annotations

from fastapi.testclient import TestClient

from server.app import app
import server.app as app_module


client = TestClient(app)


def test_bitbucket_connect_status_needs_auth(monkeypatch):
    monkeypatch.delenv("BITBUCKET_ACCESS_TOKEN", raising=False)
    monkeypatch.delenv("BITBUCKET_TOKEN", raising=False)
    monkeypatch.delenv("BITBUCKET_OAUTH_TOKEN", raising=False)
    monkeypatch.delenv("BITBUCKET_USERNAME", raising=False)
    monkeypatch.delenv("BITBUCKET_APP_PASSWORD", raising=False)
    monkeypatch.setenv("BITBUCKET_CONNECT_URL", "https://bitbucket.example.com/connect")

    response = client.get("/sf-repo-ai/repos/connect/bitbucket/status")
    assert response.status_code == 200
    payload = response.json()
    assert payload["provider"] == "bitbucket"
    assert payload["connected"] is False
    assert payload["status"] == "needs_auth"
    assert payload["login_url"] == "https://bitbucket.example.com/connect"


def test_repo_initialize_reports_missing_inputs(monkeypatch):
    monkeypatch.delenv("BITBUCKET_ACCESS_TOKEN", raising=False)
    monkeypatch.delenv("BITBUCKET_TOKEN", raising=False)
    monkeypatch.delenv("BITBUCKET_OAUTH_TOKEN", raising=False)
    monkeypatch.delenv("BITBUCKET_USERNAME", raising=False)
    monkeypatch.delenv("BITBUCKET_APP_PASSWORD", raising=False)
    monkeypatch.setenv("BITBUCKET_CONNECT_URL", "https://bitbucket.example.com/connect")

    response = client.post("/sf-repo-ai/repos/initialize", json={"provider": "bitbucket"})
    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "MISSING_INPUTS"
    assert "clone_url" in payload["missing_inputs"]
    assert "bitbucket_connection" in payload["missing_inputs"]


def test_repo_initialize_prefers_local_git_access(monkeypatch):
    monkeypatch.delenv("BITBUCKET_ACCESS_TOKEN", raising=False)
    monkeypatch.delenv("BITBUCKET_TOKEN", raising=False)
    monkeypatch.delenv("BITBUCKET_OAUTH_TOKEN", raising=False)
    monkeypatch.delenv("BITBUCKET_USERNAME", raising=False)
    monkeypatch.delenv("BITBUCKET_APP_PASSWORD", raising=False)
    monkeypatch.delenv("BITBUCKET_CONNECT_URL", raising=False)

    monkeypatch.setattr(app_module, "probe_clone_access", lambda **kwargs: {
        "ok": True,
        "auth_mode": "local_git",
        "message": "ok",
    })

    captured = {}

    def fake_register_and_sync_repo(**kwargs):
        captured.update(kwargs)
        return {
            "source_id": "src-local",
            "provider": kwargs["provider"],
            "name": kwargs["name"],
            "clone_url": kwargs["clone_url"],
            "branch": kwargs.get("branch"),
            "local_path": "/tmp/repos/bitbucket/demo",
            "is_active": 1,
            "sync_enabled": 1,
            "sync_interval_minutes": kwargs.get("sync_interval_minutes", 1440),
            "repo_kind": "sfdx",
            "has_sfdx_project": 1,
            "has_force_app": 1,
            "metadata_root": "/tmp/repos/bitbucket/demo/force-app/main/default",
            "validation_status": "VALID",
            "validation_error": None,
            "last_synced_ts": "2026-04-17T00:00:00+00:00",
            "last_synced_commit": "abc123",
            "last_sync_status": "SUCCEEDED",
            "last_sync_error": None,
            "last_indexed_ts": "2026-04-17T00:01:00+00:00",
            "last_indexed_commit": "abc123",
            "last_index_status": "SUCCEEDED",
            "last_index_error": None,
            "docs_count": 10,
            "objects_count": 2,
            "fields_count": 5,
            "classes_count": 1,
            "triggers_count": 0,
            "flows_count": 1,
            "cleanup_exempt": 0,
            "created_ts": "2026-04-17T00:00:00+00:00",
            "updated_ts": "2026-04-17T00:01:00+00:00",
        }

    monkeypatch.setattr(app_module, "register_and_sync_repo", fake_register_and_sync_repo)

    response = client.post(
        "/sf-repo-ai/repos/initialize",
        json={
            "provider": "bitbucket",
            "clone_url": "https://bitbucket.org/workspace/demo.git",
            "branch": "main",
            "name": "demo-project"
        },
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "INITIALIZED"
    assert captured["clone_url"] == "https://bitbucket.org/workspace/demo.git"


def test_repo_initialize_returns_source_when_ready(monkeypatch):
    monkeypatch.setenv("BITBUCKET_ACCESS_TOKEN", "token-123")

    captured = {}

    def fake_register_and_sync_repo(**kwargs):
        captured.update(kwargs)
        return {
            "source_id": "src-1",
            "provider": kwargs["provider"],
            "name": kwargs["name"],
            "clone_url": kwargs["clone_url"],
            "branch": kwargs.get("branch"),
            "local_path": "/tmp/repos/bitbucket/demo",
            "is_active": 1,
            "sync_enabled": 1,
            "sync_interval_minutes": kwargs.get("sync_interval_minutes", 1440),
            "repo_kind": "sfdx",
            "has_sfdx_project": 1,
            "has_force_app": 1,
            "metadata_root": "/tmp/repos/bitbucket/demo/force-app/main/default",
            "validation_status": "VALID",
            "validation_error": None,
            "last_synced_ts": "2026-04-17T00:00:00+00:00",
            "last_synced_commit": "abc123",
            "last_sync_status": "SUCCEEDED",
            "last_sync_error": None,
            "last_indexed_ts": "2026-04-17T00:01:00+00:00",
            "last_indexed_commit": "abc123",
            "last_index_status": "SUCCEEDED",
            "last_index_error": None,
            "docs_count": 10,
            "objects_count": 2,
            "fields_count": 5,
            "classes_count": 1,
            "triggers_count": 0,
            "flows_count": 1,
            "cleanup_exempt": 0,
            "created_ts": "2026-04-17T00:00:00+00:00",
            "updated_ts": "2026-04-17T00:01:00+00:00",
        }

    monkeypatch.setattr(app_module, "register_and_sync_repo", fake_register_and_sync_repo)

    response = client.post(
        "/sf-repo-ai/repos/initialize",
        json={
            "provider": "bitbucket",
            "clone_url": "https://bitbucket.org/workspace/demo.git",
            "branch": "atlasqa",
            "name": "demo-project"
        },
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "INITIALIZED"
    assert payload["source"]["name"] == "demo-project"
    assert captured["provider"] == "bitbucket"
    assert captured["branch"] == "atlasqa"


def test_environment_setup_status_default(monkeypatch):
    monkeypatch.setattr(app_module, "get_environment_setup_status", lambda run_id=None, project_namespace=None: {
        "run_id": None,
        "project_namespace": project_namespace,
        "status": "NOT_STARTED",
        "message": "Environment setup has not been started yet.",
        "steps": [],
        "backend_reachable": True,
        "run_exists": False,
        "backend_instance": "test-host",
        "requires_user_input": False,
        "missing_inputs": [],
        "next_actions": ["Provide a repository URL and start environment setup."],
        "logs": [],
    })
    response = client.get("/sf-repo-ai/setup/status")
    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "NOT_STARTED"


def test_environment_setup_start_returns_waiting_input(monkeypatch):
    monkeypatch.setattr(app_module, "start_environment_setup", lambda **kwargs: {
        "run_id": "setup-1",
        "project_namespace": kwargs.get("project_namespace"),
        "status": "WAITING_INPUT",
        "message": "Repository URL is required before setup can start.",
        "provider": "bitbucket",
        "clone_url": "",
        "branch": "",
        "name": "",
        "start_ngrok": True,
        "current_step": "repo_access",
        "backend_reachable": True,
        "run_exists": True,
        "backend_instance": "test-host",
        "requires_user_input": True,
        "missing_inputs": ["clone_url"],
        "next_actions": ["Enter the Salesforce repository clone URL and start setup again."],
        "active_repo_path": None,
        "health_url": None,
        "ngrok_public_url": None,
        "steps": [{"key": "repo_access", "label": "Repository Access", "status": "WAITING_INPUT", "message": "Repository URL is required."}],
        "logs": [],
        "created_ts": "2026-04-21T00:00:00Z",
        "updated_ts": "2026-04-21T00:00:00Z",
    })
    response = client.post("/sf-repo-ai/setup/start", json={"provider": "bitbucket"})
    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "WAITING_INPUT"
    assert payload["missing_inputs"] == ["clone_url"]


def test_project_environment_setup_status_uses_namespace(monkeypatch):
    monkeypatch.setattr(app_module, "get_environment_setup_status", lambda run_id=None, project_namespace=None: {
        "run_id": None,
        "project_namespace": project_namespace,
        "status": "NO_ACTIVE_RUN",
        "message": "No active setup run for this project.",
        "steps": [],
        "backend_reachable": True,
        "run_exists": False,
        "backend_instance": "test-host",
        "requires_user_input": False,
        "missing_inputs": [],
        "next_actions": [],
        "logs": [],
    })
    response = client.get("/sf-repo-ai/projects/natt-qa/health")
    assert response.status_code == 200
    payload = response.json()
    assert payload["project_namespace"] == "natt-qa"
    assert payload["status"] == "NO_ACTIVE_RUN"
