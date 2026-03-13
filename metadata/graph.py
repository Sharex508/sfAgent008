from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

import networkx as nx

from metadata.metadata_types import MetadataDoc


def build_graph(docs: List[MetadataDoc]) -> nx.DiGraph:
    g = nx.DiGraph()

    # Add nodes
    for d in docs:
        g.add_node(
            d.doc_id,
            kind=d.kind,
            name=d.name,
            path=d.path,
        )

    # Index docs by kind and name for quick lookup
    by_kind: Dict[str, List[MetadataDoc]] = {}
    by_name: Dict[str, List[MetadataDoc]] = {}
    for d in docs:
        by_kind.setdefault(d.kind, []).append(d)
        by_name.setdefault(d.name, []).append(d)

    # Helper sets
    apex_docs = (by_kind.get("ApexClass", []) or []) + (by_kind.get("ApexTrigger", []) or [])
    apex_trigger_docs = by_kind.get("ApexTrigger", []) or []
    flow_docs = by_kind.get("Flow", []) or []
    field_docs = by_kind.get("Field", []) or []
    object_docs = by_kind.get("Object", []) or []
    profile_docs = by_kind.get("Profile", []) or []
    permset_docs = by_kind.get("PermSet", []) or []
    approval_docs = by_kind.get("ApprovalProcess", []) or []

    # 1) Field -> Apex references via simple string match
    #    Try both `Object.Field` and `Object__c.Field__c` variants
    for fdoc in field_docs:
        field_name = fdoc.name  # Object.Field
        # Derive another variant if possible
        if "." in field_name:
            obj, fld = field_name.split(".", 1)
        else:
            obj, fld = field_name, ""
        variants = {field_name}
        # If object doesn't end with __c and field doesn't, also try adding __c
        obj_c = obj if obj.endswith("__c") else f"{obj}__c"
        fld_c = fld if fld.endswith("__c") else (f"{fld}__c" if fld else fld)
        if fld:
            variants.add(f"{obj_c}.{fld_c}")
            variants.add(f"{obj}.{fld_c}")
            variants.add(f"{obj_c}.{fld}")

        for adoc in apex_docs:
            text = adoc.text or ""
            if any(v and v in text for v in variants):
                g.add_edge(fdoc.doc_id, adoc.doc_id, kind="references")

    # 1b) Apex -> Apex references via identifier token overlap (best-effort)
    apex_by_name: Dict[str, MetadataDoc] = {d.name: d for d in apex_docs if d.name}
    apex_names = set(apex_by_name.keys())
    ident_re = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]*\b")
    for src in apex_docs:
        text = src.text or ""
        if not text:
            continue
        tokens = set(ident_re.findall(text))
        refs = (tokens & apex_names) - {src.name}
        for ref_name in refs:
            target = apex_by_name.get(ref_name)
            if target is None:
                continue
            edge_kind = "calls" if src.kind == "ApexClass" else "uses"
            g.add_edge(src.doc_id, target.doc_id, kind=edge_kind)

    # 1c) Object -> Trigger edge from trigger declaration: `trigger X on Object (...)`
    object_by_name = {d.name: d for d in object_docs}
    trig_decl_re = re.compile(r"\btrigger\s+\w+\s+on\s+([A-Za-z0-9_]+)\s*\(", re.IGNORECASE)
    for td in apex_trigger_docs:
        text = td.text or ""
        m = trig_decl_re.search(text)
        if not m:
            continue
        object_name = m.group(1)
        od = object_by_name.get(object_name) or object_by_name.get(object_name.replace("__c", ""))
        if od is not None:
            g.add_edge(od.doc_id, td.doc_id, kind="acts_on")

    # 2) Object -> Flow if flow mentions the object in its extracted objects set or text
    for odoc in object_docs:
        obj_name = odoc.name
        obj_variants = {obj_name, f"{obj_name}__c" if not obj_name.endswith("__c") else obj_name}
        for fd in flow_docs:
            mentioned = False
            # Use raw_snippet JSON if available
            if fd.raw_snippet:
                try:
                    data = json.loads(fd.raw_snippet)
                    objects = set(data.get("objects", []))
                    if objects & obj_variants:
                        mentioned = True
                except Exception:
                    pass
            # Fallback to text search
            if not mentioned:
                text = fd.text or ""
                if any(v in text for v in obj_variants):
                    mentioned = True
            if mentioned:
                g.add_edge(odoc.doc_id, fd.doc_id, kind="acts_on")

    # 3) Profile/PermSet -> Object/Field based on permissions from raw_snippet JSON
    def _edges_from_security(sec_doc: MetadataDoc):
        try:
            data = json.loads(sec_doc.raw_snippet or "{}")
        except Exception:
            data = {}
        obj_perms: Dict[str, dict] = data.get("objectPermissions", {}) or {}
        fld_perms: Dict[str, dict] = data.get("fieldPermissions", {}) or {}

        # Object permissions
        for obj_name in obj_perms.keys():
            # Find matching Object doc_id(s)
            for od in object_docs:
                if od.name == obj_name or (not od.name.endswith("__c") and f"{od.name}__c" == obj_name):
                    g.add_edge(sec_doc.doc_id, od.doc_id, kind="grants")

        # Field permissions (keys are like Account.Custom__c)
        for field_ref in fld_perms.keys():
            # Compose our internal field name forms to match
            if "." in field_ref:
                obj, fld = field_ref.split(".", 1)
            else:
                obj, fld = field_ref, ""
            candidates = {f"{obj}.{fld}"}
            # Add variant without __c suffixes if present
            obj_base = obj[:-3] if obj.endswith("__c") else obj
            fld_base = fld[:-3] if fld.endswith("__c") else fld
            if fld:
                candidates.add(f"{obj_base}.{fld_base}")
            for fd in field_docs:
                if fd.name in candidates:
                    g.add_edge(sec_doc.doc_id, fd.doc_id, kind="grants")

    for sd in profile_docs + permset_docs:
        _edges_from_security(sd)

    # 4) ApprovalProcess dependencies from raw_snippet metadata
    def _ref_node(kind: str, name: str) -> str:
        node_id = f"{kind}:{name}"
        if not g.has_node(node_id):
            g.add_node(node_id, kind=kind, name=name, path="")
        return node_id

    object_by_name = {d.name: d for d in object_docs}
    field_by_name = {d.name: d for d in field_docs}

    for ap in approval_docs:
        try:
            data = json.loads(ap.raw_snippet or "{}")
        except Exception:
            data = {}

        object_api = str(data.get("object_api_name") or "").strip()
        if object_api:
            od = object_by_name.get(object_api) or object_by_name.get(object_api.replace("__c", ""))
            if od is not None:
                g.add_edge(od.doc_id, ap.doc_id, kind="acts_on")

        for fld in data.get("criteria_fields", []) or []:
            if not isinstance(fld, str) or not fld.strip():
                continue
            fd = field_by_name.get(fld.strip())
            if fd is not None:
                g.add_edge(fd.doc_id, ap.doc_id, kind="entry_criteria")
            else:
                ref = _ref_node("CriteriaField", fld.strip())
                g.add_edge(ref, ap.doc_id, kind="entry_criteria")

        for apv in data.get("approver_refs", []) or []:
            if not isinstance(apv, dict):
                continue
            name = str(apv.get("name") or "").strip()
            typ = str(apv.get("type") or "").strip()
            if not name:
                continue
            ref_kind = {
                "queue": "Queue",
                "publicGroup": "PublicGroup",
                "relatedUserField": "RelatedUserField",
                "user": "User",
                "role": "Role",
            }.get(typ, f"ApproverType:{typ or 'unknown'}")
            ref = _ref_node(ref_kind, name)
            g.add_edge(ap.doc_id, ref, kind="assigned_approver")

        for template in data.get("email_templates", []) or []:
            if not isinstance(template, str) or not template.strip():
                continue
            ref = _ref_node("EmailTemplate", template.strip())
            g.add_edge(ap.doc_id, ref, kind="uses_email_template")

        for action in data.get("actions", []) or []:
            if not isinstance(action, dict):
                continue
            action_name = str(action.get("name") or "").strip()
            action_type = str(action.get("type") or "").strip()
            scope = str(action.get("scope") or "").strip()
            if not action_name:
                continue
            node_name = f"{action_type}:{action_name}" if action_type else action_name
            ref = _ref_node("ApprovalAction", node_name)
            edge_kind = f"has_action:{scope}" if scope else "has_action"
            g.add_edge(ap.doc_id, ref, kind=edge_kind)

    return g


def save_edgelist(g: nx.DiGraph, out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        for u, v, data in g.edges(data=True):
            kind = data.get("kind", "")
            f.write(f"{u}\t{v}\t{kind}\n")


def main():
    parser = argparse.ArgumentParser(description="Build dependency graph from metadata docs JSONL")
    parser.add_argument("--docs", type=Path, default=Path("./data/metadata/docs.jsonl"))
    parser.add_argument("--out", type=Path, default=Path("./data/metadata/graph.edgelist"))
    args = parser.parse_args()

    # Load docs JSONL
    docs: List[MetadataDoc] = []
    if args.docs.exists():
        with args.docs.open("r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                docs.append(MetadataDoc.model_validate_json(line))

    g = build_graph(docs)
    save_edgelist(g, args.out)
    print(json.dumps({
        "nodes": g.number_of_nodes(),
        "edges": g.number_of_edges(),
    }, indent=2))


if __name__ == "__main__":
    main()
