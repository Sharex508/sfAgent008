from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import re
import sqlite3
from typing import Any

from rapidfuzz import fuzz, process

from sf_repo_ai.entity_dict import EntityDictionary, build_entity_dictionary, normalize
from sf_repo_ai.evidence_engine import build_evidence
from sf_repo_ai.meta.catalog import resolve_catalog_type
from sf_repo_ai.meta.universal_explain import explain_metadata_file
from sf_repo_ai.meta.universal_inventory import (
    count_inventory,
    extract_name_candidate,
    find_inventory_by_name,
    list_inventory,
)
from sf_repo_ai.query_interpreter import resolve_field_phrase, resolve_object_phrase
from sf_repo_ai.risk_tools import detect_collisions, what_breaks
from sf_repo_ai.util import read_text


DIRECT_FIELD_PATTERN = re.compile(r"\b([A-Za-z][A-Za-z0-9_]*)\.([A-Za-z][A-Za-z0-9_]*(?:__c|__r)?)\b")
ENDPOINT_PATTERN = re.compile(r"(callout:[A-Za-z0-9_\-/.]+|https?://[^\s'\"]+)", re.IGNORECASE)
QUOTED_PATTERN = re.compile(r"[\"']([^\"']+)[\"']")
FLOW_PREFIX_PATTERN = re.compile(r"\bflow\s*:\s*([A-Za-z0-9_]+)\b", re.IGNORECASE)
CLASS_PREFIX_PATTERN = re.compile(r"\bclass\s*:\s*([A-Za-z0-9_]+)\b", re.IGNORECASE)
TRIGGER_PREFIX_PATTERN = re.compile(r"\btrigger\s*:\s*([A-Za-z0-9_]+)\b", re.IGNORECASE)
APPROVAL_COMPONENT_PATTERN = re.compile(
    r"\b([A-Za-z][A-Za-z0-9_]*(?:__c)?)\.([A-Za-z][A-Za-z0-9_]+)\b"
)
EXPLAIN_KEYWORDS = ("explain", "describe", "what does", "how does")
WRITE_VERBS = ("update", "updates", "set", "write", "writes", "modify", "populate", "change")
DELIMITERS_RE = re.compile(r"\b(and|that|which|why|where|who|how|what|with|for|on|in)\b|\?|,", re.IGNORECASE)
LWC_APEX_IMPORT_RE = re.compile(r"@salesforce/apex/([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)")
LWC_SCHEMA_REF_RE = re.compile(r"@salesforce/schema/([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)")
DML_IN_LOOP_RE = re.compile(r"for\s*\([^)]*\)\s*\{[^{}]{0,5000}\b(insert|update|upsert|delete)\b", re.IGNORECASE | re.DOTALL)


@dataclass(slots=True)
class ResolvedEntities:
    object_name: str | None = None
    field_name: str | None = None
    full_field_name: str | None = None
    metadata_type: str | None = None
    metadata_folder: str | None = None
    endpoint: str | None = None
    token: str | None = None
    object_phrase_hint: str | None = None
    approval_process_name: str | None = None
    approval_process_full_name: str | None = None
    approval_process_path: str | None = None
    requested_field: str | None = None
    field_explicit: bool = False
    confidence: float = 0.0


def _ngrams(tokens: list[str], min_n: int = 1, max_n: int = 6) -> list[str]:
    out: list[str] = []
    if not tokens:
        return out
    nmax = min(max_n, len(tokens))
    for n in range(nmax, min_n - 1, -1):
        for i in range(0, len(tokens) - n + 1):
            out.append(" ".join(tokens[i : i + n]))
    return out


def _extract_object_hint(q_norm: str) -> str | None:
    m = re.search(r"\b(?:on|for|in)\s+([a-z0-9_ ]+)", q_norm)
    if not m:
        return None
    phrase = m.group(1).strip()
    if not phrase:
        return None
    words = [w for w in phrase.split() if w not in {"the", "a", "an", "active", "enabled"}]
    if not words:
        return None
    return " ".join(words[:4]).strip()


def _field_needed(question: str, q_norm: str) -> bool:
    if DIRECT_FIELD_PATTERN.search(question):
        return True
    if ("__c" in question or "__r" in question) and re.search(
        r"\b(field|column|fls|update|updates|write|writes|used|where)\b",
        q_norm,
    ):
        return True
    if re.search(r"\b(field|column|fls)\b", q_norm):
        return True
    if any(k in q_norm for k in ["where is", "where used", "used", "update", "updates", "write", "writes", "fls for"]):
        return True
    return False


def _resolve_entities(question: str, d: EntityDictionary) -> ResolvedEntities:
    q_norm = normalize(question)
    tokens = q_norm.split()
    e = ResolvedEntities(object_phrase_hint=_extract_object_hint(q_norm))
    approval_context = "approval process" in q_norm

    fields_lower = {f.lower(): f for f in d.fields}
    should_try_field = _field_needed(question, q_norm)
    e.field_explicit = should_try_field

    if approval_context:
        m = APPROVAL_COMPONENT_PATTERN.search(question)
        if m:
            obj_hint = m.group(1).strip()
            ap_name = m.group(2).strip()
            obj_row = next((x for x in d.objects if x.lower() == obj_hint.lower()), None)
            if obj_row:
                e.object_name = obj_row
            else:
                obj_res = resolve_object_phrase(obj_hint, d.object_alias_map, score_cutoff=85)
                if obj_res:
                    e.object_name = obj_res[0]
            if e.object_name:
                e.metadata_type = "ApprovalProcess"
                e.metadata_folder = "approvalProcesses"
                e.approval_process_name = ap_name
                e.approval_process_full_name = f"{e.object_name}.{ap_name}"
                e.token = e.approval_process_full_name
                e.confidence = max(e.confidence, 0.92)
                # In approval-process context, treat Object.Name as component, not field.
                should_try_field = False
                e.field_explicit = False

    if should_try_field:
        direct_field_matches = list(DIRECT_FIELD_PATTERN.finditer(question))
        if direct_field_matches:
            e.requested_field = f"{direct_field_matches[0].group(1)}.{direct_field_matches[0].group(2)}"
        for m in direct_field_matches:
            candidate = f"{m.group(1)}.{m.group(2)}".lower()
            canonical = fields_lower.get(candidate)
            if canonical:
                e.full_field_name = canonical
                e.object_name, e.field_name = canonical.split(".", 1)
                e.confidence = max(e.confidence, 0.95)
                break

        # If user supplied explicit Object.Field and it does not exist, do not fuzzy-substitute.
        if direct_field_matches and not e.full_field_name:
            if not e.object_name:
                obj_hint = direct_field_matches[0].group(1)
                obj_row = next((x for x in d.objects if x.lower() == obj_hint.lower()), None)
                if obj_row:
                    e.object_name = obj_row
            e.field_name = direct_field_matches[0].group(2)
        elif not e.full_field_name:
            best_field: tuple[str, int] | None = None
            for gram in _ngrams(tokens, min_n=2, max_n=5):
                r = resolve_field_phrase(gram, d.field_alias_map, score_cutoff=95)
                if not r:
                    continue
                if best_field is None or r[1] > best_field[1]:
                    best_field = r
            if best_field:
                e.full_field_name = best_field[0]
                e.object_name, e.field_name = best_field[0].split(".", 1)
                if best_field[1] >= 95:
                    e.confidence = max(e.confidence, 0.80)
                else:
                    e.confidence = max(e.confidence, 0.65)

    if not e.object_name:
        # Prefer exact alias matches first to avoid fuzzy false positives.
        exact_obj: str | None = None
        search_grams = _ngrams(tokens, min_n=1, max_n=4)
        for gram in search_grams:
            alias = normalize(gram)
            if alias in d.object_alias_map:
                exact_obj = d.object_alias_map[alias]
                break
        if not exact_obj and e.object_phrase_hint:
            hint = normalize(e.object_phrase_hint)
            if hint in d.object_alias_map:
                exact_obj = d.object_alias_map[hint]
        if exact_obj:
            e.object_name = exact_obj
            e.confidence = max(e.confidence, 0.85)
        else:
            # Fuzzy only as fallback with stricter cutoff.
            best_obj: tuple[str, int] | None = None
            grams_for_fuzzy = [e.object_phrase_hint] if e.object_phrase_hint else []
            for gram in grams_for_fuzzy:
                if not gram:
                    continue
                r = resolve_object_phrase(gram, d.object_alias_map, score_cutoff=93)
                if not r:
                    continue
                if best_obj is None or r[1] > best_obj[1]:
                    best_obj = r
            if best_obj:
                e.object_name = best_obj[0]
                e.confidence = max(e.confidence, 0.72)

    best_meta: tuple[str, dict[str, str], int] | None = None
    for phrase, info in d.meta_type_alias_map.items():
        if phrase and phrase in q_norm:
            score = 100 + len(phrase)
            if best_meta is None or score > best_meta[2]:
                best_meta = (phrase, info, score)
    if best_meta:
        e.metadata_type = best_meta[1]["type"]
        e.metadata_folder = best_meta[1]["folder"]
        e.confidence = max(e.confidence, 0.70)
        if e.metadata_type == "Flow" and not e.field_explicit:
            e.full_field_name = None
            e.field_name = None

    # Prefer Flow when question explicitly asks for flows (avoids "record-triggered flows" being typed as Trigger).
    if re.search(r"\bflows?\b", q_norm) and (e.metadata_type in {None, "Trigger"}):
        e.metadata_type = "Flow"
        e.metadata_folder = "flows"
        e.confidence = max(e.confidence, 0.75)

    endpoint_match = ENDPOINT_PATTERN.search(question)
    if endpoint_match:
        e.endpoint = endpoint_match.group(1).strip()
        e.confidence = max(e.confidence, 0.85)

    if e.full_field_name:
        e.token = e.full_field_name
    elif e.object_name:
        e.token = e.object_name
    elif e.metadata_type:
        e.token = e.metadata_type
    else:
        q = QUOTED_PATTERN.search(question)
        if q:
            e.token = q.group(1).strip()

    return e


def _infer_intent(q_norm: str, e: ResolvedEntities) -> str:
    has_type = bool(e.metadata_type)
    has_object = bool(e.object_name)
    has_on_object = bool(re.search(r"\b(on|for|in)\b", q_norm))

    if any(k in q_norm for k in EXPLAIN_KEYWORDS):
        return "explain_component"

    if any(k in q_norm for k in ["where used", "used in", "references", "referenced", "where is"]):
        return "where_used_any"

    if any(k in q_norm for k in ["what breaks", "impact", "dependencies", "depends on", "dependency"]):
        return "impact_or_deps"

    has_count = any(k in q_norm for k in ["how many", "count", "number of"])
    has_list = any(k in q_norm for k in ["list", "show", "which", "what are"])

    has_all_inventory_phrase = (" all " in f" {q_norm} ") or ("objects they are on" in q_norm)

    if has_type and has_on_object and has_count and (has_object or not has_all_inventory_phrase):
        return "count_type_on_object"
    if has_type and has_on_object and has_list and (has_object or not has_all_inventory_phrase):
        return "list_type_on_object"
    if has_type and has_count:
        return "count_type"
    if has_type and has_list:
        return "list_type"
    if has_type and has_object:
        return "list_type_on_object"

    return "unknown"


def _repo_roots() -> list[Path]:
    return repo_roots()


def _read_repo_rel_path(rel_path: str | None) -> str:
    if not rel_path:
        return ""
    for root in _repo_roots():
        p = root / rel_path
        if p.exists() and p.is_file():
            return read_text(p)
    return ""


def _extract_tail(question: str, markers: list[str]) -> str | None:
    raw = (question or "").strip()
    low = raw.lower()
    best = -1
    marker = ""
    for m in markers:
        pos = low.find(m.lower())
        if pos >= 0 and pos > best:
            best = pos
            marker = raw[pos : pos + len(m)]
    if best < 0:
        return None
    tail = raw[best + len(marker) :].strip()
    if not tail:
        return None
    m = DELIMITERS_RE.search(tail)
    if m:
        tail = tail[: m.start()].strip()
    return tail or None


def _extract_component_name(question: str, type_name: str) -> str | None:
    q = (question or "").strip()
    q_low = q.lower()
    markers: dict[str, list[str]] = {
        "Flow": ["flow "],
        "ApexClass": ["apex class ", "class "],
        "Trigger": ["trigger "],
        "ValidationRule": ["validation rule "],
        "PermissionSet": ["permission set ", "permset "],
        "Profile": ["profile "],
        "ConnectedApp": ["connected app "],
        "Layout": ["layout "],
        "Flexipage": ["flexipage "],
        "LWC": ["lwc ", "lightning web component "],
    }
    if type_name in markers:
        tail = _extract_tail(q, markers[type_name])
        if tail:
            return tail

    # Fallback for "explain <type> <name>" style.
    if q_low.startswith("explain "):
        tail = q[8:].strip()
        m = DELIMITERS_RE.search(tail)
        if m:
            tail = tail[: m.start()].strip()
        return tail or None
    return None


def _resolve_flow_name(conn: sqlite3.Connection, d: EntityDictionary, candidate: str | None) -> str | None:
    if not candidate:
        return None
    row = conn.execute("SELECT flow_name FROM flows WHERE lower(flow_name)=lower(?) LIMIT 1", (candidate,)).fetchone()
    if row:
        return row["flow_name"]
    m = process.extractOne(candidate, d.flows, scorer=fuzz.WRatio, score_cutoff=85)
    return m[0] if m else None


def _resolve_class_name(conn: sqlite3.Connection, d: EntityDictionary, candidate: str | None) -> str | None:
    if not candidate:
        return None
    row = conn.execute(
        "SELECT name FROM components WHERE type='APEX' AND lower(name)=lower(?) LIMIT 1",
        (candidate,),
    ).fetchone()
    if row:
        return row["name"]
    m = process.extractOne(candidate, d.apex_classes, scorer=fuzz.WRatio, score_cutoff=85)
    return m[0] if m else None


def _resolve_trigger_name(conn: sqlite3.Connection, candidate: str | None) -> str | None:
    if not candidate:
        return None
    row = conn.execute(
        "SELECT name FROM components WHERE type='TRIGGER' AND lower(name)=lower(?) LIMIT 1",
        (candidate,),
    ).fetchone()
    if row:
        return row["name"]
    names = [r["name"] for r in conn.execute("SELECT name FROM components WHERE type='TRIGGER'").fetchall()]
    m = process.extractOne(candidate, names, scorer=fuzz.WRatio, score_cutoff=85) if names else None
    return m[0] if m else None


def _resolve_validation_rule_name(conn: sqlite3.Connection, candidate: str | None) -> str | None:
    if not candidate:
        return None
    row = conn.execute("SELECT rule_name FROM validation_rules WHERE lower(rule_name)=lower(?) LIMIT 1", (candidate,)).fetchone()
    if row:
        return row["rule_name"]
    names = [r["rule_name"] for r in conn.execute("SELECT rule_name FROM validation_rules").fetchall()]
    m = process.extractOne(candidate, names, scorer=fuzz.WRatio, score_cutoff=85) if names else None
    return m[0] if m else None


def _resolve_lwc_bundle(conn: sqlite3.Connection, candidate: str | None) -> str | None:
    if not candidate:
        return None
    row = conn.execute(
        """
        SELECT substr(path, instr(path,'/lwc/')+5, instr(substr(path, instr(path,'/lwc/')+5),'/')-1) AS bundle
        FROM meta_files
        WHERE lower(folder)='lwc'
          AND lower(path) LIKE lower(?)
        LIMIT 1
        """,
        (f"%/lwc/{candidate}/%",),
    ).fetchone()
    if row and row["bundle"]:
        return row["bundle"]
    bundles = [
        r["bundle"]
        for r in conn.execute(
            """
            SELECT DISTINCT substr(path, instr(path,'/lwc/')+5, instr(substr(path, instr(path,'/lwc/')+5),'/')-1) AS bundle
            FROM meta_files
            WHERE lower(folder)='lwc' AND path LIKE '%/lwc/%/%'
            """
        ).fetchall()
        if r["bundle"]
    ]
    m = process.extractOne(candidate, bundles, scorer=fuzz.WRatio, score_cutoff=80) if bundles else None
    return m[0] if m else None


