from __future__ import annotations

import os
import re
import shutil
import subprocess
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from repo_index import DOCS_PATH, ensure_indexes
from repo_runtime import MANAGED_REPOS_ROOT, set_active_repo
from repo_inventory import validate_repo_structure
from ingestion.repo_registry import RepoRegistry
from ingestion.bitbucket_auth import get_authenticated_clone_url


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def _slugify(text: str) -> str:
    value = re.sub(r"[^A-Za-z0-9._-]+", "-", text.strip()).strip("-")
    return value or "repo"


def _infer_repo_name(clone_url: str) -> str:
    cleaned = clone_url.rstrip("/")
    name = cleaned.rsplit("/", 1)[-1]
    if name.endswith(".git"):
        name = name[:-4]
    return _slugify(name)


def _provider_from_url(clone_url: str, provider: Optional[str] = None) -> str:
    if provider:
        return provider.lower()
    lowered = clone_url.lower()
    if lowered.startswith("file://") or Path(clone_url).expanduser().exists():
        return "local"
    if "bitbucket" in lowered:
        return "bitbucket"
    if "github" in lowered:
        return "github"
    if "gitlab" in lowered:
        return "gitlab"
    return "git"


def _run_git(args: List[str], *, cwd: Optional[Path] = None) -> Tuple[int, str, str]:
    proc = subprocess.run(
        ["git", *args],
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        text=True,
        env=os.environ.copy(),
    )
    return proc.returncode, proc.stdout or "", proc.stderr or ""


def probe_clone_access(*, clone_url: str, provider: Optional[str] = None) -> Dict[str, Any]:
    provider_name = _provider_from_url(clone_url, provider)
    if provider_name == "local":
        source_path = _resolve_local_source(clone_url)
        return {
            "ok": source_path.exists() and source_path.is_dir(),
            "auth_mode": "local_path",
            "message": f"Local source path {'found' if source_path.exists() else 'not found'}: {source_path}",
        }

    code, out, err = _run_git(["ls-remote", clone_url])
    if code == 0:
        return {
            "ok": True,
            "auth_mode": "local_git",
            "message": "Repository access succeeded using local machine Git credentials.",
        }

    detail = (err or out or "").strip() or "git ls-remote failed."
    return {
        "ok": False,
        "auth_mode": "unknown",
        "message": detail,
    }


def _current_commit(repo_dir: Path) -> Optional[str]:
    code, out, _ = _run_git(["rev-parse", "HEAD"], cwd=repo_dir)
    return out.strip() if code == 0 and out.strip() else None


def _resolve_local_source(source: str) -> Path:
    if source.startswith("file://"):
        return Path(source[7:]).expanduser().resolve()
    return Path(source).expanduser().resolve()


def _index_repo(repo_path: Path) -> Dict[str, Any]:
    ensure_indexes(repo_path=repo_path, rebuild=True)
    docs_count = 0
    if DOCS_PATH.exists():
        with DOCS_PATH.open("r", encoding="utf-8") as handle:
            docs_count = sum(1 for line in handle if line.strip())
    return {"docs_count": docs_count}


def clone_or_update_repo(*, clone_url: str, local_path: Path, branch: Optional[str] = None) -> Dict[str, Any]:
    local_path = Path(local_path).expanduser().resolve()
    local_path.parent.mkdir(parents=True, exist_ok=True)

    provider_name = _provider_from_url(clone_url)
    effective_clone_url = get_authenticated_clone_url(clone_url, provider_name)
    if provider_name == "local":
        source_path = _resolve_local_source(clone_url)
        if not source_path.exists() or not source_path.is_dir():
            raise RuntimeError(f"local source path not found: {source_path}")
        if local_path.exists():
            shutil.rmtree(local_path, ignore_errors=True)
        shutil.copytree(source_path, local_path)
        return {"local_path": str(local_path), "head_commit": None}

    if not local_path.exists() or not (local_path / ".git").exists():
        args = ["clone"]
        if branch:
            args.extend(["--branch", branch])
        args.extend([effective_clone_url, str(local_path)])
        code, out, err = _run_git(args)
        if code != 0:
            raise RuntimeError((err or out or f"git clone failed for {clone_url}").strip())
        if effective_clone_url != clone_url:
            _run_git(["remote", "set-url", "origin", clone_url], cwd=local_path)
    else:
        if effective_clone_url != clone_url:
            _run_git(["remote", "set-url", "origin", effective_clone_url], cwd=local_path)
        code, out, err = _run_git(["fetch", "--all", "--prune"], cwd=local_path)
        if code != 0:
            raise RuntimeError((err or out or f"git fetch failed for {local_path}").strip())
        if branch:
            _run_git(["checkout", branch], cwd=local_path)
            code, out, err = _run_git(["pull", "origin", branch], cwd=local_path)
        else:
            code, out, err = _run_git(["pull"], cwd=local_path)
        if effective_clone_url != clone_url:
            _run_git(["remote", "set-url", "origin", clone_url], cwd=local_path)
        if code != 0:
            raise RuntimeError((err or out or f"git pull failed for {local_path}").strip())

    commit = _current_commit(local_path)
    return {"local_path": str(local_path), "head_commit": commit}


