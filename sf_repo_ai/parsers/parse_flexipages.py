from __future__ import annotations

import re
from pathlib import Path

from sf_repo_ai.util import line_range_for_span, line_snippet, read_text

EXPLICIT_FIELD = re.compile(r"\b([A-Za-z][A-Za-z0-9_]*(?:__c|__kav|__mdt)?|Account|Case|Opportunity|Contact|Lead|Order|Asset|Product2)\.([A-Za-z_][A-Za-z0-9_]*(?:__c|__r)?)\b")
OBJECT_TAG = re.compile(r"<[^>]*(?:sobjectType|objectApiName)[^>]*>([^<]+)</", re.IGNORECASE)


def parse_flexipage_file(path: Path, rel_path: str) -> list[dict]:
    text = read_text(path)
    flexi_name = path.name.replace(".flexipage-meta.xml", "")
    refs: list[dict] = []

    for m in EXPLICIT_FIELD.finditer(text):
        key = f"{m.group(1)}.{m.group(2)}"
        ls, le = line_range_for_span(text, m.start(), m.end())
        refs.append(
            {
                "ref_type": "FIELD",
                "ref_key": key,
                "src_type": "FLEXIPAGE",
                "src_name": flexi_name,
                "src_path": rel_path,
                "line_start": ls,
                "line_end": le,
                "snippet": line_snippet(text, ls),
                "confidence": 0.9,
            }
        )

    for m in OBJECT_TAG.finditer(text):
        obj = m.group(1).strip()
        ls, le = line_range_for_span(text, m.start(), m.end())
        refs.append(
            {
                "ref_type": "OBJECT",
                "ref_key": obj,
                "src_type": "FLEXIPAGE",
                "src_name": flexi_name,
                "src_path": rel_path,
                "line_start": ls,
                "line_end": le,
                "snippet": line_snippet(text, ls),
                "confidence": 0.8,
            }
        )

    dedup: dict[tuple[str, str, int], dict] = {}
    for r in refs:
        k = (r["ref_type"], r["ref_key"], r["line_start"] or 0)
        if k not in dedup or r["confidence"] > dedup[k]["confidence"]:
            dedup[k] = r
    return list(dedup.values())
