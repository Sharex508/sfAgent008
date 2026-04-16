from __future__ import annotations

import sqlite3
from typing import Any

from .schema import AccessBundle, AccessReport


def _is_public_owd(owd: str) -> bool:
    low = (owd or "").lower()
    return ("public" in low and "read" in low) or low in {"publicreadwrite", "publicreadonly"}


def _metadata_cross_reference(conn: sqlite3.Connection, object_name: str) -> dict[str, Any]:
    ctx: dict[str, Any] = {
        "sharing_rules": [],
        "permission_artifacts": [],
    }
    try:
        rules = conn.execute(
            """
            SELECT name, rule_type, access_level, path
            FROM sharing_rules
            WHERE lower(object_name)=lower(?)
            ORDER BY name
            LIMIT 20
            """,
            (object_name,),
        ).fetchall()
        ctx["sharing_rules"] = [dict(r) for r in rules]
    except Exception:
        pass

    try:
        perms = conn.execute(
            """
            SELECT DISTINCT src_name, src_path, snippet, confidence
            FROM "references"
            WHERE src_type='PERMISSION'
              AND ref_type='OBJECT'
              AND lower(ref_key)=lower(?)
            ORDER BY confidence DESC, src_name
            LIMIT 20
            """,
            (object_name,),
        ).fetchall()
        ctx["permission_artifacts"] = [dict(r) for r in perms]
    except Exception:
        pass

    return ctx


def evaluate(bundle: AccessBundle, conn: sqlite3.Connection | None = None) -> AccessReport:
    reasons: list[str] = []
    fixes: list[dict[str, Any]] = []
    decision = "DENY"
    object_gate = "DENY"
    record_gate = "DENY"

    user = bundle.user
    obj = bundle.object_access
    sharing = bundle.sharing_model
    rec = bundle.record

    # 1) Object gate
    if not obj.can_read:
        reasons.append("Denied: object read access is false.")
        fixes.append(
            {
                "title": f"Grant read access on {obj.object_name}",
                "risk": "MEDIUM",
                "why": "User lacks object-level read permission.",
            }
        )
        metadata_context = _metadata_cross_reference(conn, obj.object_name) if conn else {}
        return AccessReport(
            decision=decision,
            object_gate=object_gate,
            record_gate=record_gate,
            reasons=reasons,
            suggested_fixes=fixes,
            evidence_used={
                "object_access": obj.__dict__,
                "sharing_model": sharing.__dict__,
                "record": rec.__dict__,
                "user": user.__dict__,
                "extras": bundle.extras,
            },
            metadata_context=metadata_context,
        )
    object_gate = "ALLOW"
    reasons.append("Object gate passed: object read access is granted.")

    # 2) ViewAll/ModifyAll
    if obj.view_all or obj.modify_all:
        decision = "ALLOW"
        record_gate = "ALLOW"
        reasons.append("Allowed: object permission has ViewAll/ModifyAll.")
    # 3) OWD public
    elif _is_public_owd(sharing.owd):
        decision = "ALLOW"
        record_gate = "ALLOW"
        reasons.append(f"Allowed: OWD is public ({sharing.owd}).")
    # 4) Owner
    elif rec.owner_id and rec.owner_id == user.user_id:
        decision = "ALLOW"
        record_gate = "ALLOW"
        reasons.append("Allowed: user owns the record.")
    # 5) Role hierarchy
    elif sharing.grant_using_hierarchy and bundle.in_role_hierarchy:
        decision = "ALLOW"
        record_gate = "ALLOW"
        reasons.append("Allowed: role hierarchy grants access.")
    else:
        # 6) Share rows
        user_or_groups = {user.user_id} | set(user.group_ids)
        matching_shares = [s for s in bundle.shares if s.user_or_group_id in user_or_groups]
        if matching_shares:
            decision = "ALLOW"
            record_gate = "ALLOW"
            reasons.append(f"Allowed: matching share row(s) found: {len(matching_shares)}")
        else:
            # 7) Team membership
            matching_teams = [t for t in bundle.teams if t.user_id == user.user_id]
            if matching_teams:
                decision = "ALLOW"
                record_gate = "ALLOW"
                reasons.append(f"Allowed: team membership found: {len(matching_teams)}")
            else:
                decision = "DENY"
                record_gate = "DENY"
                reasons.append("Denied: no share/team/ownership/hierarchy grant found for this record.")
                fixes.extend(
                    [
                        {
                            "title": "Add sharing rule or manual share",
                            "risk": "LOW",
                            "why": "OWD/private model requires record-level share for this user/group.",
                        },
                        {
                            "title": "Add user to Account/Opportunity team",
                            "risk": "LOW",
                            "why": "Team access can grant record visibility where configured.",
                        },
                        {
                            "title": "Review role hierarchy and grantUsingHierarchy",
                            "risk": "MEDIUM",
                            "why": "If hierarchy should grant access, role alignment may be incorrect.",
                        },
                    ]
                )

    metadata_context = {}
    if conn and decision == "DENY" and obj.object_name:
        metadata_context = _metadata_cross_reference(conn, obj.object_name)

    return AccessReport(
        decision=decision,
        object_gate=object_gate,
        record_gate=record_gate,
        reasons=reasons,
        suggested_fixes=fixes,
        evidence_used={
            "object_access": obj.__dict__,
            "sharing_model": sharing.__dict__,
            "record": rec.__dict__,
            "user": user.__dict__,
            "share_count": len(bundle.shares),
            "team_count": len(bundle.teams),
            "extras": bundle.extras,
        },
        metadata_context=metadata_context,
    )
