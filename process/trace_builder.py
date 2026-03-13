from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from typing import Any, Dict, List


def _node(node_id: str, node_type: str, label: str, confidence: str = "HIGH") -> Dict[str, Any]:
    return {
        "id": node_id,
        "type": node_type,
        "label": label,
        "confidence": confidence,
    }


def _parse_ts(value: str) -> datetime:
    raw = (value or "").strip()
    if not raw:
        return datetime.min.replace(tzinfo=timezone.utc)
    candidates = [raw]
    if raw.endswith("Z"):
        candidates.append(raw.replace("Z", "+00:00"))
    if len(raw) > 5 and raw[-5] in {"+", "-"} and raw[-3] != ":":
        candidates.append(f"{raw[:-2]}:{raw[-2:]}")
    for candidate in candidates:
        try:
            dt = datetime.fromisoformat(candidate)
            if dt.tzinfo is None:
                return dt.replace(tzinfo=timezone.utc)
            return dt.astimezone(timezone.utc)
        except ValueError:
            continue
    return datetime.min.replace(tzinfo=timezone.utc)


def build_trace_graph(parsed_logs: List[Dict[str, Any]], ui_events: List[Dict[str, Any]] | None = None) -> Dict[str, Any]:
    nodes: Dict[str, Dict[str, Any]] = {}
    edges: List[Dict[str, Any]] = []
    entry_points: List[str] = []
    ui_events = ui_events or []
    tx_items: List[Dict[str, Any]] = []

    for item in ui_events:
        event_id = str(item.get("event_id") or "")
        event_type = str(item.get("event_type") or "UI_EVENT")
        component_name = str(item.get("component_name") or "").strip()
        action_name = str(item.get("action_name") or "").strip()
        element_label = str(item.get("element_label") or "").strip()
        record_id = str(item.get("record_id") or "").strip()
        page_url = str(item.get("page_url") or "").strip()
        label_bits = [component_name or event_type]
        if action_name:
            label_bits.append(action_name)
        if element_label:
            label_bits.append(element_label)

        ui_id = f"UI:{event_id}"
        nodes[ui_id] = _node(ui_id, "UI_EVENT", " | ".join(label_bits), "HIGH")
        entry_points.append(ui_id)

        if component_name:
            component_id = f"LWC:{component_name}"
            nodes.setdefault(component_id, _node(component_id, "LWC_COMPONENT", component_name, "HIGH"))
            edges.append(
                {
                    "from": ui_id,
                    "to": component_id,
                    "type": "UI_EVENT_ON_COMPONENT",
                    "confidence": "HIGH",
                }
            )

        if page_url:
            page_id = f"PAGE:{page_url}"
            nodes.setdefault(page_id, _node(page_id, "UI_PAGE", page_url, "MED"))
            edges.append(
                {
                    "from": ui_id,
                    "to": page_id,
                    "type": "UI_EVENT_ON_PAGE",
                    "confidence": "MED",
                }
            )

        if record_id:
            rec_id = f"RECORD:{record_id}"
            nodes.setdefault(rec_id, _node(rec_id, "SF_RECORD", record_id, "MED"))
            edges.append(
                {
                    "from": ui_id,
                    "to": rec_id,
                    "type": "UI_EVENT_TARGETS_RECORD",
                    "confidence": "MED",
                }
            )

    for item in parsed_logs:
        tx_id = f"TX:{item['log_id']}"
        nodes[tx_id] = _node(tx_id, "UI_TRANSACTION", item["log_id"], "HIGH")
        entry_points.append(item["log_id"])
        tx_items.append({"node_id": tx_id, "start_time": _parse_ts(str(item.get("start_time") or ""))})

        for frame in item.get("stack_frames", []):
            cls_id = f"APEX:{frame['class']}"
            nodes.setdefault(cls_id, _node(cls_id, "APEX_CLASS", frame["class"], "HIGH"))
            edges.append(
                {
                    "from": tx_id,
                    "to": cls_id,
                    "type": "TRANSACTION_CALLS_CLASS",
                    "confidence": "HIGH",
                }
            )

        for flow in item.get("flows", []):
            flow_id = f"FLOW:{flow}"
            nodes.setdefault(flow_id, _node(flow_id, "FLOW", flow, "MED"))
            edges.append(
                {
                    "from": tx_id,
                    "to": flow_id,
                    "type": "TRANSACTION_INVOLVES_FLOW",
                    "confidence": "MED",
                }
            )

        if item.get("has_approval_tokens"):
            ap_id = f"APPROVAL:{item['log_id']}"
            nodes.setdefault(ap_id, _node(ap_id, "APPROVAL_PROCESS", "Approval/ProcessInstance", "LOW"))
            edges.append(
                {
                    "from": tx_id,
                    "to": ap_id,
                    "type": "TRANSACTION_INVOLVES_APPROVAL",
                    "confidence": "LOW",
                }
            )

        for obj in item.get("objects", []):
            obj_id = f"DML:{obj}"
            nodes.setdefault(obj_id, _node(obj_id, "DML_OBJECT", obj, "MED"))
            if any(op in {"INSERT", "UPDATE", "UPSERT", "DELETE", "MERGE"} for op in item.get("dml_ops", [])):
                edges.append(
                    {
                        "from": tx_id,
                        "to": obj_id,
                        "type": "TRANSACTION_WRITES_OBJECT",
                        "confidence": "MED",
                    }
                )

        for url in item.get("callouts", []):
            ep_id = f"ENDPOINT:{url}"
            nodes.setdefault(ep_id, _node(ep_id, "CALLOUT_ENDPOINT", url, "HIGH"))
            edges.append(
                {
                    "from": tx_id,
                    "to": ep_id,
                    "type": "CLASS_CALLS_ENDPOINT",
                    "confidence": "HIGH",
                }
            )

    tx_items.sort(key=lambda x: x["start_time"])
    for item in ui_events:
        event_id = str(item.get("event_id") or "")
        if not event_id:
            continue
        event_dt = _parse_ts(str(item.get("event_ts") or ""))
        next_tx = next((tx for tx in tx_items if tx["start_time"] >= event_dt), None)
        if not next_tx:
            continue
        edges.append(
            {
                "from": f"UI:{event_id}",
                "to": next_tx["node_id"],
                "type": "UI_EVENT_PRECEDES_TRANSACTION",
                "confidence": "MED",
            }
        )

    graph = {
        "entry_points": sorted(set(entry_points)),
        "nodes": list(nodes.values()),
        "edges": edges,
    }
    return graph


