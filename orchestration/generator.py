from __future__ import annotations

import json
import os
import py_compile
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple
from xml.etree import ElementTree

from llm.ollama_client import OllamaClient
from retrieval.vector_store import search_metadata


MAX_CONTEXT_CHARS = int(os.getenv("GENERATION_MAX_CONTEXT_CHARS", "12000"))
MAX_EDITABLE_FILE_BYTES = int(os.getenv("GENERATION_MAX_EDITABLE_FILE_BYTES", "50000"))
MAX_DIRECTORY_FILES = int(os.getenv("GENERATION_MAX_DIRECTORY_FILES", "8"))


@dataclass
class GenerationTarget:
    kind: str
    name: str
    path: str
    absolute_path: Path
    exists: bool
    is_dir: bool
    content_preview: str
    warnings: List[str]


@dataclass
class GenerationResult:
    model: str
    status: str
    generation_summary: str
    changed_components: List[Dict[str, Any]]
    artifacts: Dict[str, str]
    validation: Dict[str, Any]
    plan: Dict[str, Any]


def _merge_status(current: str, new: str) -> str:
    ranked = {"FAILED": 3, "TIMEOUT": 3, "SUCCEEDED": 2, "SKIPPED": 1}
    current_rank = ranked.get(current, 0)
    new_rank = ranked.get(new, 0)
    if max(current_rank, new_rank) >= 3:
        return "FAILED"
    if max(current_rank, new_rank) == 2:
        return "SUCCEEDED"
    return "SKIPPED"


def _extract_json_object(text: str) -> Dict[str, Any]:
    raw = (text or "").strip()
    if not raw:
        raise ValueError("Model returned empty output")

    fence = re.search(r"```(?:json)?\s*(\{.*\})\s*```", raw, re.DOTALL | re.IGNORECASE)
    if fence:
        raw = fence.group(1).strip()

    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict):
            return parsed
    except json.JSONDecodeError:
        pass

    start = raw.find("{")
    end = raw.rfind("}")
    if start >= 0 and end > start:
        parsed = json.loads(raw[start : end + 1])
        if isinstance(parsed, dict):
            return parsed

    raise ValueError("Unable to parse JSON object from model output")


def _safe_resolve(project_dir: Path, path_value: str) -> Path:
    candidate = Path(path_value)
    resolved = candidate.resolve() if candidate.is_absolute() else (project_dir / candidate).resolve()
    if project_dir not in resolved.parents and resolved != project_dir:
        raise ValueError(f"Resolved path escapes project directory: {path_value}")
    return resolved


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def _directory_preview(path: Path) -> Tuple[str, List[str]]:
    warnings: List[str] = []
    snippets: List[str] = []
    files = [p for p in sorted(path.rglob("*")) if p.is_file()]
    if len(files) > MAX_DIRECTORY_FILES:
        warnings.append(
            f"Directory has {len(files)} files; preview limited to first {MAX_DIRECTORY_FILES} files for safe generation."
        )
    for idx, file_path in enumerate(files[:MAX_DIRECTORY_FILES]):
        try:
            rel = file_path.relative_to(path.parent)
        except ValueError:
            rel = file_path.name
        text = _read_text(file_path)
        snippets.append(f"FILE: {rel}\n{text[:max(512, MAX_CONTEXT_CHARS // max(1, MAX_DIRECTORY_FILES))]}")
    return "\n\n".join(snippets)[:MAX_CONTEXT_CHARS], warnings


def _file_preview(path: Path) -> Tuple[str, List[str]]:
    warnings: List[str] = []
    size = path.stat().st_size if path.exists() else 0
    if size > MAX_EDITABLE_FILE_BYTES:
        warnings.append(
            f"File is {size} bytes; automatic full rewrite is disabled above {MAX_EDITABLE_FILE_BYTES} bytes."
        )
    text = _read_text(path) if path.exists() else ""
    return text[:MAX_CONTEXT_CHARS], warnings


