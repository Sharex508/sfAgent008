from __future__ import annotations

from collections import Counter
from pathlib import Path
import re
import xml.etree.ElementTree as ET
from typing import Any

from sf_repo_ai.util import read_text, xml_local_name
from repo_runtime import repo_roots


def _repo_roots() -> list[Path]:
    return repo_roots()


def _resolve_rel_path(rel_path: str) -> Path | None:
    rp = (rel_path or "").strip()
    if not rp:
        return None
    p = Path(rp)
    if p.is_absolute() and p.exists():
        return p
    for root in _repo_roots():
        cand = root / rp
        if cand.exists():
            return cand
    return None


def _line_snippets(text: str, patterns: list[str], limit: int = 8) -> list[str]:
    lines = text.splitlines()
    hits: list[str] = []
    if not lines:
        return hits
    for i, line in enumerate(lines, start=1):
        low = line.lower()
        if any(p.lower() in low for p in patterns):
            snippet = line.strip()
            if len(snippet) > 220:
                snippet = snippet[:217] + "..."
            hits.append(f"{i}: {snippet}")
            if len(hits) >= limit:
                break
    return hits


def _first_text(root: ET.Element, tag: str) -> str | None:
    for el in root.iter():
        if xml_local_name(el.tag).lower() == tag.lower():
            txt = (el.text or "").strip()
            if txt:
                return txt
    return None


def _all_texts(root: ET.Element, tag: str, max_items: int = 20) -> list[str]:
    out: list[str] = []
    for el in root.iter():
        if xml_local_name(el.tag).lower() != tag.lower():
            continue
        txt = (el.text or "").strip()
        if txt:
            out.append(txt)
            if len(out) >= max_items:
                break
    return out


def _generic_xml_facts(root: ET.Element) -> list[str]:
    tags = [xml_local_name(el.tag) for el in root.iter()]
    counts = Counter(tags)
    top = sorted(counts.items(), key=lambda x: (-x[1], x[0]))[:15]
    return [f"Tag {name}: {count}" for name, count in top]


def _record_type_facts(root: ET.Element) -> list[str]:
    facts: list[str] = []
    for key in ("label", "active", "description", "businessProcess"):
        val = _first_text(root, key)
        if val:
            facts.append(f"{key}: {val}")
    return facts


def _validation_rule_facts(root: ET.Element) -> list[str]:
    facts: list[str] = []
    for key in ("active", "errorConditionFormula", "errorMessage", "description"):
        val = _first_text(root, key)
        if val:
            facts.append(f"{key}: {val}")
    return facts


def _field_facts(root: ET.Element) -> list[str]:
    facts: list[str] = []
    for key in ("label", "type", "required", "length", "precision", "scale"):
        val = _first_text(root, key)
        if val:
            facts.append(f"{key}: {val}")
    values = _all_texts(root, "fullName", max_items=60)
    if values:
        facts.append(f"valueSet entries (sample): {', '.join(values[:8])}")
    return facts


def _list_view_facts(root: ET.Element) -> list[str]:
    facts: list[str] = []
    scope = _first_text(root, "filterScope")
    if scope:
        facts.append(f"filterScope: {scope}")
    cols = _all_texts(root, "columns", max_items=200)
    if cols:
        facts.append(f"columns count: {len(cols)}")
    return facts


def _layout_facts(root: ET.Element) -> list[str]:
    tags = [xml_local_name(el.tag) for el in root.iter()]
    counts = Counter(tags)
    facts = [
        f"layoutSections count: {counts.get('layoutSections', 0)}",
        f"layoutItems count: {counts.get('layoutItems', 0)}",
        f"relatedLists count: {counts.get('relatedLists', 0)}",
        f"quickActionListItems count: {counts.get('quickActionListItems', 0)}",
    ]
    return facts


def _sharing_rule_facts(root: ET.Element) -> list[str]:
    tags = [xml_local_name(el.tag) for el in root.iter()]
    counts = Counter(tags)
    facts = [
        f"sharingCriteriaRules count: {counts.get('sharingCriteriaRules', 0)}",
        f"sharingOwnerRules count: {counts.get('sharingOwnerRules', 0)}",
        f"sharingGuestRules count: {counts.get('sharingGuestRules', 0)}",
    ]
    return facts


def _security_facts(root: ET.Element) -> list[str]:
    tags = [xml_local_name(el.tag) for el in root.iter()]
    counts = Counter(tags)
    return [
        f"systemPermissions entries: {counts.get('userPermissions', 0)}",
        f"objectPermissions entries: {counts.get('objectPermissions', 0)}",
        f"fieldPermissions entries: {counts.get('fieldPermissions', 0)}",
    ]


def explain_metadata_file(
    *,
    type_key: str,
    path: str,
    name: str,
    object_name: str | None = None,
    max_chars: int = 200000,
) -> dict[str, Any]:
    resolved = _resolve_rel_path(path)
    if not resolved:
        return {
            "answer_lines": [f"{type_key}: {name}", "Not found in repo index"],
            "evidence": [],
            "items": [],
            "count": 0,
            "error": "file not found in repo",
        }
    text = read_text(resolved)
    if not text:
        return {
            "answer_lines": [f"{type_key}: {name}", f"Path: {path}", "File could not be read"],
            "evidence": [{"path": path, "line_no": None, "snippet": ""}],
            "items": [],
            "count": 0,
            "error": "file could not be read",
        }

    if len(text) > max_chars:
        text = text[:max_chars]

    lines = [f"{type_key}: {name}", f"Path: {path}"]
    if object_name:
        lines.append(f"Object: {object_name}")

    facts: list[str] = []
    snippets = _line_snippets(text, [type_key, name, "fullName", "label", "active", "criteria", "error", "field"], limit=10)

    root: ET.Element | None = None
    try:
        root = ET.fromstring(text)
    except ET.ParseError:
        root = None

    if root is not None:
        tk = type_key.lower()
        if tk == "recordtype":
            facts = _record_type_facts(root)
        elif tk == "validationrule":
            facts = _validation_rule_facts(root)
        elif tk == "field":
            facts = _field_facts(root)
        elif tk == "listview":
            facts = _list_view_facts(root)
        elif tk == "layout":
            facts = _layout_facts(root)
        elif tk == "sharingrules":
            facts = _sharing_rule_facts(root)
        elif tk in {"permissionset", "profile"}:
            facts = _security_facts(root)
        if not facts:
            facts = _generic_xml_facts(root)
    else:
        lines.append("XML parsing failed; showing text snippets only")

    if facts:
        lines.append("Key facts:")
        lines.extend(f"- {f}" for f in facts[:15])

    evidence = [{"path": path, "line_no": None, "snippet": s, "confidence": 1.0} for s in snippets[:10]]
    if not evidence:
        evidence = [{"path": path, "line_no": None, "snippet": f"{type_key} metadata file", "confidence": 0.9}]

    return {
        "answer_lines": lines,
        "evidence": evidence,
        "items": [{"name": name, "path": path, "type_key": type_key, "object_name": object_name}],
        "count": 1,
    }

