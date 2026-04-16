from __future__ import annotations

from dataclasses import asdict
from typing import Any

from sf_repo_ai.access.schema import AccessBundle, ObjectAccess, RecordContext, ShareRow, SharingModel, TeamMember, UserContext


def _soql_escape(value: str) -> str:
    return (value or "").replace("\\", "\\\\").replace("'", "\\'")


def _query(client: Any, soql: str, *, tooling: bool = False) -> list[dict[str, Any]]:
    if hasattr(client, "tooling_query") and tooling:
        return list(client.tooling_query(soql))
    if hasattr(client, "query"):
        return list(client.query(soql, tooling=tooling))
    raise RuntimeError("Unsupported Salesforce client for query().")


def _query_one(client: Any, soql: str, *, tooling: bool = False) -> dict[str, Any] | None:
    rows = _query(client, soql, tooling=tooling)
    return rows[0] if rows else None


def _resolve_user(client: Any, user_input: str) -> dict[str, Any]:
    raw = (user_input or "").strip()
    if len(raw) in {15, 18} and raw.isalnum():
        row = _query_one(
            client,
            "SELECT Id, Username, ProfileId, UserRoleId, IsActive, UserType "
            f"FROM User WHERE Id='{_soql_escape(raw)}' LIMIT 1",
        )
        if not row:
            raise RuntimeError(f"User not found: {user_input}")
        return row
    row = _query_one(
        client,
        "SELECT Id, Username, ProfileId, UserRoleId, IsActive, UserType "
        f"FROM User WHERE Username='{_soql_escape(raw)}' LIMIT 1",
    )
    if not row:
        raise RuntimeError(f"User not found: {user_input}")
    return row


def _resolve_object_from_record_id(client: Any, record_id: str) -> str:
    prefix = (record_id or "").strip()[:3]
    if len(prefix) != 3:
        raise RuntimeError(f"Invalid record id: {record_id}")
    row = _query_one(
        client,
        "SELECT QualifiedApiName, KeyPrefix "
        f"FROM EntityDefinition WHERE KeyPrefix='{_soql_escape(prefix)}' LIMIT 1",
    )
    if not row:
        raise RuntimeError(f"Could not resolve object from record id prefix: {prefix}")
    return str(row.get("QualifiedApiName") or "")


def _fetch_record_owner(client: Any, object_api: str, record_id: str) -> tuple[str | None, str | None]:
    rec = _query_one(
        client,
        f"SELECT Id, OwnerId FROM {object_api} WHERE Id='{_soql_escape(record_id)}' LIMIT 1",
    )
    if not rec:
        return None, None
    owner_id = rec.get("OwnerId")
    if not owner_id:
        return None, None
    owner = _query_one(
        client,
        f"SELECT Id, UserRoleId FROM User WHERE Id='{_soql_escape(str(owner_id))}' LIMIT 1",
    )
    return str(owner_id), (str(owner.get("UserRoleId")) if owner and owner.get("UserRoleId") else None)


def _fetch_profile_name(client: Any, profile_id: str | None) -> str | None:
    if not profile_id:
        return None
    row = _query_one(client, f"SELECT Id, Name FROM Profile WHERE Id='{_soql_escape(profile_id)}' LIMIT 1")
    return str(row.get("Name")) if row and row.get("Name") else None


def _fetch_permset_assignments(client: Any, user_id: str) -> list[dict[str, Any]]:
    return _query(
        client,
        "SELECT PermissionSetId, PermissionSet.Name, PermissionSet.IsOwnedByProfile "
        f"FROM PermissionSetAssignment WHERE AssigneeId='{_soql_escape(user_id)}'",
    )


def _merge_object_permissions(
    client: Any,
    *,
    object_api: str,
    profile_id: str | None,
    permset_ids: list[str],
) -> tuple[ObjectAccess, dict[str, list[str]]]:
    access = ObjectAccess(object_name=object_api)
    sources: dict[str, list[str]] = {
        "can_read": [],
        "can_create": [],
        "can_edit": [],
        "can_delete": [],
        "view_all": [],
        "modify_all": [],
    }
    parent_ids = [x for x in [profile_id, *permset_ids] if x]
    if not parent_ids:
        return access, sources
    in_clause = ",".join(f"'{_soql_escape(pid)}'" for pid in parent_ids)
    rows = _query(
        client,
        "SELECT ParentId, SObjectType, PermissionsRead, PermissionsEdit, PermissionsDelete, "
        "PermissionsCreate, PermissionsViewAllRecords, PermissionsModifyAllRecords "
        "FROM ObjectPermissions "
        f"WHERE SObjectType='{_soql_escape(object_api)}' AND ParentId IN ({in_clause})",
    )
    for row in rows:
        parent = str(row.get("ParentId") or "")
        if bool(row.get("PermissionsRead")) and not access.can_read:
            access.can_read = True
            sources["can_read"].append(parent)
        if bool(row.get("PermissionsCreate")) and not access.can_create:
            access.can_create = True
            sources["can_create"].append(parent)
        if bool(row.get("PermissionsEdit")) and not access.can_edit:
            access.can_edit = True
            sources["can_edit"].append(parent)
        if bool(row.get("PermissionsDelete")) and not access.can_delete:
            access.can_delete = True
            sources["can_delete"].append(parent)
        if bool(row.get("PermissionsViewAllRecords")) and not access.view_all:
            access.view_all = True
            sources["view_all"].append(parent)
        if bool(row.get("PermissionsModifyAllRecords")) and not access.modify_all:
            access.modify_all = True
            sources["modify_all"].append(parent)
    return access, sources