def _dispatch_family(question: str, q_norm: str, e: ResolvedEntities) -> tuple[str, str]:
    has_write = any(v in q_norm for v in WRITE_VERBS)
    has_flow_word = bool(re.search(r"\bflows?\b", q_norm))
    has_class_word = bool(re.search(r"\b(apex\s+classes?|classes?)\b", q_norm))
    has_trigger_word = bool(re.search(r"\btriggers?\b", q_norm))
    has_vr_word = "validation rule" in q_norm or "validation rules" in q_norm
    has_explain = any(k in q_norm for k in EXPLAIN_KEYWORDS)
    has_field_token = bool(DIRECT_FIELD_PATTERN.search(question)) or bool(e.requested_field) or bool(e.full_field_name)

    if has_explain:
        return "explain_component", "explain_component"

    if "approval process" in q_norm and ("where is" in q_norm or "referenced" in q_norm or "references" in q_norm):
        return "approval_process_references", "approval_process_references"

    if "approval process" in q_norm and ("list all" in q_norm or "objects they are on" in q_norm):
        return "approval_process_inventory", "approval_process_inventory"

    if has_flow_word and has_write and has_field_token and not any(x in q_norm for x in ["duplicate", "duplicating", "same updates"]):
        return "flows_write_field", "flows_write_field"
    if has_class_word and has_write and has_field_token:
        return "apex_write_field", "apex_write_field"
    if (("writers for" in q_norm or "automations write" in q_norm) and has_field_token) or (
        "single source of truth" in q_norm and has_field_token
    ):
        return "field_writers_query", "writers_for_field"

    if re.search(r"\b(show|list)\b", q_norm) and ("endpoint" in q_norm or "callout" in q_norm) and (
        "who calls" in q_norm or "callers" in q_norm or "used by" in q_norm
    ):
        return "endpoints_inventory", "endpoints_inventory"
    if "what endpoints does" in q_norm and " call" in q_norm:
        return "class_endpoints", "class_endpoints"
    if "named credential" in q_norm:
        return "endpoints_inventory", "named_credentials_inventory"

    if "dml in loop" in q_norm or "dml in loops" in q_norm:
        return "apex_smell_query", "apex_smell_dml_in_loop"
    if "dynamic soql" in q_norm:
        return "apex_smell_query", "apex_smell_dynamic_soql"
    if ("class" in q_norm or "classes" in q_norm) and ("callout" in q_norm or "call out" in q_norm):
        return "apex_smell_query", "apex_smell_callout"

    if "what classes does trigger" in q_norm and " call" in q_norm:
        return "trigger_deps", "trigger_deps"
    if has_trigger_word and ("what breaks" in q_norm or "impact" in q_norm):
        return "trigger_impact", "trigger_impact"
    if has_trigger_word and has_explain:
        return "trigger_explain", "trigger_explain"

    if ("collisions" in q_norm or "multiple writers" in q_norm or "conflicting updates" in q_norm) and has_field_token:
        return "collisions_query", "collisions_query"

    if has_vr_word and has_explain:
        return "validation_rules_queries", "validation_rule_explain"
    if has_vr_word and ("block" in q_norm or "status change" in q_norm):
        return "validation_rules_queries", "validation_rule_filter"
    if has_vr_word and ("list" in q_norm or "show" in q_norm or "which" in q_norm):
        return "validation_rules_queries", "validation_rule_list"

    if "view all data" in q_norm or "modify all data" in q_norm:
        return "security_queries", "security_global_power_users"
    if "permission set" in q_norm and has_explain:
        return "security_queries", "permission_set_explain"
    if ("permission set" in q_norm or "permission sets" in q_norm) and "modify all" in q_norm:
        return "security_queries", "security_modify_all_on_object"
    if ("profile" in q_norm or "profiles" in q_norm) and "modify all" in q_norm:
        return "security_queries", "security_profiles_modify_all_on_object"
    if (("most restricted fields" in q_norm or "restricted fields" in q_norm) or ("most restricted" in q_norm and "field" in q_norm)) and e.object_name:
        return "security_queries", "restricted_fields"

    if "shown in the ui" in q_norm or "shown in ui" in q_norm or "exposed" in q_norm:
        return "ui_queries", "ui_where_shown"

    if "explain lwc" in q_norm:
        return "lwc_queries", "lwc_explain"
    if "which lwc components call apex methods" in q_norm:
        return "lwc_queries", "lwc_calling_apex_bundles"
    if "lwc" in q_norm and "reference" in q_norm and ("field" in q_norm or (e.object_name and "object" not in q_norm)):
        return "lwc_queries", "lwc_reference_fields"
    if "apex methods are called by lwc" in q_norm or ("lwc" in q_norm and "apex methods" in q_norm):
        return "lwc_queries", "lwc_apex_methods"

    if "tech debt summary" in q_norm:
        return "advisor_queries", "techdebt_summary_org"
    if q_norm.startswith("optimize ") and "object" in q_norm:
        return "advisor_queries", "optimize_object"
    if "top 20 most risky automations" in q_norm:
        return "advisor_queries", "top_risky_automations"
    if "top 20 most complex apex classes" in q_norm:
        return "advisor_queries", "top_complex_apex"
    if "top 10 fields with the most writers" in q_norm or "top fields with the most writers" in q_norm:
        return "advisor_queries", "top_fields_by_writers"
    if "over-automated" in q_norm or "over automated" in q_norm:
        return "advisor_queries", "over_automated_objects"
    if "duplicating logic" in q_norm or "same updates" in q_norm or "duplicate flows" in q_norm:
        return "advisor_queries", "duplication_flows_same_writes"
    if "permission sprawl" in q_norm:
        return "advisor_queries", "permission_sprawl"
    if "who can see" in q_norm or "visibility is granted" in q_norm or ("summarize" in q_norm and "visibility" in q_norm):
        return "advisor_queries", "access_model_summary"

    if q_norm.startswith("given this story:") or "where should we implement" in q_norm:
        return "story_planner", "plan_story"

    if "flows touch" in q_norm and "not triggered" in q_norm:
        return "flows_touch_not_triggered", "flows_touch_object_not_triggered"

    if "approval process" in q_norm and ("what breaks" in q_norm or "impact" in q_norm):
        return "approval_process_impact", "approval_process_impact"

    if ("tighten sharing" in q_norm or "restrict sharing" in q_norm or "sharing change" in q_norm) and e.object_name:
        return "sharing_impact", "sharing_impact"

    if "what breaks" in q_norm or "impact" in q_norm or "dependencies" in q_norm:
        return "impact_or_deps", "impact_or_deps"
    if any(k in q_norm for k in ["where used", "used in", "references", "referenced", "where is"]):
        return "where_used_any", "where_used_any"

    return "generic", _infer_intent(q_norm, e)


class BaseTypeHandler:
    def __init__(self, conn: sqlite3.Connection, *, type_name: str, folder: str, question_norm: str):
        self.conn = conn
        self.type_name = type_name
        self.folder = folder
        self.question_norm = question_norm

    def count_on_object(self, object_name: str) -> dict[str, Any]:
        raise NotImplementedError

    def list_on_object(self, object_name: str) -> dict[str, Any]:
        raise NotImplementedError

    def count_all(self) -> dict[str, Any]:
        raise NotImplementedError

    def list_all(self) -> dict[str, Any]:
        raise NotImplementedError


class GenericMetaHandler(BaseTypeHandler):
    def _meta_where(self) -> tuple[str, tuple[str, str]]:
        return "(lower(folder)=lower(?) OR lower(type_guess)=lower(?))", (self.folder, self.type_name)

    def count_all(self) -> dict[str, Any]:
        where, params = self._meta_where()
        c = int(self.conn.execute(f"SELECT COUNT(*) AS c FROM meta_files WHERE {where}", params).fetchone()["c"])
        return {
            "answer_lines": [f"{self.type_name} count: {c}"],
            "evidence": [],
            "count": c,
            "items": [],
        }

    def list_all(self) -> dict[str, Any]:
        where, params = self._meta_where()
        rows = self.conn.execute(
            f"""
            SELECT api_name, path, active, sobject
            FROM meta_files
            WHERE {where}
            ORDER BY api_name
            LIMIT 200
            """,
            params,
        ).fetchall()
        return {
            "answer_lines": [f"{self.type_name} count: {len(rows)}"],
            "evidence": [{"path": r["path"], "line": None, "snippet": r["api_name"]} for r in rows[:5]],
            "count": len(rows),
            "items": [dict(r) for r in rows],
        }

    def count_on_object(self, object_name: str) -> dict[str, Any]:
        rows = self._list_on_object_rows(object_name, limit=5000)
        return {
            "answer_lines": [f"{self.type_name} on {object_name}: {len(rows)}"],
            "evidence": [{"path": r["path"], "line": None, "snippet": r.get("api_name") or r.get("name") or ""} for r in rows[:5]],
            "count": len(rows),
            "items": rows,
        }

    def list_on_object(self, object_name: str) -> dict[str, Any]:
        rows = self._list_on_object_rows(object_name, limit=200)
        return {
            "answer_lines": [f"{self.type_name} on {object_name}: {len(rows)}"],
            "evidence": [{"path": r["path"], "line": None, "snippet": r.get("api_name") or r.get("name") or ""} for r in rows[:5]],
            "count": len(rows),
            "items": rows,
        }

    def _list_on_object_rows(self, object_name: str, *, limit: int) -> list[dict[str, Any]]:
        where, params = self._meta_where()
        sobject_rows = self.conn.execute(
            f"""
            SELECT path, api_name, active, sobject
            FROM meta_files
            WHERE {where}
              AND (
                lower(sobject)=lower(?)
                OR lower(sobject) LIKE lower(?)
              )
            """,
            params + (object_name, f"%{object_name}%"),
        ).fetchall()
        ref_rows = self.conn.execute(
            """
            SELECT DISTINCT mf.path, mf.api_name, mf.active, mf.sobject
            FROM meta_refs mr
            JOIN meta_files mf ON mf.path = mr.src_path
            WHERE lower(mr.src_folder)=lower(?)
              AND mr.ref_kind='OBJECT'
              AND (lower(mr.ref_value)=lower(?) OR lower(mr.ref_value) LIKE lower(?))
            """,
            (self.folder, object_name, f"%{object_name}%"),
        ).fetchall()
        merged: dict[str, dict[str, Any]] = {}
        for row in sobject_rows + ref_rows:
            merged[row["path"]] = dict(row)
        return list(merged.values())[:limit]


class FlowHandler(GenericMetaHandler):
    def count_all(self) -> dict[str, Any]:
        c = int(self.conn.execute("SELECT COUNT(*) AS c FROM flows").fetchone()["c"])
        return {
            "answer_lines": [f"Flows total: {c}"],
            "evidence": [],
            "count": c,
            "items": [],
        }

    def list_all(self) -> dict[str, Any]:
        rows = self.conn.execute(
            "SELECT flow_name, path, trigger_object, status FROM flows ORDER BY flow_name LIMIT 200"
        ).fetchall()
        return {
            "answer_lines": [f"Flows total (listed): {len(rows)}"],
            "evidence": [{"path": r["path"], "line": None, "snippet": r["flow_name"]} for r in rows[:5]],
            "count": len(rows),
            "items": [dict(r) for r in rows],
        }

    def count_on_object(self, object_name: str) -> dict[str, Any]:
        record_triggered = int(
            self.conn.execute(
                "SELECT COUNT(*) AS c FROM flows WHERE lower(trigger_object)=lower(?)",
                (object_name,),
            ).fetchone()["c"]
        )
        touching_rows = self._touching_flow_rows(object_name, limit=5000)
        touching_count = len(touching_rows)
        return {
            "answer_lines": [
                f"Record-triggered flows on {object_name}: {record_triggered}",
                f"Flows that touch {object_name} fields: {touching_count}",
            ],
            "evidence": [
                {"path": r["path"], "line": None, "snippet": r["flow_name"]}
                for r in touching_rows[:5]
            ],
            "count": record_triggered + touching_count,
            "items": touching_rows,
            "record_triggered_count": record_triggered,
            "touching_count": touching_count,
        }

    def list_on_object(self, object_name: str) -> dict[str, Any]:
        record_rows = self.conn.execute(
            """
            SELECT flow_name, path, trigger_object, status
            FROM flows
            WHERE lower(trigger_object)=lower(?)
            ORDER BY flow_name
            LIMIT 200
            """,
            (object_name,),
        ).fetchall()
        touching_rows = self._touching_flow_rows(object_name, limit=200)
        return {
            "answer_lines": [
                f"Record-triggered flows on {object_name}: {len(record_rows)}",
                f"Flows that touch {object_name} fields: {len(touching_rows)}",
            ],
            "evidence": [
                {"path": r["path"], "line": None, "snippet": r["flow_name"]}
                for r in (list(record_rows) + touching_rows)[:5]
            ],
            "count": len(record_rows) + len(touching_rows),
            "items": [
                *[dict(r) | {"category": "record_triggered"} for r in record_rows],
                *[dict(r) | {"category": "touching"} for r in touching_rows],
            ],
        }

    def _touching_flow_rows(self, object_name: str, *, limit: int) -> list[dict[str, Any]]:
        graph_exists = int(self.conn.execute("SELECT COUNT(*) AS c FROM graph_nodes").fetchone()["c"]) > 0
        if graph_exists:
            rows = self.conn.execute(
                """
                SELECT DISTINCT src.name AS flow_name, COALESCE(src.path, e.evidence_path, f.path) AS path
                FROM graph_edges e
                JOIN graph_nodes src ON src.node_id=e.src_node_id
                JOIN graph_nodes dst ON dst.node_id=e.dst_node_id
                LEFT JOIN flows f ON f.flow_name=src.name
                WHERE src.node_type='FLOW'
                  AND (
                    (e.edge_type IN ('FLOW_UPDATES_OBJECT','FLOW_CREATES_OBJECT')
                      AND dst.node_type='OBJECT'
                      AND lower(dst.name)=lower(?))
                    OR
                    (e.edge_type IN ('FLOW_READS_FIELD','FLOW_WRITES_FIELD')
                      AND dst.node_type='FIELD'
                      AND lower(dst.name) LIKE lower(?))
                  )
                ORDER BY flow_name
                LIMIT ?
                """,
                (object_name, f"{object_name}.%", limit),
            ).fetchall()
            return [dict(r) for r in rows]

        rows = self.conn.execute(
            """
            SELECT DISTINCT flow_name, path
            FROM (
              SELECT flow_name, path FROM flow_field_reads WHERE lower(full_field_name) LIKE lower(?)
              UNION
              SELECT flow_name, evidence_path AS path
              FROM flow_true_writes
              WHERE write_kind='field_write'
                AND lower(field_full_name) LIKE lower(?)
              UNION
              SELECT flow_name, path FROM flow_field_writes WHERE lower(full_field_name) LIKE lower(?)
            )
            ORDER BY flow_name
            LIMIT ?
            """,
            (f"{object_name}.%", f"{object_name}.%", f"{object_name}.%", limit),
        ).fetchall()
        return [dict(r) for r in rows]


