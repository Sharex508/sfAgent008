from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

HIGH_RISK_SYSTEM_PERMISSIONS = {
    "ModifyAllData",
    "ViewAllData",
    "AuthorApex",
    "ManageUsers",
    "ManageProfilesPermissionsets",
    "CustomizeApplication",
    "ManageSecurity",
    "ApiEnabled",
}


def _find_text(parent: ET.Element, local_name: str) -> str | None:
    node = parent.find(f"{{*}}{local_name}")
    if node is None or node.text is None:
        return None
    value = node.text.strip()
    return value or None


def _scan_security_file(path: Path) -> dict:
    tree = ET.parse(path)
    root = tree.getroot()

    name = path.name.replace(".permissionset-meta.xml", "").replace(".profile-meta.xml", "")
    findings = {
        "name": name,
        "path": path.as_posix(),
        "type": "permset" if path.name.endswith(".permissionset-meta.xml") else "profile",
        "modify_or_view_all": [],
        "high_risk_system_permissions": [],
    }

    for op in root.findall("{*}objectPermissions"):
        obj = _find_text(op, "object")
        if not obj:
            continue
        modify_all = (_find_text(op, "modifyAllRecords") or "false").lower() == "true"
        view_all = (_find_text(op, "viewAllRecords") or "false").lower() == "true"
        if modify_all or view_all:
            findings["modify_or_view_all"].append(
                {
                    "object": obj,
                    "modifyAllRecords": modify_all,
                    "viewAllRecords": view_all,
                }
            )

    for sp in root.findall("{*}userPermissions"):
        perm_name = _find_text(sp, "name")
        enabled = (_find_text(sp, "enabled") or "false").lower() == "true"
        if perm_name in HIGH_RISK_SYSTEM_PERMISSIONS and enabled:
            findings["high_risk_system_permissions"].append(perm_name)

    return findings


def generate_security_techdebt(repo_root: Path, sfdx_root: str) -> dict:
    base = repo_root / sfdx_root
    rows: list[dict] = []

    for folder, pattern in (("permissionsets", "*.permissionset-meta.xml"), ("profiles", "*.profile-meta.xml")):
        d = base / folder
        if not d.exists():
            continue
        for path in d.glob(pattern):
            try:
                row = _scan_security_file(path)
            except Exception:
                continue
            if row["modify_or_view_all"] or row["high_risk_system_permissions"]:
                rows.append(row)

    return {
        "high_risk_system_permissions": sorted(HIGH_RISK_SYSTEM_PERMISSIONS),
        "findings": rows,
    }
