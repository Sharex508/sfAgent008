from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

from repo_index import ensure_indexes
from retrieval.vector_store import search_metadata
from sfdc.client import (
    SalesforceClient,
    tool_bulk_emailmessages,
    tool_create_record,
    tool_get_record,
    tool_soql,
    tool_update_record,
)
from llm.ollama_client import OllamaClient

DEFAULT_DOCS_PATH = Path("./data/metadata/docs.jsonl")
_INDEX_READY = False


@dataclass
class ToolCall:
    tool: str
    args: Dict[str, Any]


@dataclass
class ActionPlan:
    intent: str
    tool_calls: List[ToolCall]
    needs_approval: bool = False


def _ensure_metadata_ready(persist_dir: Path) -> None:
    """
    Ensure docs.jsonl + vector DB exist before metadata search.
    This prevents users from having to run a manual indexing command.
    """
    global _INDEX_READY
    if _INDEX_READY and DEFAULT_DOCS_PATH.exists() and persist_dir.exists():
        return
    ensure_indexes(docs_path=DEFAULT_DOCS_PATH, db_path=persist_dir, rebuild=False)
    _INDEX_READY = True


def parse_plan(plan_json: str) -> ActionPlan:
    # Extract JSON if it's wrapped in markdown blocks
    cleaned = plan_json.strip()
    if "```" in cleaned:
        # Simple extraction logic: take everything between the first ```json and the next ```
        # or just between the first and last ```
        if "```json" in cleaned:
            cleaned = cleaned.split("```json")[1].split("```")[0].strip()
        else:
            cleaned = cleaned.split("```")[1].split("```")[0].strip()
    
    try:
        data = json.loads(cleaned)
    except json.JSONDecodeError:
        # If it still fails, try to find the first { and last }
        start = cleaned.find("{")
        end = cleaned.rfind("}")
        if start != -1 and end != -1:
            cleaned = cleaned[start:end+1]
            data = json.loads(cleaned)
        else:
            raise
            
    tool_calls = [ToolCall(tc["tool"], tc.get("args", {})) for tc in data.get("tool_calls", [])]
    return ActionPlan(intent=data.get("intent", ""), tool_calls=tool_calls, needs_approval=data.get("needs_approval", False))


def execute_tool(
    call: ToolCall,
    *,
    sf_client: Optional[SalesforceClient] = None,
    persist_dir: Path = Path("./data/chroma"),
) -> Dict[str, Any]:
    """Dispatch a single tool call."""
    try:
        if call.tool == "search_metadata":
            _ensure_metadata_ready(persist_dir)
            res = search_metadata(
                call.args.get("query", ""),
                k=call.args.get("k", 8),
                persist_dir=persist_dir,
                hybrid=call.args.get("hybrid", False),
            )
            # Keep results compact for LLM consumption
            return {
                "ok": True,
                "results": [
                    {"doc_id": d.doc_id, "kind": d.kind, "name": d.name, "path": d.path} for d in res
                ],
            }
        elif call.tool == "soql":
            res = tool_soql(call.args["query"], client=sf_client)
            return {"ok": True, "result": res}
        elif call.tool == "get_record":
            res = tool_get_record(call.args["object_api"], call.args["record_id"], call.args.get("fields"), client=sf_client)
            return {"ok": True, "result": res}
        elif call.tool == "create_record":
            res = tool_create_record(
                call.args["object_api"], call.args.get("payload", {}), dry_run=call.args.get("dry_run", True), client=sf_client
            )
            return {"ok": True, "result": res}
        elif call.tool == "update_record":
            res = tool_update_record(
                call.args["object_api"],
                call.args["record_id"],
                call.args.get("payload", {}),
                dry_run=call.args.get("dry_run", True),
                client=sf_client,
            )
            return {"ok": True, "result": res}
        elif call.tool == "bulk_emailmessages":
            res = tool_bulk_emailmessages(call.args.get("case_ids", []), client=sf_client)
            return {"ok": True, "result": res}
        else:
            return {"ok": False, "error": f"Unknown tool: {call.tool}"}
    except Exception as exc:
        return {"ok": False, "error": str(exc)}


def execute_plan(
    plan: ActionPlan,
    *,
    sf_client: Optional[SalesforceClient] = None,
    persist_dir: Path = Path("./data/chroma"),
) -> List[Dict[str, Any]]:
    results: List[Dict[str, Any]] = []
    for idx, call in enumerate(plan.tool_calls):
        result = execute_tool(call, sf_client=sf_client, persist_dir=persist_dir)
        results.append({"tool": call.tool, "args": call.args, "result": result})
    return results


