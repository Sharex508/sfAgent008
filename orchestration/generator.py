from __future__ import annotations

import json
import os
import py_compile
import re
from dataclasses import dataclass
from pathlib import Path
from functools import lru_cache
from typing import Any, Dict, List, Optional, Set, Tuple
from xml.etree import ElementTree

from llm.ollama_client import OllamaClient
from retrieval.vector_store import search_metadata


MAX_CONTEXT_CHARS = int(os.getenv("GENERATION_MAX_CONTEXT_CHARS", "12000"))
MAX_EDITABLE_FILE_BYTES = int(os.getenv("GENERATION_MAX_EDITABLE_FILE_BYTES", "120000"))
MAX_DIRECTORY_FILES = int(os.getenv("GENERATION_MAX_DIRECTORY_FILES", "8"))
KNOWN_OBJECT_CHILD_FOLDERS = {
    "businessProcesses",
    "compactLayouts",
    "fieldSets",
    "fields",
    "listViews",
    "recordTypes",
    "validationRules",
    "webLinks",
}
CUSTOM_FIELD_PATTERN = re.compile(r"\b([A-Za-z][A-Za-z0-9_]*)__([A-Za-z0-9_]+)\b")


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
    project_dir: Path,
    story: str,
    analysis: Optional[Dict[str, Any]],
    targets: List[GenerationTarget],
    instructions: Optional[str],
    create_missing_components: bool,
    strict_target_scope: bool,
    validation_feedback: Optional[str] = None,
) -> Dict[str, Any]:
    analysis_text = json.dumps(analysis or {}, ensure_ascii=False, indent=2)
    target_block = _format_target_block(targets)
    inventory_text = _scoped_object_inventory_text(
        project_dir=project_dir,
        story=story,
        instructions=instructions,
        targets=targets,
    )
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
        "- Do not output file paths outside the supplied target components unless the dependency is explicitly proven by those targets.\n"
        "- Allowed dependency expansion is limited to metadata under the same Salesforce object as an explicit target when that object can be proven from the target path or name.\n"
        "- For Salesforce object child metadata, paths must use force-app/main/default/objects/<ObjectApi>/<childFolder>/... .\n"
        "- Never use top-level folders like force-app/main/default/validationRules or force-app/main/default/fields.\n"
        "- If a component is too large or risky, mark action=skip and explain why.\n"
        f"- create_missing_components={str(bool(create_missing_components)).lower()}.\n"
        f"- strict_target_scope={str(bool(strict_target_scope)).lower()}.\n\n"
        f"USER STORY:\n{story}\n\n"
        f"ANALYSIS:\n{analysis_text}\n\n"
        f"INSTRUCTIONS:\n{instructions or 'None'}\n\n"
        f"SCOPED INVENTORY:\n{inventory_text}\n\n"
        f"PREVIOUS VALIDATION FEEDBACK:\n{validation_feedback or 'None'}\n\n"
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


def _canonical_relative_path(project_dir: Path, path_value: str) -> str:
    return str(_safe_resolve(project_dir, path_value).relative_to(project_dir))


def _is_within(base: Path, candidate: Path) -> bool:
    return candidate == base or base in candidate.parents


def _is_companion_metadata_path(target_path: Path, candidate_path: Path) -> bool:
    if target_path.parent != candidate_path.parent:
        return False
    if target_path.name + "-meta.xml" == candidate_path.name:
        return True
    if candidate_path.name + "-meta.xml" == target_path.name:
        return True
    return False


def _matches_target_scope(candidate_path: Path, target: GenerationTarget) -> bool:
    if target.is_dir:
        return _is_within(target.absolute_path, candidate_path)
    return candidate_path == target.absolute_path or _is_companion_metadata_path(target.absolute_path, candidate_path)


def _covers_target_scope(candidate_path: Path, target: GenerationTarget) -> bool:
    if target.is_dir:
        return candidate_path == target.absolute_path or candidate_path in target.absolute_path.parents
    return candidate_path == target.absolute_path.parent or candidate_path in target.absolute_path.parents


