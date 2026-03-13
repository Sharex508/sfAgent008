from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Iterable, List

from metadata.metadata_types import MetadataDoc
from metadata.parsers.objects_parser import parse_objects
from metadata.parsers.apex_parser import parse_apex
from metadata.parsers.flows_parser import parse_flows
from metadata.parsers.security_parser import parse_security
from metadata.parsers.approval_parser import parse_approval_processes
from project_paths import resolve_metadata_repo_path


DEFAULT_REPO = Path("./data/repo")


def index_repo(repo_path: Path = DEFAULT_REPO) -> List[MetadataDoc]:
    """Walk the repo and aggregate MetadataDoc entries from supported folders.

    Handles common SFDX layout (force-app/**/default/*), but also falls back to
    recursive searches if specific folders are not found.
    """
    repo_path = resolve_metadata_repo_path(Path(repo_path))

    docs: List[MetadataDoc] = []

    # Heuristic roots to check (SFDX typical)
    candidates = [
        repo_path / "force-app" / "main" / "default",
        repo_path / "force-app",
        repo_path,
    ]

    root = next((c for c in candidates if c.exists()), repo_path)

    # Objects and Fields
    docs.extend(parse_objects(root / "objects") if (root / "objects").exists() else parse_objects(root))

    # Apex (classes + triggers)
    apex_root = root / "classes"
    trig_root = root / "triggers"
    if apex_root.exists() or trig_root.exists():
        docs.extend(parse_apex(apex_root if apex_root.exists() else root))
        docs.extend(parse_apex(trig_root if trig_root.exists() else root))
    else:
        docs.extend(parse_apex(root))

    # Flows
    docs.extend(parse_flows(root / "flows") if (root / "flows").exists() else parse_flows(root))

    # Approval Processes
    ap_root = root / "approvalProcesses"
    docs.extend(parse_approval_processes(ap_root if ap_root.exists() else root))

    # Security: Profiles and Permission Sets
    sec_dirs = [root / "profiles", root / "permissionsets"]
    any_sec = any(d.exists() for d in sec_dirs)
    if any_sec:
        for d in sec_dirs:
            if d.exists():
                docs.extend(parse_security(d))
    else:
        docs.extend(parse_security(root))

    return docs


def write_jsonl(docs: List[MetadataDoc], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        for d in docs:
            f.write(d.model_dump_json())
            f.write("\n")


def main():
    ap = argparse.ArgumentParser(description="Index Salesforce metadata into documents")
    ap.add_argument("--repo", type=Path, default=DEFAULT_REPO, help="Path to repo root")
    ap.add_argument("--out", type=Path, default=Path("./data/metadata/docs.jsonl"), help="Output JSONL path")
    args = ap.parse_args()

    docs = index_repo(args.repo)
    write_jsonl(docs, args.out)

    # Summary
    counts = {}
    for d in docs:
        counts[d.kind] = counts.get(d.kind, 0) + 1
    print(json.dumps({"total": len(docs), "by_kind": counts}, indent=2))


if __name__ == "__main__":
    main()
