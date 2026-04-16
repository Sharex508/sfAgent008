from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from ingestion import RepoRegistry, register_and_sync_repo, sync_due_repos, sync_repo_by_id
from repo_index import ensure_indexes
from repo_inventory import validate_repo_structure
from repo_runtime import resolve_active_repo, set_active_repo


def _docs_count() -> int:
    docs_path = Path("data/metadata/docs.jsonl")
    if not docs_path.exists():
        return 0
    with docs_path.open("r", encoding="utf-8") as handle:
        return sum(1 for line in handle if line.strip())


def main() -> None:
    ap = argparse.ArgumentParser(description="Register, activate, sync, inspect, and clean managed Salesforce repos")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_reg = sub.add_parser("register", help="Register and sync a repo")
    p_reg.add_argument("--clone-url", required=True)
    p_reg.add_argument("--branch")
    p_reg.add_argument("--provider")
    p_reg.add_argument("--name")
    p_reg.add_argument("--active", action="store_true")
    p_reg.add_argument("--sync-enabled", action="store_true", default=True)
    p_reg.add_argument("--sync-interval-minutes", type=int, default=1440)

    sub.add_parser("list", help="List registered repos")

    p_sync = sub.add_parser("sync", help="Sync a specific repo by source_id")
    p_sync.add_argument("source_id")

    sub.add_parser("sync-due", help="Sync all due repos")

    p_activate = sub.add_parser("activate", help="Activate a registered repo by source_id")
    p_activate.add_argument("source_id")

    p_cleanup = sub.add_parser("cleanup", help="Remove inactive repos older than a threshold")
    p_cleanup.add_argument("--max-age-days", type=int, default=30)
    p_cleanup.add_argument("--delete-local", action="store_true")

    sub.add_parser("stats", help="Show active repo validation and inventory stats")

    args = ap.parse_args()
    registry = RepoRegistry()

    if args.cmd == "register":
        row = register_and_sync_repo(
            clone_url=args.clone_url,
            branch=args.branch,
            provider=args.provider,
            name=args.name,
            active=args.active,
            sync_enabled=args.sync_enabled,
            sync_interval_minutes=args.sync_interval_minutes,
            registry=registry,
        )
        print(json.dumps(row, indent=2))
        return

    if args.cmd == "list":
        print(json.dumps({"active_repo_path": str(resolve_active_repo()), "sources": registry.list_sources()}, indent=2))
        return

    if args.cmd == "sync":
        print(json.dumps(sync_repo_by_id(args.source_id, registry=registry), indent=2))
        return

    if args.cmd == "sync-due":
        rows = sync_due_repos(registry=registry)
        print(json.dumps({"active_repo_path": str(resolve_active_repo()), "sources": rows}, indent=2))
        return

    if args.cmd == "activate":
        row = registry.get_source(args.source_id)
        repo_path = Path(row["local_path"]).expanduser().resolve()
        validation = validate_repo_structure(repo_path)
        if validation.get("validation_status") != "VALID":
            updated = registry.update_source(
                args.source_id,
                updated_ts=datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
                validation_status=validation.get("validation_status"),
                validation_error=validation.get("validation_error"),
                last_index_status="FAILED",
                last_index_error=validation.get("validation_error"),
            )
            print(json.dumps({"error": "Repo validation failed", "source": updated}, indent=2))
            raise SystemExit(1)
        ensure_indexes(repo_path=repo_path, rebuild=True)
        set_active_repo(repo_path)
        updated = registry.update_source(
            args.source_id,
            updated_ts=datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
            is_active=1,
            validation_status=validation.get("validation_status"),
            validation_error=validation.get("validation_error"),
            metadata_root=validation.get("metadata_root"),
            repo_kind=validation.get("repo_kind"),
            has_sfdx_project=1 if validation.get("has_sfdx_project") else 0,
            has_force_app=1 if validation.get("has_force_app") else 0,
            objects_count=int(validation.get("objects_count") or 0),
            fields_count=int(validation.get("fields_count") or 0),
            classes_count=int(validation.get("classes_count") or 0),
            triggers_count=int(validation.get("triggers_count") or 0),
            flows_count=int(validation.get("flows_count") or 0),
            last_index_status="SUCCEEDED",
            last_index_error=None,
            last_indexed_ts=datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
            last_indexed_commit=row.get("last_synced_commit"),
            docs_count=_docs_count(),
        )
        print(json.dumps(updated, indent=2))
        return

    if args.cmd == "cleanup":
        rows = registry.cleanup_inactive_sources(max_age_days=args.max_age_days, delete_local=args.delete_local)
        print(json.dumps({"removed": rows}, indent=2))
        return

    if args.cmd == "stats":
        repo_path = resolve_active_repo()
        stats = validate_repo_structure(repo_path)
        stats["active_repo_path"] = str(repo_path)
        stats["docs_count"] = _docs_count()
        print(json.dumps(stats, indent=2))
        return


if __name__ == "__main__":
    main()
