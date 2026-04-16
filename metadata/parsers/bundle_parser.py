from __future__ import annotations

from pathlib import Path
from typing import List

from metadata.metadata_types import MetadataDoc, make_doc_id

TEXT_SUFFIXES = {'.js', '.html', '.css', '.xml', '.cmp', '.app', '.evt', '.auradoc', '.design', '.svg'}


def _read_bundle_text(bundle_dir: Path) -> str:
    sections: List[str] = []
    for path in sorted(bundle_dir.iterdir(), key=lambda p: p.name.lower()):
        if path.is_dir() or path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        try:
            content = path.read_text(encoding='utf-8', errors='ignore').strip()
        except OSError:
            continue
        if not content:
            continue
        sections.append(f'FILE: {path.name}\n{content}')
    return '\n\n'.join(sections)


def parse_lwc(dir_path: Path) -> List[MetadataDoc]:
    docs: List[MetadataDoc] = []
    if not dir_path.exists():
        return docs
    for bundle_dir in sorted([p for p in dir_path.iterdir() if p.is_dir()], key=lambda p: p.name.lower()):
        text = _read_bundle_text(bundle_dir)
        docs.append(
            MetadataDoc(
                doc_id=make_doc_id('LWC', bundle_dir.name),
                kind='LWC',
                name=bundle_dir.name,
                path=str(bundle_dir),
                text=f'LWC bundle {bundle_dir.name}\n{text}'.strip(),
            )
        )
    return docs


def parse_aura(dir_path: Path) -> List[MetadataDoc]:
    docs: List[MetadataDoc] = []
    if not dir_path.exists():
        return docs
    for bundle_dir in sorted([p for p in dir_path.iterdir() if p.is_dir()], key=lambda p: p.name.lower()):
        text = _read_bundle_text(bundle_dir)
        docs.append(
            MetadataDoc(
                doc_id=make_doc_id('Aura', bundle_dir.name),
                kind='Aura',
                name=bundle_dir.name,
                path=str(bundle_dir),
                text=f'Aura bundle {bundle_dir.name}\n{text}'.strip(),
            )
        )
    return docs