class ApprovalProcessHandler(GenericMetaHandler):
    def _active_filter(self) -> bool:
        return "active" in self.question_norm

    def count_all(self) -> dict[str, Any]:
        clauses = []
        params: list[Any] = []
        if self._active_filter():
            clauses.append("active=1")
        where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
        c = int(self.conn.execute(f"SELECT COUNT(*) AS c FROM approval_processes {where}", tuple(params)).fetchone()["c"])
        unknown = int(
            self.conn.execute("SELECT COUNT(*) AS c FROM approval_processes WHERE active IS NULL").fetchone()["c"]
        )
        lines = [f"Approval processes: {c}"]
        if self._active_filter():
            lines.append(f"active=true count = {c}, unknown status = {unknown}")
        return {"answer_lines": lines, "evidence": [], "count": c, "items": []}

    def list_all(self) -> dict[str, Any]:
        clauses = []
        params: list[Any] = []
        if self._active_filter():
            clauses.append("active=1")
        where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
        rows = self.conn.execute(
            f"""
            SELECT name, object_name, active, path
            FROM approval_processes
            {where}
            ORDER BY object_name, name
            LIMIT 200
            """,
            tuple(params),
        ).fetchall()
        return {
            "answer_lines": [f"Approval processes listed: {len(rows)}"],
            "evidence": [{"path": r["path"], "line": None, "snippet": r["name"]} for r in rows[:5]],
            "count": len(rows),
            "items": [dict(r) for r in rows],
        }

    def count_on_object(self, object_name: str) -> dict[str, Any]:
        rows = self._rows_on_object(object_name, limit=5000)
        unknown = int(
            self.conn.execute(
                "SELECT COUNT(*) AS c FROM approval_processes WHERE (lower(object_name)=lower(?) OR lower(object_name) LIKE lower(?)) AND active IS NULL",
                (object_name, f"%{object_name}%"),
            ).fetchone()["c"]
        )
        lines = [f"Approval processes on {object_name}: {len(rows)}"]
        if self._active_filter():
            lines.append(f"active=true count = {len(rows)}, unknown status = {unknown}")
        return {
            "answer_lines": lines,
            "evidence": [{"path": r["path"], "line": None, "snippet": r["name"]} for r in rows[:5]],
            "count": len(rows),
            "items": rows,
        }

    def list_on_object(self, object_name: str) -> dict[str, Any]:
        rows = self._rows_on_object(object_name, limit=200)
        return {
            "answer_lines": [f"Approval processes on {object_name}: {len(rows)}"],
            "evidence": [{"path": r["path"], "line": None, "snippet": r["name"]} for r in rows[:5]],
            "count": len(rows),
            "items": rows,
        }

    def _rows_on_object(self, object_name: str, *, limit: int) -> list[dict[str, Any]]:
        clauses = ["(lower(object_name)=lower(?) OR lower(object_name) LIKE lower(?))"]
        params: list[Any] = [object_name, f"%{object_name}%"]
        if self._active_filter():
            clauses.append("active=1")
        where = " AND ".join(clauses)
        rows = self.conn.execute(
            f"""
            SELECT name, object_name, active, path
            FROM approval_processes
            WHERE {where}
            ORDER BY object_name, name
            LIMIT ?
            """,
            tuple(params + [limit]),
        ).fetchall()
        if rows:
            return [dict(r) for r in rows]

        # Fallback when object_name parsing is missing/incomplete.
        fallback = self.conn.execute(
            """
            SELECT name, object_name, active, path
            FROM approval_processes
            WHERE lower(path) LIKE lower(?)
            ORDER BY name
            LIMIT ?
            """,
            (f"%/approvalProcesses/{object_name}.%.approvalProcess-meta.xml", limit),
        ).fetchall()
        return [dict(r) for r in fallback]


class SharingRuleHandler(GenericMetaHandler):
    def count_all(self) -> dict[str, Any]:
        c = int(self.conn.execute("SELECT COUNT(*) AS c FROM sharing_rules").fetchone()["c"])
        return {"answer_lines": [f"Sharing rules: {c}"], "evidence": [], "count": c, "items": []}

    def list_all(self) -> dict[str, Any]:
        rows = self.conn.execute(
            """
            SELECT name, object_name, rule_type, access_level, path
            FROM sharing_rules
            ORDER BY object_name, name
            LIMIT 200
            """
        ).fetchall()
        return {
            "answer_lines": [f"Sharing rules listed: {len(rows)}"],
            "evidence": [{"path": r["path"], "line": None, "snippet": r["name"]} for r in rows[:5]],
            "count": len(rows),
            "items": [dict(r) for r in rows],
        }

    def count_on_object(self, object_name: str) -> dict[str, Any]:
        rows = self.conn.execute(
            """
            SELECT name, object_name, rule_type, access_level, path
            FROM sharing_rules
            WHERE lower(object_name)=lower(?) OR lower(object_name) LIKE lower(?)
            ORDER BY name
            """,
            (object_name, f"%{object_name}%"),
        ).fetchall()
        return {
            "answer_lines": [f"Sharing rules on {object_name}: {len(rows)}"],
            "evidence": [{"path": r["path"], "line": None, "snippet": r["name"]} for r in rows[:5]],
            "count": len(rows),
            "items": [dict(r) for r in rows],
        }

    def list_on_object(self, object_name: str) -> dict[str, Any]:
        return self.count_on_object(object_name)


class LWCHandler(GenericMetaHandler):
    def _bundle_rows(self, object_name: str | None = None) -> list[sqlite3.Row]:
        if object_name:
            return self.conn.execute(
                """
                SELECT DISTINCT
                  substr(mf.path, instr(mf.path,'/lwc/')+5, instr(substr(mf.path, instr(mf.path,'/lwc/')+5),'/')-1) AS bundle,
                  MIN(mf.path) AS sample_path
                FROM meta_files mf
                LEFT JOIN meta_refs mr ON mr.src_path = mf.path
                WHERE lower(mf.folder)='lwc'
                  AND (
                    lower(COALESCE(mr.ref_value,'')) LIKE lower(?)
                    OR lower(COALESCE(mr.snippet,'')) LIKE lower(?)
                    OR lower(mf.path) LIKE lower(?)
                  )
                GROUP BY bundle
                ORDER BY bundle
                LIMIT 2000
                """,
                (f"{object_name}.%", f"%{object_name}%", f"%/lwc/%{object_name.lower()}%"),
            ).fetchall()
        return self.conn.execute(
            """
            SELECT DISTINCT
              substr(path, instr(path,'/lwc/')+5, instr(substr(path, instr(path,'/lwc/')+5),'/')-1) AS bundle,
              MIN(path) AS sample_path
            FROM meta_files
            WHERE lower(folder)='lwc' AND path LIKE '%/lwc/%/%'
            GROUP BY bundle
            ORDER BY bundle
            LIMIT 2000
            """
        ).fetchall()

    def count_all(self) -> dict[str, Any]:
        rows = self._bundle_rows()
        return {
            "answer_lines": [f"LWC bundles: {len(rows)}"],
            "evidence": [{"path": r["sample_path"], "line": None, "snippet": r["bundle"]} for r in rows[:5]],
            "count": len(rows),
            "items": [{"bundle": r["bundle"], "path": r["sample_path"]} for r in rows],
        }

    def list_all(self) -> dict[str, Any]:
        rows = self._bundle_rows()
        return {
            "answer_lines": [f"LWC bundles: {len(rows)}"],
            "evidence": [{"path": r["sample_path"], "line": None, "snippet": r["bundle"]} for r in rows[:10]],
            "count": len(rows),
            "items": [{"bundle": r["bundle"], "path": r["sample_path"]} for r in rows[:500]],
        }

    def count_on_object(self, object_name: str) -> dict[str, Any]:
        rows = self._bundle_rows(object_name)
        return {
            "answer_lines": [f"LWC bundles referencing {object_name}: {len(rows)}"],
            "evidence": [{"path": r["sample_path"], "line": None, "snippet": r["bundle"]} for r in rows[:10]],
            "count": len(rows),
            "items": [{"bundle": r["bundle"], "path": r["sample_path"]} for r in rows[:500]],
        }

    def list_on_object(self, object_name: str) -> dict[str, Any]:
        return self.count_on_object(object_name)


TYPE_HANDLERS = {
    "Flow": FlowHandler,
    "ApprovalProcess": ApprovalProcessHandler,
    "SharingRule": SharingRuleHandler,
    "LWC": LWCHandler,
}


def _handler_for(conn: sqlite3.Connection, *, type_name: str, folder: str, question_norm: str) -> BaseTypeHandler:
    cls = TYPE_HANDLERS.get(type_name, GenericMetaHandler)
    return cls(conn, type_name=type_name, folder=folder, question_norm=question_norm)


def _where_used_any(conn: sqlite3.Connection, token: str) -> tuple[list[str], list[dict[str, Any]]]:
    if not token:
        return ["Could not resolve token for where-used query"], []
    meta_rows = conn.execute(
        """
        SELECT ref_kind, ref_value, src_path, line_no, snippet, confidence
        FROM meta_refs
        WHERE lower(ref_value)=lower(?)
           OR lower(ref_value) LIKE lower(?)
           OR lower(snippet) LIKE lower(?)
        """,
        (token, f"%{token}%", f"%{token}%"),
    ).fetchall()
    ref_rows = conn.execute(
        """
        SELECT
          ref_type AS ref_kind,
          ref_key AS ref_value,
          src_path,
          line_start AS line_no,
          snippet,
          confidence,
          src_type,
          src_name
        FROM "references"
        WHERE lower(ref_key)=lower(?)
           OR lower(ref_key) LIKE lower(?)
           OR lower(snippet) LIKE lower(?)
        """,
        (token, f"%{token}%", f"%{token}%"),
    ).fetchall()
    if not meta_rows and not ref_rows:
        return [f"No references found for {token}"], []
    merged: dict[tuple[str, int | None, str, str], dict[str, Any]] = {}
    for r in ref_rows:
        row = dict(r)
        row["path"] = row.get("src_path")
        key = (
            str(row.get("src_path") or ""),
            int(row["line_no"]) if row.get("line_no") is not None else None,
            str(row.get("ref_value") or ""),
            str(row.get("snippet") or ""),
        )
        row["source_table"] = "references"
        merged[key] = row
    for r in meta_rows:
        row = dict(r)
        row["path"] = row.get("src_path")
        key = (
            str(row.get("src_path") or ""),
            int(row["line_no"]) if row.get("line_no") is not None else None,
            str(row.get("ref_value") or ""),
            str(row.get("snippet") or ""),
        )
        # Keep richer "references" row if it already exists.
        if key in merged:
            continue
        row["source_table"] = "meta_refs"
        row.setdefault("src_type", "META")
        row.setdefault("src_name", "")
        merged[key] = row

    evidence = list(merged.values())
    evidence.sort(
        key=lambda r: (
            str(r.get("src_type") or "META"),
            str(r.get("src_path") or ""),
            int(r["line_no"]) if r.get("line_no") is not None else -1,
            str(r.get("ref_value") or ""),
        )
    )
    by_type: dict[str, int] = {}
    for r in evidence:
        t = str(r.get("src_type") or "META")
        by_type[t] = by_type.get(t, 0) + 1
    summary = ", ".join(f"{k}:{v}" for k, v in sorted(by_type.items()))
    answer = [f"References found for {token}: {len(evidence)}", f"By source type: {summary}"]
    return answer, evidence


def _resolve_approval_process(
    conn: sqlite3.Connection,
    *,
    object_name: str | None,
    process_name: str | None,
    raw_question: str,
) -> tuple[dict[str, Any] | None, list[str]]:
    suggestions: list[str] = []
    if not process_name and raw_question:
        m = APPROVAL_COMPONENT_PATTERN.search(raw_question)
        if m:
            object_name = object_name or m.group(1).strip()
            process_name = m.group(2).strip()
    if not process_name:
        names = [r["name"] for r in conn.execute("SELECT name FROM approval_processes ORDER BY name").fetchall()]
        if names:
            best = process.extract(raw_question, names, scorer=fuzz.WRatio, limit=3)
            suggestions = [x[0] for x in best if int(x[1]) >= 70]
        return None, suggestions

    candidates = []
    if object_name:
        candidates.append(f"{object_name}.{process_name}")
    candidates.append(process_name)
    if "." in process_name:
        candidates.append(process_name.split(".", 1)[1])

    row = None
    for c in candidates:
        row = conn.execute(
            """
            SELECT name, object_name, active, path
            FROM approval_processes
            WHERE lower(name)=lower(?)
            LIMIT 1
            """,
            (c,),
        ).fetchone()
        if row:
            break

    if not row and object_name:
        row = conn.execute(
            """
            SELECT name, object_name, active, path
            FROM approval_processes
            WHERE lower(path)=lower(?)
               OR lower(path) LIKE lower(?)
            LIMIT 1
            """,
            (
                f"force-app/main/default/approvalProcesses/{object_name}.{process_name}.approvalProcess-meta.xml",
                f"%/approvalProcesses/{object_name}.{process_name}.approvalProcess-meta.xml",
            ),
        ).fetchone()

    if row:
        return dict(row), suggestions

    names = [r["name"] for r in conn.execute("SELECT name FROM approval_processes ORDER BY name").fetchall()]
    if names:
        best = process.extract(f"{object_name or ''}.{process_name}".strip("."), names, scorer=fuzz.WRatio, limit=3)
        suggestions = [x[0] for x in best if int(x[1]) >= 70]
    return None, suggestions


def _explain_component(
    conn: sqlite3.Connection,
    *,
    question: str,
    q_norm: str,
    entities: ResolvedEntities,
    d: EntityDictionary,
) -> tuple[list[str], list[dict[str, Any]], list[dict[str, Any]], dict[str, Any] | None]:
    if entities.metadata_type == "SharingRule" or "sharing rules" in q_norm or "sharing rule" in q_norm:
        obj = entities.object_name
        if not obj:
            hint = _extract_object_hint(q_norm)
            if hint:
                obj_match = resolve_object_phrase(hint, d.object_alias_map, score_cutoff=85)
                if obj_match:
                    obj = obj_match[0]
        if not obj:
            return ["Couldn't resolve object for sharing rules explain."], [], [], None
        rows = conn.execute(
            """
            SELECT name, object_name, rule_type, access_level, path
            FROM sharing_rules
            WHERE lower(object_name)=lower(?) OR lower(object_name) LIKE lower(?)
            ORDER BY name
            LIMIT 500
            """,
            (obj, f"%{obj}%"),
        ).fetchall()
        if not rows:
            return [f"No sharing rules found for {obj} in repo index"], [], [], None
        type_counts: dict[str, int] = {}
        for r in rows:
            t = r["rule_type"] or "unknown"
            type_counts[t] = type_counts.get(t, 0) + 1
        lines = [f"Sharing rules for {obj}: {len(rows)}"]
        lines.extend([f"- {k}: {v}" for k, v in sorted(type_counts.items(), key=lambda x: x[0])])
        evidence = [{"path": r["path"], "line_no": None, "snippet": f"{r['name']} ({r['rule_type'] or 'unknown'})", "confidence": 1.0} for r in rows[:50]]
        return lines, evidence, [dict(r) for r in rows], None

    if entities.metadata_type == "ApprovalProcess" or "approval process" in q_norm:
        row, suggestions = _resolve_approval_process(
            conn,
            object_name=entities.object_name,
            process_name=entities.approval_process_name or entities.approval_process_full_name,
            raw_question=question,
        )
        if not row:
            lines = ["Couldn't find that approval process in the repo index."]
            if suggestions:
                lines.append("Closest matches: " + ", ".join(suggestions[:3]))
            return lines, [], [], None
        object_name = row.get("object_name") or entities.object_name or ""
        active_raw = row.get("active")
        active = "unknown"
        if active_raw in (0, 1):
            active = "true" if int(active_raw) == 1 else "false"
        ref_count = int(
            conn.execute(
                "SELECT COUNT(*) AS c FROM meta_refs WHERE src_path=?",
                (row["path"],),
            ).fetchone()["c"]
        )
        lines = [
            f"Approval Process: {row['name']} ({object_name})",
            f"Found at: {row['path']}",
            f"Active: {active}",
            f"Indexed references in file: {ref_count}",
        ]
        evidence = [{"path": row["path"], "line_no": None, "snippet": row["name"], "confidence": 1.0}]
        return lines, evidence, [row], None

    target = _resolve_type_locked_explain_target(conn, question, q_norm, entities, d)
    if not target:
        target = _target_from_entities(question, q_norm, entities, d)
    if not target:
        return ["Could not resolve component to explain."], [], [], None
    dossier = build_evidence(conn, target=target, depth=2, top_n=20)
    lines, evidence, items = _answer_from_evidence(
        intent="explain_component",
        q_norm=q_norm,
        metadata_type=entities.metadata_type,
        object_name=entities.object_name,
        target=target,
        dossier=dossier,
    )
    return lines, evidence, items, dossier


