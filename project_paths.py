from __future__ import annotations

import os
from pathlib import Path
from typing import Optional


DEFAULT_METADATA_REPO_POINTER = Path(__file__).resolve().parent / "data" / "repo"


def _strip_quotes(text: str) -> str:
    if len(text) >= 2 and text[0] == text[-1] and text[0] in {"'", '"'}:
        return text[1:-1]
    return text


def resolve_metadata_repo_path(candidate: Optional[Path] = None) -> Path:
    """
    Resolve the effective metadata repository directory.

    Precedence:
    1) SF_METADATA_REPO env var
    2) Provided candidate path
    3) Default pointer path (./data/repo)

    Supports git-symlink fallback files on Windows where `data/repo` may be a
    regular text file containing a relative/absolute target path.
    """
    env_path = os.getenv("SF_METADATA_REPO")
    base = Path(_strip_quotes(env_path.strip())).expanduser() if env_path else (candidate or DEFAULT_METADATA_REPO_POINTER)

    # Windows checkouts can materialize a symlink as a plain text file.
    if base.is_file():
        try:
            target_text = _strip_quotes(base.read_text(encoding="utf-8", errors="ignore").strip())
        except OSError:
            target_text = ""
        if target_text:
            target = Path(target_text)
            if not target.is_absolute():
                target = (base.parent / target).resolve()
            return target

    return base.resolve()
