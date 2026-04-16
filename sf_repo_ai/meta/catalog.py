from __future__ import annotations

from dataclasses import dataclass
import re
import sqlite3
from typing import Any

from sf_repo_ai.query_interpreter import normalize


META_XML_RE = re.compile(r"^(?P<stem>.+)-meta\.xml$", re.IGNORECASE)
CAMEL_SPLIT_RE = re.compile(r"([a-z0-9])([A-Z])")


@dataclass(slots=True)
class MetadataCatalogEntry:
    type_key: str
    scope: str
    top_folder: str
    object_child_folder: str | None
    suffix: str
    count_total: int
    sample_path: str

    @staticmethod
    def from_row(row: sqlite3.Row | dict[str, Any]) -> "MetadataCatalogEntry":
        return MetadataCatalogEntry(
            type_key=str(row["type_key"]),
            scope=str(row["scope"]),
            top_folder=str(row["top_folder"]),
            object_child_folder=(str(row["object_child_folder"]) if row["object_child_folder"] else None),
            suffix=str(row["suffix"]),
            count_total=int(row["count_total"]),
            sample_path=str(row["sample_path"]),
        )


def _pluralize(token: str) -> str:
    if not token:
        return token
    if token.endswith("s"):
        return token
    if token.endswith("y") and len(token) >= 2 and token[-2] not in "aeiou":
        return token[:-1] + "ies"
    return token + "s"


def _split_camel(text: str) -> str:
    s = CAMEL_SPLIT_RE.sub(r"\1 \2", text or "")
    s = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1 \2", s)
    return s


def _meta_type_from_file_name(file_name: str) -> tuple[str, str] | None:
    m = META_XML_RE.match(file_name or "")
    if not m:
        return None
    stem = m.group("stem")
    if "." in stem:
        type_key = stem.rsplit(".", 1)[1]
    else:
        type_key = stem
    suffix = f".{type_key}-meta.xml"
    return type_key, suffix


def _catalog_rows_from_meta_files(conn: sqlite3.Connection) -> list[dict[str, Any]]:
    rows = conn.execute(
        """
        SELECT path, file_name, folder
        FROM meta_files
        WHERE lower(file_name) LIKE '%-meta.xml'
        """
    ).fetchall()

    agg: dict[tuple[str, str, str, str | None, str], dict[str, Any]] = {}
    for row in rows:
        path = str(row["path"])
        file_name = str(row["file_name"])
        top_folder = str(row["folder"] or "")
        parsed = _meta_type_from_file_name(file_name)
        if not parsed:
            continue
        type_key, suffix = parsed
        parts = path.split("/")
        scope = "GLOBAL"
        object_child_folder: str | None = None
        if len(parts) >= 4 and parts[0].lower() == "objects":
            scope = "OBJECT_CHILD"
            object_child_folder = parts[2]
        key = (type_key, scope, top_folder, object_child_folder, suffix)
        cur = agg.get(key)
        if cur is None:
            agg[key] = {
                "type_key": type_key,
                "scope": scope,
                "top_folder": top_folder,
                "object_child_folder": object_child_folder,
                "suffix": suffix,
                "count_total": 1,
                "sample_path": path,
            }
        else:
            cur["count_total"] += 1
            if path < str(cur["sample_path"]):
                cur["sample_path"] = path
    return list(agg.values())


def build_metadata_catalog(conn: sqlite3.Connection) -> int:
    rows = _catalog_rows_from_meta_files(conn)
    conn.execute("DELETE FROM metadata_catalog")
    if rows:
        conn.executemany(
            """
            INSERT INTO metadata_catalog(
              type_key, scope, top_folder, object_child_folder, suffix, count_total, sample_path
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            [
                (
                    r["type_key"],
                    r["scope"],
                    r["top_folder"],
                    r["object_child_folder"],
                    r["suffix"],
                    r["count_total"],
                    r["sample_path"],
                )
                for r in rows
            ],
        )
    conn.commit()
    return len(rows)


def ensure_metadata_catalog(conn: sqlite3.Connection) -> None:
    cnt = int(conn.execute("SELECT COUNT(*) AS c FROM metadata_catalog").fetchone()["c"])
    if cnt == 0:
        build_metadata_catalog(conn)


def list_catalog_types(conn: sqlite3.Connection) -> list[MetadataCatalogEntry]:
    ensure_metadata_catalog(conn)
    rows = conn.execute(
        """
        SELECT type_key, scope, top_folder, object_child_folder, suffix, count_total, sample_path
        FROM metadata_catalog
        ORDER BY lower(type_key), scope, lower(top_folder), lower(COALESCE(object_child_folder,''))
        """
    ).fetchall()
    return [MetadataCatalogEntry.from_row(r) for r in rows]


def _entry_aliases(entry: MetadataCatalogEntry) -> set[str]:
    aliases: set[str] = set()
    type_words = normalize(_split_camel(entry.type_key))
    if type_words:
        aliases.add(type_words)
        aliases.add(_pluralize(type_words))
        aliases.add(type_words.replace(" ", ""))
        aliases.add(_pluralize(type_words.replace(" ", "")))
    folder_words = normalize(_split_camel(entry.top_folder))
    if folder_words:
        aliases.add(folder_words)
        aliases.add(_pluralize(folder_words))
        aliases.add(folder_words.replace(" ", ""))
        aliases.add(_pluralize(folder_words.replace(" ", "")))
    if entry.object_child_folder:
        child_words = normalize(_split_camel(entry.object_child_folder))
        if child_words:
            aliases.add(child_words)
            aliases.add(_pluralize(child_words))
            aliases.add(child_words.replace(" ", ""))
            aliases.add(_pluralize(child_words.replace(" ", "")))
    if entry.type_key.lower() == "recordtype":
        aliases.update({"record type", "record types", "recordtype", "recordtypes"})
    if entry.type_key.lower() == "validationrule":
        aliases.update({"validation rule", "validation rules"})
    if entry.type_key.lower() == "listview":
        aliases.update({"list view", "list views"})
    if entry.type_key.lower() == "permissionset":
        aliases.update({"permission set", "permission sets", "permset", "permsets"})
    return {a for a in aliases if a}


def _intent_from_question_norm(question_norm: str) -> str | None:
    q = question_norm
    if any(x in q for x in ("how many", "count", "number of")):
        return "meta_inventory_count"
    if any(x in q for x in ("list", "show", "give me", "what are")):
        return "meta_inventory_list"
    if any(x in q for x in ("explain", "describe", "what is")):
        return "meta_inventory_explain"
    return None


def resolve_catalog_type(conn: sqlite3.Connection, question_norm: str) -> dict[str, Any] | None:
    ensure_metadata_catalog(conn)
    intent = _intent_from_question_norm(question_norm)
    if not intent:
        return None
    entries = list_catalog_types(conn)
    best: tuple[int, MetadataCatalogEntry, str] | None = None
    allow_short = {"lwc"}
    for entry in entries:
        for alias in _entry_aliases(entry):
            a = normalize(alias)
            if not a:
                continue
            # Avoid noisy one-word aliases like "app"/"js" from over-matching.
            if len(a) < 4 and a not in allow_short and " " not in a:
                continue
            pat = rf"\b{re.escape(a)}\b"
            matched = bool(re.search(pat, question_norm))
            if not matched:
                continue
            score = len(a) * 10 + min(entry.count_total, 200)
            if best is None or score > best[0]:
                best = (score, entry, a)
    if not best:
        return None
    return {
        "intent": intent,
        "entry": best[1],
        "alias": best[2],
    }
