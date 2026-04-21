from __future__ import annotations

import json
import os
import subprocess
import sys
import threading
import time
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests

from ingestion import RepoRegistry, sync_repo_by_id
from ingestion.bitbucket_auth import connection_status as bitbucket_connection_status
from ingestion.git_sync import probe_clone_access
from repo_index import DOCS_PATH
from repo_runtime import ROOT, set_active_repo

RUNS_DIR = ROOT / "data" / "setup_runs"
LATEST_PATH = RUNS_DIR / "latest.json"
_LOCK = threading.Lock()
_THREADS: dict[str, threading.Thread] = {}


def _utc_now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _run_path(run_id: str) -> Path:
    return RUNS_DIR / f"{run_id}.json"


def _write_state(state: Dict[str, Any]) -> Dict[str, Any]:
    RUNS_DIR.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(state, indent=2, sort_keys=True)
    _run_path(state["run_id"]).write_text(payload, encoding="utf-8")
    LATEST_PATH.write_text(payload, encoding="utf-8")
    return state


def _read_state(run_id: Optional[str] = None) -> Optional[Dict[str, Any]]:
    path = _run_path(run_id) if run_id else LATEST_PATH
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def _initial_steps(start_ngrok: bool) -> List[Dict[str, Any]]:
    steps = [
        {"key": "backend_ready", "label": "Backend Workspace Ready", "status": "PENDING", "message": "Waiting to validate the running backend workspace."},
        {"key": "dependencies", "label": "Install Dependencies", "status": "PENDING", "message": "Waiting to validate and install backend Python dependencies."},
        {"key": "repo_access", "label": "Repository Access", "status": "PENDING", "message": "Waiting to validate Bitbucket or local Git access."},
        {"key": "clone_repo", "label": "Clone Salesforce Repo", "status": "PENDING", "message": "Waiting to clone or refresh the Salesforce metadata repository."},
        {"key": "build_index", "label": "Build Indexes", "status": "PENDING", "message": "Waiting to build the metadata intelligence index."},
        {"key": "build_graph", "label": "Build Dependency Graph", "status": "PENDING", "message": "Waiting to build the dependency graph."},
        {"key": "api_health", "label": "API Health Check", "status": "PENDING", "message": "Waiting to validate the running API server."},
    ]
    if start_ngrok:
        steps.append({"key": "ngrok", "label": "Start ngrok", "status": "PENDING", "message": "Waiting to start or reuse the public ngrok tunnel."})
    return steps


def _new_state(*, provider: str, clone_url: str, branch: str, name: str, start_ngrok: bool) -> Dict[str, Any]:
    run_id = str(uuid.uuid4())
    return {
        "run_id": run_id,
        "status": "NEW",
        "message": "Environment setup is ready to start.",
        "provider": provider,
        "clone_url": clone_url,
        "branch": branch,
        "name": name,
        "start_ngrok": start_ngrok,
        "created_ts": _utc_now_iso(),
        "updated_ts": _utc_now_iso(),
        "current_step": None,
        "requires_user_input": False,
        "missing_inputs": [],
        "next_actions": [],
        "active_repo_path": None,
        "health_url": None,
        "ngrok_public_url": None,
        "steps": _initial_steps(start_ngrok),
        "logs": [],
    }


def _append_log(state: Dict[str, Any], message: str) -> None:
    state.setdefault("logs", []).append({"ts": _utc_now_iso(), "message": message})


def _update_step(state: Dict[str, Any], key: str, *, status: str, message: str, details: Optional[Dict[str, Any]] = None) -> None:
    for step in state["steps"]:
        if step["key"] != key:
            continue
        step["status"] = status
        step["message"] = message
        step["updated_ts"] = _utc_now_iso()
        if status == "IN_PROGRESS":
            step["started_ts"] = step.get("started_ts") or _utc_now_iso()
            state["current_step"] = key
        if status in {"SUCCEEDED", "FAILED", "WAITING_INPUT", "SKIPPED"}:
            step["finished_ts"] = _utc_now_iso()
        if details is not None:
            step["details"] = details
        _append_log(state, f"{step['label']}: {message}")
        state["updated_ts"] = _utc_now_iso()
        return