def _resolve_component_target(question: str, q_norm: str, d: EntityDictionary) -> str | None:
    flow_exact = {x.lower(): x for x in d.flows}
    class_exact = {x.lower(): x for x in d.apex_classes}

    m_flow = FLOW_PREFIX_PATTERN.search(question)
    if m_flow:
        name = m_flow.group(1).strip()
        canonical = flow_exact.get(name.lower())
        if canonical:
            return f"Flow:{canonical}"

    m_class = CLASS_PREFIX_PATTERN.search(question)
    if m_class:
        name = m_class.group(1).strip()
        canonical = class_exact.get(name.lower())
        if canonical:
            return f"Class:{canonical}"

    m_trigger = TRIGGER_PREFIX_PATTERN.search(question)
    if m_trigger:
        name = m_trigger.group(1).strip()
        return f"Trigger:{name}"

    grams = _ngrams(q_norm.split(), min_n=1, max_n=5)
    flow_alias = {normalize(x): x for x in d.flows if x}
    class_alias = {normalize(x): x for x in d.apex_classes if x}

    for gram in grams:
        key = normalize(gram)
        if key in flow_alias:
            return f"Flow:{flow_alias[key]}"
        if key in class_alias:
            return f"Class:{class_alias[key]}"

    if d.flows:
        f = process.extractOne(q_norm, d.flows, scorer=fuzz.WRatio, score_cutoff=90)
        if f:
            return f"Flow:{f[0]}"
    if d.apex_classes:
        c = process.extractOne(q_norm, d.apex_classes, scorer=fuzz.WRatio, score_cutoff=90)
        if c:
            return f"Class:{c[0]}"
    return None


def _target_from_entities(question: str, q_norm: str, entities: ResolvedEntities, d: EntityDictionary) -> str | None:
    if entities.full_field_name:
        return entities.full_field_name
    if entities.object_name:
        return entities.object_name
    if entities.endpoint:
        return entities.endpoint
    return _resolve_component_target(question, q_norm, d)


def _resolve_type_locked_explain_target(
    conn: sqlite3.Connection,
    question: str,
    q_norm: str,
    entities: ResolvedEntities,
    d: EntityDictionary,
) -> str | None:
    mtype = entities.metadata_type
    if mtype == "Flow":
        name = _resolve_flow_name(conn, d, _extract_component_name(question, "Flow") or _extract_tail(question, ["flow "]))
        return f"Flow:{name}" if name else None
    if mtype == "ApexClass":
        name = _resolve_class_name(conn, d, _extract_component_name(question, "ApexClass") or _extract_tail(question, ["apex class ", "class "]))
        return f"Class:{name}" if name else None
    if mtype == "Trigger":
        name = _resolve_trigger_name(conn, _extract_component_name(question, "Trigger") or _extract_tail(question, ["trigger "]))
        return f"Trigger:{name}" if name else None
    if mtype == "LWC":
        bundle = _resolve_lwc_bundle(conn, _extract_component_name(question, "LWC") or _extract_tail(question, ["lwc "]))
        return f"LWC:{bundle}" if bundle else None
    if mtype in {"PermissionSet", "Profile", "Layout", "Flexipage", "ConnectedApp"}:
        folder_map = {
            "PermissionSet": "permissionsets",
            "Profile": "profiles",
            "Layout": "layouts",
            "Flexipage": "flexipages",
            "ConnectedApp": "connectedApps",
        }
        folder = folder_map[mtype]
        name = _extract_component_name(question, mtype)
        if not name:
            return None
        row = conn.execute(
            """
            SELECT path
            FROM meta_files
            WHERE lower(folder)=lower(?)
              AND lower(api_name)=lower(?)
            LIMIT 1
            """,
            (folder, name),
        ).fetchone()
        if row:
            return f"path:{row['path']}"
    if mtype == "ValidationRule":
        rule = _resolve_validation_rule_name(conn, _extract_component_name(question, "ValidationRule") or _extract_tail(question, ["validation rule "]))
        if not rule:
            return None
        row = conn.execute("SELECT path FROM validation_rules WHERE lower(rule_name)=lower(?) LIMIT 1", (rule,)).fetchone()
        if row:
            return f"path:{row['path']}"
    return None


def _evidence_to_rows(payload: dict[str, Any], limit: int = 50) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    seen: set[tuple[str, int | None, str]] = set()

    def add(row: dict[str, Any]) -> None:
        key = (row.get("path") or "", row.get("line_no"), row.get("snippet") or "")
        if key in seen:
            return
        seen.add(key)
        rows.append(row)

    for item in payload.get("writers", [])[:limit]:
        add(
            {
                "path": item.get("path") or item.get("evidence_path"),
                "line_no": item.get("line_start"),
                "snippet": item.get("snippet") or item.get("name"),
                "confidence": item.get("confidence"),
                "section": "writers",
            }
        )
    for item in payload.get("readers", [])[:limit]:
        add(
            {
                "path": item.get("path") or item.get("evidence_path"),
                "line_no": item.get("line_start"),
                "snippet": item.get("snippet") or item.get("name"),
                "confidence": item.get("confidence"),
                "section": "readers",
            }
        )
    for item in payload.get("refs", [])[:limit]:
        add(
            {
                "path": item.get("path"),
                "line_no": item.get("line_no"),
                "snippet": item.get("snippet") or item.get("ref_value"),
                "confidence": item.get("confidence"),
                "section": "refs",
            }
        )

    if not rows:
        for path in payload.get("evidence_paths", [])[:limit]:
            add({"path": path, "line_no": None, "snippet": "", "confidence": None, "section": "paths"})
    return rows[:limit]


def _answer_from_evidence(
    *,
    intent: str,
    q_norm: str,
    metadata_type: str | None,
    object_name: str | None,
    target: str,
    dossier: dict[str, Any],
) -> tuple[list[str], list[dict[str, Any]], list[dict[str, Any]]]:
    target_meta = dossier.get("target", {})
    if not target_meta.get("found"):
        lines = ["Not found in repo index"]
        suggestions = target_meta.get("suggestions") or []
        if suggestions:
            lines.append("Suggestions: " + ", ".join(suggestions[:5]))
        return lines, [], []

    counts = dossier.get("summary_counts", {}) or {}
    automations = dossier.get("automations", []) or []
    writers = dossier.get("writers", []) or []
    readers = dossier.get("readers", []) or []
    refs = dossier.get("refs", []) or []

    if metadata_type == "Flow" and object_name and intent in {"count_type_on_object", "list_type_on_object"}:
        rt = [a for a in automations if a.get("surface") == "record_triggered_flow"]
        touch = [a for a in automations if a.get("surface") == "flow_touching_object_fields"]
        lines = [
            f"Record-triggered flows on {object_name}: {len(rt)}",
            f"Flows that touch {object_name} fields: {len(touch)}",
        ]
        evidence = [
            {"path": a.get("path"), "line_no": None, "snippet": a.get("name"), "confidence": None}
            for a in (rt + touch)[:50]
        ]
        return lines, evidence, (rt + touch)

    if metadata_type == "ApprovalProcess" and object_name and intent in {"count_type_on_object", "list_type_on_object"}:
        aps = [a for a in automations if a.get("surface") == "approval_process"]
        if "active" in q_norm:
            active = [a for a in aps if str(a.get("active")) in {"1", "true", "True"}]
            unknown = [a for a in aps if a.get("active") is None]
            lines = [f"active=true count = {len(active)}, unknown status = {len(unknown)}"]
            evidence = [
                {"path": a.get("path"), "line_no": None, "snippet": a.get("name"), "confidence": None}
                for a in active[:50]
            ]
            return lines, evidence, active
        lines = [f"Approval processes on {object_name}: {len(aps)}"]
        evidence = [
            {"path": a.get("path"), "line_no": None, "snippet": a.get("name"), "confidence": None}
            for a in aps[:50]
        ]
        return lines, evidence, aps

    lines = [
        f"Resolved target: {target_meta.get('type')} {target_meta.get('name') or target}",
        (
            "Summary — "
            f"hotspots:{counts.get('hotspots', 0)} writers:{counts.get('writers', 0)} "
            f"readers:{counts.get('readers', 0)} refs:{counts.get('refs', 0)}"
        ),
    ]
    if intent == "where_used_any":
        lines.append(f"References found: {len(refs)}")
    if intent == "impact_or_deps":
        lines.append(f"Dependents found: {len(writers) + len(readers)}")

    evidence = _evidence_to_rows(dossier, limit=50)
    items: list[dict[str, Any]] = []
    items.extend(writers[:20])
    items.extend(readers[:20])
    items.extend(refs[:20])
    return lines, evidence, items


def _field_suggestions(d: EntityDictionary, candidate: str, limit: int = 5) -> list[str]:
    if not candidate:
        return []
    best = process.extract(candidate, d.fields, scorer=fuzz.WRatio, limit=limit)
    return [m[0] for m in best if int(m[1]) >= 60]


def _strict_field_resolution(
    conn: sqlite3.Connection,
    d: EntityDictionary,
    question: str,
    entities: ResolvedEntities,
) -> tuple[str | None, str | None]:
    direct = DIRECT_FIELD_PATTERN.search(question)
    if direct:
        requested = f"{direct.group(1)}.{direct.group(2)}"
        row = conn.execute("SELECT full_name FROM fields WHERE lower(full_name)=lower(?) LIMIT 1", (requested,)).fetchone()
        if row:
            return row["full_name"], None
        sugg = _field_suggestions(d, requested)
        if sugg:
            return None, f"Field not found: {requested}. Did you mean: {', '.join(sugg)}"
        return None, f"Field not found: {requested}"
    if entities.full_field_name:
        return entities.full_field_name, None
    if entities.requested_field:
        sugg = _field_suggestions(d, entities.requested_field)
        if sugg:
            return None, f"Field not found: {entities.requested_field}. Did you mean: {', '.join(sugg)}"
        return None, f"Field not found: {entities.requested_field}"
    return None, "field not found in repo"


def _handle_flows_write_field(conn: sqlite3.Connection, full_field_name: str) -> dict[str, Any]:
    obj, fld = full_field_name.split(".", 1)
    wildcard = f"%.{fld}"
    rows = conn.execute(
        """
        SELECT DISTINCT flow_name, evidence_path AS path, evidence_snippet AS snippet, confidence
        FROM flow_true_writes
        WHERE write_kind='field_write'
          AND (lower(field_full_name)=lower(?) OR lower(field_full_name)=lower(?))
        UNION
        SELECT DISTINCT flow_name, path, '' AS snippet, confidence
        FROM flow_field_writes
        WHERE lower(full_field_name)=lower(?) OR lower(full_field_name)=lower(?)
        ORDER BY confidence DESC, flow_name
        LIMIT 200
        """,
        (full_field_name, wildcard, full_field_name, wildcard),
    ).fetchall()
    if not rows:
        rec_rows = conn.execute(
            """
            SELECT DISTINCT flow_name, evidence_path AS path, evidence_snippet AS snippet, confidence
            FROM flow_true_writes
            WHERE write_kind='record_write' AND lower(sobject_type)=lower(?)
            ORDER BY confidence DESC, flow_name
            LIMIT 200
            """,
            (obj,),
        ).fetchall()
        rows = rec_rows

    items = [dict(r) for r in rows]
    evidence = [{"path": r["path"], "line_no": None, "snippet": r["snippet"] or r["flow_name"], "confidence": r["confidence"]} for r in rows[:50]]
    lines = [f"Flows that write {full_field_name}: {len(rows)}"]
    return {"answer_lines": lines, "evidence": evidence, "items": items, "count": len(items)}


def _handle_apex_write_field(conn: sqlite3.Connection, full_field_name: str) -> dict[str, Any]:
    _, fld = full_field_name.split(".", 1)
    wildcard = f"%.{fld}"
    rows = conn.execute(
        """
        SELECT DISTINCT class_name, path, evidence_snippet, confidence
        FROM apex_rw
        WHERE rw='write'
          AND (lower(field_full_name)=lower(?) OR lower(field_full_name)=lower(?))
        ORDER BY confidence DESC, class_name
        LIMIT 200
        """,
        (full_field_name, wildcard),
    ).fetchall()
    items = [dict(r) for r in rows]
    evidence = [{"path": r["path"], "line_no": None, "snippet": r["evidence_snippet"] or r["class_name"], "confidence": r["confidence"]} for r in rows[:50]]
    lines = [f"Apex classes that write {full_field_name}: {len(rows)}"]
    return {"answer_lines": lines, "evidence": evidence, "items": items, "count": len(items)}


def _handle_writers_for_field(conn: sqlite3.Connection, full_field_name: str) -> dict[str, Any]:
    flow_rows = conn.execute(
        """
        SELECT DISTINCT flow_name AS writer_name, evidence_path AS path, evidence_snippet AS snippet, confidence
        FROM flow_true_writes
        WHERE write_kind='field_write' AND lower(field_full_name)=lower(?)
        ORDER BY confidence DESC, writer_name
        LIMIT 500
        """,
        (full_field_name,),
    ).fetchall()
    apex_rows = conn.execute(
        """
        SELECT DISTINCT class_name AS writer_name, path, evidence_snippet AS snippet, confidence
        FROM apex_rw
        WHERE rw='write' AND lower(field_full_name)=lower(?)
        ORDER BY confidence DESC, writer_name
        LIMIT 500
        """,
        (full_field_name,),
    ).fetchall()
    flow_items = [{"type": "FLOW", "name": r["writer_name"], "path": r["path"], "snippet": r["snippet"], "confidence": r["confidence"]} for r in flow_rows]
    apex_items = [{"type": "APEX_CLASS", "name": r["writer_name"], "path": r["path"], "snippet": r["snippet"], "confidence": r["confidence"]} for r in apex_rows]
    items = flow_items + apex_items
    type_count = {"FLOW": len(flow_items), "APEX_CLASS": len(apex_items)}
    total = len(items)
    lines = [
        f"Writers for {full_field_name}: {total}",
        f"- Flows: {type_count['FLOW']}",
        f"- Apex classes: {type_count['APEX_CLASS']}",
    ]
    if total >= 3 and type_count["FLOW"] > 0 and type_count["APEX_CLASS"] > 0:
        lines.append("Recommendation: consolidate to a single source of truth (Flow or Apex) to reduce overwrite risk.")
    elif total >= 2:
        lines.append("Recommendation: review writer order and ownership; multiple writers detected.")
    evidence = [{"path": i["path"], "line_no": None, "snippet": f"{i['type']} {i['name']}", "confidence": i["confidence"]} for i in items[:50]]
    return {"answer_lines": lines, "evidence": evidence, "items": items, "count": total}


def _handle_approval_process_inventory(conn: sqlite3.Connection) -> dict[str, Any]:
    rows = conn.execute(
        """
        SELECT name, object_name, active, path
        FROM approval_processes
        ORDER BY object_name, name
        LIMIT 2000
        """
    ).fetchall()
    items = [dict(r) for r in rows]
    evidence = [{"path": r["path"], "line_no": None, "snippet": f"{r['object_name']} -> {r['name']}", "confidence": 1.0} for r in rows[:50]]
    lines = [f"Approval processes total: {len(rows)}"]
    return {"answer_lines": lines, "evidence": evidence, "items": items, "count": len(items)}


def _handle_approval_process_references(conn: sqlite3.Connection, *, question: str, entities: ResolvedEntities) -> dict[str, Any]:
    row, suggestions = _resolve_approval_process(
        conn,
        object_name=entities.object_name,
        process_name=entities.approval_process_name or entities.approval_process_full_name,
        raw_question=question,
    )
    if not row:
        lines = ["Approval process not found in repo index"]
        if suggestions:
            lines.append("Closest matches: " + ", ".join(suggestions[:5]))
        return {"answer_lines": lines, "evidence": [], "items": [], "count": 0}

    refs = conn.execute(
        """
        SELECT ref_kind, ref_value, src_path, line_no, snippet, confidence
        FROM meta_refs
        WHERE lower(ref_value)=lower(?)
           OR lower(snippet) LIKE lower(?)
        ORDER BY confidence DESC, src_path, COALESCE(line_no,0)
        LIMIT 400
        """,
        (row["name"], f"%{row['name']}%"),
    ).fetchall()
    lines = [f"References found for approval process {row['name']}: {len(refs)}"]
    evidence = [{"path": row["path"], "line_no": None, "snippet": row["name"], "confidence": 1.0}]
    evidence.extend(
        [{"path": r["src_path"], "line_no": r["line_no"], "snippet": r["snippet"] or r["ref_value"], "confidence": r["confidence"]} for r in refs[:49]]
    )
    return {"answer_lines": lines, "evidence": evidence[:50], "items": [dict(r) for r in refs], "count": len(refs)}


