from __future__ import annotations

from pathlib import Path
from typing import Iterable, List, Set

from metadata.metadata_types import MetadataDoc, make_doc_id

IGNORED_DIRS = {'.git', '.sfdx', '.sf', '__pycache__'}
IGNORED_TOP_LEVEL = {'lwc', 'aura', 'classes', 'triggers', 'flows', 'profiles', 'permissionsets'}
IGNORED_SUFFIXES = {
    '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.ico', '.pdf', '.zip', '.jar', '.woff', '.woff2', '.ttf', '.eot', '.mp4', '.mp3', '.mov', '.avi', '.exe', '.dll', '.so', '.dylib', '.bin'
}
KIND_MAP = {
    'approvalProcesses': 'ApprovalProcess',
    'layouts': 'Layout',
    'customMetadata': 'CustomMetadata',
    'flexipages': 'FlexiPage',
    'quickActions': 'QuickAction',
    'labels': 'Label',
    'applications': 'Application',
    'tabs': 'Tab',
    'pages': 'VisualforcePage',
    'workflows': 'Workflow',
    'weblinks': 'WebLink',
    'namedCredentials': 'NamedCredential',
    'staticresources': 'StaticResource',
    'components': 'VisualforceComponent',
    'reports': 'Report',
    'dashboards': 'Dashboard',
    'customPermissions': 'CustomPermission',
    'permissionsetgroups': 'PermissionSetGroup',
    'sharingRules': 'SharingRule',
    'queues': 'Queue',
    'roles': 'Role',
    'groups': 'Group',
    'translations': 'Translation',
    'globalValueSets': 'GlobalValueSet',
    'standardValueSets': 'StandardValueSet',
    'remoteSiteSettings': 'RemoteSiteSetting',
    'communities': 'Community',
    'settings': 'Setting',
    'sites': 'Site',
    'certs': 'Cert',
    'emailservices': 'EmailService',
    'email': 'EmailTemplate',
    'digitalExperiences': 'DigitalExperience',
}
OBJECT_CHILD_KIND_MAP = {
    'fields': 'Field',
    'recordTypes': 'RecordType',
    'validationRules': 'ValidationRule',
    'listViews': 'ListView',
    'compactLayouts': 'CompactLayout',
    'businessProcesses': 'BusinessProcess',
    'fieldSets': 'FieldSet',
    'sharingReasons': 'SharingReason',
    'webLinks': 'WebLink',
    'searchLayouts': 'SearchLayout',
    'namedFilters': 'NamedFilter',
    'indexes': 'Index',
}


def _infer_kind(relative: Path) -> str:
    if len(relative.parts) >= 3 and relative.parts[0] == 'objects':
        child = relative.parts[2]
        if child in OBJECT_CHILD_KIND_MAP:
            return OBJECT_CHILD_KIND_MAP[child]
    top = relative.parts[0] if relative.parts else 'Metadata'
    if top in KIND_MAP:
        return KIND_MAP[top]
    cleaned = top[:-3] + 'y' if top.endswith('ies') else (top.rstrip('s') if top.endswith('s') else top)
    return cleaned[:1].upper() + cleaned[1:]


def _strip_known_suffix(name: str) -> str:
    for suffix in [
        '.approvalProcess-meta.xml',
        '.layout-meta.xml',
        '.md-meta.xml',
        '.flexipage-meta.xml',
        '.quickAction-meta.xml',
        '.tab-meta.xml',
        '.app-meta.xml',
        '.page-meta.xml',
        '.component-meta.xml',
        '.workflow-meta.xml',
        '.labels-meta.xml',
        '.resource-meta.xml',
        '.report-meta.xml',
        '.dashboard-meta.xml',
        '.permissionsetgroup-meta.xml',
        '.sharingRules-meta.xml',
        '.queue-meta.xml',
        '.role-meta.xml',
        '.group-meta.xml',
        '.translation-meta.xml',
        '.globalValueSet-meta.xml',
        '.standardValueSet-meta.xml',
        '.remoteSite-meta.xml',
        '.field-meta.xml',
        '.meta.xml',
        '.xml',
    ]:
        if name.endswith(suffix):
            return name[: -len(suffix)]
    return name


def _infer_name(relative: Path) -> str:
    first = relative.parts[0] if relative.parts else ''
    if len(relative.parts) >= 4 and first == 'objects':
        object_name = relative.parts[1]
        child_name = _strip_known_suffix(relative.name)
        return f'{object_name}.{child_name}'
    name = _strip_known_suffix(relative.name)
    if first == 'labels':
        return 'CustomLabels'
    return '/'.join(relative.with_name(name).parts)


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding='utf-8', errors='ignore')
    except OSError:
        return ''


def parse_generic_inventory(root: Path, handled_paths: Iterable[str]) -> List[MetadataDoc]:
    docs: List[MetadataDoc] = []
    handled: Set[str] = {str(Path(p).resolve()) for p in handled_paths}
    root = Path(root).resolve()
    for path in root.rglob('*'):
        if not path.is_file():
            continue
        if any(part in IGNORED_DIRS for part in path.parts):
            continue
        if path.suffix.lower() in IGNORED_SUFFIXES:
            continue
        resolved = str(path.resolve())
        if resolved in handled:
            continue
        try:
            relative = path.relative_to(root)
        except ValueError:
            continue
        if relative.parts and relative.parts[0] in IGNORED_TOP_LEVEL:
            continue
        text = _read_text(path)
        if not text.strip():
            continue
        kind = _infer_kind(relative)
        name = _infer_name(relative)
        doc_text = f'{kind} {name}\nPath: {relative}\n{text}'.strip()
        docs.append(
            MetadataDoc(
                doc_id=make_doc_id(kind, name),
                kind=kind,
                name=name,
                path=str(path),
                text=doc_text,
            )
        )
    return docs
