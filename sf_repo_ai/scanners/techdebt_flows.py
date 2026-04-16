from __future__ import annotations

import xml.etree.ElementTree as ET
from pathlib import Path

from sf_repo_ai.util import xml_local_name


def generate_flow_techdebt(repo_root: Path, sfdx_root: str) -> dict:
    flows_dir = repo_root / sfdx_root / "flows"
    rows: list[dict] = []

    if flows_dir.exists():
        for path in flows_dir.glob("*.flow-meta.xml"):
            try:
                tree = ET.parse(path)
                root = tree.getroot()
            except Exception:
                continue

            element_count = 0
            decision_count = 0
            update_count = 0
            fault_paths = 0

            for elem in root.iter():
                if elem is root:
                    continue
                element_count += 1
                tag = xml_local_name(elem.tag).lower()
                if "decision" in tag:
                    decision_count += 1
                if "updaterecord" in tag or "recordupdate" in tag:
                    update_count += 1
                if "faultconnector" in tag:
                    fault_paths += 1
                for k, v in elem.attrib.items():
                    if "fault" in k.lower() or "fault" in (v or "").lower():
                        fault_paths += 1

            rows.append(
                {
                    "flow_name": path.name.replace(".flow-meta.xml", ""),
                    "path": path.as_posix(),
                    "element_count": element_count,
                    "decision_count": decision_count,
                    "update_count": update_count,
                    "fault_paths_count": fault_paths,
                }
            )

    top_by_elements = sorted(rows, key=lambda r: r["element_count"], reverse=True)[:20]

    return {
        "total_flows_scanned": len(rows),
        "top_20_by_element_count": top_by_elements,
    }
