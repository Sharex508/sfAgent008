from __future__ import annotations

from pathlib import Path
from typing import Iterable, List
from lxml import etree

from metadata.metadata_types import MetadataDoc, make_doc_id


def _clean_text(s: str | None) -> str:
    return (s or "").strip()


def parse_object_file(path: Path) -> List[MetadataDoc]:
    """
    Parse a Salesforce CustomObject metadata file (*.object-meta.xml) and emit:
      - one Object doc
      - one Field doc per <fields> entry
    """
    docs: List[MetadataDoc] = []
    tree = etree.parse(str(path))
    root = tree.getroot()

    nsmap = root.nsmap or {}

    # Object API name derives from filename before .object-meta.xml
    object_name = path.name.split(".object-meta.xml")[0]

    # Best-effort: read label and description
    label = root.findtext("{*}label") or object_name
    description = root.findtext("{*}description") or ""
    text = f"Object {object_name}\nLabel: {label}\nDescription: {description}".strip()

    obj_doc = MetadataDoc(
        doc_id=make_doc_id("Object", object_name),
        kind="Object",
        name=object_name,
        path=str(path),
        text=text,
    )
    docs.append(obj_doc)

    # Fields
    for f in root.findall("{*}fields"):
        field_fullname = f.findtext("{*}fullName")
        field_label = f.findtext("{*}label") or field_fullname or ""
        field_desc = f.findtext("{*}description") or ""
        if not field_fullname:
            continue
        # Field API names are like Field__c; compose Object.Field for matching
        field_api = f"{object_name}.{field_fullname}"
        ftext = f"Field {field_api}\nLabel: {field_label}\nDescription: {field_desc}"
        docs.append(
            MetadataDoc(
                doc_id=make_doc_id("Field", field_api),
                kind="Field",
                name=field_api,
                path=str(path),
                text=ftext,
            )
        )

    return docs


def parse_objects(dir_path: Path) -> List[MetadataDoc]:
    docs: List[MetadataDoc] = []
    for p in dir_path.rglob("*.object-meta.xml"):
        docs.extend(parse_object_file(p))
    return docs