def register_and_sync_repo(
    *,
    clone_url: str,
    branch: Optional[str] = None,
    provider: Optional[str] = None,
    name: Optional[str] = None,
    active: bool = False,
    sync_enabled: bool = True,
    sync_interval_minutes: int = 1440,
    registry: Optional[RepoRegistry] = None,
) -> Dict[str, Any]:
    registry = registry or RepoRegistry()
    provider_name = _provider_from_url(clone_url, provider)
    repo_name = _slugify(name or _infer_repo_name(clone_url))
    local_path = MANAGED_REPOS_ROOT / provider_name / repo_name
    ts = _utc_now_iso()

    source = registry.create_or_update_source(
        provider=provider_name,
        name=repo_name,
        clone_url=clone_url,
        branch=branch,
        local_path=str(local_path),
        active=False,
        sync_enabled=sync_enabled,
        sync_interval_minutes=sync_interval_minutes,
        ts=ts,
    )
    source = sync_repo_by_id(source["source_id"], activate=active, registry=registry)
    return source


def sync_repo_by_id(source_id: str, *, activate: bool = False, registry: Optional[RepoRegistry] = None) -> Dict[str, Any]:
    registry = registry or RepoRegistry()
    source = registry.get_source(source_id)
    repo_path = Path(source["local_path"]).expanduser().resolve()
    ts = _utc_now_iso()
    try:
        result = clone_or_update_repo(
            clone_url=source["clone_url"],
            local_path=repo_path,
            branch=source.get("branch") or None,
        )
        validation = validate_repo_structure(repo_path)
        updates: Dict[str, Any] = {
            "last_synced_ts": ts,
            "last_synced_commit": result.get("head_commit"),
            "last_sync_status": "SUCCEEDED",
            "last_sync_error": None,
            "local_path": result["local_path"],
            "repo_kind": validation.get("repo_kind"),
            "has_sfdx_project": 1 if validation.get("has_sfdx_project") else 0,
            "has_force_app": 1 if validation.get("has_force_app") else 0,
            "metadata_root": validation.get("metadata_root"),
            "validation_status": validation.get("validation_status"),
            "validation_error": validation.get("validation_error"),
            "objects_count": int(validation.get("objects_count") or 0),
            "fields_count": int(validation.get("fields_count") or 0),
            "classes_count": int(validation.get("classes_count") or 0),
            "triggers_count": int(validation.get("triggers_count") or 0),
            "flows_count": int(validation.get("flows_count") or 0),
        }
        if validation.get("validation_status") != "VALID":
            updates.update(
                {
                    "last_indexed_ts": ts,
                    "last_indexed_commit": result.get("head_commit"),
                    "last_index_status": "FAILED",
                    "last_index_error": validation.get("validation_error"),
                    "docs_count": 0,
                }
            )
            return registry.update_source(source_id, updated_ts=ts, **updates)

        if activate or int(source.get("is_active") or 0) == 1:
            index_info = _index_repo(repo_path)
            set_active_repo(repo_path)
            updates["is_active"] = 1
            updates["last_indexed_ts"] = ts
            updates["last_indexed_commit"] = result.get("head_commit")
            updates["last_index_status"] = "SUCCEEDED"
            updates["last_index_error"] = None
            updates["docs_count"] = int(index_info.get("docs_count") or 0)
        source = registry.update_source(source_id, updated_ts=ts, **updates)
        return source
    except Exception as exc:
        return registry.update_source(
            source_id,
            updated_ts=ts,
            last_synced_ts=ts,
            last_sync_status="FAILED",
            last_sync_error=str(exc),
            last_index_status="FAILED",
            last_index_error=str(exc),
        )


def sync_due_repos(*, registry: Optional[RepoRegistry] = None) -> List[Dict[str, Any]]:
    registry = registry or RepoRegistry()
    now = datetime.now(timezone.utc)
    results: List[Dict[str, Any]] = []
    for source in registry.list_sources():
        if int(source.get("sync_enabled") or 0) != 1:
            continue
        last_synced_ts = source.get("last_synced_ts")
        interval_minutes = int(source.get("sync_interval_minutes") or 1440)
        due = True
        if last_synced_ts:
            try:
                last_dt = datetime.fromisoformat(str(last_synced_ts).replace("Z", "+00:00"))
                due = now >= last_dt + timedelta(minutes=interval_minutes)
            except ValueError:
                due = True
        if due:
            results.append(sync_repo_by_id(source["source_id"], registry=registry))
    return results