def _set_waiting_for_input(state: Dict[str, Any], *, step_key: str, missing_inputs: List[str], message: str, next_actions: List[str]) -> Dict[str, Any]:
    state["status"] = "WAITING_INPUT"
    state["requires_user_input"] = True
    state["missing_inputs"] = missing_inputs
    state["next_actions"] = next_actions
    _update_step(state, step_key, status="WAITING_INPUT", message=message)
    return _write_state(state)


def _run_command(args: List[str], *, cwd: Path) -> Dict[str, Any]:
    proc = subprocess.run(
        args,
        cwd=str(cwd),
        capture_output=True,
        text=True,
        env=os.environ.copy(),
    )
    return {
        "returncode": proc.returncode,
        "stdout": proc.stdout or "",
        "stderr": proc.stderr or "",
        "command": " ".join(args),
    }


def _determine_health_url() -> str:
    configured = (os.getenv("SF_REPO_AI_LOCAL_URL") or "").strip()
    if configured:
        return configured.rstrip("/") + "/sf-repo-ai/health"
    port = (os.getenv("PORT") or os.getenv("UVICORN_PORT") or "8001").strip()
    return f"http://127.0.0.1:{port}/sf-repo-ai/health"


def _ngrok_api_tunnels() -> List[Dict[str, Any]]:
    try:
        response = requests.get("http://127.0.0.1:4040/api/tunnels", timeout=5)
        response.raise_for_status()
        payload = response.json()
        return payload.get("tunnels", []) or []
    except Exception:
        return []


def _ensure_ngrok(state: Dict[str, Any]) -> Dict[str, Any]:
    port = (os.getenv("PORT") or os.getenv("UVICORN_PORT") or "8001").strip()
    tunnels = _ngrok_api_tunnels()
    for tunnel in tunnels:
        public_url = str(tunnel.get("public_url") or "")
        if public_url.startswith("https://"):
            state["ngrok_public_url"] = public_url
            return {"status": "reused", "public_url": public_url}

    proc = subprocess.Popen(
        ["ngrok", "http", port],
        cwd=str(ROOT),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        env=os.environ.copy(),
    )
    for _ in range(20):
        time.sleep(1)
        tunnels = _ngrok_api_tunnels()
        for tunnel in tunnels:
            public_url = str(tunnel.get("public_url") or "")
            if public_url.startswith("https://"):
                state["ngrok_public_url"] = public_url
                return {"status": "started", "public_url": public_url, "pid": proc.pid}
    raise RuntimeError("ngrok did not expose a public HTTPS tunnel on http://127.0.0.1:4040.")


def _prepare_repo_source(state: Dict[str, Any]) -> Dict[str, Any]:
    registry = RepoRegistry()
    ts = _utc_now_iso()
    clone_url = state["clone_url"]
    provider = state["provider"]
    name = state["name"] or Path(clone_url.rstrip("/")).stem.replace(".git", "")
    branch = state["branch"] or None
    local_root = ROOT / "data" / "repos" / provider / name
    source = registry.create_or_update_source(
        provider=provider,
        name=name,
        clone_url=clone_url,
        branch=branch,
        local_path=str(local_root),
        active=False,
        sync_enabled=True,
        sync_interval_minutes=1440,
        ts=ts,
    )
    state["name"] = source["name"]
    state["branch"] = source.get("branch") or state["branch"]
    return sync_repo_by_id(source["source_id"], activate=False, registry=registry)


def _activate_repo(source: Dict[str, Any]) -> Dict[str, Any]:
    registry = RepoRegistry()
    ts = _utc_now_iso()
    docs_count = 0
    if DOCS_PATH.exists():
        with DOCS_PATH.open("r", encoding="utf-8") as handle:
            docs_count = sum(1 for line in handle if line.strip())
    local_path = Path(source["local_path"]).expanduser().resolve()
    set_active_repo(local_path)
    return registry.update_source(
        source["source_id"],
        updated_ts=ts,
        is_active=1,
        last_indexed_ts=ts,
        last_index_status="SUCCEEDED",
        last_index_error=None,
        docs_count=docs_count,
    )


