from __future__ import annotations

from pathlib import Path
from typing import List

from lxml import etree

from metadata.metadata_types import MetadataDoc, make_doc_id


def parse_fields(dir_path: Path) -> List[MetadataDoc]:
    docs: List[MetadataDoc] = []
    for path in dir_path.rglob('*.field-meta.xml'):
        object_name = path.parent.parent.name
        field_name = path.name.removesuffix('.field-meta.xml')
        field_api = f'{object_name}.{field_name}'
        try:
            root = etree.parse(str(path)).getroot()
            label = root.findtext('{*}label') or field_name
            field_type = root.findtext('{*}type') or ''
            description = root.findtext('{*}description') or ''
            formula = root.findtext('{*}formula') or ''
            relationship = ', '.join(v.text.strip() for v in root.findall('.//{*}referenceTo') if v.text)
            text = (
                f'Field {field_api}\n'
                f'Label: {label}\n'
                f'Type: {field_type}\n'
                f'Description: {description}\n'
                f'ReferenceTo: {relationship}\n'
                f'Formula: {formula}'
            ).strip()
        except Exception:
            text = f'Field {field_api}\nPath: {path}'
        docs.append(
            MetadataDoc(
                doc_id=make_doc_id('Field', field_api),
                kind='Field',
                name=field_api,
                path=str(path),
                text=text,
            )
        )
    return docs