def _extract_object_api_from_target(target: GenerationTarget) -> Optional[str]:
    parts = Path(target.path).parts
    if len(parts) >= 6 and parts[:3] == ("force-app", "main", "default") and parts[3] == "objects":
        return parts[4]

    approval_match = re.search(r"(^|/)approvalProcesses/([^/]+?)\.[^/]+\.approvalProcess-meta\.xml$", target.path)
    if approval_match:
        return approval_match.group(2)

    name_match = re.match(r"([A-Za-z0-9_]+(?:__c|__mdt)?)\..+", target.name)
    if name_match:
        return name_match.group(1)
    return None


def _allowed_dependency_roots(project_dir: Path, targets: List[GenerationTarget]) -> List[Path]:
    roots: List[Path] = []
    seen: set[str] = set()
    for target in targets:
        object_api = _extract_object_api_from_target(target)
        if not object_api:
            continue
        root = _safe_resolve(project_dir, f"force-app/main/default/objects/{object_api}")
        key = str(root).lower()
        if key not in seen:
            seen.add(key)
            roots.append(root)
    return roots


def _matches_allowed_dependency(candidate_path: Path, dependency_roots: List[Path]) -> bool:
    return any(_is_within(root, candidate_path) for root in dependency_roots)


def _object_api_from_dependency_root(project_dir: Path, root: Path) -> Optional[str]:
    try:
        parts = root.relative_to(project_dir).parts
    except ValueError:
        return None
    if len(parts) >= 5 and parts[:3] == ("force-app", "main", "default") and parts[3] == "objects":
        return parts[4]
    return None


@lru_cache(maxsize=256)
def _field_inventory_for_object(project_dir_str: str, object_api: str) -> Set[str]:
    project_dir = Path(project_dir_str)
    fields_dir = project_dir / "force-app" / "main" / "default" / "objects" / object_api / "fields"
    if not fields_dir.exists():
        return set()
    field_names: Set[str] = set()
    for field_path in fields_dir.glob("*.field-meta.xml"):
        name = field_path.name.removesuffix(".field-meta.xml")
        if name:
            field_names.add(name)
    return field_names


def _extract_custom_field_tokens(text: str) -> Set[str]:
    tokens: Set[str] = set()
    for match in CUSTOM_FIELD_PATTERN.finditer(text):
        tokens.add(match.group(0))
    return tokens


def _context_terms(text: str) -> Set[str]:
    return {token for token in re.findall(r"[A-Za-z0-9_]+", text.lower()) if len(token) >= 3}


def _rank_inventory_names(names: Set[str], context_text: str, limit: int = 20) -> List[str]:
    context_terms = _context_terms(context_text)
    scored: List[Tuple[int, str]] = []
    for name in names:
        name_terms = _context_terms(name.replace("__", "_").replace(".", "_"))
        score = len(context_terms & name_terms)
        if any(term in name.lower() for term in context_terms):
            score += 1
        scored.append((score, name))
    scored.sort(key=lambda item: (-item[0], item[1]))
    ranked = [name for score, name in scored if score > 0][:limit]
    if ranked:
        return ranked
    return [name for _, name in scored[: min(limit, len(scored))]]


