from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List, Optional

from lxml import etree

from metadata.metadata_types import MetadataDoc, make_doc_id


def _split_process_name(file_name: str) -> tuple[str, str]:
    # Example: Case.CONTAINER_Service_Case_Approval_Process.approvalProcess-meta.xml
    base = file_name.replace(".approvalProcess-meta.xml", "")
    if "." in base:
        obj, dev_name = base.split(".", 1)
        return obj, dev_name
    return "UnknownObject", base


def _clean(s: Optional[str]) -> str:
    return (s or "").strip()


def _collect_actions(root) -> List[Dict[str, str]]:
    actions: List[Dict[str, str]] = []

    top_level = (
        "initialSubmissionActions",
        "finalApprovalActions",
        "finalRejectionActions",
        "recallActions",
    )
    for scope in top_level:
        for el in root.findall(f"{{*}}{scope}/{{*}}action"):
            name = _clean(el.findtext("{*}name"))
            action_type = _clean(el.findtext("{*}type"))
            if name:
                actions.append({"scope": scope, "name": name, "type": action_type})

    for step in root.findall("{*}approvalStep"):
        step_name = _clean(step.findtext("{*}name")) or _clean(step.findtext("{*}label")) or "approval_step"
        for scope in ("approvalActions", "rejectionActions"):
            for el in step.findall(f"{{*}}{scope}/{{*}}action"):
                name = _clean(el.findtext("{*}name"))
                action_type = _clean(el.findtext("{*}type"))
                if name:
                    actions.append(
                        {
                            "scope": f"step:{step_name}:{scope}",
                            "name": name,
                            "type": action_type,
                        }
                    )
    return actions


def parse_approval_process_file(path: Path) -> MetadataDoc:
    tree = etree.parse(str(path))
    root = tree.getroot()

    object_api_name, developer_name = _split_process_name(path.name)
    process_name = f"{object_api_name}.{developer_name}"

    label = _clean(root.findtext("{*}label")) or developer_name
    description = _clean(root.findtext("{*}description"))
    active = _clean(root.findtext("{*}active")).lower() == "true"

    email_templates = sorted(
        {
            _clean(el.text)
            for el in root.findall(".//{*}emailTemplate")
            if _clean(el.text)
        }
    )
    allowed_submitters = sorted(
        {
            _clean(el.text)
            for el in root.findall("{*}allowedSubmitters/{*}type")
            if _clean(el.text)
        }
    )

    approver_refs: List[Dict[str, str]] = []
    for approver in root.findall(".//{*}assignedApprover/{*}approver"):
        name = _clean(approver.findtext("{*}name"))
        approver_type = _clean(approver.findtext("{*}type")) or "unknown"
        if name:
            approver_refs.append({"type": approver_type, "name": name})

    criteria_fields = sorted(
        {
            _clean(el.text)
            for el in root.findall(".//{*}criteriaItems/{*}field")
            if _clean(el.text)
        }
    )

    actions = _collect_actions(root)

    step_summaries: List[Dict[str, str]] = []
    for step in root.findall("{*}approvalStep"):
        step_name = _clean(step.findtext("{*}name"))
        step_label = _clean(step.findtext("{*}label"))
        desc = _clean(step.findtext("{*}description"))
        step_summaries.append(
            {
                "name": step_name,
                "label": step_label,
                "description": desc,
            }
        )

    approver_text = ", ".join([f"{a.get('type', '')}:{a.get('name', '')}" for a in approver_refs])
    action_text = ", ".join([f"{a.get('scope', '')}:{a.get('type', '')}:{a.get('name', '')}" for a in actions])
    step_text = ", ".join([s.get("name") or s.get("label") or "" for s in step_summaries])

    lines = [
        f"ApprovalProcess {process_name}",
        f"Label: {label}",
        f"Object: {object_api_name}",
        f"Active: {active}",
        f"Description: {description}",
        f"Allowed Submitters: {', '.join(allowed_submitters)}",
        f"Email Templates: {', '.join(email_templates)}",
        f"Criteria Fields: {', '.join(criteria_fields)}",
        f"Approvers: {approver_text}",
        f"Actions: {action_text}",
        f"Steps: {step_text}",
    ]
    text = "\n".join(lines)

    raw = json.dumps(
        {
            "object_api_name": object_api_name,
            "developer_name": developer_name,
            "label": label,
            "active": active,
            "description": description,
            "allowed_submitters": allowed_submitters,
            "email_templates": email_templates,
            "criteria_fields": criteria_fields,
            "approver_refs": approver_refs,
            "actions": actions,
            "steps": step_summaries,
        },
        ensure_ascii=False,
    )

    return MetadataDoc(
        doc_id=make_doc_id("ApprovalProcess", process_name),
        kind="ApprovalProcess",
        name=process_name,
        path=str(path),
        text=text,
        raw_snippet=raw,
    )


def parse_approval_processes(dir_path: Path) -> List[MetadataDoc]:
    docs: List[MetadataDoc] = []
    for p in dir_path.rglob("*.approvalProcess-meta.xml"):
        docs.append(parse_approval_process_file(p))
    return docs
