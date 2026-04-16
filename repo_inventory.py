from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List

IGNORED_DIRS = {'.git', '.sfdx', '.sf', '__pycache__'}
FOLDER_KIND_MAP = {
    'approvalProcesses': 'ApprovalProcess',
    'appMenus': 'AppMenu',
    'applications': 'CustomApplication',
    'assignmentRules': 'AssignmentRules',
    'aura': 'AuraDefinitionBundle',
    'authproviders': 'AuthProvider',
    'autoResponseRules': 'AutoResponseRules',
    'classes': 'ApexClass',
    'components': 'ApexComponent',
    'connectedApps': 'ConnectedApp',
    'contentassets': 'ContentAsset',
    'customMetadata': 'CustomMetadata',
    'customPermissions': 'CustomPermission',
    'dashboards': 'Dashboard',
    'digitalExperiences': 'ExperienceBundle',
    'duplicateRules': 'DuplicateRule',
    'email': 'EmailTemplate',
    'emailservices': 'EmailService',
    'escalationRules': 'EscalationRules',
    'externalCredentials': 'ExternalCredential',
    'flexipages': 'FlexiPage',
    'flows': 'Flow',
    'globalValueSets': 'GlobalValueSet',
    'globalValueSetTranslations': 'GlobalValueSetTranslation',
    'groups': 'Group',
    'labels': 'CustomLabels',
    'layouts': 'Layout',
    'letterhead': 'Letterhead',
    'lwc': 'LightningComponentBundle',
    'matchingRules': 'MatchingRule',
    'namedCredentials': 'NamedCredential',
    'navigationMenus': 'NavigationMenu',
    'networks': 'Network',
    'objects': 'CustomObject',
    'pages': 'ApexPage',
    'permissionsets': 'PermissionSet',
    'permissionsetgroups': 'PermissionSetGroup',
    'profiles': 'Profile',
    'quickActions': 'QuickAction',
    'queues': 'Queue',
    'remoteSiteSettings': 'RemoteSiteSetting',
    'reportTypes': 'ReportType',
    'reports': 'Report',
    'roles': 'Role',
    'sharingRules': 'SharingRules',
    'sharingSets': 'SharingSet',
    'sites': 'CustomSite',
    'siteDotComSites': 'SiteDotCom',
    'standardValueSets': 'StandardValueSet',
    'standardValueSetTranslations': 'StandardValueSetTranslation',
    'staticresources': 'StaticResource',
    'tabs': 'CustomTab',
    'territory2Models': 'Territory2Model',
    'territory2Types': 'Territory2Type',
    'testSuites': 'ApexTestSuite',
    'translations': 'Translations',
    'triggers': 'ApexTrigger',
    'weblinks': 'WebLink',
    'workflows': 'Workflow',
}
OBJECT_CHILD_KIND_MAP = {
    'fields': 'CustomField',
    'recordTypes': 'RecordType',
    'businessProcesses': 'BusinessProcess',
    'compactLayouts': 'CompactLayout',
    'fieldSets': 'FieldSet',
    'validationRules': 'ValidationRule',
    'listViews': 'ListView',
    'sharingReasons': 'SharingReason',
    'searchLayouts': 'SearchLayout',
    'webLinks': 'WebLink',
    'indexes': 'Index',
    'namedFilters': 'NamedFilter',
}


def detect_metadata_root(repo_path: Path) -> Path:
    repo_path = Path(repo_path).expanduser().resolve()
    candidates = [
        repo_path / 'force-app' / 'main' / 'default',
        repo_path / 'force-app',
        repo_path,
    ]
    return next((c for c in candidates if c.exists()), repo_path)


def _safe_dirs(path: Path) -> List[Path]:
    if not path.exists():
        return []
    return sorted([p for p in path.iterdir() if p.is_dir() and p.name not in IGNORED_DIRS], key=lambda p: p.name.lower())


def _safe_files(path: Path) -> List[Path]:
    if not path.exists():
        return []
    return sorted([p for p in path.iterdir() if p.is_file()], key=lambda p: p.name.lower())


def _count_files_recursive(path: Path) -> int:
    total = 0
    if not path.exists():
        return 0
    for item in path.rglob('*'):
        if any(part in IGNORED_DIRS for part in item.parts):
            continue
        if item.is_file():
            total += 1
    return total


def _folder_metadata_type(folder_name: str) -> str:
    if folder_name in FOLDER_KIND_MAP:
        return FOLDER_KIND_MAP[folder_name]
    if folder_name.endswith('ies'):
        cleaned = folder_name[:-3] + 'y'
    elif folder_name.endswith('s'):
        cleaned = folder_name[:-1]
    else:
        cleaned = folder_name
    return cleaned[:1].upper() + cleaned[1:]