def _run_setup(run_id: str) -> None:
    with _LOCK:
        state = _read_state(run_id)
        if not state:
            return
        state["status"] = "IN_PROGRESS"
        state["requires_user_input"] = False
        state["missing_inputs"] = []
        state["next_actions"] = []
        _write_state(state)

    try:
        _update_step(state, "backend_ready", status="IN_PROGRESS", message="Validating the current backend workspace.")
        requirements_path = ROOT / "requirements.txt"
        if not requirements_path.exists():
            raise RuntimeError(f"requirements.txt not found at {requirements_path}")
        _update_step(state, "backend_ready", status="SUCCEEDED", message="The backend workspace is already running and ready.", details={"root": str(ROOT)})
        _write_state(state)

        _update_step(state, "dependencies", status="IN_PROGRESS", message="Installing backend dependencies from requirements.txt.")
        dep_result = _run_command([sys.executable, "-m", "pip", "install", "-r", str(requirements_path)], cwd=ROOT)
        if dep_result["returncode"] != 0:
            raise RuntimeError((dep_result["stderr"] or dep_result["stdout"] or "Dependency installation failed.").strip())
        _update_step(state, "dependencies", status="SUCCEEDED", message="Backend dependencies are installed.", details={"command": dep_result["command"]})
        _write_state(state)

        _update_step(state, "repo_access", status="IN_PROGRESS", message="Validating repository access.")
        access = probe_clone_access(clone_url=state["clone_url"], provider=state["provider"])
        auth_mode = access.get("auth_mode") or "unknown"
        access_message = access.get("message") or "Repository access validation finished."
        if not access.get("ok") and state["provider"] == "bitbucket":
            connection = bitbucket_connection_status()
            if not connection.get("connected"):
                next_actions = []
                login_url = connection.get("login_url")
                if login_url:
                    next_actions.append("Use Connect Bitbucket in the UI to complete Atlassian SSO/OAuth, then resume setup.")
                else:
                    next_actions.append("Configure backend Bitbucket OAuth or app-password credentials, or rely on local machine Git access.")
                _set_waiting_for_input(
                    state,
                    step_key="repo_access",
                    missing_inputs=["bitbucket_connection"],
                    message="Repository access requires Bitbucket authentication or working local machine Git credentials.",
                    next_actions=next_actions,
                )
                return
            auth_mode = connection.get("auth_mode") or "oauth"
            access_message = connection.get("message") or access_message
        _update_step(state, "repo_access", status="SUCCEEDED", message=access_message, details={"auth_mode": auth_mode})
        _write_state(state)

        _update_step(state, "clone_repo", status="IN_PROGRESS", message="Cloning or refreshing the Salesforce metadata repository.")
        source = _prepare_repo_source(state)
        if str(source.get("last_sync_status") or "").upper() != "SUCCEEDED":
            raise RuntimeError(str(source.get("last_sync_error") or "Repository sync failed."))
        state["active_repo_path"] = source.get("local_path")
        _update_step(state, "clone_repo", status="SUCCEEDED", message="Salesforce repository is available on the backend.", details={"local_path": source.get("local_path"), "branch": source.get("branch")})
        _write_state(state)

        _update_step(state, "build_index", status="IN_PROGRESS", message="Building the metadata intelligence index.")
        index_result = _run_command([sys.executable, "-m", "sf_repo_ai.cli", "index", "--repo", state["active_repo_path"]], cwd=ROOT)
        if index_result["returncode"] != 0:
            raise RuntimeError((index_result["stderr"] or index_result["stdout"] or "Index build failed.").strip())
        _update_step(state, "build_index", status="SUCCEEDED", message="Metadata index build completed.", details={"command": index_result["command"], "summary": index_result["stdout"].strip()[-500:]})
        _write_state(state)

        _update_step(state, "build_graph", status="IN_PROGRESS", message="Building the dependency graph.")
        graph_result = _run_command([sys.executable, "-m", "sf_repo_ai.cli", "graph-build", "--repo", state["active_repo_path"]], cwd=ROOT)
        if graph_result["returncode"] != 0:
            raise RuntimeError((graph_result["stderr"] or graph_result["stdout"] or "Dependency graph build failed.").strip())
        source = _activate_repo(source)
        _update_step(state, "build_graph", status="SUCCEEDED", message="Dependency graph build completed and repo activated.", details={"command": graph_result["command"], "summary": graph_result["stdout"].strip()[-500:]})
        _write_state(state)

        _update_step(state, "api_health", status="IN_PROGRESS", message="Validating the API server health endpoint.")
        health_url = _determine_health_url()
        state["health_url"] = health_url
        response = requests.get(health_url, timeout=10)
        response.raise_for_status()
        _update_step(state, "api_health", status="SUCCEEDED", message="API server health check succeeded.", details={"health_url": health_url, "response": response.json()})
        _write_state(state)

        if state.get("start_ngrok"):
            _update_step(state, "ngrok", status="IN_PROGRESS", message="Starting or reusing the ngrok tunnel.")
            ngrok_info = _ensure_ngrok(state)
            _update_step(state, "ngrok", status="SUCCEEDED", message="ngrok tunnel is ready.", details=ngrok_info)
            _write_state(state)

        state["status"] = "READY"
        state["message"] = "Environment setup completed successfully."
        state["requires_user_input"] = False
        state["missing_inputs"] = []
        state["next_actions"] = ["Use the active repo for analysis, prompt runs, and development flows."]
        state["updated_ts"] = _utc_now_iso()
        _write_state(state)
    except Exception as exc:
        state["status"] = "FAILED"
        state["message"] = str(exc)
        state["requires_user_input"] = False
        state["next_actions"] = ["Review the failed step details and rerun setup after fixing the issue."]
        state["updated_ts"] = _utc_now_iso()
        current_step = state.get("current_step")
        if current_step:
            _update_step(state, current_step, status="FAILED", message=str(exc))
        _write_state(state)


