from __future__ import annotations

from dataclasses import dataclass
import re
import sqlite3
import string
from typing import Optional

from rapidfuzz import fuzz, process


@dataclass
class ParsedQuery:
    intent: str  # field_where_used | flows_update_field | endpoint_callers | validation_rules | explain_object | impact_object | impact_field | unknown
    object_name: Optional[str] = None
    field_name: Optional[str] = None
    full_field_name: Optional[str] = None
    endpoint: Optional[str] = None
    contains: Optional[str] = None
    raw_question: str = ""
    confidence: float = 0.0


DIRECT_FIELD_PATTERN = re.compile(r"\b([A-Za-z][A-Za-z0-9_]*)\.([A-Za-z][A-Za-z0-9_]*(?:__c|__r)?)\b")
ENDPOINT_PATTERN = re.compile(r"(callout:[A-Za-z0-9_\-/.]+|https?://[^\s'\"]+)", re.IGNORECASE)
QUOTED_CONTAINS_PATTERN = re.compile(r"contains\s+[\"']([^\"']+)[\"']", re.IGNORECASE)
NAMED_CRED_PATTERN = re.compile(r"named\s+credential\s+([A-Za-z0-9_\-]+)", re.IGNORECASE)


STANDARD_FIELD_SHORTCUTS = {
    "name": ["name"],
    "status": ["status"],
    "stagename": ["stage", "stage name"],
    "ownerid": ["owner", "owner id"],
    "createddate": ["created date", "created"],
    "lastmodifieddate": ["last modified date", "modified date"],
}

SYNONYM_MAP = {
    "name on account": "account name",
    "account stage": "opportunity stage",
    "case status": "status",
}