def _scoped_object_inventory_text(
    *,
    project_dir: Path,
    story: str,
    instructions: Optional[str],
    targets: List[GenerationTarget],
) -> str:
    object_apis: List[str] = []
    seen: Set[str] = set()
    for target in targets:
        object_api = _extract_object_api_from_target(target)
        if object_api and object_api not in seen:
            seen.add(object_api)
            object_apis.append(object_api)

    if not object_apis:
        return "None"

    context_text = f"{story}\n{instructions or ''}"
    blocks: List[str] = []
    for object_api in object_apis:
        field_names = _field_inventory_for_object(str(project_dir), object_api)
        ranked_fields = _rank_inventory_names(field_names, context_text, limit=25)

        record_types_dir = project_dir / "force-app" / "main" / "default" / "objects" / object_api / "recordTypes"
        record_types = {p.name.removesuffix('.recordType-meta.xml') for p in record_types_dir.glob('*.recordType-meta.xml')} if record_types_dir.exists() else set()
        ranked_record_types = _rank_inventory_names(record_types, context_text, limit=12)

        validation_rules_dir = project_dir / "force-app" / "main" / "default" / "objects" / object_api / "validationRules"
        validation_rules = {p.name.removesuffix('.validationRule-meta.xml') for p in validation_rules_dir.glob('*.validationRule-meta.xml')} if validation_rules_dir.exists() else set()
        ranked_validation_rules = _rank_inventory_names(validation_rules, context_text, limit=12)

        block = [f"Object: {object_api}"]
        if ranked_fields:
            block.append("Known fields: " + ", ".join(ranked_fields))
        if ranked_record_types:
            block.append("Known record types: " + ", ".join(ranked_record_types))
        if ranked_validation_rules:
            block.append("Existing validation rules: " + ", ".join(ranked_validation_rules))
        blocks.append("\n".join(block))
    return "\n\n".join(blocks)


def _validate_plan_field_references(
    *,
    project_dir: Path,
    plan_payload: Dict[str, Any],
    targets: List[GenerationTarget],
    dependency_roots: List[Path],
) -> List[str]:
    object_apis: Set[str] = set()
    for target in targets:
        object_api = _extract_object_api_from_target(target)
        if object_api:
            object_apis.add(object_api)
    for root in dependency_roots:
        object_api = _object_api_from_dependency_root(project_dir, root)
        if object_api:
            object_apis.add(object_api)

    if not object_apis:
        return []

    known_fields: Set[str] = set()
    for object_api in object_apis:
        known_fields.update(_field_inventory_for_object(str(project_dir), object_api))

    errors: List[str] = []
    payload_text = json.dumps(plan_payload, ensure_ascii=False)
    for token in sorted(_extract_custom_field_tokens(payload_text)):
        if token in object_apis:
            continue
        if token in known_fields:
            continue
        errors.append(
            f"Unknown custom field reference `{token}` for scoped objects {', '.join(sorted(object_apis))}."
        )
    return errors


def _salesforce_dx_path_error(rel_path: str) -> Optional[str]:
    parts = Path(rel_path).parts
    if len(parts) < 4 or parts[:3] != ("force-app", "main", "default"):
        return None

    if len(parts) >= 5 and parts[3] in KNOWN_OBJECT_CHILD_FOLDERS:
        return (
            f"Invalid Salesforce DX path `{rel_path}`. `{parts[3]}` must be nested under "
            "force-app/main/default/objects/<ObjectApi>/."
        )

    if len(parts) >= 7 and parts[3] == "objects" and parts[5] in KNOWN_OBJECT_CHILD_FOLDERS:
        return None

    return None


