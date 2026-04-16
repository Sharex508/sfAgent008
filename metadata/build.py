from __future__ import annotations

import argparse
import json
from pathlib import Path

from metadata.indexer import DEFAULT_REPO, index_repo, write_jsonl
from metadata.graph import build_graph, save_edgelist


def main():
    ap = argparse.ArgumentParser(description="Index Salesforce metadata and build dependency graph")
    ap.add_argument("--repo", type=Path, default=DEFAULT_REPO, help="Path to the cloned metadata repo")
    ap.add_argument("--docs", type=Path, default=Path("./data/metadata/docs.jsonl"), help="Output JSONL for docs")
    ap.add_argument("--graph", type=Path, default=Path("./data/metadata/graph.edgelist"), help="Output edgelist file")
    args = ap.parse_args()

    docs = index_repo(args.repo)
    write_jsonl(docs, args.docs)

    g = build_graph(docs)
    save_edgelist(g, args.graph)

    counts = {}
    for d in docs:
        counts[d.kind] = counts.get(d.kind, 0) + 1

    print(json.dumps({
        "repo": str(args.repo),
        "docs_written": str(args.docs),
        "graph_written": str(args.graph),
        "doc_total": len(docs),
        "by_kind": counts,
        "graph": {
            "nodes": g.number_of_nodes(),
            "edges": g.number_of_edges(),
        },
    }, indent=2))


if __name__ == "__main__":
    main()
