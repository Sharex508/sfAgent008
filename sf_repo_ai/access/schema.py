from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class UserContext:
    user_id: str
    username: str | None = None
    profile_name: str | None = None
    role_id: str | None = None
    group_ids: list[str] = field(default_factory=list)


@dataclass
class ObjectAccess:
    object_name: str
    can_read: bool = False
    can_create: bool = False
    can_edit: bool = False
    can_delete: bool = False
    view_all: bool = False
    modify_all: bool = False


@dataclass
class SharingModel:
    object_name: str
    owd: str = "Private"
    grant_using_hierarchy: bool = True


@dataclass
class RecordContext:
    record_id: str
    object_name: str
    owner_id: str | None = None
    owner_role_id: str | None = None


@dataclass
class ShareRow:
    user_or_group_id: str
    access_level: str | None = None
    row_cause: str | None = None


@dataclass
class TeamMember:
    user_id: str
    access_level: str | None = None
    team_type: str | None = None


@dataclass
class AccessBundle:
    user: UserContext
    object_access: ObjectAccess
    sharing_model: SharingModel
    record: RecordContext
    shares: list[ShareRow] = field(default_factory=list)
    teams: list[TeamMember] = field(default_factory=list)
    in_role_hierarchy: bool = False
    extras: dict[str, Any] = field(default_factory=dict)

    @staticmethod
    def from_dict(data: dict[str, Any]) -> "AccessBundle":
        user = data.get("user") or {}
        obj = data.get("object_access") or data.get("objectAccess") or {}
        sharing = data.get("sharing_model") or data.get("sharingModel") or {}
        record = data.get("record") or {}
        shares = data.get("shares") or []
        teams = data.get("teams") or data.get("team_members") or []
        extras = data.get("extras") or {}
        return AccessBundle(
            user=UserContext(
                user_id=str(user.get("user_id") or user.get("id") or ""),
                username=user.get("username"),
                profile_name=user.get("profile_name") or user.get("profile"),
                role_id=user.get("role_id") or user.get("roleId"),
                group_ids=[str(x) for x in (user.get("group_ids") or user.get("groupIds") or [])],
            ),
            object_access=ObjectAccess(
                object_name=str(obj.get("object_name") or obj.get("object") or ""),
                can_read=bool(obj.get("can_read") or obj.get("read") or obj.get("allowRead")),
                can_create=bool(obj.get("can_create") or obj.get("create") or obj.get("allowCreate")),
                can_edit=bool(obj.get("can_edit") or obj.get("edit") or obj.get("allowEdit")),
                can_delete=bool(obj.get("can_delete") or obj.get("delete") or obj.get("allowDelete")),
                view_all=bool(obj.get("view_all") or obj.get("viewAll") or obj.get("viewAllRecords")),
                modify_all=bool(obj.get("modify_all") or obj.get("modifyAll") or obj.get("modifyAllRecords")),
            ),
            sharing_model=SharingModel(
                object_name=str(sharing.get("object_name") or sharing.get("object") or obj.get("object_name") or ""),
                owd=str(sharing.get("owd") or sharing.get("default") or "Private"),
                grant_using_hierarchy=bool(sharing.get("grant_using_hierarchy", sharing.get("grantUsingHierarchy", True))),
            ),
            record=RecordContext(
                record_id=str(record.get("record_id") or record.get("id") or ""),
                object_name=str(record.get("object_name") or record.get("object") or obj.get("object_name") or ""),
                owner_id=record.get("owner_id") or record.get("ownerId"),
                owner_role_id=record.get("owner_role_id") or record.get("ownerRoleId"),
            ),
            shares=[
                ShareRow(
                    user_or_group_id=str(x.get("user_or_group_id") or x.get("userOrGroupId") or ""),
                    access_level=x.get("access_level") or x.get("accessLevel"),
                    row_cause=x.get("row_cause") or x.get("rowCause"),
                )
                for x in shares
                if isinstance(x, dict)
            ],
            teams=[
                TeamMember(
                    user_id=str(x.get("user_id") or x.get("userId") or ""),
                    access_level=x.get("access_level") or x.get("accessLevel"),
                    team_type=x.get("team_type") or x.get("teamType"),
                )
                for x in teams
                if isinstance(x, dict)
            ],
            in_role_hierarchy=bool(data.get("in_role_hierarchy") or data.get("inRoleHierarchy")),
            extras=extras if isinstance(extras, dict) else {},
        )


@dataclass
class AccessReport:
    decision: str
    object_gate: str
    record_gate: str
    reasons: list[str]
    suggested_fixes: list[dict[str, Any]]
    evidence_used: dict[str, Any]
    metadata_context: dict[str, Any] = field(default_factory=dict)
