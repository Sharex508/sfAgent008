from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

from sf_repo_ai.util import xml_local_name


def _find_text(root: ET.Element, local_name: str) -> str | None:
    node = root.find(f".//{{*}}{local_name}")
    if node is None or node.text is None:
        return None
    value = node.text.strip()
    return value or None


def _bool_or_none(value: str | None) -> int | None:
    if value is None:
        return None
    low = value.strip().lower()
    if low == "true":
        return 1
    if low == "false":
        return 0
    return None


def _infer_object_from_filename(path: Path) -> str | None:
    base = path.name.replace(".approvalProcess-meta.xml", "")
    if "." in base:
        return base.split(".", 1)[0] or None
    return None


def parse_approval_process_meta(path: Path, rel_path: str) -> dict:
    object_name: str | None = None
    active: int | None = None
    name = path.name.replace(".approvalProcess-meta.xml", "")

    try:
        tree = ET.parse(path)
        root = tree.getroot()
        name = _find_text(root, "fullName") or name
        object_name = (
            _find_text(root, "object")
            or _find_text(root, "tableEnumOrId")
            or _find_text(root, "sObject")
            or _find_text(root, "sObjectType")
        )
        active = _bool_or_none(_find_text(root, "active"))

        if not object_name:
            for node in root.iter():
                local = xml_local_name(node.tag)
                if local in {"object", "tableEnumOrId", "sObject", "sObjectType"} and node.text:
                    text = node.text.strip()
                    if text:
                        object_name = text
                        break
    except Exception:
        pass

    if not object_name:
        object_name = _infer_object_from_filename(path)

    return {
        "name": name,
        "object_name": object_name,
        "active": active,
        "path": rel_path,
    }

