from __future__ import annotations

import json
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PROJECT_DIR = Path(os.getenv("SF_SFDX_PROJECT_DIR", str(ROOT / "NATTQA-ENV"))).resolve()


@dataclass
class CliCommandResult:
    command: str
    workdir: str
    exit_code: int
    status: str
    stdout: str
    stderr: str
    data: Optional[Dict[str, Any]]


def default_project_dir() -> Path:
    return DEFAULT_PROJECT_DIR


def _run_sf(
    args: List[str],
    *,
    workdir: Optional[Path] = None,
    env_overrides: Optional[Dict[str, str]] = None,
    timeout_sec: int = 1800,
) -> CliCommandResult:
    actual_workdir = Path(workdir or ROOT).resolve()
    env = os.environ.copy()
    if env_overrides:
        env.update({k: v for k, v in env_overrides.items() if v is not None})

    final_args = list(args)
    if "--json" not in final_args:
        final_args.append("--json")

    command = ["cmd", "/c", "npx", "@salesforce/cli", *final_args]
    try:
        proc = subprocess.run(
            command,
            cwd=str(actual_workdir),
            env=env,
            capture_output=True,
            text=True,
            timeout=timeout_sec,
        )
        data: Optional[Dict[str, Any]] = None
        stdout = proc.stdout or ""
        stderr = proc.stderr or ""
        for candidate in (stdout, stderr):
            text = (candidate or "").strip()
            if not text:
                continue
            try:
                parsed = json.loads(text)
                if isinstance(parsed, dict):
                    data = parsed
                    break
            except json.JSONDecodeError:
                continue
        return CliCommandResult(
            command=subprocess.list2cmdline(command),
            workdir=str(actual_workdir),
            exit_code=int(proc.returncode),
            status="SUCCEEDED" if proc.returncode == 0 else "FAILED",
            stdout=stdout,
            stderr=stderr,
            data=data,
        )
    except subprocess.TimeoutExpired as exc:
        return CliCommandResult(
            command=subprocess.list2cmdline(command),
            workdir=str(actual_workdir),
            exit_code=124,
            status="TIMEOUT",
            stdout=exc.stdout or "",
            stderr=exc.stderr or f"Timed out after {timeout_sec} seconds",
            data=None,
        )


def list_orgs(*, all_orgs: bool = True) -> CliCommandResult:
    args = ["org", "list"]
    if all_orgs:
        args.append("--all")
    return _run_sf(args, workdir=ROOT, timeout_sec=300)


def login_access_token(
    *,
    alias: str,
    instance_url: str,
    access_token: str,
    set_default: bool = False,
    set_default_dev_hub: bool = False,
) -> CliCommandResult:
    args = [
        "org",
        "login",
        "access-token",
        "--instance-url",
        instance_url,
        "--alias",
        alias,
        "--no-prompt",
    ]
    if set_default:
        args.append("--set-default")
    if set_default_dev_hub:
        args.append("--set-default-dev-hub")
    return _run_sf(args, workdir=ROOT, env_overrides={"SF_ACCESS_TOKEN": access_token}, timeout_sec=300)


def deploy_start(
    *,
    target_org: str,
    project_dir: Optional[Path] = None,
    source_dirs: Optional[List[str]] = None,
    metadata: Optional[List[str]] = None,
    manifest: Optional[str] = None,
    wait_minutes: int = 30,
    api_version: Optional[str] = None,
    dry_run: bool = False,
    ignore_conflicts: bool = False,
    ignore_warnings: bool = False,
    ignore_errors: bool = False,
    test_level: Optional[str] = None,
    tests: Optional[List[str]] = None,
) -> CliCommandResult:
    args = ["project", "deploy", "start", "--target-org", target_org, "--wait", str(max(1, wait_minutes))]
    if api_version:
        args.extend(["--api-version", api_version])
    if dry_run:
        args.append("--dry-run")
    if ignore_conflicts:
        args.append("--ignore-conflicts")
    if ignore_warnings:
        args.append("--ignore-warnings")
    if ignore_errors:
        args.append("--ignore-errors")
    if manifest:
        args.extend(["--manifest", manifest])
    elif metadata:
        for item in metadata:
            args.extend(["--metadata", item])
    elif source_dirs:
        for item in source_dirs:
            args.extend(["--source-dir", item])
    if test_level:
        args.extend(["--test-level", test_level])
    if tests:
        for item in tests:
            args.extend(["--tests", item])
    return _run_sf(args, workdir=project_dir or DEFAULT_PROJECT_DIR, timeout_sec=max(1800, wait_minutes * 60 + 300))


def retrieve_start(
    *,
    target_org: str,
    project_dir: Optional[Path] = None,
    source_dirs: Optional[List[str]] = None,
    metadata: Optional[List[str]] = None,
    manifest: Optional[str] = None,
    output_dir: Optional[str] = None,
    wait_minutes: int = 33,
    api_version: Optional[str] = None,
    ignore_conflicts: bool = False,
) -> CliCommandResult:
    args = ["project", "retrieve", "start", "--target-org", target_org, "--wait", str(max(1, wait_minutes))]
    if api_version:
        args.extend(["--api-version", api_version])
    if ignore_conflicts:
        args.append("--ignore-conflicts")
    if output_dir:
        args.extend(["--output-dir", output_dir])
    if manifest:
        args.extend(["--manifest", manifest])
    elif metadata:
        for item in metadata:
            args.extend(["--metadata", item])
    elif source_dirs:
        for item in source_dirs:
            args.extend(["--source-dir", item])
    return _run_sf(args, workdir=project_dir or DEFAULT_PROJECT_DIR, timeout_sec=max(1800, wait_minutes * 60 + 300))


def apex_run_test(
    *,
    target_org: str,
    project_dir: Optional[Path] = None,
    wait_minutes: int = 30,
    test_level: Optional[str] = None,
    tests: Optional[List[str]] = None,
    class_names: Optional[List[str]] = None,
    suite_names: Optional[List[str]] = None,
    code_coverage: bool = True,
    detailed_coverage: bool = False,
    synchronous: bool = False,
    api_version: Optional[str] = None,
    output_dir: Optional[str] = None,
) -> CliCommandResult:
    args = ["apex", "run", "test", "--target-org", target_org, "--wait", str(max(1, wait_minutes))]
    if api_version:
        args.extend(["--api-version", api_version])
    if output_dir:
        args.extend(["--output-dir", output_dir])
    if test_level:
        args.extend(["--test-level", test_level])
    if code_coverage:
        args.append("--code-coverage")
    if detailed_coverage:
        args.append("--detailed-coverage")
    if synchronous:
        args.append("--synchronous")
    if tests:
        for item in tests:
            args.extend(["--tests", item])
    if class_names:
        for item in class_names:
            args.extend(["--class-names", item])
    if suite_names:
        for item in suite_names:
            args.extend(["--suite-names", item])
    return _run_sf(args, workdir=project_dir or DEFAULT_PROJECT_DIR, timeout_sec=max(1800, wait_minutes * 60 + 300))
