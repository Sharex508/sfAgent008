from __future__ import annotations

import re
from pathlib import Path

from sf_repo_ai.util import read_text

METHOD_RE = re.compile(r"\b(public|private|global|protected)\b[^\n;{}]*\(", re.IGNORECASE)
SOQL_IN_LOOP_RE = re.compile(r"for\s*\([^)]*\)\s*\{[^{}]{0,5000}\bselect\b[^{}]{0,5000}\bfrom\b", re.IGNORECASE | re.DOTALL)
DML_IN_LOOP_RE = re.compile(r"for\s*\([^)]*\)\s*\{[^{}]{0,5000}\b(insert|update|upsert|delete)\b", re.IGNORECASE | re.DOTALL)


def _loc(text: str) -> int:
    return sum(1 for line in text.splitlines() if line.strip())


def generate_apex_techdebt(repo_root: Path, sfdx_root: str) -> dict:
    classes_dir = repo_root / sfdx_root / "classes"
    rows: list[dict] = []

    if classes_dir.exists():
        for path in classes_dir.glob("*.cls"):
            text = read_text(path)
            loc = _loc(text)
            method_count = len(METHOD_RE.findall(text))
            soql_in_loop = bool(SOQL_IN_LOOP_RE.search(text))
            dml_in_loop = bool(DML_IN_LOOP_RE.search(text))
            hardcoded_endpoint = "https://" in text or "http://" in text
            smell_score = (
                (4 if soql_in_loop else 0)
                + (4 if dml_in_loop else 0)
                + (3 if hardcoded_endpoint else 0)
                + min(5, loc // 400)
            )
            rows.append(
                {
                    "class_name": path.stem,
                    "path": path.as_posix(),
                    "loc": loc,
                    "method_count": method_count,
                    "soql_in_loop": soql_in_loop,
                    "dml_in_loop": dml_in_loop,
                    "hardcoded_endpoint": hardcoded_endpoint,
                    "smell_score": smell_score,
                }
            )

    top_by_loc = sorted(rows, key=lambda r: r["loc"], reverse=True)[:20]
    top_by_smell = sorted(rows, key=lambda r: (r["smell_score"], r["loc"]), reverse=True)[:20]

    return {
        "total_classes_scanned": len(rows),
        "top_20_by_loc": top_by_loc,
        "top_20_by_smell": top_by_smell,
    }
