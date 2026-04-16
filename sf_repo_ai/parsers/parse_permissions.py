from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path


def _find_text(parent: ET.Element, local_name: str) -> str | None:
    node = parent.find(f"{{*}}{local_name}")
    if node is None or node.text is None:
        return None
    value = node.text.strip()
    return value or None


def parse_permission_file(path: Path, rel_path: str) -> dict:
    tree = ET.parse(path)
    root = tree.getroot()

    is_permset = path.name.endswith(".permissionset-meta.xml")
    src_name = path.name.replace(".permissionset-meta.xml", "").replace(".profile-meta.xml", "")

    refs: list[dict] = []

    for fp in root.findall("{*}fieldPermissions"):
        field = _find_text(fp, "field")
        if not field:
            continue
        readable = (_find_text(fp, "readable") or "false").lower() == "true"
        editable = (_find_text(fp, "editable") or "false").lower() == "true"
        refs.append(
            {
                "ref_type": "FIELD",
                "ref_key": field,
                "src_type": "PERMISSION",
                "src_name": src_name,
                "src_path": rel_path,
                "line_start": None,
                "line_end": None,
                "snippet": f"readable={readable};editable={editable}",
                "confidence": 1.0,
            }
        )

    for op in root.findall("{*}objectPermissions"):
        obj = _find_text(op, "object")
        if not obj:
            continue
        allow_read = (_find_text(op, "allowRead") or "false").lower() == "true"
        allow_edit = (_find_text(op, "allowEdit") or "false").lower() == "true"
        modify_all = (_find_text(op, "modifyAllRecords") or "false").lower() == "true"
        view_all = (_find_text(op, "viewAllRecords") or "false").lower() == "true"
        refs.append(
            {
                "ref_type": "OBJECT",
                "ref_key": obj,
                "src_type": "PERMISSION",
                "src_name": src_name,
                "src_path": rel_path,
                "line_start": None,
                "line_end": None,
                "snippet": f"allowRead={allow_read};allowEdit={allow_edit};modifyAll={modify_all};viewAll={view_all}",
                "confidence": 1.0,
            }
        )

    return {
        "component_type": "PERMSET" if is_permset else "PROFILE",
        "component_name": src_name,
        "references": refs,
    }
