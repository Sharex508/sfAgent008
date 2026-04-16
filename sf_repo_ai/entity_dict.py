from __future__ import annotations

from dataclasses import dataclass
import re
import sqlite3

from sf_repo_ai.query_interpreter import build_alias_maps, normalize as normalize_text


@dataclass(slots=True)
class EntityDictionary:
    object_alias_map: dict[str, str]
    field_alias_map: dict[str, str]
    meta_type_alias_map: dict[str, dict[str, str]]
    objects: list[str]
    fields: list[str]
    flows: list[str]
    apex_classes: list[str]
    folders: list[str]


def normalize(s: str) -> str:
    return normalize_text(s)


def split_camel(text: str) -> str:
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", text)
    s = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1 \2", s)
    return s


def pluralize(term: str) -> str:
    if not term:
        return term
    if term.endswith("s"):
        return term
    if term.endswith("y") and len(term) >= 2 and term[-2] not in "aeiou":
        return term[:-1] + "ies"
    return term + "s"


def _plural_phrase(phrase: str) -> str:
    parts = phrase.split()
    if not parts:
        return phrase
    parts[-1] = pluralize(parts[-1])
    return " ".join(parts)


def _choose_preferred_object(existing: str, new: str) -> str:
    if len(new) < len(existing):
        return new
    return existing


def _generate_object_aliases(object_name: str) -> set[str]:
    aliases: set[str] = set()
    canonical = normalize(object_name)
    spaced = normalize(split_camel(object_name.replace("_", " ")))
    variants = {canonical, spaced}

    for v in variants:
        if not v:
            continue
        aliases.add(v)
        aliases.add(_plural_phrase(v))
        aliases.add(normalize(f"{v} object"))
        aliases.add(normalize(f"object {v}"))
    return {a for a in aliases if a}


def _meta_catalog() -> list[tuple[str, str, list[str]]]:
    return [
        ("ApexClass", "classes", ["apex class", "apex classes", "class", "classes"]),
        ("Trigger", "triggers", ["trigger", "triggers"]),
        ("Flow", "flows", ["flow", "flows"]),
        ("LWC", "lwc", ["lwc", "lwc component", "lwc components", "lightning web component", "lightning web components"]),
        ("Layout", "layouts", ["layout", "layouts"]),
        ("Flexipage", "flexipages", ["flexipage", "flexipages", "flexi page", "flexi pages"]),
        ("QuickAction", "quickActions", ["quick action", "quick actions"]),
        ("ApprovalProcess", "approvalProcesses", ["approval process", "approval processes"]),
        ("SharingRule", "sharingRules", ["sharing rule", "sharing rules"]),
        ("AssignmentRule", "assignmentRules", ["assignment rule", "assignment rules"]),
        ("ValidationRule", "validationRules", ["validation rule", "validation rules"]),
        ("Profile", "profiles", ["profile", "profiles"]),
        ("PermissionSet", "permissionsets", ["permission set", "permission sets"]),
        ("Workflow", "workflows", ["workflow", "workflows", "workflow rule", "workflow rules"]),
        ("EscalationRule", "escalationRules", ["escalation rule", "escalation rules"]),
        ("AutoResponseRule", "autoResponseRules", ["auto response rule", "auto response rules"]),
        ("DuplicateRule", "duplicateRules", ["duplicate rule", "duplicate rules"]),
        ("MatchingRule", "matchingRules", ["matching rule", "matching rules"]),
        ("Queue", "queues", ["queue", "queues"]),
        ("Group", "groups", ["group", "groups"]),
        ("ConnectedApp", "connectedApps", ["connected app", "connected apps"]),
        ("AuthProvider", "authproviders", ["auth provider", "auth providers"]),
        ("CspTrustedSite", "cspTrustedSites", ["csp trusted site", "csp trusted sites"]),
        ("CorsWhitelistOrigin", "corsWhitelistOrigins", ["cors whitelist origin", "cors whitelist origins"]),
        ("RemoteSiteSetting", "remoteSiteSettings", ["remote site setting", "remote site settings"]),
        ("Setting", "settings", ["setting", "settings"]),
    ]


def build_entity_dictionary(conn: sqlite3.Connection) -> EntityDictionary:
    field_alias_map, object_alias_map = build_alias_maps(conn)

    object_rows = conn.execute("SELECT object_name FROM objects").fetchall()
    field_object_rows = conn.execute("SELECT DISTINCT object_name FROM fields").fetchall()
    approval_object_rows = conn.execute(
        "SELECT DISTINCT object_name FROM approval_processes WHERE object_name IS NOT NULL AND object_name <> ''"
    ).fetchall()
    sharing_object_rows = conn.execute(
        "SELECT DISTINCT object_name FROM sharing_rules WHERE object_name IS NOT NULL AND object_name <> ''"
    ).fetchall()

    object_names = {r["object_name"] for r in object_rows}
    object_names.update({r["object_name"] for r in field_object_rows})
    object_names.update({r["object_name"] for r in approval_object_rows})
    object_names.update({r["object_name"] for r in sharing_object_rows})

    for obj in sorted(x for x in object_names if x):
        for alias in _generate_object_aliases(obj):
            current = object_alias_map.get(alias)
            if current is None:
                object_alias_map[alias] = obj
            else:
                object_alias_map[alias] = _choose_preferred_object(current, obj)

    field_rows = conn.execute("SELECT full_name FROM fields ORDER BY full_name").fetchall()
    flow_rows = conn.execute("SELECT flow_name FROM flows ORDER BY flow_name").fetchall()
    apex_rows = conn.execute(
        "SELECT DISTINCT name FROM components WHERE type='APEX' ORDER BY name"
    ).fetchall()
    folder_rows = conn.execute("SELECT DISTINCT folder FROM meta_files ORDER BY folder").fetchall()

    existing_folders = {r["folder"] for r in folder_rows}
    meta_type_alias_map: dict[str, dict[str, str]] = {}
    for type_name, folder, aliases in _meta_catalog():
        if folder not in existing_folders:
            continue
        for alias in aliases:
            meta_type_alias_map[normalize(alias)] = {"type": type_name, "folder": folder}

    # Auto-add folder-name aliases for non-catalog folders.
    for folder in sorted(existing_folders):
        if any(v.get("folder") == folder for v in meta_type_alias_map.values()):
            continue
        friendly = normalize(split_camel(folder.replace("_", " ")))
        if not friendly:
            continue
        type_name = folder[:-1] if folder.endswith("s") else folder
        meta_type_alias_map[friendly] = {"type": type_name, "folder": folder}
        meta_type_alias_map[_plural_phrase(friendly)] = {"type": type_name, "folder": folder}

    return EntityDictionary(
        object_alias_map=object_alias_map,
        field_alias_map=field_alias_map,
        meta_type_alias_map=meta_type_alias_map,
        objects=sorted(object_names),
        fields=[r["full_name"] for r in field_rows],
        flows=[r["flow_name"] for r in flow_rows],
        apex_classes=[r["name"] for r in apex_rows],
        folders=[r["folder"] for r in folder_rows],
    )
