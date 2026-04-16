from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Iterable


def sha1_file(path: Path, chunk_size: int = 65536) -> str:
    h = hashlib.sha1()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(chunk_size), b""):
            h.update(chunk)
    return h.hexdigest()


def rel_path(path: Path, root: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except Exception:
        return path.as_posix()


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def xml_local_name(tag: str) -> str:
    if "}" in tag:
        return tag.split("}", 1)[1]
    return tag


def line_number_for_offset(text: str, offset: int) -> int:
    if offset <= 0:
        return 1
    return text.count("\n", 0, offset) + 1


def line_range_for_span(text: str, start: int, end: int) -> tuple[int, int]:
    return line_number_for_offset(text, start), line_number_for_offset(text, end)


def line_snippet(text: str, line_no: int, max_len: int = 240) -> str:
    if line_no < 1:
        return ""
    lines = text.splitlines()
    if line_no > len(lines):
        return ""
    line = lines[line_no - 1].strip()
    if len(line) > max_len:
        return line[: max_len - 3] + "..."
    return line


def uniq_preserve(items: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for x in items:
        if x in seen:
            continue
        seen.add(x)
        out.append(x)
    return out