def _handle_endpoints_inventory(conn: sqlite3.Connection) -> dict[str, Any]:
    rows = conn.execute(
        """
        SELECT endpoint_value, class_name, path, endpoint_type, line_start, line_end
        FROM apex_endpoints
        ORDER BY endpoint_value, class_name
        LIMIT 1000
        """
    ).fetchall()
    grouped: dict[str, list[dict[str, Any]]] = {}
    for r in rows:
        grouped.setdefault(r["endpoint_value"], []).append(dict(r))
    items: list[dict[str, Any]] = []
    evidence: list[dict[str, Any]] = []
    for endpoint, writers in grouped.items():
        items.append(
            {
                "endpoint": endpoint,
                "callers": [
                    {
                        "class_name": w["class_name"],
                        "path": w["path"],
                        "line_start": w["line_start"],
                        "line_end": w["line_end"],
                        "endpoint_type": w["endpoint_type"],
                    }
                    for w in writers[:5]
                ],
            }
        )
        for w in writers[:2]:
            evidence.append(
                {
                    "path": w["path"],
                    "line_no": w["line_start"],
                    "snippet": f"{endpoint} <- {w['class_name']}",
                    "confidence": 1.0,
                }
            )
    lines = [f"Callout endpoints found: {len(grouped)}"]
    return {"answer_lines": lines, "evidence": evidence[:50], "items": items, "count": len(items)}


def _handle_named_credentials_inventory(conn: sqlite3.Connection) -> dict[str, Any]:
    named = conn.execute(
        """
        SELECT DISTINCT endpoint_value
        FROM apex_endpoints
        WHERE endpoint_type='named_credential' OR lower(endpoint_value) LIKE 'callout:%'
        ORDER BY endpoint_value
        """
    ).fetchall()
    checked = ["namedCredentials", "externalCredentials", "authproviders", "connectedApps", "customMetadata"]
    mf_rows = conn.execute(
        """
        SELECT folder, api_name, path
        FROM meta_files
        WHERE lower(folder) IN ('namedcredentials','externalcredentials','authproviders','connectedapps','custommetadata')
        ORDER BY folder, api_name
        LIMIT 1000
        """
    ).fetchall()
    by_name: dict[str, dict[str, Any]] = {}
    for r in named:
        by_name[r["endpoint_value"]] = {"name": r["endpoint_value"], "source": "apex_endpoints", "path": None}
    for r in mf_rows:
        name = r["api_name"] or Path(r["path"]).stem
        key = f"{r['folder']}:{name}"
        by_name.setdefault(key, {"name": name, "source": r["folder"], "path": r["path"]})
    items = list(by_name.values())
    evidence = [{"path": i.get("path"), "line_no": None, "snippet": i["name"], "confidence": 1.0} for i in items[:50]]
    lines = [f"Named credentials found: {len(items)}"]
    if not items:
        lines.append(f"Named Credentials not found in repo metadata (0). Checked folders: {', '.join(checked)}")
    return {"answer_lines": lines, "evidence": evidence, "items": items, "count": len(items)}


def _handle_class_endpoints(conn: sqlite3.Connection, d: EntityDictionary, question: str) -> dict[str, Any]:
    candidate = _extract_tail(question, ["what endpoints does ", "endpoints does "])
    cls = _resolve_class_name(conn, d, candidate)
    if not cls:
        return {"answer_lines": [], "evidence": [], "items": [], "count": 0, "error": "Apex class not found in repo"}
    rows = conn.execute(
        """
        SELECT endpoint_value, endpoint_type, path, line_start, line_end
        FROM apex_endpoints
        WHERE lower(class_name)=lower(?)
        ORDER BY endpoint_value
        LIMIT 200
        """,
        (cls,),
    ).fetchall()
    items = [dict(r) for r in rows]
    evidence = [{"path": r["path"], "line_no": r["line_start"], "snippet": r["endpoint_value"], "confidence": 1.0} for r in rows[:50]]
    lines = [f"Endpoints called by {cls}: {len(rows)}"]
    return {"answer_lines": lines, "evidence": evidence, "items": items, "count": len(items), "class_name": cls}


def _handle_apex_smell_query(conn: sqlite3.Connection, q_norm: str) -> dict[str, Any]:
    if "dynamic soql" in q_norm:
        rows = conn.execute(
            """
            SELECT class_name, path, soql_count, dml_count, has_dynamic_soql, has_callout
            FROM apex_class_stats
            WHERE has_dynamic_soql=1
            ORDER BY soql_count DESC, class_name
            LIMIT 200
            """
        ).fetchall()
        items = [dict(r) for r in rows]
        evidence = [{"path": r["path"], "line_no": None, "snippet": r["class_name"], "confidence": 1.0} for r in rows[:50]]
        return {"answer_lines": [f"Classes with dynamic SOQL: {len(rows)}"], "evidence": evidence, "items": items, "count": len(items)}

    if "dml in loop" in q_norm or "dml in loops" in q_norm:
        rows = conn.execute("SELECT class_name, path FROM apex_class_stats ORDER BY class_name LIMIT 5000").fetchall()
        flagged: list[dict[str, Any]] = []
        for r in rows:
            text = _read_repo_rel_path(r["path"])
            if not text:
                continue
            if DML_IN_LOOP_RE.search(text):
                flagged.append({"class_name": r["class_name"], "path": r["path"], "evidence_snippet": "for (...) { ... update|insert ... }"})
        evidence = [{"path": r["path"], "line_no": None, "snippet": r["class_name"], "confidence": 0.9} for r in flagged[:50]]
        return {
            "answer_lines": [f"Classes with DML in loops: {len(flagged)}"],
            "evidence": evidence,
            "items": flagged[:200],
            "count": len(flagged),
        }

    # Callout-focused class list.
    rows = conn.execute(
        """
        SELECT DISTINCT class_name, path
        FROM apex_endpoints
        ORDER BY class_name
        LIMIT 200
        """
    ).fetchall()
    items = [dict(r) for r in rows]
    evidence = [{"path": r["path"], "line_no": None, "snippet": r["class_name"], "confidence": 1.0} for r in rows[:50]]
    return {"answer_lines": [f"Classes with callouts: {len(rows)}"], "evidence": evidence, "items": items, "count": len(items)}


def _handle_trigger_query(conn: sqlite3.Connection, d: EntityDictionary, question: str, intent: str) -> dict[str, Any]:
    candidate = _extract_component_name(question, "Trigger") or _extract_tail(question, ["trigger "])
    trig = _resolve_trigger_name(conn, candidate)
    if not trig:
        return {"answer_lines": [], "evidence": [], "items": [], "count": 0, "error": "Trigger not found in repo"}

    trow = conn.execute(
        "SELECT path FROM components WHERE type='TRIGGER' AND lower(name)=lower(?) LIMIT 1",
        (trig,),
    ).fetchone()
    path = trow["path"] if trow else None

    called = conn.execute(
        """
        SELECT DISTINCT d.name AS class_name, COALESCE(d.path, e.evidence_path) AS path, e.evidence_line_start, e.evidence_snippet, e.confidence
        FROM graph_edges e
        JOIN graph_nodes s ON s.node_id=e.src_node_id
        JOIN graph_nodes d ON d.node_id=e.dst_node_id
        WHERE s.node_type='TRIGGER' AND lower(s.name)=lower(?) AND e.edge_type='TRIGGER_CALLS_CLASS'
        ORDER BY e.confidence DESC, class_name
        LIMIT 200
        """,
        (trig,),
    ).fetchall()

    if intent == "trigger_impact":
        dossier = build_evidence(conn, target=f"Trigger:{trig}", depth=2, top_n=20)
        lines, evidence, items = _answer_from_evidence(
            intent="impact_or_deps",
            q_norm=normalize(question),
            metadata_type="Trigger",
            object_name=None,
            target=f"Trigger:{trig}",
            dossier=dossier,
        )
        return {"answer_lines": lines, "evidence": evidence, "items": items, "count": len(items), "dossier": dossier, "trigger_name": trig}

    lines = [f"Trigger: {trig}"]
    if path:
        lines.append(f"Path: {path}")
    lines.append(f"Classes called: {len(called)}")
    evidence = [{"path": path, "line_no": None, "snippet": trig, "confidence": 1.0}] if path else []
    for r in called[:50]:
        evidence.append({"path": r["path"], "line_no": r["evidence_line_start"], "snippet": r["class_name"], "confidence": r["confidence"]})
    return {"answer_lines": lines, "evidence": evidence[:50], "items": [dict(r) for r in called], "count": len(called), "trigger_name": trig}


def _handle_collisions_query(conn: sqlite3.Connection, e: ResolvedEntities) -> dict[str, Any]:
    if not e.full_field_name:
        return {"answer_lines": [], "evidence": [], "items": [], "count": 0, "error": "field not found in repo"}
    report = detect_collisions(conn, field_name=e.full_field_name)
    collisions = report.get("collisions") or []
    if not collisions:
        return {"answer_lines": [f"Collisions on {e.full_field_name}: 0"], "evidence": [], "items": [], "count": 0}
    c = collisions[0]
    writers = c.get("writers") or []
    type_set = sorted({w.get("type") for w in writers if w.get("type")})
    lines = [
        f"Collisions on {e.full_field_name}: {len(collisions)}",
        f"Writers on field: {len(writers)}",
        f"Writer types: {', '.join(type_set) if type_set else 'unknown'}",
        f"Risk: {c.get('risk')}",
    ]
    evidence = [
        {
            "path": w.get("path"),
            "line_no": None,
            "snippet": f"{w.get('type')} {w.get('name')}",
            "confidence": w.get("confidence"),
        }
        for w in writers[:50]
    ]
    return {"answer_lines": lines, "evidence": evidence, "items": collisions[:20], "count": len(collisions)}


def _handle_approval_process_impact(
    conn: sqlite3.Connection,
    *,
    question: str,
    entities: ResolvedEntities,
) -> dict[str, Any]:
    row, _ = _resolve_approval_process(
        conn,
        object_name=entities.object_name,
        process_name=entities.approval_process_name or entities.approval_process_full_name,
        raw_question=question,
    )
    if not row:
        return {"answer_lines": [], "evidence": [], "items": [], "count": 0, "error": "Approval process not found in repo"}

    obj = row.get("object_name") or ""
    refs = conn.execute(
        """
        SELECT ref_kind, ref_value, src_path, line_no, snippet, confidence
        FROM meta_refs
        WHERE src_path=?
        ORDER BY confidence DESC, COALESCE(line_no,0)
        LIMIT 200
        """,
        (row["path"],),
    ).fetchall()
    dossier = build_evidence(conn, target=obj, depth=1, top_n=20) if obj else {"target": {"found": False}}
    writers = dossier.get("writers") or []
    readers = dossier.get("readers") or []
    lines = [
        f"Approval process impact: {row['name']}",
        f"Direct dependents of approval process file references: {len(refs)}",
    ]
    if obj:
        lines.append(f"Indirect dependents via object association ({obj}): {len(writers) + len(readers)}")
    if not refs and obj:
        lines.append("Only object association found; no other references detected in repo.")
    evidence = [{"path": row["path"], "line_no": None, "snippet": row["name"], "confidence": 1.0}]
    evidence.extend(
        [{"path": r["src_path"], "line_no": r["line_no"], "snippet": r["snippet"] or r["ref_value"], "confidence": r["confidence"]} for r in refs[:20]]
    )
    evidence.extend(_evidence_to_rows(dossier, limit=20))
    return {
        "answer_lines": lines,
        "evidence": evidence[:50],
        "items": [{"approval_process": row, "direct_refs": [dict(r) for r in refs[:50]], "dossier": dossier}],
        "count": len(refs),
        "object_name": obj,
    }


def _handle_validation_rule_query(conn: sqlite3.Connection, question: str, q_norm: str, e: ResolvedEntities, intent: str) -> dict[str, Any]:
    obj = e.object_name
    if not obj:
        hint = _extract_object_hint(q_norm)
        if hint:
            obj_res = resolve_object_phrase(hint, build_entity_dictionary(conn).object_alias_map, score_cutoff=85)
            if obj_res:
                obj = obj_res[0]

    if intent == "validation_rule_explain":
        candidate = _extract_component_name(question, "ValidationRule") or _extract_tail(question, ["validation rule "])
        rule = _resolve_validation_rule_name(conn, candidate)
        if not rule:
            return {"answer_lines": [], "evidence": [], "items": [], "count": 0, "error": "Validation rule not found in repo"}
        row = conn.execute(
            """
            SELECT object_name, rule_name, active, error_condition, error_message, path
            FROM validation_rules
            WHERE lower(rule_name)=lower(?)
            LIMIT 1
            """,
            (rule,),
        ).fetchone()
        if not row:
            return {"answer_lines": ["Validation rule not found in repo index"], "evidence": [], "items": [], "count": 0}
        refs = conn.execute(
            """
            SELECT src_path, line_start, snippet, confidence
            FROM "references"
            WHERE src_type='VR' AND lower(src_name)=lower(?)
            ORDER BY confidence DESC
            LIMIT 20
            """,
            (rule,),
        ).fetchall()
        lines = [
            f"Validation Rule: {row['rule_name']}",
            f"Object: {row['object_name']}",
            f"Active: {'true' if int(row['active'] or 0) == 1 else 'false'}",
            f"Error condition: {row['error_condition'] or 'Not specified in repo evidence.'}",
            f"Error message: {row['error_message'] or 'Not specified in repo evidence.'}",
        ]
        evidence = [{"path": row["path"], "line_no": None, "snippet": row["rule_name"], "confidence": 1.0}]
        evidence.extend(
            [{"path": r["src_path"], "line_no": r["line_start"], "snippet": r["snippet"], "confidence": r["confidence"]} for r in refs]
        )
        return {"answer_lines": lines, "evidence": evidence[:50], "items": [dict(row)], "count": 1, "object_name": row["object_name"]}

    if not obj:
        return {"answer_lines": [], "evidence": [], "items": [], "count": 0, "error": "object not found in repo"}

    if intent == "validation_rule_filter":
        contains = "status" if "status" in q_norm else "stage" if "stage" in q_norm else "type" if "type" in q_norm else None
        if not contains:
            contains = "status"
        rows = conn.execute(
            """
            SELECT object_name, rule_name, active, error_condition, error_message, path
            FROM validation_rules
            WHERE lower(object_name)=lower(?)
              AND (
                lower(COALESCE(error_condition,'')) LIKE lower(?)
                OR lower(COALESCE(error_message,'')) LIKE lower(?)
              )
            ORDER BY rule_name
            LIMIT 200
            """,
            (obj, f"%{contains}%", f"%{contains}%"),
        ).fetchall()
        lines = [f"Validation rules on {obj} matching '{contains}': {len(rows)}"]
    else:
        rows = conn.execute(
            """
            SELECT object_name, rule_name, active, error_condition, error_message, path
            FROM validation_rules
            WHERE lower(object_name)=lower(?)
            ORDER BY rule_name
            LIMIT 200
            """,
            (obj,),
        ).fetchall()
        lines = [f"Validation rules on {obj}: {len(rows)}"]
    evidence = [{"path": r["path"], "line_no": None, "snippet": r["rule_name"], "confidence": 1.0} for r in rows[:50]]
    return {"answer_lines": lines, "evidence": evidence, "items": [dict(r) for r in rows], "count": len(rows), "object_name": obj}


