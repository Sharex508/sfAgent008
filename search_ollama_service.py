#!/usr/bin/env python3
"""
Ask a question about the local NATTQA-ENV repo using Ollama + vector retrieval.
The model is forced to answer ONLY from repo context.
"""

import argparse
import os
import sys

# Suppress tokenizers fork warning from sentence-transformers/chroma
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")

from repo_index import ROOT_DIR
from repo_qa import answer_from_context, retrieve_fast, retrieve_plan

DEFAULT_MODEL = os.getenv("OLLAMA_MODEL", "gpt-oss:20b")


def main() -> None:
    parser = argparse.ArgumentParser(description="Ask Ollama with repo-only context (vector RAG).")
    parser.add_argument("prompt", help="Question to answer about the repo")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"Ollama model (default: {DEFAULT_MODEL})")
    parser.add_argument("--k", type=int, default=8, help="Number of retrieved docs")
    parser.add_argument("--hybrid", dest="hybrid", action="store_true", default=True, help="Use hybrid retrieval (default: true)")
    parser.add_argument("--no-hybrid", dest="hybrid", action="store_false", help="Disable hybrid retrieval")
    parser.add_argument("--max-lines", type=int, default=400, help="Max context lines to send to model")
    parser.add_argument("--rebuild-index", action="store_true", help="Rebuild docs + vector index")
    parser.add_argument("--mode", choices=["fast", "plan"], default="plan", help="Retrieval mode (default: plan)")
    parser.add_argument("--plan-queries", type=int, default=4, help="Max queries in plan mode")
    parser.add_argument("--compare", action="store_true", help="Run both fast and plan and print both answers")
    args = parser.parse_args()

    if args.compare:
        context_fast, source_fast = retrieve_fast(args.prompt, k=args.k, hybrid=args.hybrid, max_lines=args.max_lines)
        answer_fast = answer_from_context(args.prompt, context_fast, args.model)

        context_plan, source_plan, plan_queries = retrieve_plan(
            args.prompt,
            model=args.model,
            max_queries=args.plan_queries,
            k=args.k,
            hybrid=args.hybrid,
            max_lines=args.max_lines,
        )
        answer_plan = answer_from_context(args.prompt, context_plan, args.model)

        plan_block = "\n".join(f"- {q}" for q in plan_queries) or "- (planner returned no queries)"

        sys.stdout.write(
            f"Mode: fast\n"
            f"Model: {args.model}\n"
            f"Repo: {ROOT_DIR}\n"
            f"Context source: {source_fast}\n"
            f"Context lines: {len(context_fast)}\n\n"
            f"{answer_fast}\n\n"
            f"Mode: plan\n"
            f"Model: {args.model}\n"
            f"Repo: {ROOT_DIR}\n"
            f"Context source: {source_plan}\n"
            f"Context lines: {len(context_plan)}\n"
            f"Plan queries:\n{plan_block}\n\n"
            f"{answer_plan}\n"
        )
        return

    if args.mode == "plan":
        context_lines, context_source, plan_queries = retrieve_plan(
            args.prompt,
            model=args.model,
            max_queries=args.plan_queries,
            k=args.k,
            hybrid=args.hybrid,
            max_lines=args.max_lines,
        )
    else:
        context_lines, context_source = retrieve_fast(
            args.prompt,
            k=args.k,
            hybrid=args.hybrid,
            max_lines=args.max_lines,
        )

    answer = answer_from_context(args.prompt, context_lines, args.model)

    sys.stdout.write(
        f"Model: {args.model}\n"
        f"Repo: {ROOT_DIR}\n"
        f"Context source: {context_source}\n"
        f"Context lines: {len(context_lines)}\n"
    )
    if args.mode == "plan":
        plan_block = "\n".join(f"- {q}" for q in plan_queries) or "- (planner returned no queries)"
        sys.stdout.write(f"Plan queries:\n{plan_block}\n\n")
    else:
        sys.stdout.write("\n")

    sys.stdout.write(answer)


if __name__ == "__main__":
    main()
