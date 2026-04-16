from __future__ import annotations

import os
from pathlib import Path
from typing import List, Optional

ROOT = Path(__file__).resolve().parent
ACTIVE_REPO_LINK = ROOT / "data" / "repo"
MANAGED_REPOS_ROOT = ROOT / "data" / "repos"
METADATA_DIR = ROOT / "data" / "metadata"
METADATA_INVENTORY_PATH = METADATA_DIR / "repo_metadata_inventory.json"
FALLBACK_REPO = ROOT / "template_repo"


def resolve_active_repo(default: Optional[Path] = None) -> Path:
    env_override = os.getenv("SF_ACTIVE_REPO_DIR")
    if env_override:
        candidate = Path(env_override).expanduser().resolve()
        if candidate.exists():
            return candidate

    if ACTIVE_REPO_LINK.exists():
        try:
            candidate = ACTIVE_REPO_LINK.resolve()
        except OSError:
            candidate = ACTIVE_REPO_LINK
        if candidate.exists():
            return candidate

    fallback = Path(default).resolve() if default else FALLBACK_REPO.resolve()
    return fallback




def repo_roots(default: Optional[Path] = None) -> List[Path]:
    roots = [resolve_active_repo(default), FALLBACK_REPO.resolve(), ROOT]
    seen: set[str] = set()
    out: List[Path] = []
    for root in roots:
        key = root.resolve().as_posix() if root.exists() else root.as_posix()
        if key in seen:
            continue
        seen.add(key)
        out.append(root)
    return out


def set_active_repo(repo_path: Path) -> Path:
    repo_path = Path(repo_path).expanduser().resolve()
    if not repo_path.exists():
        raise FileNotFoundError(f"Repo path not found: {repo_path}")

    ACTIVE_REPO_LINK.parent.mkdir(parents=True, exist_ok=True)
    if ACTIVE_REPO_LINK.exists() or ACTIVE_REPO_LINK.is_symlink():
        ACTIVE_REPO_LINK.unlink()
    ACTIVE_REPO_LINK.symlink_to(repo_path, target_is_directory=True)
    return ACTIVE_REPO_LINK
