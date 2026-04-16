from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import List, Set

from metadata.metadata_types import MetadataDoc
from metadata.parsers.apex_parser import parse_apex
from metadata.parsers.bundle_parser import parse_aura, parse_lwc
from metadata.parsers.fields_parser import parse_fields
from metadata.parsers.flows_parser import parse_flows
from metadata.parsers.generic_inventory_parser import parse_generic_inventory
from metadata.parsers.objects_parser import parse_objects
from metadata.parsers.security_parser import parse_security

DEFAULT_REPO = Path('./data/repo')


def _dedupe_docs(docs: List[MetadataDoc]) -> List[MetadataDoc]:
    seen_keys: Set[tuple[str, str, str]] = set()
    deduped: List[MetadataDoc] = []
    for doc in docs:
        key = (doc.kind, doc.name, doc.path)
        if key in seen_keys:
            continue
        seen_keys.add(key)
        deduped.append(doc)
    return deduped


def index_repo(repo_path: Path = DEFAULT_REPO) -> List[MetadataDoc]:
    repo_path = Path(repo_path)
    docs: List[MetadataDoc] = []

    candidates = [
        repo_path / 'force-app' / 'main' / 'default',
        repo_path / 'force-app',
        repo_path,
    ]
    root = next((c for c in candidates if c.exists()), repo_path)

    objects_root = root / 'objects'
    classes_root = root / 'classes'
    triggers_root = root / 'triggers'
    flows_root = root / 'flows'
    profiles_root = root / 'profiles'
    permsets_root = root / 'permissionsets'
    lwc_root = root / 'lwc'
    aura_root = root / 'aura'

    if objects_root.exists():
        docs.extend(parse_objects(objects_root))
        docs.extend(parse_fields(objects_root))
    else:
        docs.extend(parse_objects(root))
        docs.extend(parse_fields(root))

    if classes_root.exists():
        docs.extend(parse_apex(classes_root))
    if triggers_root.exists():
        docs.extend(parse_apex(triggers_root))
    if not classes_root.exists() and not triggers_root.exists():
        docs.extend(parse_apex(root))

    docs.extend(parse_flows(flows_root) if flows_root.exists() else parse_flows(root))

    if profiles_root.exists():
        docs.extend(parse_security(profiles_root))
    if permsets_root.exists():
        docs.extend(parse_security(permsets_root))
    if not profiles_root.exists() and not permsets_root.exists():
        docs.extend(parse_security(root))

    docs.extend(parse_lwc(lwc_root))
    docs.extend(parse_aura(aura_root))

    handled_paths = {doc.path for doc in docs}
    docs.extend(parse_generic_inventory(root, handled_paths))

    return _dedupe_docs(docs)


def write_jsonl(docs: List[MetadataDoc], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open('w', encoding='utf-8') as f:
        for d in docs:
            f.write(d.model_dump_json())
            f.write('\n')


def main():
    ap = argparse.ArgumentParser(description='Index Salesforce metadata into documents')
    ap.add_argument('--repo', type=Path, default=DEFAULT_REPO, help='Path to repo root')
    ap.add_argument('--out', type=Path, default=Path('./data/metadata/docs.jsonl'), help='Output JSONL path')
    args = ap.parse_args()

    docs = index_repo(args.repo)
    write_jsonl(docs, args.out)

    counts = {}
    for d in docs:
        counts[d.kind] = counts.get(d.kind, 0) + 1
    print(json.dumps({'total': len(docs), 'by_kind': counts}, indent=2))


if __name__ == '__main__':
    main()