def _handle_security_query(conn: sqlite3.Connection, question: str, q_norm: str, e: ResolvedEntities, intent: str) -> dict[str, Any]:
    if "view all data" in q_norm or "modify all data" in q_norm:
        rows = conn.execute(
            """
            SELECT path, api_name, folder
            FROM meta_files
            WHERE lower(folder) IN ('permissionsets','profiles')
            ORDER BY folder, api_name
            LIMIT 5000
            """
        ).fetchall()
        items: list[dict[str, Any]] = []
        for r in rows:
            text = _read_repo_rel_path(r["path"]).lower()
            if not text:
                continue
            has_view = "<viewalldata>true</viewalldata>" in text
            has_modify = "<modifyalldata>true</modifyalldata>" in text
            if not has_view and not has_modify:
                continue
            items.append(
                {
                    "path": r["path"],
                    "api_name": r["api_name"],
                    "folder": r["folder"],
                    "view_all_data": has_view,
                    "modify_all_data": has_modify,
                }
            )
        evidence = [
            {
                "path": r["path"],
                "line_no": None,
                "snippet": f"{r['api_name']} viewAllData={r['view_all_data']} modifyAllData={r['modify_all_data']}",
                "confidence": 1.0,
            }
            for r in items[:50]
        ]
        lines = [f"Profiles/permsets with View All Data or Modify All Data: {len(items)}"]
        if not items:
            lines.append("0 found in repo (verified by scanning profiles+permsets).")
        return {"answer_lines": lines, "evidence": evidence, "items": items, "count": len(items)}

    if intent in {"security_modify_all_on_object", "security_profiles_modify_all_on_object"}:
        obj = e.object_name
        if not obj:
            return {"answer_lines": [], "evidence": [], "items": [], "count": 0, "error": "object not found in repo"}
        rows = conn.execute(
            """
            SELECT src_name, src_path, snippet, confidence
            FROM "references"
            WHERE src_type='PERMISSION'
              AND ref_type='OBJECT'
              AND lower(ref_key)=lower(?)
              AND lower(snippet) LIKE '%modifyall=true%'
            ORDER BY confidence DESC, src_name
            LIMIT 400
            """,
            (obj,),
        ).fetchall()
        items = [dict(r) for r in rows]
        if intent == "security_modify_all_on_object":
            items = [r for r in items if "/permissionsets/" in (r.get("src_path") or "").lower()]
            heading = f"Permission sets granting Modify All on {obj}: {len(items)}"
        elif intent == "security_profiles_modify_all_on_object":
            items = [r for r in items if "/profiles/" in (r.get("src_path") or "").lower()]
            heading = f"Profiles granting Modify All on {obj}: {len(items)}"
        else:
            heading = f"Permission sets/profiles granting Modify All on {obj}: {len(items)}"
        evidence = [{"path": r["src_path"], "line_no": None, "snippet": r["src_name"], "confidence": r["confidence"]} for r in items[:50]]
        return {"answer_lines": [heading], "evidence": evidence, "items": items, "count": len(items)}

    if intent == "restricted_fields":
        obj = e.object_name
        if not obj:
            return {"answer_lines": [], "evidence": [], "items": [], "count": 0, "error": "object not found in repo"}
        rows = conn.execute(
            """
            SELECT ref_key, src_name, src_path, snippet, confidence
            FROM "references"
            WHERE src_type='PERMISSION'
              AND ref_type='FIELD'
              AND lower(ref_key) LIKE lower(?)
            ORDER BY ref_key
            LIMIT 10000
            """,
            (f"{obj}.%",),
        ).fetchall()
        by_field: dict[str, dict[str, Any]] = {}
        for r in rows:
            key = r["ref_key"]
            rec = by_field.setdefault(key, {"field": key, "denied_edit": 0, "denied_read": 0, "evidence": []})
            snip = (r["snippet"] or "").lower()
            if "editable=false" in snip:
                rec["denied_edit"] += 1
            if "readable=false" in snip:
                rec["denied_read"] += 1
            if len(rec["evidence"]) < 5:
                rec["evidence"].append({"path": r["src_path"], "snippet": r["snippet"], "src_name": r["src_name"]})
        ranked = []
        for rec in by_field.values():
            score = rec["denied_edit"] * 2 + rec["denied_read"]
            if score <= 0:
                continue
            rec["restriction_score"] = score
            rec["confidence_tier"] = "HIGH"
            ranked.append(rec)
        ranked.sort(key=lambda x: (x["restriction_score"], x["denied_edit"], x["denied_read"]), reverse=True)
        top = ranked[:20]
        evidence = []
        for r in top:
            for ev in r["evidence"][:2]:
                evidence.append({"path": ev["path"], "line_no": None, "snippet": f"{r['field']} {ev['snippet']}", "confidence": 1.0})
        return {
            "answer_lines": [f"Most restricted fields on {obj}: {len(top)}"],
            "evidence": evidence[:50],
            "items": top,
            "count": len(top),
            "object_name": obj,
        }

    # Explain permission set.
    name = _extract_component_name(question, "PermissionSet")
    if not name:
        return {"answer_lines": [], "evidence": [], "items": [], "count": 0, "error": "Permission set not found in repo"}
    row = conn.execute(
        """
        SELECT path, api_name
        FROM meta_files
        WHERE lower(folder)='permissionsets'
          AND lower(api_name)=lower(?)
        LIMIT 1
        """,
        (name,),
    ).fetchone()
    if not row:
        names = [r["api_name"] for r in conn.execute("SELECT api_name FROM meta_files WHERE lower(folder)='permissionsets'").fetchall()]
        m = process.extractOne(name, names, scorer=fuzz.WRatio, score_cutoff=80) if names else None
        if m:
            row = conn.execute(
                "SELECT path, api_name FROM meta_files WHERE lower(folder)='permissionsets' AND lower(api_name)=lower(?) LIMIT 1",
                (m[0],),
            ).fetchone()
    if not row:
        return {"answer_lines": ["Permission set not found in repo index"], "evidence": [], "items": [], "count": 0}
    refs = conn.execute(
        """
        SELECT ref_type, ref_key, src_path, snippet, confidence
        FROM "references"
        WHERE src_type='PERMISSION' AND lower(src_name)=lower(?)
        ORDER BY confidence DESC
        LIMIT 200
        """,
        (row["api_name"],),
    ).fetchall()
    lines = [f"Permission Set: {row['api_name']}", f"Path: {row['path']}", f"Indexed permission references: {len(refs)}"]
    evidence = [{"path": row["path"], "line_no": None, "snippet": row["api_name"], "confidence": 1.0}]
    evidence.extend([{"path": r["src_path"], "line_no": None, "snippet": f"{r['ref_type']} {r['ref_key']} {r['snippet']}", "confidence": r["confidence"]} for r in refs[:20]])
    return {"answer_lines": lines, "evidence": evidence[:50], "items": [dict(r) for r in refs], "count": len(refs)}


def _handle_ui_query(conn: sqlite3.Connection, e: ResolvedEntities) -> dict[str, Any]:
    token = e.full_field_name or e.object_name
    if not token:
        return {"answer_lines": [], "evidence": [], "items": [], "count": 0, "error": "Could not resolve UI target"}
    ui_rows = conn.execute(
        """
        SELECT ref_kind, ref_value, src_path, line_no, snippet, confidence
        FROM meta_refs
        WHERE lower(src_folder) IN ('layouts','flexipages')
          AND (
            lower(ref_value)=lower(?)
            OR lower(ref_value) LIKE lower(?)
            OR lower(snippet) LIKE lower(?)
          )
        ORDER BY confidence DESC, src_path
        LIMIT 300
        """,
        (token, f"%{token}%", f"%{token}%"),
    ).fetchall()
    fls_rows: list[sqlite3.Row] = []
    if e.full_field_name:
        fls_rows = conn.execute(
            """
            SELECT src_name, src_path, snippet, confidence
            FROM "references"
            WHERE src_type='PERMISSION'
              AND ref_type='FIELD'
              AND (lower(ref_key)=lower(?) OR lower(ref_key)=lower(?))
            ORDER BY confidence DESC, src_name
            LIMIT 300
            """,
            (e.full_field_name, f"%.{e.field_name or ''}"),
        ).fetchall()

    items = {
        "fls_surface": [dict(r) for r in fls_rows],
        "ui_surface": [dict(r) for r in ui_rows],
    }
    evidence = [
        {"path": r["src_path"], "line_no": None, "snippet": f"FLS {r['src_name']} {r['snippet']}", "confidence": r["confidence"]}
        for r in fls_rows[:25]
    ]
    evidence.extend(
        [{"path": r["src_path"], "line_no": r["line_no"], "snippet": r["snippet"] or r["ref_value"], "confidence": r["confidence"]} for r in ui_rows[:25]]
    )

    lines = [
        f"FLS: entries for {token}: {len(fls_rows)}",
        f"UI: references for {token}: {len(ui_rows)}",
    ]
    if e.full_field_name and not ui_rows and e.object_name:
        layout_rows = conn.execute(
            """
            SELECT path, api_name
            FROM meta_files
            WHERE lower(folder)='layouts'
              AND lower(path) LIKE lower(?)
            ORDER BY api_name
            LIMIT 50
            """,
            (f"%/{e.object_name}-%",),
        ).fetchall()
        if layout_rows:
            lines.append("Field not detected directly in UI index; showing object layouts as fallback.")
            for r in layout_rows[:10]:
                evidence.append({"path": r["path"], "line_no": None, "snippet": r["api_name"], "confidence": 0.5})
    return {"answer_lines": lines, "evidence": evidence[:50], "items": items, "count": len(evidence)}


def _handle_lwc_query(conn: sqlite3.Connection, d: EntityDictionary, question: str, q_norm: str, e: ResolvedEntities, intent: str) -> dict[str, Any]:
    if intent == "lwc_calling_apex_bundles":
        rows = conn.execute(
            """
            SELECT path
            FROM meta_files
            WHERE lower(folder)='lwc' AND path LIKE '%/lwc/%/%'
            ORDER BY path
            LIMIT 5000
            """
        ).fetchall()
        bundles: dict[str, dict[str, Any]] = {}
        for r in rows:
            rel = r["path"]
            text = _read_repo_rel_path(rel)
            if not text:
                continue
            matches = [f"{m.group(1)}.{m.group(2)}" for m in LWC_APEX_IMPORT_RE.finditer(text)]
            if not matches:
                continue
            bundle = rel.split("/lwc/", 1)[1].split("/", 1)[0]
            rec = bundles.setdefault(bundle, {"bundle": bundle, "path": rel, "apex_methods": set()})
            rec["apex_methods"].update(matches)
        items = [
            {"bundle": b, "path": v["path"], "apex_methods": sorted(v["apex_methods"])}
            for b, v in sorted(bundles.items())
        ]
        evidence = [{"path": i["path"], "line_no": None, "snippet": f"{i['bundle']} -> {', '.join(i['apex_methods'][:3])}", "confidence": 1.0} for i in items[:50]]
        return {"answer_lines": [f"LWC components calling Apex methods: {len(items)}"], "evidence": evidence, "items": items, "count": len(items)}

    if intent == "lwc_reference_fields":
        obj = e.object_name
        if not obj:
            return {"answer_lines": [], "evidence": [], "items": [], "count": 0, "error": "object not found in repo"}
        rows = conn.execute(
            """
            SELECT DISTINCT
              substr(mf.path, instr(mf.path,'/lwc/')+5, instr(substr(mf.path, instr(mf.path,'/lwc/')+5),'/')-1) AS bundle,
              mf.path, mr.line_no, mr.snippet, mr.ref_value, mr.confidence
            FROM meta_refs mr
            JOIN meta_files mf ON mf.path = mr.src_path
            WHERE lower(mf.folder)='lwc'
              AND (
                (mr.ref_kind='FIELD' AND lower(mr.ref_value) LIKE lower(?))
                OR lower(mr.snippet) LIKE lower(?)
              )
            ORDER BY bundle
            LIMIT 400
            """,
            (f"{obj}.%", f"%@salesforce/schema/{obj}.%"),
        ).fetchall()
        items = [dict(r) for r in rows]
        evidence = [{"path": r["path"], "line_no": r["line_no"], "snippet": r["snippet"] or r["bundle"], "confidence": r["confidence"]} for r in rows[:50]]
        bundles = sorted({r["bundle"] for r in rows if r["bundle"]})
        return {"answer_lines": [f"LWC components referencing {obj} fields: {len(bundles)}"], "evidence": evidence, "items": items, "count": len(bundles)}

    bundle_name = _resolve_lwc_bundle(conn, _extract_component_name(question, "LWC") or _extract_tail(question, ["lwc "]))
    if not bundle_name:
        return {"answer_lines": [], "evidence": [], "items": [], "count": 0, "error": "LWC bundle not found in repo"}
    file_rows = conn.execute(
        """
        SELECT path
        FROM meta_files
        WHERE lower(folder)='lwc'
          AND lower(path) LIKE lower(?)
        ORDER BY path
        LIMIT 300
        """,
        (f"%/lwc/{bundle_name}/%",),
    ).fetchall()
    files = [r["path"] for r in file_rows]
    apex_methods: list[dict[str, Any]] = []
    field_refs: list[dict[str, Any]] = []
    for rel in files:
        text = _read_repo_rel_path(rel)
        if not text:
            continue
        for m in LWC_APEX_IMPORT_RE.finditer(text):
            apex_methods.append({"class_name": m.group(1), "method_name": m.group(2), "path": rel})
        for m in LWC_SCHEMA_REF_RE.finditer(text):
            field_refs.append({"object": m.group(1), "field": m.group(2), "path": rel})

    if intent == "lwc_apex_methods":
        lines = [f"Apex methods called by LWC {bundle_name}: {len(apex_methods)}"]
        evidence = [{"path": m["path"], "line_no": None, "snippet": f"{m['class_name']}.{m['method_name']}", "confidence": 1.0} for m in apex_methods[:50]]
        return {"answer_lines": lines, "evidence": evidence, "items": apex_methods, "count": len(apex_methods), "bundle": bundle_name}

    # lwc_explain
    lines = [
        f"LWC: {bundle_name}",
        f"Files in bundle: {len(files)}",
        f"Apex methods imported: {len(apex_methods)}",
        f"Schema field references: {len(field_refs)}",
    ]
    evidence = [{"path": rel, "line_no": None, "snippet": bundle_name, "confidence": 1.0} for rel in files[:20]]
    return {"answer_lines": lines, "evidence": evidence, "items": [{"files": files, "apex_methods": apex_methods, "field_refs": field_refs}], "count": len(files), "bundle": bundle_name}


def _handle_flows_touch_not_triggered(conn: sqlite3.Connection, object_name: str) -> dict[str, Any]:
    touching = conn.execute(
        """
        SELECT DISTINCT flow_name, path
        FROM (
          SELECT flow_name, path FROM flow_field_reads WHERE lower(full_field_name) LIKE lower(?)
          UNION
          SELECT flow_name, path FROM flow_field_writes WHERE lower(full_field_name) LIKE lower(?)
          UNION
          SELECT flow_name, evidence_path AS path FROM flow_true_writes
           WHERE write_kind='field_write' AND lower(field_full_name) LIKE lower(?)
        )
        """,
        (f"{object_name}.%", f"{object_name}.%", f"{object_name}.%"),
    ).fetchall()
    triggered = {
        r["flow_name"]
        for r in conn.execute(
            "SELECT flow_name FROM flows WHERE lower(trigger_object)=lower(?)",
            (object_name,),
        ).fetchall()
    }
    rows = [dict(r) for r in touching if r["flow_name"] not in triggered]
    rows.sort(key=lambda x: x["flow_name"])
    evidence = [{"path": r["path"], "line_no": None, "snippet": r["flow_name"], "confidence": 0.8} for r in rows[:50]]
    lines = [f"Flows touching {object_name} but not triggered on {object_name}: {len(rows)}"]
    return {"answer_lines": lines, "evidence": evidence, "items": rows, "count": len(rows)}