def _fetch_group_ids(client: Any, user_id: str) -> list[str]:
    rows = _query(
        client,
        f"SELECT GroupId FROM GroupMember WHERE UserOrGroupId='{_soql_escape(user_id)}'",
    )
    return [str(r.get("GroupId")) for r in rows if r.get("GroupId")]


def _fetch_shares(client: Any, object_api: str, record_id: str) -> list[ShareRow]:
    share_object = f"{object_api.replace('__c', '__Share')}" if object_api.endswith("__c") else f"{object_api}Share"
    try:
        rows = _query(
            client,
            f"SELECT Id, UserOrGroupId, AccessLevel, RowCause FROM {share_object} "
            f"WHERE ParentId='{_soql_escape(record_id)}'",
        )
    except Exception:
        return []
    out: list[ShareRow] = []
    for r in rows:
        if not r.get("UserOrGroupId"):
            continue
        out.append(
            ShareRow(
                user_or_group_id=str(r.get("UserOrGroupId")),
                access_level=str(r.get("AccessLevel")) if r.get("AccessLevel") else None,
                row_cause=str(r.get("RowCause")) if r.get("RowCause") else None,
            )
        )
    return out


def _fetch_teams(client: Any, object_api: str, record_id: str) -> list[TeamMember]:
    out: list[TeamMember] = []
    team_object = None
    where_field = None
    if object_api == "Account":
        team_object, where_field = "AccountTeamMember", "AccountId"
    elif object_api == "Opportunity":
        team_object, where_field = "OpportunityTeamMember", "OpportunityId"
    if not team_object:
        return out
    try:
        rows = _query(
            client,
            f"SELECT UserId, TeamMemberRole FROM {team_object} "
            f"WHERE {where_field}='{_soql_escape(record_id)}'",
        )
    except Exception:
        return out
    for r in rows:
        if not r.get("UserId"):
            continue
        out.append(
            TeamMember(
                user_id=str(r.get("UserId")),
                access_level=None,
                team_type=str(r.get("TeamMemberRole")) if r.get("TeamMemberRole") else None,
            )
        )
    return out


def _fetch_role_hierarchy_grant(client: Any, *, user_role_id: str | None, owner_role_id: str | None) -> bool:
    if not user_role_id or not owner_role_id:
        return False
    if user_role_id == owner_role_id:
        return True
    rows = _query(client, "SELECT Id, ParentRoleId FROM UserRole")
    parent_by_id = {str(r.get("Id")): (str(r.get("ParentRoleId")) if r.get("ParentRoleId") else None) for r in rows}
    current = owner_role_id
    seen: set[str] = set()
    while current and current not in seen:
        seen.add(current)
        current = parent_by_id.get(current)
        if current == user_role_id:
            return True
    return False


def build_access_bundle_from_org(client: Any, *, user_input: str, record_id: str) -> AccessBundle:
    user_row = _resolve_user(client, user_input)
    user_id = str(user_row.get("Id") or "")
    profile_id = str(user_row.get("ProfileId") or "") if user_row.get("ProfileId") else None
    user_role_id = str(user_row.get("UserRoleId") or "") if user_row.get("UserRoleId") else None

    object_api = _resolve_object_from_record_id(client, record_id)
    owner_id, owner_role_id = _fetch_record_owner(client, object_api, record_id)
    profile_name = _fetch_profile_name(client, profile_id)
    assignments = _fetch_permset_assignments(client, user_id)
    permset_ids = [str(r.get("PermissionSetId")) for r in assignments if r.get("PermissionSetId")]
    object_access, object_access_sources = _merge_object_permissions(
        client,
        object_api=object_api,
        profile_id=profile_id,
        permset_ids=permset_ids,
    )
    groups = _fetch_group_ids(client, user_id)
    shares = _fetch_shares(client, object_api, record_id)
    teams = _fetch_teams(client, object_api, record_id)
    in_hierarchy = _fetch_role_hierarchy_grant(client, user_role_id=user_role_id, owner_role_id=owner_role_id)

    bundle = AccessBundle(
        user=UserContext(
            user_id=user_id,
            username=str(user_row.get("Username") or ""),
            profile_name=profile_name,
            role_id=user_role_id,
            group_ids=groups,
        ),
        object_access=object_access,
        sharing_model=SharingModel(
            object_name=object_api,
            owd="Unknown",
            grant_using_hierarchy=True,
        ),
        record=RecordContext(
            record_id=record_id,
            object_name=object_api,
            owner_id=owner_id,
            owner_role_id=owner_role_id,
        ),
        shares=shares,
        teams=teams,
        in_role_hierarchy=in_hierarchy,
        extras={
            "profile_id": profile_id,
            "permset_assignments": assignments,
            "object_access_sources": object_access_sources,
            "owd_source": "unknown_runtime",
            "runtime_counts": {
                "permsets": len(assignments),
                "groups": len(groups),
                "shares": len(shares),
                "teams": len(teams),
            },
        },
    )
    # Ensure bundle is fully serializable by normalizing dataclass-heavy rows.
    bundle.extras["object_access"] = asdict(object_access)
    return bundle