# ---------- LLM (Ollama) integration helpers ----------

PLAN_PROMPT_TEMPLATE = """You are an orchestrator that returns ONLY a JSON action plan.
Schema:
{{
  "intent": "USER_STORY_ANALYSIS | RECORD_INSERT | EMAIL_TRIAGE | METADATA_QA",
  "tool_calls": [
    {{"tool": "search_metadata", "args": {{"query": "<string>", "k": 8}}}},
    {{"tool": "soql", "args": {{"query": "<SOQL string>"}}}},
    {{"tool": "get_record", "args": {{"object_api": "<Object>", "record_id": "<Id>", "fields": ["Field__c", "..."]}}}},
    {{"tool": "create_record", "args": {{"object_api": "<Object>", "payload": {{...}}, "dry_run": true}}}},
    {{"tool": "update_record", "args": {{"object_api": "<Object>", "record_id": "<Id>", "payload": {{...}}, "dry_run": true}}}},
    {{"tool": "bulk_emailmessages", "args": {{"case_ids": ["500...","500..."]}}}}
  ],
  "needs_approval": false
}}
Return ONLY JSON, no prose.
User request:
{user_prompt}
"""

FINAL_PROMPT_TEMPLATE = """You are an assistant. Given the user request and tool results, produce the final answer.
User request:
{user_prompt}

Tool results (JSON):
{tool_results}
"""


def build_plan_with_llm(user_prompt: str, client: OllamaClient) -> ActionPlan:
    prompt = PLAN_PROMPT_TEMPLATE.format(user_prompt=user_prompt)
    content = client.chat(prompt)
    return parse_plan(content)


def build_final_with_llm(user_prompt: str, tool_results: List[Dict[str, Any]], client: OllamaClient) -> str:
    prompt = FINAL_PROMPT_TEMPLATE.format(user_prompt=user_prompt, tool_results=json.dumps(tool_results, indent=2))
    return client.chat(prompt)


def _load_plan_from_file(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(description="Run an Action Plan against available tools.")
    ap.add_argument("--plan-json", type=str, help="Inline JSON for plan.")
    ap.add_argument("--plan-file", type=Path, help="Path to JSON plan file.")
    ap.add_argument("--user-prompt", type=str, help="If set with --use-ollama, ask the local LLM to build the plan/final answer.")
    ap.add_argument("--persist-dir", type=Path, default=Path("./data/chroma"), help="Chroma DB directory.")
    ap.add_argument("--use-sfdc", action="store_true", help="Enable Salesforce client (requires env vars).")
    ap.add_argument("--use-ollama", action="store_true", help="Use local Ollama LLM to generate the plan/final output.")
    ap.add_argument("--ollama-host", type=str, default=None, help="Ollama host (default env OLLAMA_HOST or http://localhost:11434)")
    ap.add_argument("--ollama-model", type=str, default=None, help="Ollama model (default env OLLAMA_MODEL or llama3.1:70b)")
    args = ap.parse_args()

    if not args.plan_json and not args.plan_file and not (args.use_ollama and args.user_prompt):
        raise SystemExit("Provide --plan-json/--plan-file or use --use-ollama with --user-prompt")

    plan: ActionPlan
    user_prompt = args.user_prompt or ""
    sf_client = SalesforceClient.from_env(dry_run=True) if args.use_sfdc else None

    if args.use_ollama and args.user_prompt:
        host = args.ollama_host or os.getenv("OLLAMA_HOST", "http://localhost:11434")
        model = args.ollama_model or os.getenv("OLLAMA_MODEL", "llama3.1:8b")
        ollama_client = OllamaClient(host=host, model=model)
        plan = build_plan_with_llm(user_prompt, ollama_client)
    else:
        plan_json = args.plan_json or _load_plan_from_file(args.plan_file)
        plan = parse_plan(plan_json)


    results = execute_plan(plan, sf_client=sf_client, persist_dir=args.persist_dir)

    output: Dict[str, Any] = {
        "intent": plan.intent,
        "needs_approval": plan.needs_approval,
        "tool_results": results,
    }

    if args.use_ollama and args.user_prompt:
        final_answer = build_final_with_llm(user_prompt, results, ollama_client)
        output["final_answer"] = final_answer

    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
