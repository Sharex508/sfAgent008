from __future__ import annotations

from pathlib import Path
import re
from typing import Any

from sf_repo_ai.util import read_text


_TOKEN_RE = re.compile(r"[A-Za-z0-9_.:@/-]{3,}")


def _uniq_paths(paths: list[str]) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for p in paths:
        if not p or p in seen:
            continue
        seen.add(p)
        out.append(p)
    return out


def _resolve_file(repo_root: Path, rel_path: str | None) -> Path | None:
    if not rel_path:
        return None
    p = Path(rel_path)
    if p.is_absolute() and p.exists() and p.is_file():
        return p
    full = repo_root / rel_path
    if full.exists() and full.is_file():
        return full
    return None


def _line_window(lines: list[str], center: int, radius: int) -> tuple[int, int, str]:
    if not lines:
        return 1, 1, ""
    c = max(1, min(center, len(lines)))
    start = max(1, c - radius)
    end = min(len(lines), c + radius)
    body = "\n".join(f"{i}: {lines[i - 1]}" for i in range(start, end + 1))
    return start, end, body


def _extract_tokens(question: str, resolved: dict[str, Any]) -> list[str]:
    tokens = [m.group(0) for m in _TOKEN_RE.finditer(question or "")]
    for k in ("target", "full_field_name", "object_name", "approval_process_full_name", "metadata_type", "endpoint"):
        v = resolved.get(k)
        if isinstance(v, str) and v.strip():
            tokens.append(v.strip())
            if "." in v:
                tokens.extend(x for x in v.split(".") if x)
    out: list[str] = []
    seen: set[str] = set()
    for t in tokens:
        tl = t.lower()
        if tl in seen or len(tl) < 3:
            continue
        seen.add(tl)
        out.append(t)
    return out[:80]


def build_evidence_pack(
    *,
    question: str,
    resolved: dict[str, Any],
    deterministic_payload: dict[str, Any],
    repo_root: Path,
    mode: str,
    max_chars: int = 120000,
    primary_max_chars: int = 80000,
) -> dict[str, Any]:
    dossier = deterministic_payload.get("dossier") or {}
    evidence_rows = deterministic_payload.get("evidence") or []

    candidate_paths: list[str] = []
    for e in evidence_rows:
        if not isinstance(e, dict):
            continue
        p = e.get("path") or e.get("src_path")
        if p:
            candidate_paths.append(str(p))
    for p in dossier.get("evidence_paths", []) or []:
        if p:
            candidate_paths.append(str(p))
    candidate_paths = _uniq_paths(candidate_paths)

    primary_path = resolved.get("resolved_path")
    if not primary_path and candidate_paths:
        primary_path = candidate_paths[0]

    mode_requested = mode
    mode_used = mode_requested
    primary_included_full = False
    primary_full_text = ""

    files: list[dict[str, Any]] = []
    file_seen: set[str] = set()

    def _add_file(path: str, *, role: str, included: str) -> None:
        if path in file_seen:
            return
        file_seen.add(path)
        files.append({"path": path, "role": role, "included": included})

    if primary_path:
        if mode_requested == "full_primary":
            fp = _resolve_file(repo_root, primary_path)
            txt = read_text(fp) if fp else ""
            if txt and len(txt) <= primary_max_chars and len(txt) <= max_chars:
                primary_included_full = True
                primary_full_text = txt
                _add_file(str(primary_path), role="primary", included="full")
            else:
                mode_used = "rag_snippets_fallback"
                _add_file(str(primary_path), role="primary", included="snippets")
        else:
            _add_file(str(primary_path), role="primary", included="snippets")

    for p in candidate_paths:
        if p == primary_path:
            continue
        _add_file(p, role="evidence", included="snippets")

    tokens = _extract_tokens(question, resolved)

    # Build snippet candidates.
    candidates: list[dict[str, Any]] = []
    seen_span: set[tuple[str, int, int]] = set()
    lines_cache: dict[str, list[str]] = {}

    def _lines_for(path: str) -> list[str]:
        if path in lines_cache:
            return lines_cache[path]
        fp = _resolve_file(repo_root, path)
        txt = read_text(fp) if fp else ""
        lines = txt.splitlines()
        lines_cache[path] = lines
        return lines

    for e in evidence_rows[:300]:
        if not isinstance(e, dict):
            continue
        path = e.get("path") or e.get("src_path")
        if not path:
            continue
        lines = _lines_for(str(path))
        if not lines:
            continue
        line_no = e.get("line_no")
        if line_no is None:
            line_no = e.get("line")
        if line_no is None:
            continue
        try:
            center = int(line_no)
        except Exception:
            continue
        s, en, text = _line_window(lines, center, 25)
        key = (str(path), s, en)
        if key in seen_span or not text:
            continue
        seen_span.add(key)
        candidates.append({"path": str(path), "start_line": s, "end_line": en, "text": text, "score": 100})

    # Keyword snippets fallback/augmentation.
    token_l = [t.lower() for t in tokens if t]
    for p in files:
        path = p["path"]
        lines = _lines_for(path)
        if not lines:
            continue
        hits = 0
        for i, ln in enumerate(lines, start=1):
            low = ln.lower()
            if token_l and not any(t in low for t in token_l):
                continue
            s, en, text = _line_window(lines, i, 8)
            key = (path, s, en)
            if key in seen_span or not text:
                continue
            seen_span.add(key)
            candidates.append({"path": path, "start_line": s, "end_line": en, "text": text, "score": 60})
            hits += 1
            if hits >= 6:
                break

    candidates.sort(key=lambda x: (-int(x["score"]), x["path"], int(x["start_line"])))

    fixed_chars = len(question or "") + len(primary_full_text)
    snippets: list[dict[str, Any]] = []
    used = fixed_chars
    for c in candidates:
        t = c["text"]
        if used + len(t) > max_chars:
            continue
        snippets.append(
            {
                "path": c["path"],
                "start_line": c["start_line"],
                "end_line": c["end_line"],
                "text": t,
            }
        )
        used += len(t)
        if len(snippets) >= 200:
            break

    facts = {
        "intent": deterministic_payload.get("intent"),
        "routing_family": deterministic_payload.get("routing_family"),
        "handler": deterministic_payload.get("handler"),
        "answer_lines": deterministic_payload.get("answer_lines") or [],
        "count": deterministic_payload.get("count"),
    }

    stats = {
        "mode_requested": mode_requested,
        "mode_used": mode_used,
        "total_chars": used,
        "file_count": len(files),
        "snippet_count": len(snippets),
        "primary_included_full": primary_included_full,
    }

    return {
        "question": question,
        "resolved": resolved,
        "facts": facts,
        "files": files,
        "primary_full_text": primary_full_text if primary_included_full else "",
        "snippets": snippets,
        "limits": {"max_chars": max_chars, "primary_max_chars": primary_max_chars},
        "mode_used": mode_used,
        "evidence_pack_stats": stats,
    }

