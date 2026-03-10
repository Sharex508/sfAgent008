from __future__ import annotations

import json
import re
import subprocess
from typing import Iterable, List, Tuple

from repo_index import ROOT_DIR, build_context, ensure_indexes, retrieve_docs


def _ollama_chat(model: str, prompt: str) -> str:
    result = subprocess.run(["ollama", "run", model], input=prompt, text=True, capture_output=True)
    if result.returncode != 0:
        raise RuntimeError(f"ollama run failed: {result.stderr}")
    return result.stdout


def _extract_json(text: str) -> dict:
    text = text.strip()
    # Try direct parse
    try:
        return json.loads(text)
    except Exception:
        pass
    # Extract first JSON object
    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end != -1 and end > start:
        return json.loads(text[start : end + 1])
    raise ValueError("No JSON object found")


def plan_queries(prompt: str, model: str, max_queries: int = 4) -> List[str]:
    planner_prompt = (
        "You are a repo search planner. Return ONLY JSON with a list of search queries. "
        "No prose.\n\n"
        "Schema: {\"queries\": [\"...\", \"...\"]}\n\n"
        f"User question: {prompt}\n"
        f"Return 1 to {max_queries} focused queries."
    )
    try:
        plan_text = _ollama_chat(model, planner_prompt)
        data = _extract_json(plan_text)
        queries = data.get("queries") or []
        return [q for q in queries if isinstance(q, str) and q.strip()]
    except Exception:
        return [prompt]


def retrieve_fast(prompt: str, *, k: int, hybrid: bool, max_lines: int) -> Tuple[List[str], str]:
    ensure_indexes()
    docs = retrieve_docs(prompt, k=k, hybrid=hybrid)
    context = build_context(docs, max_lines=max_lines)
    return context, f"vector(k={k}, hybrid={hybrid})"


def retrieve_plan(
    prompt: str,
    *,
    model: str,
    max_queries: int,
    k: int,
    hybrid: bool,
    max_lines: int,
) -> Tuple[List[str], str, List[str]]:
    ensure_indexes()
    queries = plan_queries(prompt, model, max_queries=max_queries)
    seen = set()
    merged = []
    for q in queries:
        docs = retrieve_docs(q, k=k, hybrid=hybrid)
        for d in docs:
            if d.doc_id in seen:
                continue
            seen.add(d.doc_id)
            merged.append(d)
    context = build_context(merged, max_lines=max_lines)
    return context, f"plan(queries={len(queries)}, k={k}, hybrid={hybrid})", queries


def answer_from_context(prompt: str, context: Iterable[str], model: str) -> str:
    context_text = "\n".join(context)
    if not context_text:
        return "NOT FOUND IN REPO"
    full_prompt = (
        "You are a repo analysis assistant. Do NOT use tools or external knowledge. "
        "Use ONLY the provided context. "
        "If the answer is not explicitly in the context, reply: NOT FOUND IN REPO.\n\n"
        f"Question: {prompt}\n\n"
        f"Context snippets from {ROOT_DIR}:\n{context_text}"
    )
    return _ollama_chat(model, full_prompt)