def normalize(s: str) -> str:
    s = s.lower()
    s = s.replace("_", " ").replace(".", " ")
    s = re.sub(r"\b__c\b|\b__r\b", "", s)
    s = re.sub(r"[^a-z0-9\s:/]", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s


def _camel_to_words(s: str) -> str:
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", s)
    s = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1 \2", s)
    return s


def _humanize_api(api_name: str) -> str:
    x = re.sub(r"__(c|r)$", "", api_name)
    x = x.replace("_", " ")
    x = " ".join(_camel_to_words(token) for token in x.split())
    x = re.sub(r"\s+", " ", x).strip().lower()
    return x


def _choose_preferred_field(existing: str, new: str) -> str:
    ex_obj, ex_field = existing.split(".", 1)
    new_obj, new_field = new.split(".", 1)

    ex_custom = ex_field.endswith("__c")
    new_custom = new_field.endswith("__c")
    if ex_custom != new_custom:
        return new if not new_custom else existing

    if len(new_field) != len(ex_field):
        return new if len(new_field) < len(ex_field) else existing

    if (new_obj, new_field) < (ex_obj, ex_field):
        return new
    return existing


def build_alias_maps(db: sqlite3.Connection) -> tuple[dict[str, str], dict[str, str]]:
    field_alias_map: dict[str, str] = {}
    object_alias_map: dict[str, str] = {}

    object_rows = db.execute("SELECT object_name FROM objects ORDER BY object_name").fetchall()
    field_obj_rows = db.execute("SELECT DISTINCT object_name FROM fields ORDER BY object_name").fetchall()

    object_names = {r["object_name"] for r in object_rows}
    object_names.update({r["object_name"] for r in field_obj_rows})

    for obj in sorted(object_names):
        variants = {
            normalize(obj),
            normalize(_humanize_api(obj)),
            normalize(_camel_to_words(obj)),
        }
        for alias in variants:
            if not alias:
                continue
            if alias not in object_alias_map:
                object_alias_map[alias] = obj

    field_rows = db.execute(
        "SELECT object_name, field_api, full_name FROM fields ORDER BY object_name, field_api"
    ).fetchall()

    for row in field_rows:
        obj = row["object_name"]
        field_api = row["field_api"]
        full = row["full_name"]

        obj_h = _humanize_api(obj)
        field_h = _humanize_api(field_api)
        field_compact = normalize(field_api)

        aliases = {
            normalize(full),
            normalize(f"{obj} {field_api}"),
            normalize(f"{obj} {field_h}"),
            normalize(f"{obj_h} {field_api}"),
            normalize(f"{obj_h} {field_h}"),
            normalize(f"{obj} {field_compact}"),
        }

        key_name = field_api.replace("_", "").lower()
        key_name = re.sub(r"__(c|r)$", "", key_name)
        shortcuts = STANDARD_FIELD_SHORTCUTS.get(key_name, [])
        for shortcut in shortcuts:
            aliases.add(normalize(f"{obj} {shortcut}"))
            aliases.add(normalize(f"{obj_h} {shortcut}"))

        if field_h == "stage name":
            aliases.add(normalize(f"{obj} stage"))
            aliases.add(normalize(f"{obj_h} stage"))

        for alias in aliases:
            if not alias:
                continue
            current = field_alias_map.get(alias)
            if current is None:
                field_alias_map[alias] = full
            else:
                field_alias_map[alias] = _choose_preferred_field(current, full)

    # Add simple normalized synonym rewrites if target alias exists.
    for source, target in SYNONYM_MAP.items():
        src = normalize(source)
        tgt = normalize(target)
        if tgt in field_alias_map and src not in field_alias_map:
            field_alias_map[src] = field_alias_map[tgt]

    return field_alias_map, object_alias_map


def resolve_field_phrase(
    phrase: str,
    field_alias_map: dict[str, str],
    score_cutoff: int = 85,
) -> Optional[tuple[str, int]]:
    norm = normalize(phrase)
    if not norm:
        return None
    if norm in field_alias_map:
        return field_alias_map[norm], 100

    choices = list(field_alias_map.keys())
    if not choices:
        return None
    match = process.extractOne(norm, choices, scorer=fuzz.WRatio, score_cutoff=score_cutoff)
    if not match:
        return None
    alias, score, _ = match
    return field_alias_map[alias], int(score)


def resolve_object_phrase(
    phrase: str,
    object_alias_map: dict[str, str],
    score_cutoff: int = 85,
) -> Optional[tuple[str, int]]:
    norm = normalize(phrase)
    if not norm:
        return None
    if norm in object_alias_map:
        return object_alias_map[norm], 100

    choices = list(object_alias_map.keys())
    if not choices:
        return None
    match = process.extractOne(norm, choices, scorer=fuzz.WRatio, score_cutoff=score_cutoff)
    if not match:
        return None
    alias, score, _ = match
    return object_alias_map[alias], int(score)


def infer_intent(question_norm: str) -> str:
    q = question_norm

    endpoint_terms = ["endpoint", "callout", "named credential", "setendpoint"]
    if any(t in q for t in endpoint_terms):
        return "endpoint_callers"

    flow_terms = ["which flows", "flows update", "flow updates", "flow set", "flow changes", "flows set"]
    if any(t in q for t in flow_terms) or ("flow" in q and "update" in q):
        return "flows_update_field"

    vr_terms = ["validation rule", "validation rules", "error message"]
    if any(t in q for t in vr_terms) or ("block" in q and ("status" in q or "change" in q)):
        return "validation_rules"

    explain_terms = ["explain", "tell me about", "describe", "show everything touching"]
    if any(t in q for t in explain_terms):
        return "explain_object"

    impact_terms = ["impact", "what breaks", "dependency", "depends on", "touching"]
    if any(t in q for t in impact_terms):
        if "." in q or any(k in q for k in [" name", " status", " stage", " owner", " field"]):
            return "impact_field"
        return "impact_object"

    where_terms = ["where", "used", "usage", "references", "referenced"]
    if any(t in q for t in where_terms):
        return "field_where_used"

    return "unknown"


def _ngrams(tokens: list[str], min_n: int = 1, max_n: int = 5) -> list[str]:
    out: list[str] = []
    nmax = min(max_n, len(tokens))
    for n in range(nmax, min_n - 1, -1):
        for i in range(0, len(tokens) - n + 1):
            out.append(" ".join(tokens[i : i + n]))
    return out


def _field_catalog(db: sqlite3.Connection) -> tuple[set[str], dict[str, str]]:
    rows = db.execute("SELECT full_name FROM fields").fetchall()
    canonical = {r["full_name"] for r in rows}
    lower_map = {x.lower(): x for x in canonical}
    return canonical, lower_map


def _object_catalog(db: sqlite3.Connection) -> tuple[set[str], dict[str, str]]:
    rows = db.execute("SELECT object_name FROM objects").fetchall()
    rows2 = db.execute("SELECT DISTINCT object_name FROM fields").fetchall()
    names = {r["object_name"] for r in rows}
    names.update({r["object_name"] for r in rows2})
    lower_map = {x.lower(): x for x in names}
    return names, lower_map


def _confidence_from_score(score: int | None) -> float:
    if score is None:
        return 0.0
    if score >= 92:
        return 0.75
    if score >= 85:
        return 0.6
    return 0.0


def _resolve_direct_canonical(question: str, field_lower_map: dict[str, str]) -> Optional[str]:
    for match in DIRECT_FIELD_PATTERN.finditer(question):
        key = f"{match.group(1)}.{match.group(2)}".lower()
        if key in field_lower_map:
            return field_lower_map[key]
    return None


def _extract_endpoint(question: str, question_norm: str) -> Optional[str]:
    m = ENDPOINT_PATTERN.search(question)
    if m:
        return m.group(1).strip().rstrip(string.punctuation)

    m2 = NAMED_CRED_PATTERN.search(question)
    if m2:
        return f"callout:{m2.group(1)}"

    if "callout" in question_norm:
        return "callout:"
    return None


def _extract_contains(question: str, question_norm: str) -> Optional[str]:
    m = QUOTED_CONTAINS_PATTERN.search(question)
    if m:
        return m.group(1).strip()

    for token in ["status", "stage", "type", "owner", "name"]:
        if re.search(rf"\b{re.escape(token)}\b", question_norm):
            return token
    return None


def _needs_resolution(parsed: ParsedQuery) -> bool:
    if parsed.intent in {"field_where_used", "flows_update_field", "impact_field"}:
        return not parsed.full_field_name
    if parsed.intent in {"explain_object", "impact_object", "validation_rules"}:
        return not parsed.object_name
    if parsed.intent == "endpoint_callers":
        return not parsed.endpoint
    return parsed.intent == "unknown"


def _validate_llm_result(
    parsed: ParsedQuery,
    object_lower_map: dict[str, str],
    field_lower_map: dict[str, str],
) -> ParsedQuery:
    intent = parsed.intent or "unknown"

    if parsed.full_field_name:
        canonical = field_lower_map.get(parsed.full_field_name.lower())
        if canonical:
            obj, fld = canonical.split(".", 1)
            parsed.full_field_name = canonical
            parsed.object_name = obj
            parsed.field_name = fld
        else:
            parsed.full_field_name = None

    if not parsed.full_field_name and parsed.object_name and parsed.field_name:
        cand = f"{parsed.object_name}.{parsed.field_name}"
        canonical = field_lower_map.get(cand.lower())
        if canonical:
            obj, fld = canonical.split(".", 1)
            parsed.full_field_name = canonical
            parsed.object_name = obj
            parsed.field_name = fld

    if parsed.object_name:
        obj = object_lower_map.get(parsed.object_name.lower())
        parsed.object_name = obj

    if intent in {"field_where_used", "flows_update_field", "impact_field"} and not parsed.full_field_name:
        return ParsedQuery(intent="unknown", raw_question=parsed.raw_question, confidence=0.0)

    if intent in {"explain_object", "impact_object", "validation_rules"} and not parsed.object_name:
        return ParsedQuery(intent="unknown", raw_question=parsed.raw_question, confidence=0.0)

    if intent == "endpoint_callers" and not parsed.endpoint:
        return ParsedQuery(intent="unknown", raw_question=parsed.raw_question, confidence=0.0)

    parsed.confidence = max(parsed.confidence, 0.55)
    return parsed


def parse_question(question: str, db: sqlite3.Connection) -> ParsedQuery:
    question = (question or "").strip()
    q_norm = normalize(question)

    parsed = ParsedQuery(intent=infer_intent(q_norm), raw_question=question, confidence=0.0)

    field_alias_map, object_alias_map = build_alias_maps(db)
    _, field_lower_map = _field_catalog(db)
    _, object_lower_map = _object_catalog(db)

    direct = _resolve_direct_canonical(question, field_lower_map)
    if direct:
        obj, fld = direct.split(".", 1)
        parsed.object_name = obj
        parsed.field_name = fld
        parsed.full_field_name = direct
        parsed.confidence = 0.9

    needs_field_resolution = parsed.intent in {"field_where_used", "flows_update_field", "impact_field", "unknown"}
    if not parsed.full_field_name and needs_field_resolution:
        tokens = q_norm.split()
        best: tuple[str, int] | None = None
        for phrase in _ngrams(tokens, min_n=1, max_n=5):
            resolved = resolve_field_phrase(phrase, field_alias_map, score_cutoff=85)
            if not resolved:
                continue
            full, score = resolved
            if best is None or score > best[1]:
                best = (full, score)
                if score == 100:
                    break

        if best:
            parsed.full_field_name = best[0]
            parsed.object_name, parsed.field_name = best[0].split(".", 1)
            parsed.confidence = max(parsed.confidence, _confidence_from_score(best[1]))

    needs_object_resolution = parsed.intent in {"validation_rules", "explain_object", "impact_object", "unknown"}
    if not parsed.object_name and needs_object_resolution:
        tokens = q_norm.split()
        best_obj: tuple[str, int] | None = None
        for phrase in _ngrams(tokens, min_n=1, max_n=4):
            resolved = resolve_object_phrase(phrase, object_alias_map, score_cutoff=85)
            if not resolved:
                continue
            obj, score = resolved
            if best_obj is None or score > best_obj[1]:
                best_obj = (obj, score)
                if score == 100:
                    break
        if best_obj:
            parsed.object_name = best_obj[0]
            parsed.confidence = max(parsed.confidence, _confidence_from_score(best_obj[1]))

    if parsed.intent == "endpoint_callers":
        parsed.endpoint = _extract_endpoint(question, q_norm)
        if parsed.endpoint:
            parsed.confidence = max(parsed.confidence, 0.75)

    if parsed.intent == "validation_rules":
        parsed.contains = _extract_contains(question, q_norm)

    # Intent refinement for impact/explain style prompts.
    if parsed.intent == "explain_object" and parsed.full_field_name:
        parsed.intent = "impact_field"

    if parsed.intent.startswith("impact"):
        if parsed.full_field_name:
            parsed.intent = "impact_field"
        elif parsed.object_name:
            parsed.intent = "impact_object"

    if _needs_resolution(parsed):
        try:
            from sf_repo_ai.llm_extract import llm_extract

            known_objects = sorted(object_lower_map.values())[:200]
            known_fields = db.execute("SELECT full_name FROM fields ORDER BY full_name LIMIT 400").fetchall()
            known_fields_sample = [r["full_name"] for r in known_fields]

            llm_parsed = llm_extract(question, known_objects, known_fields_sample)
            llm_parsed.raw_question = question
            llm_parsed = _validate_llm_result(llm_parsed, object_lower_map, field_lower_map)

            if llm_parsed.intent != "unknown":
                # keep deterministic intent if it already had high-confidence routing.
                if parsed.intent != "unknown" and parsed.confidence >= 0.75:
                    llm_parsed.intent = parsed.intent
                return llm_parsed
        except Exception:
            pass

    return parsed
