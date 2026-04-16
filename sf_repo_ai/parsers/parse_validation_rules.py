from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from pathlib import Path

STOPWORDS = {
    "AND",
    "OR",
    "NOT",
    "TRUE",
    "FALSE",
    "NULL",
    "BLANKVALUE",
    "ISBLANK",
    "ISPICKVAL",
    "PRIORVALUE",
    "TEXT",
    "CASE",
    "IF",
    "CONTAINS",
    "LEN",
    "NOW",
    "TODAY",
    "DATE",
    "DATETIMEVALUE",
    "REGEX",
    "SUBSTITUTE",
    "UPPER",
    "LOWER",
    "TRIM",
    "VALUE",
    "ROUND",
    "MIN",
    "MAX",
    "MOD",
    "ABS",
    "ISCHANGED",
    "ISNEW",
}

EXPLICIT_FIELD = re.compile(r"\b([A-Za-z][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)\b")
WORD_TOKEN = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\b")


def _find_text(parent: ET.Element, local_name: str) -> str | None:
    node = parent.find(f"{{*}}{local_name}")
    if node is None or node.text is None:
        return None
    value = node.text.strip()
    return value or None


def parse_validation_rule_meta(path: Path, rel_path: str) -> tuple[dict, list[dict]]:
    tree = ET.parse(path)
    root = tree.getroot()

    object_name = path.parent.parent.name
    rule_name = _find_text(root, "fullName") or path.name.replace(".validationRule-meta.xml", "")
    active = 1 if (_find_text(root, "active") or "false").lower() == "true" else 0
    error_condition = _find_text(root, "errorConditionFormula") or ""
    error_message = _find_text(root, "errorMessage") or ""

    vr_row = {
        "object_name": object_name,
        "rule_name": rule_name,
        "active": active,
        "error_condition": error_condition,
        "error_message": error_message,
        "path": rel_path,
    }

    refs: list[dict] = []
    seen: set[str] = set()

    for m in EXPLICIT_FIELD.finditer(error_condition):
        full_name = f"{m.group(1)}.{m.group(2)}"
        if full_name in seen:
            continue
        seen.add(full_name)
        refs.append(
            {
                "ref_type": "FIELD",
                "ref_key": full_name,
                "src_type": "VR",
                "src_name": rule_name,
                "src_path": rel_path,
                "line_start": None,
                "line_end": None,
                "snippet": error_condition[:240],
                "confidence": 0.9,
            }
        )

    for token in WORD_TOKEN.findall(error_condition):
        upper = token.upper()
        if upper in STOPWORDS:
            continue
        if token.startswith("$"):
            continue
        if token in {"null", "true", "false"}:
            continue
        if token.startswith("PRIOR"):
            continue
        if token.startswith("VLOOKUP"):
            continue
        if len(token) < 2:
            continue
        full_name = f"{object_name}.{token}"
        if full_name in seen:
            continue
        seen.add(full_name)
        refs.append(
            {
                "ref_type": "FIELD",
                "ref_key": full_name,
                "src_type": "VR",
                "src_name": rule_name,
                "src_path": rel_path,
                "line_start": None,
                "line_end": None,
                "snippet": error_condition[:240],
                "confidence": 0.6,
            }
        )

    return vr_row, refs
