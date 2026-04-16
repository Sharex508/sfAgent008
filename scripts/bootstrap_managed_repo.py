from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from ingestion import register_and_sync_repo
from repo_runtime import resolve_active_repo


def main() -> None:
    ap = argparse.ArgumentParser(description="Clone, register, activate, and index a Salesforce repo for this template project")
    ap.add_argument("--clone-url", required=True, help="Git clone URL or local path")
    ap.add_argument("--branch", help="Branch to clone or sync")
    ap.add_argument("--provider", help="bitbucket, github, gitlab, git, or local")
    ap.add_argument("--name", help="Local managed repo name")
    ap.add_argument("--activate", action="store_true", help="Activate this repo immediately after sync")
    ap.add_argument("--sync-enabled", action="store_true", default=True, help="Keep this repo eligible for sync-due")
    ap.add_argument("--sync-interval-minutes", type=int, default=1440, help="Minutes between automatic sync windows")
    args = ap.parse_args()

    row = register_and_sync_repo(
        clone_url=args.clone_url,
        branch=args.branch,
        provider=args.provider,
        name=args.name,
        active=args.activate,
        sync_enabled=args.sync_enabled,
        sync_interval_minutes=args.sync_interval_minutes,
    )
    payload = {
        "registered_repo": row,
        "active_repo_path": str(resolve_active_repo()),
    }
    print(json.dumps(payload, indent=2))


if __name__ == "__main__":
    main()