def _validate_generation_plan(
    *,
    project_dir: Path,
    plan: Dict[str, Any],
    targets: List[GenerationTarget],
    strict_target_scope: bool,
) -> Dict[str, Any]:
    errors: List[str] = []
    matched_explicit_target = False
    normalized_changes: List[Dict[str, Any]] = []
    dependency_roots = _allowed_dependency_roots(project_dir, targets) if strict_target_scope else []

    for change_index, raw_change in enumerate(plan.get("changes") or [], start=1):
        change = dict(raw_change)
        normalized_change_path = str(change.get("path") or "").strip()
        if normalized_change_path:
            normalized_change_path = _canonical_relative_path(project_dir, normalized_change_path)
            change["path"] = normalized_change_path
            dx_error = _salesforce_dx_path_error(normalized_change_path)
            if dx_error:
                errors.append(f"Change {change_index}: {dx_error}")
            if strict_target_scope:
                candidate_abs = _safe_resolve(project_dir, normalized_change_path)
                if any(_matches_target_scope(candidate_abs, target) or _covers_target_scope(candidate_abs, target) for target in targets):
                    matched_explicit_target = True
                elif not _matches_allowed_dependency(candidate_abs, dependency_roots):
                    errors.append(
                        f"Change {change_index}: path `{normalized_change_path}` is outside the supplied target component scope and allowed dependency roots."
                    )

        normalized_files: List[Dict[str, Any]] = []
        for file_index, raw_file in enumerate(change.get("files") or [], start=1):
            file_target = dict(raw_file)
            file_path = str(file_target.get("path") or "").strip()
            if not file_path:
                errors.append(f"Change {change_index} file {file_index}: missing path.")
                continue

            normalized_file_path = _canonical_relative_path(project_dir, file_path)
            file_target["path"] = normalized_file_path
            dx_error = _salesforce_dx_path_error(normalized_file_path)
            if dx_error:
                errors.append(f"Change {change_index} file {file_index}: {dx_error}")

            if strict_target_scope:
                candidate_abs = _safe_resolve(project_dir, normalized_file_path)
                if any(_matches_target_scope(candidate_abs, target) for target in targets):
                    matched_explicit_target = True
                elif not _matches_allowed_dependency(candidate_abs, dependency_roots):
                    errors.append(
                        f"Change {change_index} file {file_index}: path `{normalized_file_path}` is outside the supplied target component scope and allowed dependency roots."
                    )
            normalized_files.append(file_target)

        change["files"] = normalized_files
        normalized_changes.append(change)

    if strict_target_scope and not matched_explicit_target:
        errors.append("Plan does not touch any of the explicitly supplied target components.")

    field_errors = _validate_plan_field_references(
        project_dir=project_dir,
        plan_payload={"changes": normalized_changes, "summary": plan.get("summary")},
        targets=targets,
        dependency_roots=dependency_roots,
    )
    errors.extend(field_errors)

    validated_plan = dict(plan)
    validated_plan["changes"] = normalized_changes
    validated_plan["allowed_dependency_roots"] = [str(root.relative_to(project_dir)) for root in dependency_roots]
    validated_plan["validation_errors"] = errors
    if errors:
        raise ValueError("Invalid generation plan: " + " | ".join(errors))
    return validated_plan


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

        ext_checks = validate_salesforce_file(path)
        for check in ext_checks:
            checks.append(check)
            overall = _merge_status(overall, str(check.get("status") or "SKIPPED"))
    return {"status": overall, "checks": checks}


def _balanced_pairs(text: str, left: str, right: str) -> bool:
    count = 0
    for ch in text:
        if ch == left:
            count += 1
        elif ch == right:
            count -= 1
            if count < 0:
                return False
    return count == 0


def _validate_apex_file(path: Path) -> List[Dict[str, Any]]:
    checks: List[Dict[str, Any]] = []
    text = _read_text(path)
    lower = text.lower()
    expected = "class" if path.suffix.lower() == ".cls" else "trigger"
    if expected not in lower:
        checks.append(
            {
                "name": str(path),
                "status": "FAILED",
                "message": f"Apex file does not appear to contain a {expected} declaration.",
            }
        )
    else:
        checks.append(
            {
                "name": str(path),
                "status": "SUCCEEDED",
                "message": f"Apex {expected} declaration detected.",
            }
        )

    if _balanced_pairs(text, "{", "}"):
        checks.append({"name": str(path), "status": "SUCCEEDED", "message": "Balanced curly braces"})
    else:
        checks.append({"name": str(path), "status": "FAILED", "message": "Unbalanced curly braces"})

    meta_path = path.with_name(path.name + "-meta.xml")
    if meta_path.exists():
        checks.append({"name": str(meta_path), "status": "SUCCEEDED", "message": "Companion metadata file exists"})
    else:
        checks.append({"name": str(meta_path), "status": "FAILED", "message": "Missing companion metadata file"})
    return checks


