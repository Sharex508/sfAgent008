from __future__ import annotations

import requests


def answer_with_evidence(
    *,
    base_url: str,
    model: str,
    question: str,
    evidence: str,
    temperature: float,
    top_p: float,
    timeout: int = 180,
) -> str:
    prompt = (
        "Answer only from provided evidence. Cite file paths. "
        "If not in evidence, say not found.\n\n"
        f"Question:\n{question}\n\n"
        f"Evidence:\n{evidence}\n"
    )

    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": {
            "temperature": temperature,
            "top_p": top_p,
        },
    }
    resp = requests.post(f"{base_url.rstrip('/')}/api/generate", json=payload, timeout=timeout)
    resp.raise_for_status()
    data = resp.json()
    return (data.get("response") or "").strip()
