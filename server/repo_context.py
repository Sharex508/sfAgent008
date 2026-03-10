from __future__ import annotations

from typing import List, Tuple

from repo_index import build_context, ensure_indexes, retrieve_docs
from repo_insights import summary_from_prompt


def auto_context(
    prompt: str,
    *,
    max_lines: int = 400,
    k: int = 8,
    hybrid: bool = True,
) -> Tuple[List[str], str]:
    """Return context lines and a label describing the chosen strategy."""
    if not prompt:
        return [], "empty"

    summary = summary_from_prompt(prompt)
    if summary:
        return summary.splitlines()[:max_lines], "computed"

    ensure_indexes()
    docs = retrieve_docs(prompt, k=k, hybrid=hybrid)
    context = build_context(docs, max_lines=max_lines)
    source = f"vector(k={k}, hybrid={hybrid})"
    return context, source
