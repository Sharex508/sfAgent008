from __future__ import annotations

import json
import xml.etree.ElementTree as ET
from pathlib import Path

from sf_repo_ai.util import xml_local_name


def _find_text(parent: ET.Element, local_name: str) -> str | None:
    node = parent.find(f"{{*}}{local_name}")
    if node is None or node.text is None:
        return None
    value = node.text.strip()
    return value or None


def _object_from_filename(path: Path) -> str:
    return path.name.replace(".sharingRules-meta.xml", "")


def parse_sharing_rules_meta(path: Path, rel_path: str) -> dict:
    object_name = _object_from_filename(path)
    rows: list[dict] = []
    refs: list[dict] = []

    try:
        tree = ET.parse(path)
        root = tree.getroot()
    except Exception:
        return {
            "object_name": object_name,
            "rows": rows,
            "references": refs,
        }

    refs.append(
        {
            "ref_type": "OBJECT",
            "ref_key": object_name,
            "src_type": "SHARING_RULE",
            "src_name": object_name,
            "src_path": rel_path,
            "line_start": None,
            "line_end": None,
            "snippet": f"SharingRules for {object_name}",
            "confidence": 0.9,
        }
    )

    for child in root:
        rule_type = xml_local_name(child.tag)
        if "rules" not in rule_type.lower():
            continue

        name = _find_text(child, "fullName") or f"{rule_type}_unnamed"
        access_level = _find_text(child, "accessLevel")
        label = _find_text(child, "label")
        description = _find_text(child, "description")

        criteria_fields = []
        for item in child.findall("{*}criteriaItems"):
            field_name = _find_text(item, "field")
            if not field_name:
                continue
            criteria_fields.append(field_name)
            if "." in field_name:
                ref_key = field_name
                confidence = 0.85
            else:
                ref_key = f"{object_name}.{field_name}"
                confidence = 0.8
            refs.append(
                {
                    "ref_type": "FIELD",
                    "ref_key": ref_key,
                    "src_type": "SHARING_RULE",
                    "src_name": name,
                    "src_path": rel_path,
                    "line_start": None,
                    "line_end": None,
                    "snippet": f"{rule_type} criteria field {field_name}",
                    "confidence": confidence,
                }
            )

        shared_to = {}
        shared_to_node = child.find("{*}sharedTo")
        if shared_to_node is not None:
            for n in shared_to_node:
                local = xml_local_name(n.tag)
                value = (n.text or "").strip()
                if value:
                    shared_to[local] = value

        rows.append(
            {
                "name": name,
                "object_name": object_name,
                "rule_type": rule_type,
                "access_level": access_level,
                "active": None,
                "path": rel_path,
                "extra_json": json.dumps(
                    {
                        "label": label,
                        "description": description,
                        "criteria_fields": criteria_fields,
                        "shared_to": shared_to,
                    },
                    ensure_ascii=True,
                ),
            }
        )

    # Deduplicate references by key to keep index compact.
    dedup: dict[tuple[str, str, str], dict] = {}
    for ref in refs:
        k = (ref["ref_type"], ref["ref_key"], ref["src_name"])
        existing = dedup.get(k)
        if existing is None or (ref["confidence"] or 0.0) > (existing["confidence"] or 0.0):
            dedup[k] = ref

    return {
        "object_name": object_name,
        "rows": rows,
        "references": list(dedup.values()),
    }