def _validate_lwc_bundle(path: Path) -> List[Dict[str, Any]]:
    checks: List[Dict[str, Any]] = []
    parts = list(path.parts)
    if "lwc" not in parts:
        return checks
    idx = parts.index("lwc")
    if len(parts) <= idx + 1:
        return checks
    bundle_dir = Path(*parts[: idx + 2])
    bundle_name = bundle_dir.name
    js_path = bundle_dir / f"{bundle_name}.js"
    html_path = bundle_dir / f"{bundle_name}.html"
    meta_path = bundle_dir / f"{bundle_name}.js-meta.xml"

    if js_path.exists() or html_path.exists():
        checks.append({"name": str(bundle_dir), "status": "SUCCEEDED", "message": "LWC bundle has view/controller file"})
    else:
        checks.append({"name": str(bundle_dir), "status": "FAILED", "message": "LWC bundle is missing both .js and .html files"})

    if meta_path.exists():
        checks.append({"name": str(meta_path), "status": "SUCCEEDED", "message": "LWC bundle metadata file exists"})
    else:
        checks.append({"name": str(meta_path), "status": "FAILED", "message": "LWC bundle metadata file is missing"})
    return checks


def _validate_aura_bundle(path: Path) -> List[Dict[str, Any]]:
    checks: List[Dict[str, Any]] = []
    parts = list(path.parts)
    if "aura" not in parts:
        return checks
    idx = parts.index("aura")
    if len(parts) <= idx + 1:
        return checks
    bundle_dir = Path(*parts[: idx + 2])
    cmp_files = list(bundle_dir.glob("*.cmp")) + list(bundle_dir.glob("*.app")) + list(bundle_dir.glob("*.auradoc"))
    if cmp_files:
        checks.append({"name": str(bundle_dir), "status": "SUCCEEDED", "message": "Aura bundle root file detected"})
    else:
        checks.append({"name": str(bundle_dir), "status": "FAILED", "message": "Aura bundle is missing a root component/application file"})
    return checks


def _validate_metadata_xml(path: Path) -> List[Dict[str, Any]]:
    checks: List[Dict[str, Any]] = []
    if not path.name.endswith("-meta.xml"):
        return checks
    root = ElementTree.fromstring(_read_text(path))
    tag = root.tag.split("}")[-1]
    if tag:
        checks.append({"name": str(path), "status": "SUCCEEDED", "message": f"Metadata root element detected: {tag}"})
    else:
        checks.append({"name": str(path), "status": "FAILED", "message": "Metadata XML root element is empty"})
    return checks


def validate_salesforce_file(path: Path) -> List[Dict[str, Any]]:
    suffix = path.suffix.lower()
    checks: List[Dict[str, Any]] = []
    if suffix in {".cls", ".trigger"}:
        checks.extend(_validate_apex_file(path))
    if "lwc" in path.parts:
        checks.extend(_validate_lwc_bundle(path))
    if "aura" in path.parts:
        checks.extend(_validate_aura_bundle(path))
    if suffix == ".xml":
        checks.extend(_validate_metadata_xml(path))
    return checks


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
        plan = _validate_generation_plan(
            project_dir=project_dir,
            plan=plan,
            targets=targets,
            strict_target_scope=bool(target_components),
        )
    else:
        plan_error: Optional[str] = None
        plan = None
        for attempt in range(2):
            candidate_plan = build_generation_plan(
                ollama=ollama,
                project_dir=project_dir,
                story=str(work_item.get("story") or ""),
                analysis=work_item.get("analysis_json"),
                targets=targets,
                instructions=instructions,
                create_missing_components=create_missing_components,
                strict_target_scope=bool(target_components),
                validation_feedback=plan_error,
            )
            try:
                plan = _validate_generation_plan(
                    project_dir=project_dir,
                    plan=candidate_plan,
                    targets=targets,
                    strict_target_scope=bool(target_components),
                )
                break
            except ValueError as exc:
                plan_error = str(exc)
                if attempt >= 1:
                    raise
        if plan is None:
            raise ValueError(plan_error or 'Failed to generate a valid plan.')
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
