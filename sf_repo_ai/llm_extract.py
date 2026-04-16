from __future__ import annotations

from dataclasses import asdict
import json
import os
import re

import requests

from sf_repo_ai.query_interpreter import ParsedQuery


def _extract_json_blob(text: str) -> dict | None:
    text = (text or "").strip()
    if not text:
        return None

    try:
        obj = json.loads(text)
        if isinstance(obj, dict):
            return obj
    except Exception:
        pass

    m = re.search(r"\{.*\}", text, flags=re.DOTALL)
    if not m:
        return None
    try:
        obj = json.loads(m.group(0))
        return obj if isinstance(obj, dict) else None
    except Exception:
        return None


def llm_extract(question: str, known_objects: list[str], known_fields_sample: list[str]) -> ParsedQuery:
    base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434").rstrip("/")
    model = os.getenv("OLLAMA_GEN_MODEL", "gpt-oss:20b")

    objects_preview = ", ".join(known_objects[:200])
    fields_preview = ", ".join(known_fields_sample[:200])

    prompt = f"""
You are an intent/entity extractor for Salesforce metadata search.
Return ONLY JSON. No prose.
Use this exact schema:
{{
  "intent": "field_where_used|flows_update_field|endpoint_callers|validation_rules|explain_object|impact_object|impact_field|unknown",
  "object_name": "",
  "field_name": "",
  "full_field_name": "",
  "endpoint": "",
  "contains": ""
}}

Known objects (subset):
{objects_preview}

Known fields sample (subset):
{fields_preview}

Question:
{question}
""".strip()

    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.0, "top_p": 0.1},
    }

    try:
        resp = requests.post(f"{base_url}/api/generate", json=payload, timeout=90)
        resp.raise_for_status()
        body = resp.json()
    except Exception:
        return ParsedQuery(intent="unknown", raw_question=question, confidence=0.0)

    response_text = body.get("response", "")
    data = _extract_json_blob(response_text)
    if not data:
        return ParsedQuery(intent="unknown", raw_question=question, confidence=0.0)

    parsed = ParsedQuery(
        intent=str(data.get("intent") or "unknown"),
        object_name=(str(data.get("object_name")) or None),
        field_name=(str(data.get("field_name")) or None),
        full_field_name=(str(data.get("full_field_name")) or None),
        endpoint=(str(data.get("endpoint")) or None),
        contains=(str(data.get("contains")) or None),
        raw_question=question,
        confidence=0.55,
    )

    # Normalize blank strings to None.
    for k, v in asdict(parsed).items():
        if isinstance(v, str) and not v.strip():
            setattr(parsed, k, None if k != "intent" else "unknown")

    return parsed