def start_environment_setup(
    *,
    provider: str,
    clone_url: Optional[str],
    branch: Optional[str],
    name: Optional[str],
    start_ngrok: bool = True,
) -> Dict[str, Any]:
    state = _new_state(
        provider=(provider or "bitbucket").strip().lower(),
        clone_url=(clone_url or "").strip(),
        branch=(branch or "").strip(),
        name=(name or "").strip(),
        start_ngrok=bool(start_ngrok),
    )
    if not state["clone_url"]:
        state["status"] = "WAITING_INPUT"
        state["message"] = "Repository URL is required before setup can start."
        state["requires_user_input"] = True
        state["missing_inputs"] = ["clone_url"]
        state["next_actions"] = ["Enter the Salesforce repository clone URL and start setup again."]
        _update_step(state, "repo_access", status="WAITING_INPUT", message="Repository URL is required.")
        return _write_state(state)

    _write_state(state)
    thread = threading.Thread(target=_run_setup, args=(state["run_id"],), daemon=True)
    _THREADS[state["run_id"]] = thread
    thread.start()
    return state


def continue_environment_setup(
    *,
    run_id: str,
    provider: Optional[str] = None,
    clone_url: Optional[str] = None,
    branch: Optional[str] = None,
    name: Optional[str] = None,
    start_ngrok: Optional[bool] = None,
) -> Dict[str, Any]:
    state = _read_state(run_id)
    if not state:
        raise KeyError(f"Environment setup run not found: {run_id}")
    if provider is not None:
        state["provider"] = provider.strip().lower()
    if clone_url is not None:
        state["clone_url"] = clone_url.strip()
    if branch is not None:
        state["branch"] = branch.strip()
    if name is not None:
        state["name"] = name.strip()
    if start_ngrok is not None:
        state["start_ngrok"] = bool(start_ngrok)
    state["message"] = "Environment setup resumed."
    state["requires_user_input"] = False
    state["missing_inputs"] = []
    state["next_actions"] = []
    state["updated_ts"] = _utc_now_iso()
    _write_state(state)
    thread = threading.Thread(target=_run_setup, args=(run_id,), daemon=True)
    _THREADS[run_id] = thread
    thread.start()
    return state


def get_environment_setup_status(run_id: Optional[str] = None) -> Dict[str, Any]:
    return _read_state(run_id) or {
        "run_id": None,
        "status": "NOT_STARTED",
        "message": "Environment setup has not been started yet.",
        "steps": _initial_steps(True),
        "requires_user_input": False,
        "missing_inputs": [],
        "next_actions": ["Provide a repository URL and start environment setup."],
        "active_repo_path": None,
        "health_url": None,
        "ngrok_public_url": None,
        "logs": [],
    }
