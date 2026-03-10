from __future__ import annotations

from pathlib import Path
from typing import List

from metadata.metadata_types import MetadataDoc, make_doc_id


def _read_text(p: Path) -> str:
    try:
        return p.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def parse_apex(dir_path: Path) -> List[MetadataDoc]:
    """Parse Apex classes (*.cls) and triggers (*.trigger)."""
    docs: List[MetadataDoc] = []

    # Classes
    for p in dir_path.rglob("*.cls"):
        name = p.stem
        src = _read_text(p)
        docs.append(
            MetadataDoc(
                doc_id=make_doc_id("ApexClass", name),
                kind="ApexClass",
                name=name,
                path=str(p),
                text=src,
                raw_snippet=None,
            )
        )

    # Triggers
    for p in dir_path.rglob("*.trigger"):
        name = p.stem
        src = _read_text(p)
        docs.append(
            MetadataDoc(
                doc_id=make_doc_id("ApexTrigger", name),
                kind="ApexTrigger",
                name=name,
                path=str(p),
                text=src,
                raw_snippet=None,
            )
        )

    return docs