def _load_techdebt_json() -> dict[str, Any] | None:
    path = Path.cwd() / "data" / "tech_debt.json"
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def _handle_advisor_query(conn: sqlite3.Connection, q_norm: str, e: ResolvedEntities) -> dict[str, Any]:
    if "tech debt summary" in q_norm:
        td = _load_techdebt_json()
        if not td:
            return {"answer_lines": ["tech_debt.json not found. Run: python3 -m sf_repo_ai.cli techdebt --out data/tech_debt.json"], "evidence": [], "items": [], "count": 0}
        apex_total = (td.get("apex") or {}).get("total_classes_scanned", 0)
        flow_total = (td.get("flows") or {}).get("total_flows_scanned", 0)
        sec_risky = len((td.get("security") or {}).get("high_risk_system_permissions", []))
        apex_top = (td.get("apex") or {}).get("top_20_by_smell", [])[:5]
        flow_top = (td.get("flows") or {}).get("top_20_by_element_count", [])[:5]
        sec_top = (td.get("security") or {}).get("findings", [])[:5]
        sec_risky_perms = (td.get("security") or {}).get("high_risk_system_permissions", [])[:10]
        lines = [
            "Tech debt summary for org",
            f"- Apex classes scanned: {apex_total}",
            f"- Flows scanned: {flow_total}",
            f"- High-risk security findings: {sec_risky}",
        ]
        if apex_top:
            lines.append("- Top Apex smells:")
            for r in apex_top:
                lines.append(f"  - {r.get('class_name')} score={r.get('smell_score')}")
        if flow_top:
            lines.append("- Top complex flows:")
            for r in flow_top:
                lines.append(f"  - {r.get('flow_name')} elements={r.get('element_count')}")
        if sec_top:
            lines.append("- Top security findings:")
            for r in sec_top:
                lines.append(f"  - {r.get('subject')} [{r.get('permission')}]")
        elif sec_risky_perms:
            lines.append("- High-risk system permissions:")
            for p in sec_risky_perms:
                lines.append(f"  - {p}")
        evidence = []
        for r in apex_top:
            if r.get("path"):
                evidence.append({"path": r.get("path"), "line_no": None, "snippet": r.get("class_name"), "confidence": 1.0})
        for r in flow_top:
            if r.get("path"):
                evidence.append({"path": r.get("path"), "line_no": None, "snippet": r.get("flow_name"), "confidence": 1.0})
        for r in sec_top:
            if r.get("path"):
                evidence.append({"path": r.get("path"), "line_no": None, "snippet": r.get("subject"), "confidence": 1.0})
        return {"answer_lines": lines, "evidence": evidence[:50], "items": [td], "count": 1}

    if "optimize " in q_norm and e.object_name:
        dossier = build_evidence(conn, target=e.object_name, depth=2, top_n=20)
        lines, evidence, items = _answer_from_evidence(
            intent="impact_or_deps",
            q_norm=q_norm,
            metadata_type=None,
            object_name=e.object_name,
            target=e.object_name,
            dossier=dossier,
        )
        lines.insert(0, f"Optimization evidence for {e.object_name}")
        return {"answer_lines": lines, "evidence": evidence, "items": items, "count": len(items), "dossier": dossier}

    if "top 20 most complex apex classes" in q_norm:
        rows = conn.execute(
            """
            SELECT class_name, path, loc, soql_count, dml_count, has_dynamic_soql, has_callout
            FROM apex_class_stats
            ORDER BY loc DESC, (soql_count + dml_count) DESC
            LIMIT 20
            """
        ).fetchall()
        items = [dict(r) for r in rows]
        evidence = [{"path": r["path"], "line_no": None, "snippet": r["class_name"], "confidence": 1.0} for r in rows]
        return {"answer_lines": [f"Top complex Apex classes: {len(rows)}"], "evidence": evidence, "items": items, "count": len(items)}

    if "top 10 fields with the most writers" in q_norm or "top fields with the most writers" in q_norm:
        rows = conn.execute(
            """
            WITH writers AS (
              SELECT field_full_name, 'FLOW:' || flow_name AS writer
              FROM flow_true_writes
              WHERE write_kind='field_write' AND field_full_name IS NOT NULL
              UNION ALL
              SELECT field_full_name, 'APEX:' || class_name AS writer
              FROM apex_rw
              WHERE rw='write' AND field_full_name IS NOT NULL
            )
            SELECT field_full_name,
                   COUNT(DISTINCT writer) AS writer_count,
                   COUNT(DISTINCT CASE WHEN writer LIKE 'FLOW:%' THEN writer END) AS flow_writers,
                   COUNT(DISTINCT CASE WHEN writer LIKE 'APEX:%' THEN writer END) AS apex_writers
            FROM writers
            GROUP BY field_full_name
            ORDER BY writer_count DESC, field_full_name
            LIMIT 10
            """
        ).fetchall()
        items = [dict(r) for r in rows]
        evidence = [{"path": "", "line_no": None, "snippet": f"{r['field_full_name']} writers={r['writer_count']}", "confidence": 1.0} for r in rows]
        return {"answer_lines": [f"Top fields by writer count: {len(rows)}"], "evidence": evidence, "items": items, "count": len(items)}

    if "top 20 most risky automations" in q_norm:
        rows = conn.execute(
            """
            SELECT f.flow_name, f.path,
                   COALESCE(w.c,0) AS writes,
                   COALESCE(r.c,0) AS reads
            FROM flows f
            LEFT JOIN (SELECT flow_name, COUNT(*) AS c FROM flow_true_writes GROUP BY flow_name) w ON w.flow_name=f.flow_name
            LEFT JOIN (SELECT flow_name, COUNT(*) AS c FROM flow_field_reads GROUP BY flow_name) r ON r.flow_name=f.flow_name
            ORDER BY (COALESCE(w.c,0)*2 + COALESCE(r.c,0)) DESC, f.flow_name
            LIMIT 20
            """
        ).fetchall()
        items = [dict(r) for r in rows]
        evidence = [{"path": r["path"], "line_no": None, "snippet": r["flow_name"], "confidence": 0.8} for r in rows]
        return {"answer_lines": [f"Top risky automations: {len(rows)}"], "evidence": evidence, "items": items, "count": len(items)}

    if "over-automated" in q_norm or "over automated" in q_norm:
        rows = conn.execute(
            """
            SELECT o.object_name,
                   COALESCE(fr.c,0)+COALESCE(fw.c,0)+COALESCE(vr.c,0) AS score
            FROM objects o
            LEFT JOIN (SELECT substr(full_field_name,1,instr(full_field_name,'.')-1) AS object_name, COUNT(DISTINCT flow_name) AS c FROM flow_field_reads GROUP BY 1) fr
                ON fr.object_name=o.object_name
            LEFT JOIN (SELECT substr(field_full_name,1,instr(field_full_name,'.')-1) AS object_name, COUNT(DISTINCT flow_name) AS c FROM flow_true_writes WHERE field_full_name IS NOT NULL GROUP BY 1) fw
                ON fw.object_name=o.object_name
            LEFT JOIN (SELECT object_name, COUNT(*) AS c FROM validation_rules GROUP BY object_name) vr
                ON vr.object_name=o.object_name
            ORDER BY score DESC, o.object_name
            LIMIT 20
            """
        ).fetchall()
        items = [dict(r) for r in rows]
        return {
            "answer_lines": [f"Over-automated objects (top 20): {len(rows)}"],
            "evidence": [
                {"path": "", "line_no": None, "snippet": f"{r['object_name']} score={r['score']}", "confidence": 0.7}
                for r in rows[:20]
            ],
            "items": items,
            "count": len(items),
        }

    if "permission sprawl" in q_norm and e.object_name:
        obj = e.object_name
        obj_rows = conn.execute(
            """
            SELECT src_name, src_path, snippet
            FROM "references"
            WHERE src_type='PERMISSION' AND ref_type='OBJECT' AND lower(ref_key)=lower(?)
            """,
            (obj,),
        ).fetchall()
        grants = {"read": 0, "edit": 0, "delete": 0, "modifyall": 0, "viewall": 0}
        by_src: dict[str, dict[str, Any]] = {}
        for r in obj_rows:
            snip = (r["snippet"] or "").lower()
            src = r["src_name"]
            rec = by_src.setdefault(src, {"src_name": src, "src_path": r["src_path"], "snippet": r["snippet"]})
            if "allowread=true" in snip:
                grants["read"] += 1
            if "allowedit=true" in snip:
                grants["edit"] += 1
            if "allowdelete=true" in snip:
                grants["delete"] += 1
            if "modifyall=true" in snip:
                grants["modifyall"] += 1
            if "viewall=true" in snip:
                grants["viewall"] += 1
        lines = [
            f"Permission sprawl on {obj}",
            f"- Grants with read: {grants['read']}",
            f"- Grants with edit: {grants['edit']}",
            f"- Grants with delete: {grants['delete']}",
            f"- Grants with modifyAll: {grants['modifyall']}",
            f"- Grants with viewAll: {grants['viewall']}",
        ]
        evidence = [{"path": v["src_path"], "line_no": None, "snippet": v["src_name"], "confidence": 1.0} for v in list(by_src.values())[:50]]
        return {"answer_lines": lines, "evidence": evidence, "items": list(by_src.values())[:200], "count": len(by_src)}

    if ("who can see" in q_norm or "visibility is granted" in q_norm or ("summarize" in q_norm and "visibility" in q_norm)) and e.object_name:
        obj = e.object_name
        sharing_rows = conn.execute(
            """
            SELECT name, object_name, rule_type, access_level, path
            FROM sharing_rules
            WHERE lower(object_name)=lower(?)
            ORDER BY name
            LIMIT 200
            """,
            (obj,),
        ).fetchall()
        perm_rows = conn.execute(
            """
            SELECT src_name, src_path, snippet
            FROM "references"
            WHERE src_type='PERMISSION' AND ref_type='OBJECT' AND lower(ref_key)=lower(?) AND lower(snippet) LIKE '%allowread=true%'
            ORDER BY src_name
            LIMIT 500
            """,
            (obj,),
        ).fetchall()
        settings_rows = conn.execute(
            """
            SELECT path, api_name
            FROM meta_files
            WHERE lower(folder)='settings' AND lower(path) LIKE '%sharing.settings-meta.xml'
            LIMIT 20
            """
        ).fetchall()
        lines = [
            f"Who can see {obj} (high-level, repo-based)",
            f"- Baseline access (sharing settings files found): {len(settings_rows)}",
            f"- Grants via profiles/permsets (allowRead=true): {len(perm_rows)}",
            f"- Additional sharing rules: {len(sharing_rows)}",
            "- Notes: role hierarchy/runtime grants are not fully inferable from repo only.",
        ]
        evidence = [{"path": r["src_path"], "line_no": None, "snippet": r["src_name"], "confidence": 1.0} for r in perm_rows[:25]]
        evidence.extend([{"path": r["path"], "line_no": None, "snippet": r["name"], "confidence": 1.0} for r in sharing_rows[:25]])
        evidence.extend([{"path": r["path"], "line_no": None, "snippet": r["api_name"], "confidence": 0.7} for r in settings_rows[:5]])
        return {"answer_lines": lines, "evidence": evidence[:50], "items": {"sharing_rules": [dict(r) for r in sharing_rows], "permission_grants": [dict(r) for r in perm_rows]}, "count": len(evidence)}

    # duplication flows by write signature
    rows = conn.execute(
        """
        SELECT flow_name, COALESCE(sobject_type, substr(field_full_name,1,instr(field_full_name,'.')-1)) AS obj, field_full_name
        FROM flow_true_writes
        WHERE write_kind='field_write'
          AND field_full_name IS NOT NULL
        ORDER BY flow_name, field_full_name
        """
    ).fetchall()
    sig_by_flow: dict[str, tuple[str, tuple[str, ...]]] = {}
    tmp: dict[str, dict[str, Any]] = {}
    for r in rows:
        flow = r["flow_name"]
        obj = r["obj"] or ""
        entry = tmp.setdefault(flow, {"obj": obj, "fields": []})
        if obj and not entry["obj"]:
            entry["obj"] = obj
        entry["fields"].append(r["field_full_name"])
    for flow, v in tmp.items():
        sig_by_flow[flow] = (v["obj"], tuple(sorted(set(v["fields"]))))
    clusters: dict[tuple[str, tuple[str, ...]], list[str]] = {}
    for flow, sig in sig_by_flow.items():
        clusters.setdefault(sig, []).append(flow)
    dup = [{"object": k[0], "fields": list(k[1]), "flows": sorted(v)} for k, v in clusters.items() if len(v) > 1]
    dup.sort(key=lambda x: len(x["flows"]), reverse=True)
    evidence = [
        {
            "path": "",
            "line_no": None,
            "snippet": f"{len(d['flows'])} flows write {len(d['fields'])} same fields",
            "confidence": 0.7,
        }
        for d in dup[:20]
    ]
    return {"answer_lines": [f"Duplicate flow-write signatures: {len(dup)}"], "evidence": evidence, "items": dup[:50], "count": len(dup)}


def _handle_story_planner(conn: sqlite3.Connection, question: str, e: ResolvedEntities) -> dict[str, Any]:
    targets: list[str] = []
    if e.full_field_name:
        targets.append(e.full_field_name)
    if e.object_name and e.object_name not in targets:
        targets.append(e.object_name)
    for m in DIRECT_FIELD_PATTERN.finditer(question):
        cand = f"{m.group(1)}.{m.group(2)}"
        row = conn.execute("SELECT full_name FROM fields WHERE lower(full_name)=lower(?) LIMIT 1", (cand,)).fetchone()
        if row and row["full_name"] not in targets:
            targets.append(row["full_name"])
    if not targets:
        return {"answer_lines": ["Could not resolve story targets from repo entities"], "evidence": [], "items": [], "count": 0}

    plans: list[dict[str, Any]] = []
    evidence: list[dict[str, Any]] = []
    for t in targets[:5]:
        dossier = build_evidence(conn, target=t, depth=2, top_n=10)
        target_meta = dossier.get("target", {})
        plans.append(
            {
                "target": t,
                "resolved_type": target_meta.get("type"),
                "writers": len(dossier.get("writers") or []),
                "readers": len(dossier.get("readers") or []),
                "automations": len(dossier.get("automations") or []),
                "paths": (dossier.get("evidence_paths") or [])[:10],
            }
        )
        for p in (dossier.get("evidence_paths") or [])[:5]:
            evidence.append({"path": p, "line_no": None, "snippet": f"candidate target {t}", "confidence": 0.8})

    lines = ["Story implementation candidates (deterministic evidence):"]
    for p in plans:
        lines.append(
            f"- {p['target']} [{p['resolved_type']}] writers={p['writers']} readers={p['readers']} automations={p['automations']}"
        )
    lines.append("Review top evidence paths and implement in existing automation/class touchpoints first.")
    return {"answer_lines": lines, "evidence": evidence[:50], "items": plans, "count": len(plans)}


def _handle_sharing_impact(conn: sqlite3.Connection, object_name: str) -> dict[str, Any]:
    sharing_rows = conn.execute(
        """
        SELECT name, object_name, rule_type, access_level, path
        FROM sharing_rules
        WHERE lower(object_name)=lower(?)
        ORDER BY name
        LIMIT 200
        """,
        (object_name,),
    ).fetchall()
    querying_classes = conn.execute(
        """
        SELECT DISTINCT s.name AS class_name, COALESCE(s.path, e.evidence_path) AS path, e.confidence
        FROM graph_edges e
        JOIN graph_nodes s ON s.node_id=e.src_node_id
        JOIN graph_nodes d ON d.node_id=e.dst_node_id
        WHERE e.edge_type='CLASS_QUERIES_OBJECT'
          AND d.node_type='OBJECT'
          AND lower(d.name)=lower(?)
        ORDER BY e.confidence DESC, class_name
        LIMIT 200
        """,
        (object_name,),
    ).fetchall()
    touching_flows = conn.execute(
        """
        SELECT DISTINCT flow_name, path
        FROM (
            SELECT flow_name, path FROM flow_field_reads WHERE lower(full_field_name) LIKE lower(?)
            UNION
            SELECT flow_name, evidence_path AS path FROM flow_true_writes WHERE write_kind='field_write' AND lower(field_full_name) LIKE lower(?)
        )
        ORDER BY flow_name
        LIMIT 200
        """,
        (f"{object_name}.%", f"{object_name}.%"),
    ).fetchall()
    lines = [
        f"Sharing impact for {object_name}",
        f"- Sharing rules referencing {object_name}: {len(sharing_rows)}",
        f"- Apex classes querying {object_name}: {len(querying_classes)}",
        f"- Flows touching {object_name} fields: {len(touching_flows)}",
    ]
    lines.append("Likely impacted areas to review are listed below (confidence: MEDIUM, repo-only heuristic).")
    evidence = [{"path": r["path"], "line_no": None, "snippet": r["name"], "confidence": 1.0} for r in sharing_rows[:20]]
    evidence.extend([{"path": r["path"], "line_no": None, "snippet": r["class_name"], "confidence": r["confidence"]} for r in querying_classes[:15]])
    evidence.extend([{"path": r["path"], "line_no": None, "snippet": r["flow_name"], "confidence": 0.8} for r in touching_flows[:15]])
    return {
        "answer_lines": lines,
        "evidence": evidence[:50],
        "items": {
            "sharing_rules": [dict(r) for r in sharing_rows],
            "querying_classes": [dict(r) for r in querying_classes],
            "touching_flows": [dict(r) for r in touching_flows],
        },
        "count": len(evidence),
        "object_name": object_name,
    }