def _build_target(project_dir: Path, component: Dict[str, Any]) -> Optional[GenerationTarget]:
    path_value = str(component.get("path") or "").strip()
    if not path_value:
        return None
    absolute_path = _safe_resolve(project_dir, path_value)
    exists = absolute_path.exists()
    is_dir = absolute_path.is_dir()
    warnings: List[str] = []
    if exists:
        if is_dir:
            preview, extra = _directory_preview(absolute_path)
            warnings.extend(extra)
        else:
            preview, extra = _file_preview(absolute_path)
            warnings.extend(extra)
    else:
        preview = ""
        warnings.append("Target path does not exist locally.")
    return GenerationTarget(
        kind=str(component.get("kind") or "Unknown"),
        name=str(component.get("name") or absolute_path.name),
        path=path_value,
        absolute_path=absolute_path,
        exists=exists,
        is_dir=is_dir,
        content_preview=preview,
        warnings=warnings,
    )


def _lookup_component(project_dir: Path, component: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    kind = str(component.get("kind") or "").strip()
    name = str(component.get("name") or "").strip()
    if not name:
        return None
    query = f"{kind} {name}".strip()
    hits = search_metadata(query, k=5, hybrid=True)
    for hit in hits:
        if kind and hit.kind != kind:
            continue
        if hit.name == name or hit.name.endswith(name):
            return {"kind": hit.kind, "name": hit.name, "path": hit.path}
    if hits:
        hit = hits[0]
        return {"kind": hit.kind, "name": hit.name, "path": hit.path}
    return None


def load_generation_targets(
    *,
    project_dir: Path,
    impacted_components: Optional[List[Dict[str, Any]]] = None,
    target_components: Optional[List[Dict[str, Any]]] = None,
    max_targets: int = 12,
) -> Tuple[List[GenerationTarget], List[str]]:
    warnings: List[str] = []
    raw_targets = target_components or impacted_components or []
    resolved: List[GenerationTarget] = []
    seen: set[str] = set()

    for item in raw_targets:
        comp = dict(item)
        if not str(comp.get("path") or "").strip():
            looked_up = _lookup_component(project_dir, comp)
            if looked_up:
                comp.update(looked_up)
            else:
                warnings.append(f"Could not resolve path for component {comp.get('kind')}:{comp.get('name')}")
                continue

        target = _build_target(project_dir, comp)
        if not target:
            continue
        key = str(target.absolute_path).lower()
        if key in seen:
            continue
        seen.add(key)
        resolved.append(target)
        if len(resolved) >= max_targets:
            warnings.append(f"Target list truncated to {max_targets} components.")
            break
    return resolved, warnings


def _format_target_block(targets: List[GenerationTarget]) -> str:
    lines: List[str] = []
    for idx, target in enumerate(targets, start=1):
        lines.append(f"{idx}. kind={target.kind} name={target.name} path={target.path} exists={target.exists} is_dir={target.is_dir}")
        if target.warnings:
            for warning in target.warnings:
                lines.append(f"   warning: {warning}")
        if target.content_preview:
            lines.append("   preview:")
            lines.append(target.content_preview[:MAX_CONTEXT_CHARS])
    return "\n".join(lines)


def build_generation_plan(
    *,
    ollama: OllamaClient,
    story: str,
    analysis: Optional[Dict[str, Any]],
    targets: List[GenerationTarget],
    instructions: Optional[str],
    create_missing_components: bool,
) -> Dict[str, Any]:
    analysis_text = json.dumps(analysis or {}, ensure_ascii=False, indent=2)
    target_block = _format_target_block(targets)
    prompt = (
        "You are a senior Salesforce engineer.\n"
        "Produce a precise implementation plan for component changes.\n"
        "You must return JSON only.\n"
        "Schema:\n"
        "{\n"
        '  "summary": "short summary",\n'
        '  "changes": [\n'
        "    {\n"
        '      "kind": "component kind",\n'
        '      "name": "component name",\n'
        '      "path": "existing target path",\n'
        '      "action": "update|create|skip",\n'
        '      "reason": "why",\n'
        '      "files": [\n'
        "        {\n"
        '          "path": "project-relative file path",\n'
        '          "action": "update|create",\n'
        '          "purpose": "what this file change does"\n'
        "        }\n"
        "      ]\n"
        "    }\n"
        "  ]\n"
        "}\n"
        "Rules:\n"
        "- Prefer changing existing files over creating new ones.\n"
        "- Do not invent org-specific assumptions that are not present in the input.\n"
        "- If a component is too large or risky, mark action=skip and explain why.\n"
        f"- create_missing_components={str(bool(create_missing_components)).lower()}.\n\n"
        f"USER STORY:\n{story}\n\n"
        f"ANALYSIS:\n{analysis_text}\n\n"
        f"INSTRUCTIONS:\n{instructions or 'None'}\n\n"
        f"TARGETS:\n{target_block}\n"
    )
    plan = _extract_json_object(ollama.chat(prompt))
    if not isinstance(plan.get("changes"), list):
        plan["changes"] = []
    return plan


def _language_hint(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix in {".cls", ".trigger"}:
        return "Apex"
    if suffix == ".js":
        return "JavaScript"
    if suffix == ".html":
        return "HTML"
    if suffix == ".xml":
        return "XML"
    if suffix == ".json":
        return "JSON"
    if suffix == ".py":
        return "Python"
    if suffix == ".css":
        return "CSS"
    if suffix == ".md":
        return "Markdown"
    return "plain text"


def generate_file_content(
    *,
    ollama: OllamaClient,
    project_dir: Path,
    story: str,
    instructions: Optional[str],
    target: Dict[str, Any],
    analysis: Optional[Dict[str, Any]],
) -> Dict[str, Any]:
    rel_path = str(target.get("path") or "").strip()
    abs_path = _safe_resolve(project_dir, rel_path)
    existing_content = _read_text(abs_path) if abs_path.exists() and abs_path.is_file() else ""
    size = abs_path.stat().st_size if abs_path.exists() and abs_path.is_file() else 0
    if size > MAX_EDITABLE_FILE_BYTES:
        raise ValueError(f"Refusing to auto-rewrite large file {rel_path} ({size} bytes)")

    prompt = (
        f"You are editing a {_language_hint(abs_path)} file in a Salesforce repository.\n"
        "Return JSON only with this schema:\n"
        '{ "path": "<same path>", "content": "<full new file content>", "summary": "<short summary>" }\n'
        "Rules:\n"
        "- Return the full new file content, not a diff.\n"
        "- Preserve behavior not mentioned in the story.\n"
        "- Keep the file valid for its language or metadata type.\n"
        "- Use ASCII unless the existing file already requires otherwise.\n\n"
        f"USER STORY:\n{story}\n\n"
        f"ANALYSIS:\n{json.dumps(analysis or {}, ensure_ascii=False, indent=2)}\n\n"
        f"INSTRUCTIONS:\n{instructions or 'None'}\n\n"
        f"TARGET FILE:\n{rel_path}\n"
        f"PURPOSE:\n{target.get('purpose') or ''}\n"
        f"ACTION:\n{target.get('action') or 'update'}\n\n"
        "EXISTING CONTENT:\n"
        f"{existing_content[:MAX_CONTEXT_CHARS]}\n"
    )
    result = _extract_json_object(ollama.chat(prompt))
    result["path"] = rel_path
    return result


def validate_generated_files(project_dir: Path, changed_files: List[Dict[str, Any]]) -> Dict[str, Any]:
    checks: List[Dict[str, Any]] = []
    overall = "SKIPPED"
    for item in changed_files:
        path = _safe_resolve(project_dir, str(item.get("path") or ""))
        suffix = path.suffix.lower()
        if not path.exists() or not path.is_file():
            checks.append({"name": str(path), "status": "FAILED", "message": "Generated file missing"})
            overall = _merge_status(overall, "FAILED")
            continue
        try:
            if suffix == ".xml":
                ElementTree.fromstring(_read_text(path))
                checks.append({"name": str(path), "status": "SUCCEEDED", "message": "XML parsed"})
                overall = _merge_status(overall, "SUCCEEDED")
            elif suffix == ".json":
                json.loads(_read_text(path))
                checks.append({"name": str(path), "status": "SUCCEEDED", "message": "JSON parsed"})
                overall = _merge_status(overall, "SUCCEEDED")
            elif suffix == ".py":
                py_compile.compile(str(path), doraise=True)
                checks.append({"name": str(path), "status": "SUCCEEDED", "message": "Python compiled"})
                overall = _merge_status(overall, "SUCCEEDED")
            else:
                checks.append({"name": str(path), "status": "SKIPPED", "message": f"No generic validator for {suffix or 'no extension'}"})
        except Exception as exc:
            overall = _merge_status(overall, "FAILED")
            checks.append({"name": str(path), "status": "FAILED", "message": str(exc)})
    return {"status": overall, "checks": checks}


def _normalize_deploy_path(project_dir: Path, path: Path) -> str:
    relative = path.relative_to(project_dir)
    parts = relative.parts
    for bundle_dir in ("lwc", "aura"):
        if bundle_dir in parts:
            idx = parts.index(bundle_dir)
            if len(parts) > idx + 1:
                return str(Path(*parts[: idx + 2]))
    return str(relative)


def validate_generated_files_with_org(
    *,
    project_dir: Path,
    changed_files: List[Dict[str, Any]],
    run_local_validation: bool,
    run_org_validation: bool,
    target_org_alias: Optional[str],
    org_validation_test_level: Optional[str],
) -> Dict[str, Any]:
    validation = (
        validate_generated_files(project_dir, changed_files)
        if run_local_validation
        else {"status": "SKIPPED", "checks": []}
    )

    if not run_org_validation:
        return validation

    if not changed_files:
        validation["checks"].append(
            {
                "name": "salesforce_org_validation",
                "status": "SKIPPED",
                "message": "No changed files available for org validation.",
            }
        )
        return validation

    if not target_org_alias:
        validation["checks"].append(
            {
                "name": "salesforce_org_validation",
                "status": "SKIPPED",
                "message": "No target_org_alias configured on the work item.",
            }
        )
        return validation

    source_dirs: List[str] = []
    seen: set[str] = set()
    for item in changed_files:
        rel_path = str(item.get("path") or "").strip()
        if not rel_path:
            continue
        deploy_item = _normalize_deploy_path(project_dir, _safe_resolve(project_dir, rel_path))
        key = deploy_item.lower()
        if key not in seen:
            seen.add(key)
            source_dirs.append(deploy_item)

    if not source_dirs:
        validation["checks"].append(
            {
                "name": "salesforce_org_validation",
                "status": "SKIPPED",
                "message": "Could not determine deployable source paths for changed files.",
            }
        )
        return validation

    from orchestration.cli import deploy_start

    wait_minutes = max(5, int(os.getenv("GENERATION_ORG_VALIDATION_WAIT_MINUTES", "15")))
    result = deploy_start(
        target_org=target_org_alias,
        project_dir=project_dir,
        source_dirs=source_dirs,
        wait_minutes=wait_minutes,
        dry_run=True,
        ignore_conflicts=True,
        test_level=org_validation_test_level,
    )
    org_status = "SUCCEEDED" if result.status == "SUCCEEDED" else "FAILED"
    message = "Salesforce dry-run deployment validation succeeded."
    if org_status == "FAILED":
        message = (result.stderr or result.stdout or "Salesforce org validation failed.").strip()
    validation["checks"].append(
        {
            "name": "salesforce_org_validation",
            "status": org_status,
            "message": message[:4000],
            "target_org_alias": target_org_alias,
            "source_dirs": source_dirs,
            "command": result.command,
        }
    )
    validation["status"] = _merge_status(str(validation.get("status") or "SKIPPED"), org_status)
    return validation


def generate_or_update_components(
    *,
    project_dir: Path,
    work_item: Dict[str, Any],
    model: Optional[str],
    mode: str,
    target_components: Optional[List[Dict[str, Any]]],
    instructions: Optional[str],
    create_missing_components: bool,
    run_local_validation: bool,
    run_org_validation: bool,
    org_validation_test_level: Optional[str],
    write_changes: bool,
    artifact_root: Path,
    target_org_alias: Optional[str] = None,
    plan_override: Optional[Dict[str, Any]] = None,
    max_targets: int = 12,
) -> GenerationResult:
    artifact_root.mkdir(parents=True, exist_ok=True)
    ollama = OllamaClient(
        host=os.getenv("OLLAMA_HOST", "http://localhost:11434"),
        model=model or str(work_item.get("llm_model") or os.getenv("OLLAMA_MODEL", "gpt-oss:20b")),
    )

    targets, load_warnings = load_generation_targets(
        project_dir=project_dir,
        impacted_components=work_item.get("impacted_components_json"),
        target_components=target_components,
        max_targets=max_targets,
    )
    if not targets:
        raise ValueError("No generation targets could be resolved.")

    if plan_override is not None:
        plan = json.loads(json.dumps(plan_override))
        if not isinstance(plan.get("changes"), list):
            plan["changes"] = []
    else:
        plan = build_generation_plan(
            ollama=ollama,
            story=str(work_item.get("story") or ""),
            analysis=work_item.get("analysis_json"),
            targets=targets,
            instructions=instructions,
            create_missing_components=create_missing_components,
        )
    plan["load_warnings"] = load_warnings
    plan_path = artifact_root / "generation_plan.json"
    plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding="utf-8")

    changed_components: List[Dict[str, Any]] = []
    validation = {"status": "SKIPPED", "checks": []}
    patch_lines: List[str] = []

    effective_write = bool(write_changes) and mode != "plan_only"
    if effective_write:
        changed_root = artifact_root / "generated_files"
        backup_root = artifact_root / "backups"
        changed_root.mkdir(parents=True, exist_ok=True)
        backup_root.mkdir(parents=True, exist_ok=True)
        for change in plan.get("changes", []):
            for file_target in change.get("files") or []:
                file_result = generate_file_content(
                    ollama=ollama,
                    project_dir=project_dir,
                    story=str(work_item.get("story") or ""),
                    instructions=instructions,
                    target=file_target,
                    analysis=work_item.get("analysis_json"),
                )
                rel_path = str(file_result.get("path") or file_target.get("path") or "")
                abs_path = _safe_resolve(project_dir, rel_path)
                abs_path.parent.mkdir(parents=True, exist_ok=True)

                if abs_path.exists() and abs_path.is_file():
                    backup_path = backup_root / rel_path
                    backup_path.parent.mkdir(parents=True, exist_ok=True)
                    backup_path.write_text(_read_text(abs_path), encoding="utf-8")

                new_content = str(file_result.get("content") or "")
                abs_path.write_text(new_content, encoding="utf-8")

                snapshot_path = changed_root / rel_path
                snapshot_path.parent.mkdir(parents=True, exist_ok=True)
                snapshot_path.write_text(new_content, encoding="utf-8")

                changed_components.append(
                    {
                        "kind": str(change.get("kind") or "Unknown"),
                        "name": str(change.get("name") or rel_path),
                        "path": rel_path,
                        "action": str(file_target.get("action") or change.get("action") or "update"),
                        "purpose": str(file_target.get("purpose") or ""),
                        "summary": str(file_result.get("summary") or ""),
                    }
                )
                patch_lines.append(f"- {file_target.get('action') or 'update'} `{rel_path}`: {file_result.get('summary') or ''}")

        validation = validate_generated_files_with_org(
            project_dir=project_dir,
            changed_files=changed_components,
            run_local_validation=run_local_validation,
            run_org_validation=run_org_validation,
            target_org_alias=target_org_alias,
            org_validation_test_level=org_validation_test_level,
        )

    patch_summary_path = artifact_root / "patch_summary.md"
    patch_summary_path.write_text(
        "\n".join(patch_lines) if patch_lines else "No files were written. Plan only or no actionable changes.",
        encoding="utf-8",
    )

    summary = str(plan.get("summary") or "")
    if load_warnings:
        summary = (summary + "\nWarnings: " + "; ".join(load_warnings)).strip()

    status = "AWAITING_APPROVAL" if mode == "plan_only" or not effective_write else "GENERATED"
    if effective_write and validation.get("status") == "FAILED":
        status = "GENERATION_FAILED"

    return GenerationResult(
        model=ollama.model,
        status=status,
        generation_summary=summary,
        changed_components=changed_components,
        artifacts={
            "generation_plan_path": str(plan_path),
            "patch_summary_path": str(patch_summary_path),
        },
        validation=validation,
        plan=plan,
    )