def build_metadata_inventory(repo_path: Path) -> Dict[str, Any]:
    repo_path = Path(repo_path).expanduser().resolve()
    metadata_root = detect_metadata_root(repo_path)
    top_level: List[Dict[str, Any]] = []
    object_children: List[Dict[str, Any]] = []

    for folder in _safe_dirs(metadata_root):
        folder_files = _count_files_recursive(folder)
        dir_count = len(_safe_dirs(folder))
        top_level.append(
            {
                'folder': folder.name,
                'metadata_type': _folder_metadata_type(folder.name),
                'path': str(folder),
                'file_count': folder_files,
                'dir_count': dir_count,
            }
        )

    objects_dir = metadata_root / 'objects'
    if objects_dir.exists():
        child_counts: Dict[str, int] = {k: 0 for k in OBJECT_CHILD_KIND_MAP}
        for obj_dir in _safe_dirs(objects_dir):
            for child_name, metadata_type in OBJECT_CHILD_KIND_MAP.items():
                child_dir = obj_dir / child_name
                if not child_dir.exists() or not child_dir.is_dir():
                    continue
                child_counts[child_name] += len(_safe_files(child_dir))
        object_children = []
        for child_name, metadata_type in OBJECT_CHILD_KIND_MAP.items():
            count = child_counts.get(child_name, 0)
            if not count:
                continue
            object_children.append(
                {
                    'folder': child_name,
                    'metadata_type': metadata_type,
                    'count': count,
                }
            )

    present_types = sorted({item['metadata_type'] for item in top_level} | {item['metadata_type'] for item in object_children})
    total_files = sum(item['file_count'] for item in top_level)

    return {
        'generated_at': datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        'repo_path': str(repo_path),
        'metadata_root': str(metadata_root),
        'top_level_types': top_level,
        'object_child_types': object_children,
        'present_metadata_types': present_types,
        'metadata_type_count': len(present_types),
        'top_level_folder_count': len(top_level),
        'total_metadata_files': total_files,
    }


def write_metadata_inventory(inventory: Dict[str, Any], out_path: Path) -> Path:
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(inventory, indent=2), encoding='utf-8')
    return out_path


def load_metadata_inventory(path: Path) -> Dict[str, Any]:
    return json.loads(Path(path).read_text(encoding='utf-8'))


def validate_repo_structure(repo_path: Path) -> Dict[str, Any]:
    repo_path = Path(repo_path).expanduser().resolve()
    sfdx_project = repo_path / 'sfdx-project.json'
    metadata_root = detect_metadata_root(repo_path)
    objects_dir = metadata_root / 'objects'
    classes_dir = metadata_root / 'classes'
    flows_dir = metadata_root / 'flows'
    triggers_dir = metadata_root / 'triggers'
    template_marker = repo_path / '.sf_repo_template'
    has_force_app = (repo_path / 'force-app').exists()
    object_count = len([p for p in _safe_dirs(objects_dir)]) if objects_dir.exists() else 0
    class_count = len(list(classes_dir.glob('*.cls'))) if classes_dir.exists() else 0
    trigger_count = len(list(triggers_dir.glob('*.trigger'))) if triggers_dir.exists() else 0
    flow_count = len(list(flows_dir.glob('*.flow-meta.xml'))) if flows_dir.exists() else 0
    field_count = sum(len(list((obj_dir / 'fields').glob('*.field-meta.xml'))) for obj_dir in _safe_dirs(objects_dir) if (obj_dir / 'fields').exists()) if objects_dir.exists() else 0

    errors: List[str] = []
    if not repo_path.exists():
        errors.append('Repo path does not exist.')
    if not sfdx_project.exists():
        errors.append('Missing sfdx-project.json.')
    if not has_force_app:
        errors.append('Missing force-app directory.')
    has_metadata = object_count > 0 or class_count > 0 or flow_count > 0 or trigger_count > 0
    is_template = template_marker.exists() and sfdx_project.exists() and has_force_app and not has_metadata
    if not has_metadata and not is_template:
        errors.append('No Salesforce metadata detected under the expected SFDX structure.')

    return {
        'repo_path': str(repo_path),
        'repo_kind': 'sfdx',
        'has_sfdx_project': sfdx_project.exists(),
        'has_force_app': has_force_app,
        'metadata_root': str(metadata_root),
        'objects_count': object_count,
        'fields_count': field_count,
        'classes_count': class_count,
        'triggers_count': trigger_count,
        'flows_count': flow_count,
        'validation_status': 'TEMPLATE' if is_template else ('VALID' if not errors else 'INVALID'),
        'validation_error': None if is_template else (' | '.join(errors) if errors else None),
    }


def list_objects(repo_path: Path) -> List[Dict[str, Any]]:
    metadata_root = detect_metadata_root(repo_path)
    objects_dir = metadata_root / 'objects'
    results: List[Dict[str, Any]] = []
    if not objects_dir.exists():
        return results
    for obj_dir in _safe_dirs(objects_dir):
        fields_dir = obj_dir / 'fields'
        results.append(
            {
                'object_api_name': obj_dir.name,
                'path': str(obj_dir),
                'field_count': len(list(fields_dir.glob('*.field-meta.xml'))) if fields_dir.exists() else 0,
            }
        )
    return results


def list_fields(repo_path: Path, object_api_name: str) -> List[Dict[str, Any]]:
    metadata_root = detect_metadata_root(repo_path)
    fields_dir = metadata_root / 'objects' / object_api_name / 'fields'
    results: List[Dict[str, Any]] = []
    if not fields_dir.exists():
        return results
    for field_path in sorted(fields_dir.glob('*.field-meta.xml'), key=lambda p: p.name.lower()):
        results.append(
            {
                'field_api_name': field_path.name.removesuffix('.field-meta.xml'),
                'object_api_name': object_api_name,
                'path': str(field_path),
            }
        )
    return results
