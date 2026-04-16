from __future__ import annotations

import json
from pathlib import Path
from typing import List, Set
from lxml import etree

from metadata.metadata_types import MetadataDoc, make_doc_id


def parse_flow_file(path: Path) -> MetadataDoc:
    tree = etree.parse(str(path))
    root = tree.getroot()

    name = path.stem.split(".flow-meta")[0]
    label = root.findtext("{*}label") or name
    description = root.findtext("{*}description") or ""

    # Try to collect referenced objects from common tags
    object_tags = [
        "{*}object",
        "{*}sObject",
        "{*}targetObject",
        "{*}inputObject",
    ]
    objects: Set[str] = set()
    for tag in object_tags:
        for el in root.findall(f".//{tag}"):
            if el.text:
                objects.add(el.text.strip())

    text = f"Flow {label} ({name})\nDescription: {description}\nObjects: {', '.join(sorted(objects))}"
    raw = json.dumps({"objects": sorted(objects)})

    return MetadataDoc(
        doc_id=make_doc_id("Flow", name),
        kind="Flow",
        name=name,
        path=str(path),
        text=text,
        raw_snippet=raw,
    )


def parse_flows(dir_path: Path) -> List[MetadataDoc]:
    docs: List[MetadataDoc] = []
    for p in dir_path.rglob("*.flow-meta.xml"):
        docs.append(parse_flow_file(p))
    return docs
