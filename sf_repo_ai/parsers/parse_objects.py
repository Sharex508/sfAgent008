from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path


def _find_text(parent: ET.Element, local_name: str) -> str | None:
    node = parent.find(f"{{*}}{local_name}")
    if node is None or node.text is None:
        return None
    value = node.text.strip()
    return value or None


def parse_object_meta(path: Path, rel_path: str) -> tuple[dict, list[dict]]:
    tree = ET.parse(path)
    root = tree.getroot()

    object_name = path.name.replace(".object-meta.xml", "")
    object_row = {"object_name": object_name, "path": rel_path}

    fields: list[dict] = []
    for field_el in root.findall("{*}fields"):
        field_api = _find_text(field_el, "fullName")
        if not field_api:
            continue
        data_type = _find_text(field_el, "type") or ""
        formula = _find_text(field_el, "formula")
        reference_to = _find_text(field_el, "referenceTo")
        fields.append(
            {
                "object_name": object_name,
                "field_api": field_api,
                "full_name": f"{object_name}.{field_api}",
                "data_type": data_type,
                "formula": formula,
                "reference_to": reference_to,
                "path": rel_path,
            }
        )

    return object_row, fields


def parse_field_meta(path: Path, rel_path: str) -> dict | None:
    tree = ET.parse(path)
    root = tree.getroot()

    object_name = path.parent.parent.name
    field_api = _find_text(root, "fullName") or path.name.replace(".field-meta.xml", "")
    if not field_api:
        return None

    data_type = _find_text(root, "type") or ""
    formula = _find_text(root, "formula")
    reference_to = _find_text(root, "referenceTo")

    return {
        "object_name": object_name,
        "field_api": field_api,
        "full_name": f"{object_name}.{field_api}",
        "data_type": data_type,
        "formula": formula,
        "reference_to": reference_to,
        "path": rel_path,
    }
