from __future__ import annotations

from typing import Optional
from pydantic import BaseModel


class MetadataDoc(BaseModel):
    doc_id: str
    kind: str  # Object | Field | ApexClass | ApexTrigger | Flow | Profile | PermSet ...
    name: str
    path: str
    text: str  # cleaned text for search + LLM
    raw_snippet: Optional[str] = None


def make_doc_id(kind: str, name: str) -> str:
    return f"{kind}:{name}"
