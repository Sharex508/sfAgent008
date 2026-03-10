from __future__ import annotations

import hashlib
import json
from typing import Any, Dict, List


def _node(node_id: str, node_type: str, label: str, confidence: str = "HIGH") -> Dict[str, Any]:
    return {
        "id": node_id,
        "type": node_type,
        "label": label,
        "confidence": confidence,
    }


def build_trace_graph(parsed_logs: List[Dict[str, Any]]) -> Dict[str, Any]:
    nodes: Dict[str, Dict[str, Any]] = {}
    edges: List[Dict[str, Any]] = []
    entry_points: List[str] = []

    for item in parsed_logs:
        tx_id = f"TX:{item['log_id']}"
        nodes[tx_id] = _node(tx_id, "UI_TRANSACTION", item["log_id"], "HIGH")
        entry_points.append(item["log_id"])

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
    lines = [
        "# Process Capture Summary",
        "",
        f"- Logs analyzed: {total_logs}",
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