def _detect_meta_inventory_request(
    conn: sqlite3.Connection,
    *,
    question: str,
    question_norm: str,
    entities: ResolvedEntities,
    family: str,
    intent: str,
) -> dict[str, Any] | None:
    resolved = resolve_catalog_type(conn, question_norm)
    if not resolved:
        return None
    if family != "generic" and intent not in {
        "count_type",
        "list_type",
        "count_type_on_object",
        "list_type_on_object",
        "explain_component",
        "unknown",
    }:
        return None
    # Preserve specialized routing whenever entity resolution already has a known metadata type.
    # Only let catalog routing override generic/unresolved cases.
    specialized_types = {
        "Flow",
        "ApprovalProcess",
        "SharingRule",
        "ApexClass",
        "Trigger",
        "ValidationRule",
        "PermissionSet",
        "Profile",
        "ConnectedApp",
        "Layout",
        "Flexipage",
        "LWC",
        "QuickAction",
        "AuthProvider",
    }
    if entities.metadata_type in specialized_types:
        return None
    if family in {"count_type", "list_type", "count_type_on_object", "list_type_on_object"} and entities.metadata_type:
        return None
    if family == "explain_component" and entities.metadata_type:
        return None
    entry = resolved["entry"]
    alias = str(resolved.get("alias") or "")
    meta_intent = str(resolved["intent"])
    object_name = entities.object_name
    if meta_intent == "meta_inventory_count":
        result = count_inventory(conn, entry=entry, object_name=object_name)
        return {
            "family": "meta_inventory",
            "intent": meta_intent,
            "handler": "meta_inventory_count",
            "result": result,
            "entry": entry,
            "alias": alias,
        }
    if meta_intent == "meta_inventory_list":
        result = list_inventory(conn, entry=entry, object_name=object_name, limit=50)
        return {
            "family": "meta_inventory",
            "intent": meta_intent,
            "handler": "meta_inventory_list",
            "result": result,
            "entry": entry,
            "alias": alias,
        }

    # Explain mode: resolve candidate file for this type.
    name_candidate = extract_name_candidate(
        question,
        alias=alias or entry.type_key,
        object_name=object_name,
    )
    if not name_candidate:
        # No specific name provided: if scoped by object and has only one file, explain it.
        listing = list_inventory(conn, entry=entry, object_name=object_name, limit=2)
        items = listing.get("items") or []
        if len(items) == 1:
            item = items[0]
            result = explain_metadata_file(
                type_key=entry.type_key,
                path=str(item.get("path")),
                name=str(item.get("name")),
                object_name=item.get("object_name"),
            )
            return {
                "family": "meta_inventory",
                "intent": meta_intent,
                "handler": "meta_inventory_explain",
                "result": result,
                "entry": entry,
                "alias": alias,
                "item": item,
            }
        return {
            "family": "meta_inventory",
            "intent": meta_intent,
            "handler": "meta_inventory_explain",
            "result": {
                "answer_lines": [
                    f"Provide a {entry.type_key} name to explain.",
                    "Not found in repo index",
                ],
                "evidence": [],
                "items": [],
                "count": 0,
                "error": f"{entry.type_key} name missing",
            },
            "entry": entry,
            "alias": alias,
        }

    item = find_inventory_by_name(conn, entry=entry, name=name_candidate, object_name=object_name)
    if not item:
        listing = list_inventory(conn, entry=entry, object_name=object_name, limit=5)
        sugg = [x.get("name") for x in (listing.get("items") or [])[:5] if x.get("name")]
        return {
            "family": "meta_inventory",
            "intent": meta_intent,
            "handler": "meta_inventory_explain",
            "result": {
                "answer_lines": [
                    f"{entry.type_key} not found: {name_candidate}",
                    ("Suggestions: " + ", ".join(sugg)) if sugg else "Not found in repo index",
                ],
                "evidence": [{"path": x.get("path"), "line_no": None, "snippet": x.get("name"), "confidence": 0.8} for x in (listing.get("items") or [])[:5]],
                "items": listing.get("items") or [],
                "count": 0,
                "error": f"{entry.type_key} not found",
            },
            "entry": entry,
            "alias": alias,
        }
    result = explain_metadata_file(
        type_key=entry.type_key,
        path=str(item.get("path")),
        name=str(item.get("name")),
        object_name=item.get("object_name"),
    )
    return {
        "family": "meta_inventory",
        "intent": meta_intent,
        "handler": "meta_inventory_explain",
        "result": result,
        "entry": entry,
        "alias": alias,
        "item": item,
    }


def route_ask_question(conn: sqlite3.Connection, question: str) -> dict[str, Any]:
    q = (question or "").strip()
    q_norm = normalize(q)
    d = build_entity_dictionary(conn)
    entities = _resolve_entities(q, d)
    family, intent = _dispatch_family(q, q_norm, entities)
    meta_request = _detect_meta_inventory_request(
        conn,
        question=q,
        question_norm=q_norm,
        entities=entities,
        family=family,
        intent=intent,
    )
    if meta_request:
        family = str(meta_request["family"])
        intent = str(meta_request["intent"])

    payload: dict[str, Any] = {
        "question": q,
        "intent": intent,
        "routing_family": family,
        "handler": None,
        "resolved": {
            "object_name": entities.object_name,
            "field_name": entities.field_name,
            "full_field_name": entities.full_field_name,
            "metadata_type": entities.metadata_type,
            "metadata_folder": entities.metadata_folder,
            "endpoint": entities.endpoint,
            "token": entities.token,
            "approval_process_name": entities.approval_process_name,
            "approval_process_full_name": entities.approval_process_full_name,
            "confidence": round(entities.confidence, 3),
        },
        "answer_lines": [],
        "evidence": [],
        "items": [],
        "count": 0,
        "error": None,
    }

    if meta_request:
        entry = meta_request["entry"]
        payload["resolved"]["metadata_type"] = entry.type_key
        payload["resolved"]["metadata_folder"] = entry.top_folder
        payload["resolved"]["metadata_scope"] = entry.scope
        payload["resolved"]["metadata_child_folder"] = entry.object_child_folder
        payload["resolved"]["metadata_alias"] = meta_request.get("alias")

    def _apply_result(result: dict[str, Any], handler_name: str) -> dict[str, Any]:
        payload["handler"] = handler_name
        payload["answer_lines"] = result.get("answer_lines", [])
        payload["evidence"] = result.get("evidence", [])
        payload["items"] = result.get("items", [])
        payload["count"] = int(result.get("count", len(payload["items"])))
        if result.get("error"):
            payload["error"] = result["error"]
        if result.get("dossier") is not None:
            payload["dossier"] = result["dossier"]
        for k in ("target", "target_type", "target_found", "class_name", "trigger_name", "bundle", "object_name"):
            if result.get(k) is not None:
                payload["resolved"][k] = result[k]
        return payload

    if meta_request:
        return _apply_result(meta_request["result"], str(meta_request["handler"]))

    if family == "flows_write_field":
        canonical_field, field_err = _strict_field_resolution(conn, d, q, entities)
        if not canonical_field:
            payload["error"] = field_err
            return payload
        payload["resolved"]["target"] = canonical_field
        payload["resolved"]["full_field_name"] = canonical_field
        return _apply_result(_handle_flows_write_field(conn, canonical_field), "flows_write_field")

    if family == "apex_write_field":
        canonical_field, field_err = _strict_field_resolution(conn, d, q, entities)
        if not canonical_field:
            payload["error"] = field_err
            return payload
        payload["resolved"]["target"] = canonical_field
        payload["resolved"]["full_field_name"] = canonical_field
        return _apply_result(_handle_apex_write_field(conn, canonical_field), "apex_write_field")

    if family == "field_writers_query":
        canonical_field, field_err = _strict_field_resolution(conn, d, q, entities)
        if not canonical_field:
            payload["error"] = field_err
            return payload
        payload["resolved"]["target"] = canonical_field
        payload["resolved"]["full_field_name"] = canonical_field
        return _apply_result(_handle_writers_for_field(conn, canonical_field), "field_writers_query")

    if family == "endpoints_inventory":
        if intent == "named_credentials_inventory":
            return _apply_result(_handle_named_credentials_inventory(conn), "named_credentials_inventory")
        return _apply_result(_handle_endpoints_inventory(conn), "endpoints_inventory")

    if family == "class_endpoints":
        return _apply_result(_handle_class_endpoints(conn, d, q), "class_endpoints")

    if family == "apex_smell_query":
        return _apply_result(_handle_apex_smell_query(conn, q_norm), "apex_smell_query")

    if family in {"trigger_deps", "trigger_explain", "trigger_impact"}:
        return _apply_result(_handle_trigger_query(conn, d, q, intent), family)

    if family == "collisions_query":
        canonical_field, field_err = _strict_field_resolution(conn, d, q, entities)
        if not canonical_field:
            payload["error"] = field_err
            return payload
        entities.full_field_name = canonical_field
        payload["resolved"]["target"] = canonical_field
        payload["resolved"]["full_field_name"] = canonical_field
        return _apply_result(_handle_collisions_query(conn, entities), "collisions_query")

    if family == "approval_process_inventory":
        return _apply_result(_handle_approval_process_inventory(conn), "approval_process_inventory")

    if family == "approval_process_references":
        return _apply_result(_handle_approval_process_references(conn, question=q, entities=entities), "approval_process_references")

    if family == "validation_rules_queries":
        return _apply_result(_handle_validation_rule_query(conn, q, q_norm, entities, intent), "validation_rules")

    if family == "security_queries":
        return _apply_result(_handle_security_query(conn, q, q_norm, entities, intent), "security_queries")

    if family == "ui_queries":
        return _apply_result(_handle_ui_query(conn, entities), "ui_queries")

    if family == "lwc_queries":
        return _apply_result(_handle_lwc_query(conn, d, q, q_norm, entities, intent), "lwc_queries")

    if family == "advisor_queries":
        return _apply_result(_handle_advisor_query(conn, q_norm, entities), "advisor_queries")

    if family == "story_planner":
        return _apply_result(_handle_story_planner(conn, q, entities), "story_planner")

    if family == "flows_touch_not_triggered":
        if not entities.object_name:
            payload["error"] = "object not found in repo"
            return payload
        return _apply_result(_handle_flows_touch_not_triggered(conn, entities.object_name), "flows_touch_not_triggered")

    if family == "approval_process_impact":
        return _apply_result(_handle_approval_process_impact(conn, question=q, entities=entities), "approval_process_impact")

    if family == "sharing_impact":
        if not entities.object_name:
            payload["error"] = "object not found in repo"
            return payload
        return _apply_result(_handle_sharing_impact(conn, entities.object_name), "sharing_impact")

    if intent == "explain_component":
        lines, evidence, items, dossier = _explain_component(
            conn,
            question=q,
            q_norm=q_norm,
            entities=entities,
            d=d,
        )
        payload["handler"] = "explain_component"
        payload["answer_lines"] = lines
        payload["evidence"] = evidence
        payload["items"] = items
        payload["count"] = len(items)
        if dossier is not None:
            payload["dossier"] = dossier
            payload["resolved"]["target"] = (dossier.get("target") or {}).get("name")
            payload["resolved"]["target_type"] = (dossier.get("target") or {}).get("type")
            payload["resolved"]["target_found"] = bool((dossier.get("target") or {}).get("found"))
        return payload

    if intent in {"count_type_on_object", "list_type_on_object"}:
        if not entities.metadata_type or not entities.metadata_folder:
            payload["error"] = "Could not resolve metadata type in question"
            return payload
        object_name = entities.object_name
        if not object_name:
            if " all " in f" {q_norm} ":
                handler = _handler_for(
                    conn,
                    type_name=entities.metadata_type,
                    folder=entities.metadata_folder,
                    question_norm=q_norm,
                )
                result = handler.count_all() if intent == "count_type_on_object" else handler.list_all()
                payload["handler"] = handler.__class__.__name__
                return _apply_result(result, handler.__class__.__name__)
            if entities.object_phrase_hint:
                payload["error"] = f"object not found in repo: {entities.object_phrase_hint}"
            else:
                payload["error"] = "object not found in repo"
            return payload

        if entities.metadata_type in {"Flow", "ApprovalProcess"}:
            dossier = build_evidence(conn, target=object_name, depth=2, top_n=20)
            payload["handler"] = "evidence_by_object"
            payload["resolved"]["target"] = object_name
            payload["resolved"]["target_type"] = dossier.get("target", {}).get("type")
            payload["resolved"]["target_found"] = bool(dossier.get("target", {}).get("found"))
            lines, evidence, items = _answer_from_evidence(
                intent=intent,
                q_norm=q_norm,
                metadata_type=entities.metadata_type,
                object_name=object_name,
                target=object_name,
                dossier=dossier,
            )
            payload["answer_lines"] = lines
            payload["evidence"] = evidence
            payload["items"] = items
            payload["count"] = len(items)
            payload["dossier"] = dossier
            return payload

        handler = _handler_for(
            conn,
            type_name=entities.metadata_type,
            folder=entities.metadata_folder,
            question_norm=q_norm,
        )
        result = handler.count_on_object(object_name) if intent == "count_type_on_object" else handler.list_on_object(object_name)
        payload["handler"] = handler.__class__.__name__
        return _apply_result(result, handler.__class__.__name__)

    if intent in {"count_type", "list_type"}:
        if not entities.metadata_type or not entities.metadata_folder:
            payload["error"] = "Could not resolve metadata type in question"
            return payload
        handler = _handler_for(
            conn,
            type_name=entities.metadata_type,
            folder=entities.metadata_folder,
            question_norm=q_norm,
        )
        result = handler.count_all() if intent == "count_type" else handler.list_all()
        payload = _apply_result(result, handler.__class__.__name__)
        if entities.metadata_type == "Flow" and not entities.field_explicit:
            payload["answer_lines"].append('Tip: ask "Which flows update Account.Status__c?" for field-level answers.')
        return payload

    if intent == "where_used_any":
        token = entities.token or entities.endpoint or entities.object_name or entities.full_field_name or ""
        lines, evidence = _where_used_any(conn, token)
        payload["handler"] = "where_used_any"
        payload["answer_lines"] = lines
        payload["evidence"] = evidence
        payload["items"] = evidence
        payload["count"] = len(evidence)
        return payload

    target = _target_from_entities(q, q_norm, entities, d)
    if not target:
        if intent == "impact_or_deps" and entities.token:
            report = what_breaks(conn, target=entities.token, depth=2)
            counts = report.get("counts", {})
            payload["handler"] = "what_breaks"
            payload["answer_lines"] = [
                f"Impact target: {entities.token}",
                f"Dependents — FLOW:{counts.get('FLOW', 0)} APEX_CLASS:{counts.get('APEX_CLASS', 0)} "
                f"TRIGGER:{counts.get('TRIGGER', 0)} FIELD:{counts.get('FIELD', 0)} OBJECT:{counts.get('OBJECT', 0)}",
            ]
            payload["evidence"] = report.get("dependents", [])[:50]
            payload["items"] = report.get("dependents", [])
            payload["count"] = len(payload["items"])
            return payload
        payload["error"] = "Could not resolve intent/entities"
        return payload

    dossier = build_evidence(conn, target=target, depth=2, top_n=20)
    payload["handler"] = "build_evidence"
    payload["intent"] = "evidence" if intent == "unknown" else intent
    payload["resolved"]["target"] = target
    payload["resolved"]["target_type"] = dossier.get("target", {}).get("type")
    payload["resolved"]["target_found"] = bool(dossier.get("target", {}).get("found"))
    payload["resolved"]["confidence"] = max(payload["resolved"]["confidence"], 0.7)
    lines, evidence, items = _answer_from_evidence(
        intent=intent,
        q_norm=q_norm,
        metadata_type=entities.metadata_type,
        object_name=entities.object_name,
        target=target,
        dossier=dossier,
    )
    payload["answer_lines"] = lines
    payload["evidence"] = evidence
    payload["items"] = items
    payload["count"] = len(items)
    payload["dossier"] = dossier
    return payload
