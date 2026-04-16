from __future__ import annotations

import re
from pathlib import Path
from typing import Optional

from repo_runtime import resolve_active_repo


def _root_dir() -> Path:
    return resolve_active_repo()


def _objects_dir() -> Path:
    return _root_dir() / "force-app" / "main" / "default" / "objects"


def _classes_dir() -> Path:
    return _root_dir() / "force-app" / "main" / "default" / "classes"


def _normalize(text: str) -> str:
    return "".join(ch for ch in text.lower() if ch.isalnum())


def _has_word(text: str, word: str) -> bool:
    return re.search(rf"\b{re.escape(word)}\b", text) is not None


def _infer_object_from_prompt(prompt: str) -> Optional[str]:
    if not prompt:
        return None
    prompt_norm = _normalize(prompt)
    matches = []

    objects_dir = _objects_dir()
    if objects_dir.exists():
        for obj_dir in objects_dir.iterdir():
            if not obj_dir.is_dir():
                continue
            obj_name = obj_dir.name
            obj_norm = _normalize(obj_name)
            if obj_norm and obj_norm in prompt_norm:
                matches.append(obj_name)

    # Fallback for common standard objects even if metadata folder not present.
    standard_objects = [
        "Account",
        "Contact",
        "Case",
        "Opportunity",
        "Lead",
        "Product2",
        "Quote",
        "Order",
        "Asset",
        "Contract",
    ]
    for obj in standard_objects:
        if _has_word(prompt.lower(), obj.lower()):
            matches.append(obj)

    # Fallback for custom objects like Something__c mentioned in prompt
    custom_match = re.findall(r"\\b[A-Za-z0-9_]+__c\\b", prompt)
    matches.extend(custom_match)

    if not matches:
        return None

    matches.sort(key=len, reverse=True)
    return matches[0]


def _count_apex_classes() -> int:
    classes_dir = _classes_dir()
    if not classes_dir.exists():
        return 0
    return len(list(classes_dir.glob("*.cls")))


def _classes_referencing_object_fields(object_api: str) -> list[str]:
    classes_dir = _classes_dir()
    if not classes_dir.exists():
        return []
    pattern = re.compile(rf"\b{re.escape(object_api)}\.[A-Za-z0-9_]+")
    matches: list[str] = []
    for cls_path in classes_dir.glob("*.cls"):
        try:
            text = cls_path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        if pattern.search(text):
            matches.append(cls_path.stem)
    return sorted(set(matches))


def summary_from_prompt(prompt: str) -> str:
    """Return a computed summary for count-style repo questions, else empty string."""
    if not prompt:
        return ""
    p = prompt.lower()

    # Generic: how many apex classes
    if ("how many" in p or "count" in p) and "apex class" in p and "field" not in p:
        count = _count_apex_classes()
        return f"Apex classes count (from repo): {count}"

    # Count apex classes referencing object fields
    if ("how many" in p or _has_word(p, "count")) and "apex class" in p and "field" in p:
        object_api = _infer_object_from_prompt(prompt)
        if not object_api:
            return ""
        count = len(_classes_referencing_object_fields(object_api))
        return (
            f"Apex classes referencing {object_api} fields (repo-based): {count}\n"
            "Note: matched by pattern <Object>.<Field> in Apex classes."
        )

    if (_has_word(p, "list") or _has_word(p, "names") or _has_word(p, "show")) and "apex class" in p and "field" in p:
        object_api = _infer_object_from_prompt(prompt)
        if not object_api:
            return ""
        classes = _classes_referencing_object_fields(object_api)
        if not classes:
            return f"No Apex classes found referencing {object_api} fields."
        lines = [f"Apex classes referencing {object_api} fields (repo-based): {len(classes)}"]
        lines.extend(classes)
        return "\n".join(lines)

    return ""
