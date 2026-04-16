from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List, Tuple
from lxml import etree

from metadata.metadata_types import MetadataDoc, make_doc_id


def _parse_object_permissions(root) -> Dict[str, Dict[str, bool]]:
    perms: Dict[str, Dict[str, bool]] = {}
    for el in root.findall("{*}objectPermissions"):
        obj = el.findtext("{*}object")
        if not obj:
            continue
        perms[obj] = {
            "allowCreate": (el.findtext("{*}allowCreate") or "false").lower() == "true",
            "allowDelete": (el.findtext("{*}allowDelete") or "false").lower() == "true",
            "allowEdit": (el.findtext("{*}allowEdit") or "false").lower() == "true",
            "allowRead": (el.findtext("{*}allowRead") or "false").lower() == "true",
            "modifyAllRecords": (el.findtext("{*}modifyAllRecords") or "false").lower() == "true",
            "viewAllRecords": (el.findtext("{*}viewAllRecords") or "false").lower() == "true",
        }
    return perms


def _parse_field_permissions(root) -> Dict[str, Dict[str, bool]]:
    perms: Dict[str, Dict[str, bool]] = {}
    for el in root.findall("{*}fieldPermissions"):
        fld = el.findtext("{*}field")  # e.g., Account.Custom__c
        if not fld:
            continue
        perms[fld] = {
            "readable": (el.findtext("{*}readable") or "false").lower() == "true",
            "editable": (el.findtext("{*}editable") or "false").lower() == "true",
        }
    return perms


def parse_profile_file(path: Path) -> MetadataDoc:
    tree = etree.parse(str(path))
    root = tree.getroot()
    name = path.stem.split(".profile-meta")[0]
    obj_perms = _parse_object_permissions(root)
    fld_perms = _parse_field_permissions(root)
    text = (
        f"Profile {name}\nObjects: {', '.join(sorted(obj_perms.keys()))}\n"
        f"Fields: {', '.join(sorted(fld_perms.keys()))}"
    )
    raw = json.dumps({"objectPermissions": obj_perms, "fieldPermissions": fld_perms})
    return MetadataDoc(
        doc_id=make_doc_id("Profile", name),
        kind="Profile",
        name=name,
        path=str(path),
        text=text,
        raw_snippet=raw,
    )


def parse_permissionset_file(path: Path) -> MetadataDoc:
    tree = etree.parse(str(path))
    root = tree.getroot()
    name = path.stem.split(".permissionset-meta")[0]
    obj_perms = _parse_object_permissions(root)
    fld_perms = _parse_field_permissions(root)
    text = (
        f"PermSet {name}\nObjects: {', '.join(sorted(obj_perms.keys()))}\n"
        f"Fields: {', '.join(sorted(fld_perms.keys()))}"
    )
    raw = json.dumps({"objectPermissions": obj_perms, "fieldPermissions": fld_perms})
    return MetadataDoc(
        doc_id=make_doc_id("PermSet", name),
        kind="PermSet",
        name=name,
        path=str(path),
        text=text,
        raw_snippet=raw,
    )


def parse_security(dir_path: Path) -> List[MetadataDoc]:
    docs: List[MetadataDoc] = []
    for p in dir_path.rglob("*.profile-meta.xml"):
        docs.append(parse_profile_file(p))
    for p in dir_path.rglob("*.permissionset-meta.xml"):
        docs.append(parse_permissionset_file(p))
    return docs
