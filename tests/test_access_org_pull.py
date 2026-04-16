from __future__ import annotations

from typing import Any

from sf_repo_ai.access.org_pull import build_access_bundle_from_org


class _FakeSfClient:
    def query(self, soql: str, tooling: bool = False) -> list[dict[str, Any]]:  # noqa: ANN001
        s = " ".join(soql.split())
        if "FROM User WHERE Username=" in s:
            return [{"Id": "005USER", "Username": "user@example.com", "ProfileId": "00ePROFILE", "UserRoleId": "00EROLEU"}]
        if "FROM User WHERE Id='005OWN'" in s:
            return [{"Id": "005OWN", "UserRoleId": "00EROLEO"}]
        if "FROM EntityDefinition WHERE KeyPrefix='001'" in s:
            return [{"QualifiedApiName": "Account", "KeyPrefix": "001"}]
        if "FROM Account WHERE Id='001REC'" in s:
            return [{"Id": "001REC", "OwnerId": "005OWN"}]
        if "FROM Profile WHERE Id='00ePROFILE'" in s:
            return [{"Id": "00ePROFILE", "Name": "Standard User"}]
        if "FROM PermissionSetAssignment WHERE AssigneeId='005USER'" in s:
            return [{"PermissionSetId": "0PS1", "PermissionSet": {"Name": "PS1", "IsOwnedByProfile": False}}]
        if "FROM ObjectPermissions" in s:
            return [
                {
                    "ParentId": "00ePROFILE",
                    "SObjectType": "Account",
                    "PermissionsRead": True,
                    "PermissionsEdit": False,
                    "PermissionsDelete": False,
                    "PermissionsCreate": True,
                    "PermissionsViewAllRecords": False,
                    "PermissionsModifyAllRecords": False,
                }
            ]
        if "FROM GroupMember WHERE UserOrGroupId='005USER'" in s:
            return [{"GroupId": "00G1"}]
        if "FROM AccountShare WHERE ParentId='001REC'" in s:
            return [{"UserOrGroupId": "00G1", "AccessLevel": "Read", "RowCause": "Manual"}]
        if "FROM AccountTeamMember WHERE AccountId='001REC'" in s:
            return []
        if "FROM UserRole" in s:
            return [
                {"Id": "00EROLEO", "ParentRoleId": "00EROLEU"},
                {"Id": "00EROLEU", "ParentRoleId": None},
            ]
        return []


def test_build_access_bundle_from_org() -> None:
    bundle = build_access_bundle_from_org(_FakeSfClient(), user_input="user@example.com", record_id="001REC")
    assert bundle.user.user_id == "005USER"
    assert bundle.record.object_name == "Account"
    assert bundle.record.owner_id == "005OWN"
    assert bundle.object_access.can_read is True
    assert bundle.object_access.can_create is True
    assert len(bundle.shares) == 1
    assert bundle.in_role_hierarchy is True

