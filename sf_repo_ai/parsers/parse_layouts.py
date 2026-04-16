from __future__ import annotations

import re
from pathlib import Path

from sf_repo_ai.util import line_range_for_span, line_snippet, read_text

EXPLICIT_FIELD = re.compile(r"\b([A-Za-z][A-Za-z0-9_]*(?:__c|__kav|__mdt)?|Account|Case|Opportunity|Contact|Lead|Order|Asset|Product2)\.([A-Za-z_][A-Za-z0-9_]*(?:__c|__r)?)\b")
FIELD_TAG = re.compile(r"<[^>]*field[^>]*>([^<]+)</[^>]*field>", re.IGNORECASE)


def parse_layout_file(path: Path, rel_path: str) -> list[dict]:
    text = read_text(path)
    refs: list[dict] = []

    layout_name = path.name.replace(".layout-meta.xml", "")
    inferred_object = layout_name.split("-", 1)[0] if "-" in layout_name else None

    for m in EXPLICIT_FIELD.finditer(text):
        key = f"{m.group(1)}.{m.group(2)}"
        ls, le = line_range_for_span(text, m.start(), m.end())
        refs.append(
            {
                "ref_type": "FIELD",
                "ref_key": key,
                "src_type": "LAYOUT",
                "src_name": layout_name,
                "src_path": rel_path,
                "line_start": ls,
                "line_end": le,
                "snippet": line_snippet(text, ls),
                "confidence": 0.9,
            }
        )

    if inferred_object:
        for m in FIELD_TAG.finditer(text):
            field = m.group(1).strip()
            if "." in field or not field:
                continue
            key = f"{inferred_object}.{field}"
            ls, le = line_range_for_span(text, m.start(), m.end())
            refs.append(
                {
                    "ref_type": "FIELD",
                    "ref_key": key,
                    "src_type": "LAYOUT",
                    "src_name": layout_name,
                    "src_path": rel_path,
                    "line_start": ls,
                    "line_end": le,
                    "snippet": line_snippet(text, ls),
                    "confidence": 0.7,
                }
            )

    dedup: dict[tuple[str, int], dict] = {}
    for r in refs:
        k = (r["ref_key"], r["line_start"] or 0)
        if k not in dedup or r["confidence"] > dedup[k]["confidence"]:
            dedup[k] = r
    return list(dedup.values())
