from __future__ import annotations

import json
from typing import Any


SYSTEM_PROMPT = (
    "You are a Salesforce metadata/code reviewer.\n"
    "Use ONLY the evidence pack provided.\n"
    "Do not invent components, fields, behavior, or file paths.\n"
    "If unknown, say: Not found in repo evidence.\n"
    "Cite file paths in parentheses when asserting details.\n"
)

PLANNER_SYSTEM_PROMPT = (
    "You are a deterministic query planner for Salesforce repo analysis.\n"
    "Return ONLY JSON. No prose, no markdown fences.\n"
    "Never invent targets or intents not grounded in the question.\n"
    "Use at most 8 subqueries and prefer minimal coverage.\n"
)


def build_user_prompt(*, question: str, evidence_pack: dict[str, Any]) -> str:
    payload = {
        "question": question,
        "evidence_pack": evidence_pack,
    }
    return (
        "Answer the question using only this evidence pack.\n"
        "Output concise markdown bullets with path citations.\n\n"
        f"{json.dumps(payload, indent=2)}"
    )


def build_planner_prompt(
    *,
    question: str,
    resolved: dict[str, Any],
    repo_summary: dict[str, Any],
) -> str:
    skeleton = {
        "targets": [{"kind": "OBJECT|FIELD|COMPONENT", "name": "..."}],
        "subqueries": [
            {"tool": "ask_internal", "intent": "flows_write_field", "args": {"field": "Account.Status__c"}},
            {"tool": "ask_internal", "intent": "apex_write_field", "args": {"field": "Account.Status__c"}},
        ],
        "focus": ["dependencies", "blast_radius", "security", "tests"],
        "notes": "",
    }
    payload = {
        "question": question,
        "resolved": resolved,
        "repo_summary": repo_summary,
        "required_schema": skeleton,
    }
    return (
        "Return JSON only, matching required_schema keys.\n"
        "tool must be ask_internal.\n"
        "Keep subqueries minimal and <= 8.\n"
        "Prefer intents supported by deterministic router.\n\n"
        f"{json.dumps(payload, indent=2)}"
    )