def graph_hash(graph: Dict[str, Any]) -> str:
    payload = json.dumps(graph, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def build_mermaid_sequence(graph: Dict[str, Any]) -> str:
    lines = ["sequenceDiagram", "    actor User", "    participant SF as Salesforce UI"]

    tx_nodes = [n for n in graph["nodes"] if n["type"] == "UI_TRANSACTION"]
    for tx in tx_nodes:
        tx_alias = tx["id"].replace(":", "_")
        lines.append(f"    participant {tx_alias} as {tx['label'][:24]}")
        lines.append(f"    User->>SF: Run process")
        lines.append(f"    SF->>{tx_alias}: Transaction")

    for edge in graph["edges"]:
        src = edge["from"].replace(":", "_")
        dst = edge["to"].replace(":", "_")
        lines.append(f"    {src}->>{dst}: {edge['type']}")

    return "\n".join(lines) + "\n"


def build_mermaid_flow(graph: Dict[str, Any]) -> str:
    lines = ["flowchart TD"]
    for node in graph["nodes"]:
        node_id = node["id"].replace(":", "_").replace("-", "_")
        label = node["label"].replace('"', "'")
        lines.append(f"    {node_id}[\"{label}\"]")
    for edge in graph["edges"]:
        src = edge["from"].replace(":", "_").replace("-", "_")
        dst = edge["to"].replace(":", "_").replace("-", "_")
        lines.append(f"    {src} -->|{edge['type']}| {dst}")
    return "\n".join(lines) + "\n"


def summarize_trace(graph: Dict[str, Any], parsed_logs: List[Dict[str, Any]]) -> str:
    total_logs = len(parsed_logs)
    exceptions = sum(len(p.get("exceptions", [])) for p in parsed_logs)
    endpoints = sorted({u for p in parsed_logs for u in p.get("callouts", [])})
    flows = sorted({f for p in parsed_logs for f in p.get("flows", [])})
    ui_events = [n for n in graph.get("nodes", []) if n.get("type") == "UI_EVENT"]
    lines = [
        "# Process Capture Summary",
        "",
        f"- Logs analyzed: {total_logs}",
        f"- UI events captured: {len(ui_events)}",
        f"- Exceptions found: {exceptions}",
        f"- Flow references: {len(flows)}",
        f"- Callout endpoints: {len(endpoints)}",
        "",
        "## Entry Points",
    ]
    for ep in graph.get("entry_points", []):
        lines.append(f"- {ep}")
    if flows:
        lines.extend(["", "## Flows"])
        for f in flows:
            lines.append(f"- {f}")
    if endpoints:
        lines.extend(["", "## Callouts"])
        for e in endpoints:
            lines.append(f"- {e}")
    return "\n".join(lines) + "\n"
