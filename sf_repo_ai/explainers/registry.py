from __future__ import annotations

from typing import Any

from .base import ExplainerAdapter
from .adapters import (
    ApexClassExplainer,
    ApprovalProcessExplainer,
    AuthProviderExplainer,
    ConnectedAppExplainer,
    CspCorsExplainer,
    FlexipageExplainer,
    FlowExplainer,
    GenericMetadataExplainer,
    LayoutExplainer,
    LWCExplainer,
    PermissionSurfaceExplainer,
    QuickActionExplainer,
    SharingRulesExplainer,
    TriggerExplainer,
    ValidationRuleExplainer,
)


FLOW = FlowExplainer()
APEX = ApexClassExplainer()
TRIGGER = TriggerExplainer()
LWC = LWCExplainer()
PERM = PermissionSurfaceExplainer()
SHARING = SharingRulesExplainer()
APPROVAL = ApprovalProcessExplainer()
VR = ValidationRuleExplainer()
LAYOUT = LayoutExplainer()
FLEXIPAGE = FlexipageExplainer()
QUICKACTION = QuickActionExplainer()
CONNECTED = ConnectedAppExplainer()
AUTH = AuthProviderExplainer()
CSP_CORS = CspCorsExplainer()
GENERIC = GenericMetadataExplainer()

_TYPE_MAP: dict[str, ExplainerAdapter] = {
    "flow": FLOW,
    "apexclass": APEX,
    "trigger": TRIGGER,
    "lwc": LWC,
    "permissionset/profile": PERM,
    "permissionset": PERM,
    "profile": PERM,
    "sharingrule": SHARING,
    "approvalprocess": APPROVAL,
    "validationrule": VR,
    "layout": LAYOUT,
    "flexipage": FLEXIPAGE,
    "quickaction": QUICKACTION,
    "connectedapp": CONNECTED,
    "authprovider": AUTH,
}

_FOLDER_MAP: dict[str, ExplainerAdapter] = {
    "flows": FLOW,
    "classes": APEX,
    "triggers": TRIGGER,
    "lwc": LWC,
    "permissionsets": PERM,
    "profiles": PERM,
    "sharingrules": SHARING,
    "approvalprocesses": APPROVAL,
    "validationrules": VR,
    "layouts": LAYOUT,
    "flexipages": FLEXIPAGE,
    "quickactions": QUICKACTION,
    "connectedapps": CONNECTED,
    "authproviders": AUTH,
    "csptrustedsites": CSP_CORS,
    "corswhitelistorigins": CSP_CORS,
    "remotesitesettings": CSP_CORS,
}


def get_explainer(resolved: dict[str, Any]) -> ExplainerAdapter:
    t = str(resolved.get("resolved_type") or "").strip().lower()
    if t in _TYPE_MAP:
        return _TYPE_MAP[t]
    folder = str(resolved.get("metadata_folder") or "").strip().lower()
    if folder in _FOLDER_MAP:
        return _FOLDER_MAP[folder]

    raw = str(resolved.get("raw_target") or "").lower()
    if "sharing rule" in raw or "sharing rules" in raw:
        return SHARING
    if "approval process" in raw:
        return APPROVAL
    if "validation rule" in raw:
        return VR
    if "layout" in raw:
        return LAYOUT
    if "flexipage" in raw:
        return FLEXIPAGE
    if "lwc" in raw:
        return LWC
    if "connected app" in raw:
        return CONNECTED

    return GENERIC
