from __future__ import annotations

import sqlite3

from sf_repo_ai.access.evaluator import evaluate
from sf_repo_ai.access.schema import AccessBundle
from sf_repo_ai.db import init_schema


def _bundle(data: dict) -> AccessBundle:
    return AccessBundle.from_dict(data)


def test_access_denied_when_object_read_missing() -> None:
    bundle = _bundle(
        {
            "user": {"user_id": "005U1"},
            "object_access": {"object_name": "Account", "can_read": False},
            "sharing_model": {"object_name": "Account", "owd": "Private"},
            "record": {"record_id": "001R1", "object_name": "Account", "owner_id": "005OWN"},
        }
    )
    report = evaluate(bundle)
    assert report.decision == "DENY"
    assert report.object_gate == "DENY"
    assert any("object read access is false" in r for r in report.reasons)


def test_access_allowed_by_view_all() -> None:
    bundle = _bundle(
        {
            "user": {"user_id": "005U1"},
            "object_access": {"object_name": "Account", "can_read": True, "view_all": True},
            "sharing_model": {"object_name": "Account", "owd": "Private"},
            "record": {"record_id": "001R1", "object_name": "Account", "owner_id": "005OWN"},
        }
    )
    report = evaluate(bundle)
    assert report.decision == "ALLOW"
    assert report.record_gate == "ALLOW"
    assert any("ViewAll/ModifyAll" in r for r in report.reasons)


def test_access_allowed_by_share_row_group_membership() -> None:
    bundle = _bundle(
        {
            "user": {"user_id": "005U1", "group_ids": ["00GTEAM"]},
            "object_access": {"object_name": "Account", "can_read": True},
            "sharing_model": {"object_name": "Account", "owd": "Private"},
            "record": {"record_id": "001R1", "object_name": "Account", "owner_id": "005OWN"},
            "shares": [{"user_or_group_id": "00GTEAM", "access_level": "Read"}],
        }
    )
    report = evaluate(bundle)
    assert report.decision == "ALLOW"
    assert report.record_gate == "ALLOW"
    assert any("matching share row" in r for r in report.reasons)


def test_access_denied_includes_metadata_cross_reference() -> None:
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    init_schema(conn)
    conn.execute(
        """
        INSERT INTO sharing_rules(name, object_name, rule_type, access_level, active, path)
        VALUES ('AccountShareRule', 'Account', 'criteria', 'Read', 1, 'force-app/main/default/sharingRules/Account.share-meta.xml')
        """
    )
    conn.execute(
        """
        INSERT INTO "references"(ref_type, ref_key, src_type, src_name, src_path, confidence)
        VALUES ('OBJECT', 'Account', 'PERMISSION', 'Account_Read_PS', 'force-app/main/default/permissionsets/Account_Read.permissionset-meta.xml', 0.9)
        """
    )
    conn.commit()

    bundle = _bundle(
        {
            "user": {"user_id": "005U1"},
            "object_access": {"object_name": "Account", "can_read": True},
            "sharing_model": {"object_name": "Account", "owd": "Private"},
            "record": {"record_id": "001R1", "object_name": "Account", "owner_id": "005OWN"},
            "shares": [],
            "teams": [],
        }
    )
    report = evaluate(bundle, conn=conn)
    assert report.decision == "DENY"
    assert report.metadata_context["sharing_rules"]
    assert report.metadata_context["permission_artifacts"]

