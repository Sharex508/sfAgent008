from __future__ import annotations

import json
import os
from pathlib import Path
import re
from html import escape
from datetime import datetime, timezone
from typing import Any, Callable, Dict, List, Optional
import xml.etree.ElementTree as ET

from fastapi import FastAPI, HTTPException, Header, Security, Depends
from fastapi.responses import HTMLResponse
from fastapi.security import APIKeyHeader
from pydantic import BaseModel, Field

from agent.runtime import (
    ActionPlan,
    ToolCall,
    build_final_with_llm,
    build_plan_with_llm,
    execute_plan,
)
from llm.ollama_client import OllamaClient
from ingestion import RepoRegistry, register_and_sync_repo, sync_due_repos, sync_repo_by_id
from ingestion.bitbucket_auth import connection_status as bitbucket_connection_status, start_connect_flow as bitbucket_start_connect_flow, complete_connect_flow as bitbucket_complete_connect_flow
from ingestion.git_sync import probe_clone_access
from repo_inventory import build_metadata_inventory, list_fields, list_objects, load_metadata_inventory, validate_repo_structure, write_metadata_inventory
from orchestration import (
    GenerationResult,
    OrchestrationStore,
    apex_run_test,
    continue_environment_setup,
    default_project_dir,
    deploy_start,
    get_environment_setup_status,
    generate_or_update_components,
    list_orgs,
    retrieve_start,
    start_environment_setup,
)
from repo_index import ensure_indexes, ensure_runtime_indexes
from retrieval.vector_store import search_metadata
from repo_runtime import METADATA_INVENTORY_PATH, resolve_active_repo, set_active_repo
from sfdc.client import SalesforceClient
from server.repo_context import auto_context

API_KEY_NAME = "X-API-Key"
api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=False)
DEFAULT_DOCS_PATH = Path("./data/metadata/docs.jsonl")
DEFAULT_DB_PATH = Path("./data/chroma")
_INDEX_READY = False

def get_api_key(api_key: str = Security(api_key_header)):
    expected_key = os.getenv("AGENT_API_KEY")
    if expected_key and api_key != expected_key:
        raise HTTPException(status_code=403, detail="Could not validate API Key")
    return api_key


def _default_meta_root() -> Path:
    return resolve_active_repo() / "force-app" / "main" / "default"


def _require_non_empty_text(value: Optional[str], field_name: str) -> str:
    text = (value or "").strip()
    if not text:
        raise HTTPException(status_code=400, detail=f"{field_name} must not be blank.")
    return text

class AskRequest(BaseModel):
    user_prompt: str = Field(..., description="Natural language request")
    model: Optional[str] = Field(None, description="Ollama model name, e.g., llama3.1:8b or gpt-oss:20b")
    use_sfdc: bool = Field(False, description="Enable Salesforce tools (env creds required)")
    hybrid: bool = Field(True, description="Use hybrid retrieval for metadata search")
    k: int = Field(8, description="Number of retrieval results")


class AskResponse(BaseModel):
    intent: str
    needs_approval: bool
    tool_results: List[Dict[str, Any]]
    final_answer: str


class RepoSearchRequest(BaseModel):
    query: str = Field(..., description="Search term or phrase")
    model: Optional[str] = Field(None, description="Ollama model name")
    max_lines: int = Field(400, description="Max context lines to send to model")
    k: int = Field(8, description="Number of retrieved docs to include")
    hybrid: bool = Field(True, description="Use hybrid (vector + lexical) retrieval")


class RepoSearchResponse(BaseModel):
    query: str
    context_source: str
    context_lines: int
    explanation: str


class UserStoryRequest(BaseModel):
    story: str = Field(..., description="Technical user story")
    model: Optional[str] = Field(None, description="Ollama model name")
    max_lines: int = Field(800, description="Max context lines to send to model")
    k: int = Field(12, description="Number of retrieved docs to include")
    hybrid: bool = Field(True, description="Use hybrid (vector + lexical) retrieval")


class UserStoryResponse(BaseModel):
    story: str
    context_source: str
    context_lines: int
    recommendations: str


class DataPromptRequest(BaseModel):
    data: str = Field(..., description="Raw data or excerpts")
    prompt: str = Field(..., description="Question to ask about the data")
    model: Optional[str] = Field(None, description="Ollama model name")


class DataPromptResponse(BaseModel):
    prompt: str
    response: str


class SfRepoAskRequest(BaseModel):
    question: str = Field(..., description="Question from Salesforce UI/Apex")
    model: Optional[str] = Field(None, description="Ollama model override")
    record_id: Optional[str] = Field(None, description="Salesforce record Id context")
    object_api_name: Optional[str] = Field(None, description="Salesforce object API name")
    use_sfdc: bool = Field(False, description="Enable Salesforce tools (env creds required)")
    hybrid: bool = Field(True, description="Use hybrid retrieval for metadata search")
    k: int = Field(8, description="Number of retrieval results")
    evidence: Optional[Dict[str, Any]] = Field(
        None,
        description="Optional pre-built evidence JSON from Salesforce Prompt Runner.",
    )
    evidence_only: bool = Field(
        True,
        description="When true and evidence is provided, answer from evidence only.",
    )


class SfRepoAskResponse(BaseModel):
    question: str
    record_id: Optional[str]
    object_api_name: Optional[str]
    intent: str
    needs_approval: bool
    tool_results: List[Dict[str, Any]]
    final_answer: str


class FeatureExplainRequest(BaseModel):
    prompt: Optional[str] = Field(None, description="Prompt/instruction coming from Salesforce")
    question: Optional[str] = Field(None, description="Alias for prompt (compatibility)")
    data: Optional[Any] = Field(None, description="Data payload from Salesforce (JSON object/array or text)")
    evidence: Optional[Any] = Field(None, description="Alias for data (compatibility)")
    model: Optional[str] = Field(None, description="Ollama model override")


class FeatureExplainResponse(BaseModel):
    prompt: str
    response: str
    model: str


class UserStoryAnalyzeRequest(BaseModel):
    story: str = Field(..., description="User story text")
    model: Optional[str] = Field(None, description="Ollama model override")
    k: int = Field(8, description="Number of components to fetch from metadata model")
    hybrid: bool = Field(True, description="Use hybrid metadata retrieval")
    logs: Optional[Any] = Field(None, description="Optional debug log payload from Salesforce")


class UserStoryAnalyzeResponse(BaseModel):
    story: str
    model: str
    initial_analysis: str
    components: List[Dict[str, Any]]
    final_answer: str


class DebugAnalyzeRequest(BaseModel):
    input_text: str = Field(..., description="Debug question or symptom")
    logs: Any = Field(..., description="Debug logs payload from Salesforce")
    model: Optional[str] = Field(None, description="Ollama model override")
    k: int = Field(8, description="Number of components to fetch from metadata model")
    hybrid: bool = Field(True, description="Use hybrid metadata retrieval")


class DebugAnalyzeResponse(BaseModel):
    input_text: str
    model: str
    initial_analysis: str
    components: List[Dict[str, Any]]
    final_answer: str


class WorkItemCreateRequest(BaseModel):
    title: Optional[str] = Field(None, description="Short work item title")
    story: str = Field(..., description="User story or enhancement request")
    model: Optional[str] = Field(None, description="Ollama model override")
    metadata_project_dir: Optional[str] = Field(None, description="SFDX project directory; defaults to the active registered repo")
    target_org_alias: Optional[str] = Field(None, description="Preferred Salesforce CLI org alias")


class WorkItemResponse(BaseModel):
    work_item_id: str
    title: Optional[str]
    story: str
    status: str
    llm_model: Optional[str]
    metadata_project_dir: Optional[str]
    target_org_alias: Optional[str]
    analysis: Optional[Dict[str, Any]]
    impacted_components: Optional[List[Dict[str, Any]]]
    changed_components: Optional[Any]
    deployment_result: Optional[Dict[str, Any]]
    test_result: Optional[Dict[str, Any]]
    debug_result: Optional[Dict[str, Any]]
    final_summary: Optional[str]
    created_ts: str
    updated_ts: str


class WorkItemListResponse(BaseModel):
    items: List[WorkItemResponse]


class WorkItemExecutionResponse(BaseModel):
    execution_id: str
    work_item_id: Optional[str]
    operation_type: str
    status: str
    command_summary: Optional[str]
    request: Optional[Dict[str, Any]]
    result: Optional[Dict[str, Any]]
    exit_code: Optional[int]
    created_ts: str
    updated_ts: str


class WorkItemExecutionListResponse(BaseModel):
    executions: List[WorkItemExecutionResponse]


class WorkItemAnalyzeRequest(BaseModel):
    model: Optional[str] = Field(None, description="Ollama model override")
    k: int = Field(8, description="Number of retrieved components")
    hybrid: bool = Field(True, description="Use hybrid retrieval")
    logs: Optional[Any] = Field(None, description="Optional log payload to include in analysis")


class WorkItemGenerateRequest(BaseModel):
    model: Optional[str] = Field(None, description="Ollama model override")
    mode: str = Field("apply", description="plan_only or apply")
    target_components: Optional[List[Dict[str, Any]]] = Field(
        None,
        description="Optional narrowed target components; each item can include kind, name, and path.",
    )
    instructions: Optional[str] = Field(None, description="Additional implementation instructions")
    create_missing_components: bool = Field(True, description="Allow creation of missing files/components")
    run_local_validation: bool = Field(True, description="Run local generic validators after writing files")
    run_org_validation: bool = Field(False, description="Run Salesforce dry-run validation using target_org_alias")
    org_validation_test_level: Optional[str] = Field(None, description="Optional test level for dry-run org validation")
    write_changes: bool = Field(True, description="When false, only generate a plan")
    max_targets: int = Field(12, description="Maximum components to load into context")


class WorkItemGenerateResponse(BaseModel):
    work_item_id: str
    status: str
    model: str
    generation_summary: str
    changed_components: List[Dict[str, Any]]
    artifacts: Dict[str, str]
    validation: Dict[str, Any]
    plan: Dict[str, Any]
    updated_work_item: WorkItemResponse


class WorkItemApproveGenerationRequest(BaseModel):
    execution_id: Optional[str] = Field(None, description="Optional plan-only generation execution to approve")
    model: Optional[str] = Field(None, description="Optional model override for file generation")
    run_local_validation: bool = Field(True, description="Run local validators after applying approved generation")
    run_org_validation: bool = Field(False, description="Run Salesforce dry-run validation after applying approved generation")
    org_validation_test_level: Optional[str] = Field(None, description="Optional test level for org validation")


class WorkItemApproveDeployRequest(BaseModel):
    execution_id: Optional[str] = Field(
        None,
        description="Optional generation execution to approve for deployment. Defaults to latest applied generation.",
    )
    notes: Optional[str] = Field(None, description="Optional approval notes")


class WorkItemRunRequest(BaseModel):
    title: Optional[str] = Field(None, description="Optional work item title")
    story: str = Field(..., description="User story or implementation request")
    model: Optional[str] = Field(None, description="Ollama model override")
    metadata_project_dir: Optional[str] = Field(None, description="Metadata project directory; defaults to the active registered repo")
    target_org_alias: Optional[str] = Field(None, description="Salesforce CLI target org alias")
    analyze: bool = Field(True, description="Run story analysis")
    generate: bool = Field(True, description="Run generation step")
    generate_mode: str = Field("apply", description="plan_only or apply")
    auto_approve_generation: bool = Field(False, description="If true, auto-apply a plan_only generation plan")
    instructions: Optional[str] = Field(None, description="Extra implementation instructions for generation")
    target_components: Optional[List[Dict[str, Any]]] = Field(None, description="Optional explicit target components")
    create_missing_components: bool = Field(True, description="Allow creation of missing components")
    run_local_validation: bool = Field(True, description="Run local generation validators")
    run_org_validation: bool = Field(False, description="Run org dry-run validation on generated changes")
    org_validation_test_level: Optional[str] = Field(None, description="Test level for org dry-run validation")
    retrieve_before_deploy: bool = Field(False, description="Retrieve metadata before deployment")
    retrieve_metadata: Optional[List[str]] = Field(None, description="Optional retrieve metadata members")
    retrieve_source_dirs: Optional[List[str]] = Field(None, description="Optional retrieve source dirs")
    retrieve_manifest: Optional[str] = Field(None, description="Optional retrieve manifest")
    retrieve_wait_minutes: int = Field(20, description="Retrieve wait time in minutes")
    deploy: bool = Field(False, description="Deploy after generation")
    deploy_source_dirs: Optional[List[str]] = Field(None, description="Optional explicit deploy source dirs")
    deploy_metadata: Optional[List[str]] = Field(None, description="Optional deploy metadata members")
    deploy_manifest: Optional[str] = Field(None, description="Optional deploy manifest")
    deploy_wait_minutes: int = Field(30, description="Deploy wait time in minutes")
    deploy_test_level: Optional[str] = Field("RunLocalTests", description="Deployment test level")
    deploy_tests: Optional[List[str]] = Field(None, description="Specific deployment tests")
    deploy_ignore_conflicts: bool = Field(True, description="Ignore conflicts during deploy")
    deploy_dry_run: bool = Field(False, description="Use deployment validate-only mode")
    run_tests: bool = Field(False, description="Run Apex tests after deploy")
    test_wait_minutes: int = Field(30, description="Test wait time in minutes")
    test_level: Optional[str] = Field("RunLocalTests", description="Apex test level")
    test_names: Optional[List[str]] = Field(None, description="Specific Apex tests")
    test_class_names: Optional[List[str]] = Field(None, description="Specific Apex test classes")
    test_suite_names: Optional[List[str]] = Field(None, description="Specific Apex test suites")


class WorkItemRunResponse(BaseModel):
    work_item: WorkItemResponse
    stages: List[Dict[str, Any]]


class DevelopmentAnalyzeRequest(BaseModel):
    work_item_id: Optional[str] = Field(None, description="Existing work item to reuse")
    title: Optional[str] = Field(None, description="Short work item title")
    story: Optional[str] = Field(None, description="User story or enhancement request")
    model: Optional[str] = Field(None, description="Ollama model override")
    metadata_project_dir: Optional[str] = Field(None, description="SFDX project directory; defaults to the active registered repo")
    target_org_alias: Optional[str] = Field(None, description="Preferred Salesforce CLI org alias")
    k: int = Field(8, description="Number of retrieved components")
    hybrid: bool = Field(True, description="Use hybrid retrieval")
    logs: Optional[Any] = Field(None, description="Optional log payload to include in analysis")


class DevelopmentAnalyzeResponse(BaseModel):
    work_item: WorkItemResponse
    next_actions: List[str]


class DevelopmentPlanRequest(BaseModel):
    work_item_id: Optional[str] = Field(None, description="Existing work item to reuse")
    title: Optional[str] = Field(None, description="Short work item title")
    story: Optional[str] = Field(None, description="User story or enhancement request when work_item_id is not supplied")
    model: Optional[str] = Field(None, description="Ollama model override")
    metadata_project_dir: Optional[str] = Field(None, description="SFDX project directory; defaults to the active registered repo")
    target_org_alias: Optional[str] = Field(None, description="Preferred Salesforce CLI org alias")
    k: int = Field(8, description="Number of retrieved components")
    hybrid: bool = Field(True, description="Use hybrid retrieval")
    logs: Optional[Any] = Field(None, description="Optional log payload to include in analysis")
    target_components: Optional[List[Dict[str, Any]]] = Field(None, description="Optional explicit target components")
    instructions: Optional[str] = Field(None, description="Additional implementation instructions")
    create_missing_components: bool = Field(True, description="Allow creation of missing components")
    run_local_validation: bool = Field(True, description="Run local validators for the generated plan")
    run_org_validation: bool = Field(False, description="Run Salesforce dry-run validation using target_org_alias")
    org_validation_test_level: Optional[str] = Field(None, description="Optional test level for org dry-run validation")
    max_targets: int = Field(12, description="Maximum components to load into generation context")


class DevelopmentPlanResponse(BaseModel):
    work_item: WorkItemResponse
    generation: WorkItemGenerateResponse
    next_actions: List[str]


class DevelopmentRunRequest(WorkItemRunRequest):
    pass


class DevelopmentRunResponse(BaseModel):
    work_item: WorkItemResponse
    stages: List[Dict[str, Any]]
    next_actions: List[str]


class SfCliDeployRequest(BaseModel):
    work_item_id: Optional[str] = Field(None, description="Optional work item to attach execution to")
    target_org: str = Field(..., description="Salesforce CLI alias or username")
    project_dir: Optional[str] = Field(None, description="SFDX project directory; defaults to the active registered repo")
    source_dirs: Optional[List[str]] = Field(None, description="Source paths to deploy")
    metadata: Optional[List[str]] = Field(None, description="Metadata members to deploy")
    manifest: Optional[str] = Field(None, description="package.xml path to deploy")
    wait_minutes: int = Field(30, description="CLI wait time in minutes")
    api_version: Optional[str] = Field(None, description="API version override")
    dry_run: bool = Field(False, description="Validate only")
    ignore_conflicts: bool = Field(False, description="Pass through CLI conflict ignore flag")
    ignore_warnings: bool = Field(False, description="Pass through CLI ignore warnings flag")
    ignore_errors: bool = Field(False, description="Pass through CLI ignore errors flag")
    test_level: Optional[str] = Field(None, description="Deployment test level")
    tests: Optional[List[str]] = Field(None, description="Specified Apex tests")


class SfCliRetrieveRequest(BaseModel):
    work_item_id: Optional[str] = Field(None, description="Optional work item to attach execution to")
    target_org: str = Field(..., description="Salesforce CLI alias or username")
    project_dir: Optional[str] = Field(None, description="SFDX project directory; defaults to the active registered repo")
    source_dirs: Optional[List[str]] = Field(None, description="Source paths to retrieve")
    metadata: Optional[List[str]] = Field(None, description="Metadata members to retrieve")
    manifest: Optional[str] = Field(None, description="package.xml path to retrieve")
    output_dir: Optional[str] = Field(None, description="Optional retrieve output dir")
    wait_minutes: int = Field(33, description="CLI wait time in minutes")
    api_version: Optional[str] = Field(None, description="API version override")
    ignore_conflicts: bool = Field(False, description="Pass through CLI conflict ignore flag")


class SfCliTestRequest(BaseModel):
    work_item_id: Optional[str] = Field(None, description="Optional work item to attach execution to")
    target_org: str = Field(..., description="Salesforce CLI alias or username")
    project_dir: Optional[str] = Field(None, description="SFDX project directory; defaults to the active registered repo")
    wait_minutes: int = Field(30, description="CLI wait time in minutes")
    api_version: Optional[str] = Field(None, description="API version override")
    test_level: Optional[str] = Field("RunLocalTests", description="Apex test level")
    tests: Optional[List[str]] = Field(None, description="Specific tests to run")
    class_names: Optional[List[str]] = Field(None, description="Specific Apex test classes to run")
    suite_names: Optional[List[str]] = Field(None, description="Specific Apex test suites to run")
    code_coverage: bool = Field(True, description="Request coverage")
    detailed_coverage: bool = Field(False, description="Request detailed coverage")
    synchronous: bool = Field(False, description="Run tests synchronously")
    output_dir: Optional[str] = Field(None, description="Optional test output directory")


class SfCliCommandResponse(BaseModel):
    execution_id: str
    work_item_id: Optional[str]
    operation_type: str
    status: str
    exit_code: Optional[int]
    command: Optional[str]
    workdir: Optional[str]
    data: Optional[Dict[str, Any]]
    stdout: str
    stderr: str
    created_ts: str
    updated_ts: str


class RepoSourceRegisterRequest(BaseModel):
    clone_url: str = Field(..., description="Git clone URL for the Salesforce repository")
    branch: Optional[str] = Field(None, description="Branch to clone or sync")
    provider: Optional[str] = Field(None, description="Optional provider hint, e.g. bitbucket")
    name: Optional[str] = Field(None, description="Optional local logical repo name")
    active: bool = Field(True, description="Activate this repo immediately after sync")
    sync_enabled: bool = Field(True, description="Include this repo in due-sync processing")
    sync_interval_minutes: int = Field(1440, description="Minutes between automatic syncs")


class RepoSourceResponse(BaseModel):
    source_id: str
    provider: str
    name: str
    clone_url: str
    branch: Optional[str]
    local_path: str
    is_active: bool
    sync_enabled: bool
    sync_interval_minutes: int
    repo_kind: Optional[str]
    has_sfdx_project: bool = False
    has_force_app: bool = False
    metadata_root: Optional[str]
    validation_status: Optional[str]
    validation_error: Optional[str]
    last_synced_ts: Optional[str]
    last_synced_commit: Optional[str]
    last_sync_status: Optional[str]
    last_sync_error: Optional[str]
    last_indexed_ts: Optional[str]
    last_indexed_commit: Optional[str]
    last_index_status: Optional[str]
    last_index_error: Optional[str]
    docs_count: int = 0
    meta_files: int = 0
    graph_nodes: int = 0
    graph_edges: int = 0
    objects_count: int = 0
    fields_count: int = 0
    classes_count: int = 0
    triggers_count: int = 0
    flows_count: int = 0
    cleanup_exempt: bool = False
    created_ts: str
    updated_ts: str


class RepoSourceListResponse(BaseModel):
    active_repo_path: str
    sources: List[RepoSourceResponse]


class RepoCleanupRequest(BaseModel):
    max_age_days: int = Field(30, description="Remove inactive registered repos older than this many days")
    delete_local: bool = Field(False, description="Also delete local cloned directories")


class RepoCleanupResponse(BaseModel):
    removed: List[RepoSourceResponse]


class BitbucketConnectStatusResponse(BaseModel):
    provider: str
    connected: bool
    status: str
    auth_mode: str
    login_url: Optional[str] = None
    message: str
    has_client_config: bool = False


class RepoInitializeRequest(BaseModel):
    provider: Optional[str] = Field(None, description="Repo provider, defaults to bitbucket")
    clone_url: Optional[str] = Field(None, description="Git clone URL for the Salesforce repository")
    branch: Optional[str] = Field(None, description="Optional branch to clone or sync")
    name: Optional[str] = Field(None, description="Optional local logical repo name")
    active: bool = Field(True, description="Activate this repo immediately after sync")
    sync_enabled: bool = Field(True, description="Include this repo in due-sync processing")
    sync_interval_minutes: int = Field(1440, description="Minutes between automatic syncs")


class RepoInitializeResponse(BaseModel):
    status: str
    provider: str
    connected: bool
    missing_inputs: List[str]
    message: str
    defaults: Dict[str, Any]
    next_actions: List[str]
    source: Optional[RepoSourceResponse] = None


class ActiveRepoResponse(BaseModel):
    active_repo_path: str
    source: Optional[RepoSourceResponse] = None


class SetupStepResponse(BaseModel):
    key: str
    label: str
    status: str
    message: str
    updated_ts: Optional[str] = None
    started_ts: Optional[str] = None
    finished_ts: Optional[str] = None
    details: Optional[Dict[str, Any]] = None


class EnvironmentSetupRequest(BaseModel):
    provider: Optional[str] = Field(None, description="Repo provider, defaults to bitbucket")
    clone_url: Optional[str] = Field(None, description="Git clone URL for the Salesforce repository")
    branch: Optional[str] = Field(None, description="Optional branch to clone or sync")
    name: Optional[str] = Field(None, description="Optional local logical repo name")
    project_namespace: Optional[str] = Field(None, description="Stable namespace used to isolate this project's setup and health state")
    start_ngrok: bool = Field(True, description="Start or reuse ngrok after setup completes")
    run_id: Optional[str] = Field(None, description="Optional existing setup run to continue")


class EnvironmentSetupStatusResponse(BaseModel):
    run_id: Optional[str]
    project_namespace: Optional[str] = None
    status: str
    message: str
    provider: Optional[str] = None
    clone_url: Optional[str] = None
    branch: Optional[str] = None
    name: Optional[str] = None
    start_ngrok: Optional[bool] = None
    current_step: Optional[str] = None
    backend_reachable: bool = True
    run_exists: bool = False
    backend_instance: Optional[str] = None
    requires_user_input: bool = False
    missing_inputs: List[str] = Field(default_factory=list)
    next_actions: List[str] = Field(default_factory=list)
    active_repo_path: Optional[str] = None
    health_url: Optional[str] = None
    ngrok_public_url: Optional[str] = None
    steps: List[SetupStepResponse] = Field(default_factory=list)
    logs: List[Dict[str, Any]] = Field(default_factory=list)
    created_ts: Optional[str] = None
    updated_ts: Optional[str] = None


class IndexStatsResponse(BaseModel):
    active_repo_path: str
    validation_status: str
    metadata_root: str
    docs_count: int
    objects_count: int
    fields_count: int
    classes_count: int
    triggers_count: int
    flows_count: int


class IndexedObjectResponse(BaseModel):
    object_api_name: str
    path: str
    field_count: int


class IndexedObjectsResponse(BaseModel):
    active_repo_path: str
    total: int
    objects: List[IndexedObjectResponse]


class IndexedFieldResponse(BaseModel):
    field_api_name: str
    object_api_name: str
    path: str


class IndexedFieldsResponse(BaseModel):
    active_repo_path: str
    object_api_name: str
    total: int
    fields: List[IndexedFieldResponse]


class IndexedMetadataTypeResponse(BaseModel):
    folder: str
    metadata_type: str
    path: str
    file_count: int
    dir_count: int


class MetadataInventoryResponse(BaseModel):
    active_repo_path: str
    inventory_path: str
    metadata_root: str
    metadata_type_count: int
    top_level_folder_count: int
    total_metadata_files: int
    present_metadata_types: List[str]
    top_level_types: List[IndexedMetadataTypeResponse]
    object_child_types: List[Dict[str, Any]]


def _repo_source_response(row: Dict[str, Any]) -> RepoSourceResponse:
    return RepoSourceResponse(
        source_id=row["source_id"],
        provider=row["provider"],
        name=row["name"],
        clone_url=row["clone_url"],
        branch=row.get("branch"),
        local_path=row["local_path"],
        is_active=bool(row.get("is_active")),
        sync_enabled=bool(row.get("sync_enabled")),
        sync_interval_minutes=int(row.get("sync_interval_minutes") or 1440),
        repo_kind=row.get("repo_kind"),
        has_sfdx_project=bool(row.get("has_sfdx_project")),
        has_force_app=bool(row.get("has_force_app")),
        metadata_root=row.get("metadata_root"),
        validation_status=row.get("validation_status"),
        validation_error=row.get("validation_error"),
        last_synced_ts=row.get("last_synced_ts"),
        last_synced_commit=row.get("last_synced_commit"),
        last_sync_status=row.get("last_sync_status"),
        last_sync_error=row.get("last_sync_error"),
        last_indexed_ts=row.get("last_indexed_ts"),
        last_indexed_commit=row.get("last_indexed_commit"),
        last_index_status=row.get("last_index_status"),
        last_index_error=row.get("last_index_error"),
        docs_count=int(row.get("docs_count") or 0),
        meta_files=int(row.get("meta_files") or 0),
        graph_nodes=int(row.get("graph_nodes") or 0),
        graph_edges=int(row.get("graph_edges") or 0),
        objects_count=int(row.get("objects_count") or 0),
        fields_count=int(row.get("fields_count") or 0),
        classes_count=int(row.get("classes_count") or 0),
        triggers_count=int(row.get("triggers_count") or 0),
        flows_count=int(row.get("flows_count") or 0),
        cleanup_exempt=bool(row.get("cleanup_exempt")),
        created_ts=row["created_ts"],
        updated_ts=row["updated_ts"],
    )


def _clone_url_has_inline_credentials(clone_url: Optional[str]) -> bool:
    if not clone_url:
        return False
    lowered = clone_url.lower()
    return "@bitbucket.org" in lowered and "://" in lowered


def _bitbucket_connection_snapshot() -> BitbucketConnectStatusResponse:
    data = bitbucket_connection_status()
    return BitbucketConnectStatusResponse(**data)


def _suggest_repo_name(clone_url: Optional[str]) -> Optional[str]:
    if not clone_url:
        return None
    cleaned = clone_url.rstrip('/')
    name = cleaned.rsplit('/', 1)[-1]
    if name.endswith('.git'):
        name = name[:-4]
    name = re.sub(r"[^A-Za-z0-9._-]+", "-", name.strip()).strip("-")
    return name or None


def _active_repo_response(registry: Optional[RepoRegistry] = None) -> ActiveRepoResponse:
    registry = registry or RepoRegistry()
    active_row = registry.active_source()
    return ActiveRepoResponse(
        active_repo_path=str(resolve_active_repo()),
        source=_repo_source_response(active_row) if active_row else None,
    )


def _environment_setup_response(payload: Dict[str, Any]) -> EnvironmentSetupStatusResponse:
    steps = [SetupStepResponse(**step) for step in payload.get("steps", [])]
    return EnvironmentSetupStatusResponse(
        run_id=payload.get("run_id"),
        project_namespace=payload.get("project_namespace"),
        status=str(payload.get("status") or "UNKNOWN"),
        message=str(payload.get("message") or ""),
        provider=payload.get("provider"),
        clone_url=payload.get("clone_url"),
        branch=payload.get("branch"),
        name=payload.get("name"),
        start_ngrok=payload.get("start_ngrok"),
        current_step=payload.get("current_step"),
        backend_reachable=bool(payload.get("backend_reachable", True)),
        run_exists=bool(payload.get("run_exists", False)),
        backend_instance=payload.get("backend_instance"),
        requires_user_input=bool(payload.get("requires_user_input")),
        missing_inputs=list(payload.get("missing_inputs") or []),
        next_actions=list(payload.get("next_actions") or []),
        active_repo_path=payload.get("active_repo_path"),
        health_url=payload.get("health_url"),
        ngrok_public_url=payload.get("ngrok_public_url"),
        steps=steps,
        logs=list(payload.get("logs") or []),
        created_ts=payload.get("created_ts"),
        updated_ts=payload.get("updated_ts"),
    )


def _active_index_stats() -> IndexStatsResponse:
    repo_path = resolve_active_repo()
    inventory = validate_repo_structure(repo_path)
    docs_count = 0
    if DEFAULT_DOCS_PATH.exists():
        with DEFAULT_DOCS_PATH.open("r", encoding="utf-8") as handle:
            docs_count = sum(1 for line in handle if line.strip())
    return IndexStatsResponse(
        active_repo_path=str(repo_path),
        validation_status=str(inventory.get("validation_status") or "UNKNOWN"),
        metadata_root=str(inventory.get("metadata_root") or ""),
        docs_count=docs_count,
        objects_count=int(inventory.get("objects_count") or 0),
        fields_count=int(inventory.get("fields_count") or 0),
        classes_count=int(inventory.get("classes_count") or 0),
        triggers_count=int(inventory.get("triggers_count") or 0),
        flows_count=int(inventory.get("flows_count") or 0),
    )


def _active_metadata_inventory() -> MetadataInventoryResponse:
    repo_path = resolve_active_repo()
    if METADATA_INVENTORY_PATH.exists():
        inventory = load_metadata_inventory(METADATA_INVENTORY_PATH)
    else:
        inventory = build_metadata_inventory(repo_path)
        write_metadata_inventory(inventory, METADATA_INVENTORY_PATH)
    top_level = [IndexedMetadataTypeResponse(**item) for item in inventory.get('top_level_types', [])]
    return MetadataInventoryResponse(
        active_repo_path=str(repo_path),
        inventory_path=str(METADATA_INVENTORY_PATH),
        metadata_root=str(inventory.get('metadata_root') or ''),
        metadata_type_count=int(inventory.get('metadata_type_count') or 0),
        top_level_folder_count=int(inventory.get('top_level_folder_count') or 0),
        total_metadata_files=int(inventory.get('total_metadata_files') or 0),
        present_metadata_types=list(inventory.get('present_metadata_types') or []),
        top_level_types=top_level,
        object_child_types=list(inventory.get('object_child_types') or []),
    )


def get_ollama_client(model_override: Optional[str] = None) -> OllamaClient:
    host = os.getenv("OLLAMA_HOST", "http://localhost:11434")
    model = model_override or os.getenv("OLLAMA_MODEL", "gpt-oss:20b")
    return OllamaClient(host=host, model=model)

def _ensure_metadata_indexes() -> None:
    global _INDEX_READY
    if _INDEX_READY and DEFAULT_DOCS_PATH.exists() and DEFAULT_DB_PATH.exists():
        return
    ensure_indexes(docs_path=DEFAULT_DOCS_PATH, db_path=DEFAULT_DB_PATH, rebuild=False)
    _INDEX_READY = True


def _extract_object_from_question(question: str) -> Optional[str]:
    q = question.strip()
    m = re.search(r"\b(?:on|for)\s+(?:the\s+)?([A-Za-z][A-Za-z0-9_]*(?:__c)?)\b", q, flags=re.IGNORECASE)
    if not m:
        return None
    token = m.group(1)
    if "__c" in token:
        return token
    return token[0].upper() + token[1:]


def _scan_related_files(paths: List[Path], terms: List[str]) -> List[Dict[str, str]]:
    out: List[Dict[str, str]] = []
    term_set = [t for t in terms if t]
    for p in paths:
        try:
            text = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        lower = text.lower()
        for t in term_set:
            if t.lower() in lower:
                snippet = ""
                for line in text.splitlines():
                    if t.lower() in line.lower():
                        snippet = line.strip()[:240]
                        break
                out.append({"path": str(p), "snippet": snippet or f"Contains '{t}'"})
                break
    return out


def _scan_approval_related_usage(
    paths: List[Path],
    *,
    object_name: Optional[str],
    process_names: List[str],
) -> List[Dict[str, str]]:
    out: List[Dict[str, str]] = []
    obj_token = object_name.lower() if object_name else ""
    proc_tokens = [p.lower() for p in process_names]

    for p in paths:
        try:
            text = p.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        lower_text = text.lower()
        lower_name = p.name.lower()

        matched = False
        matched_token = ""

        # Strong match 1: explicit approval process name token appears in file text.
        for t in proc_tokens:
            if t and t in lower_text:
                matched = True
                matched_token = t
                break

        # Strong match 2: filename itself is clearly object+approval oriented.
        if not matched:
            if "approval" in lower_name and (not obj_token or obj_token in lower_name):
                matched = True
                matched_token = "approval"

        # Strong match 3: runtime approval constructs plus object hint in text.
        if not matched:
            has_runtime = ("processinstance" in lower_text) or ("processdefinition" in lower_text)
            if has_runtime and (not obj_token or obj_token in lower_text):
                matched = True
                matched_token = "processinstance/processdefinition"

        if not matched:
            continue

        snippet = ""
        token_for_line = matched_token if matched_token != "processinstance/processdefinition" else "processinstance"
        for line in text.splitlines():
            ll = line.lower()
            if token_for_line in ll or ("processdefinition" in ll and token_for_line == "processinstance"):
                snippet = line.strip()[:240]
                break
        if not snippet:
            snippet = f"Matched by approval-process relationship rule ({matched_token})"
        out.append({"path": str(p), "snippet": snippet})
    return out


def _approval_process_inventory_response(question: str, object_hint: Optional[str]) -> Optional[AskResponse]:
    q = question.lower()
    if "approval process" not in q and "approval processes" not in q:
        return None
    if not any(k in q for k in ["list", "show", "give me", "what are", "how many"]):
        return None

    obj = object_hint or _extract_object_from_question(question)
    ap_dir = _default_meta_root() / "approvalProcesses"
    if not ap_dir.exists():
        return None

    if obj:
        approval_files = sorted(ap_dir.glob(f"{obj}.*.approvalProcess-meta.xml"))
    else:
        approval_files = sorted(ap_dir.glob("*.approvalProcess-meta.xml"))

    items: List[Dict[str, Any]] = []
    ap_names: List[str] = []
    for f in approval_files:
        stem = f.name.replace(".approvalProcess-meta.xml", "")
        if "." in stem:
            file_obj, name = stem.split(".", 1)
        else:
            file_obj, name = "UNKNOWN", stem
        ap_names.append(name)
        try:
            txt = f.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            txt = ""
        active = "true" if "<active>true</active>" in txt.lower() else "false"
        items.append(
            {
                "type": "APPROVAL_PROCESS",
                "object": file_obj,
                "name": name,
                "active": active,
                "path": str(f),
                "snippet": f"<active>{active}</active>",
            }
        )

    # Related automations are shown separately and explicitly labeled as related usage.
    flow_files = list((_default_meta_root() / "flows").glob("*.flow-meta.xml"))
    trig_files = list((_default_meta_root() / "triggers").glob("*.trigger"))
    cls_files = list((_default_meta_root() / "classes").glob("*.cls"))
    related_flows = _scan_approval_related_usage(flow_files, object_name=obj, process_names=ap_names)
    related_apex = _scan_approval_related_usage(trig_files + cls_files, object_name=obj, process_names=ap_names)

    max_related = 10
    for rf in related_flows[:max_related]:
        items.append(
            {
                "type": "RELATED_FLOW",
                "name": Path(rf["path"]).name.replace(".flow-meta.xml", ""),
                "path": rf["path"],
                "snippet": rf["snippet"],
            }
        )
    for ra in related_apex[:max_related]:
        p = Path(ra["path"])
        kind = "RELATED_TRIGGER" if p.suffix == ".trigger" else "RELATED_APEX"
        items.append(
            {
                "type": kind,
                "name": p.stem,
                "path": ra["path"],
                "snippet": ra["snippet"],
            }
        )

    target = obj or "all objects"
    lines: List[str] = []
    lines.append(f"Approval processes on {target}: {len(approval_files)}")
    if approval_files:
        lines.append("Primary approval process definitions:")
        for it in items:
            if it.get("type") == "APPROVAL_PROCESS":
                lines.append(f"- {it['object']}.{it['name']} (active={it['active']})")
                lines.append(f"  {it['path']}")
    else:
        lines.append("No ApprovalProcess metadata files found for that object.")

    lines.append("")
    lines.append("Related usage (supporting automation, not the approval-process definition):")
    lines.append(f"- Related flows: {len(related_flows)}")
    lines.append(f"- Related apex (classes/triggers): {len(related_apex)}")
    for it in items:
        t = it.get("type")
        if t in {"RELATED_FLOW", "RELATED_TRIGGER", "RELATED_APEX"}:
            lines.append(f"- [{t}] {it['name']}")
            lines.append(f"  {it['path']}")
            if it.get("snippet"):
                lines.append(f"  {it['snippet']}")

    return AskResponse(
        intent="APPROVAL_PROCESS_INVENTORY",
        needs_approval=False,
        tool_results=[{"tool": "approval_process_inventory", "args": {"object": obj}, "result": {"ok": True, "items": items}}],
        final_answer="\n".join(lines),
    )


def _extract_object_name_from_question(question: str) -> Optional[str]:
    q = question.strip()
    patterns = [
        r"\bon\s+the\s+([A-Za-z][A-Za-z0-9_]+)\s+object\b",
        r"\bon\s+([A-Za-z][A-Za-z0-9_]+)\s+object\b",
        r"\bfor\s+the\s+([A-Za-z][A-Za-z0-9_]+)\s+object\b",
        r"\bfor\s+([A-Za-z][A-Za-z0-9_]+)\s+object\b",
        r"\bon\s+the\s+([A-Za-z][A-Za-z0-9_]+)\b",
        r"\bon\s+([A-Za-z][A-Za-z0-9_]+)\b",
        r"\bfor\s+the\s+([A-Za-z][A-Za-z0-9_]+)\b",
        r"\bfor\s+([A-Za-z][A-Za-z0-9_]+)\b",
    ]
    for pattern in patterns:
        m = re.search(pattern, q, re.IGNORECASE)
        if m:
            return m.group(1)
    return None


def _flow_inventory_response(question: str, object_hint: Optional[str]) -> Optional[AskResponse]:
    q = question.strip()
    q_lower = q.lower()
    if "flow" not in q_lower:
        return None
    if "approval process" in q_lower:
        return None
    if not any(token in q_lower for token in ["list", "how many", "count", "number of", "inventory"]):
        return None

    obj = (object_hint or _extract_object_name_from_question(q) or "").strip()
    if not obj:
        return None

    active_only = "active" in q_lower
    flows_root = _default_meta_root() / "flows"
    if not flows_root.exists():
        return None

    items: List[Dict[str, Any]] = []
    ns = {"m": "http://soap.sforce.com/2006/04/metadata"}
    for flow_file in sorted(flows_root.glob("*.flow-meta.xml")):
        try:
            root = ET.parse(flow_file).getroot()
        except ET.ParseError:
            continue
        start = root.find("m:start", ns)
        if start is None:
            continue
        flow_object = start.findtext("m:object", default="", namespaces=ns).strip()
        if flow_object != obj:
            continue
        status = root.findtext("m:status", default="", namespaces=ns).strip() or "Unknown"
        if active_only and status.lower() != "active":
            continue
        label = root.findtext("m:label", default="", namespaces=ns).strip() or flow_file.stem.replace(".flow-meta", "")
        trigger_type = start.findtext("m:triggerType", default="", namespaces=ns).strip()
        record_trigger_type = start.findtext("m:recordTriggerType", default="", namespaces=ns).strip()
        items.append(
            {
                "type": "FLOW",
                "object": flow_object,
                "label": label,
                "name": flow_file.name.replace(".flow-meta.xml", ""),
                "status": status,
                "trigger_type": trigger_type,
                "record_trigger_type": record_trigger_type,
                "path": str(flow_file),
            }
        )

    if not items:
        qualifier = "active " if active_only else ""
        return AskResponse(
            intent="FLOW_INVENTORY",
            needs_approval=False,
            tool_results=[
                {
                    "tool": "flow_inventory",
                    "args": {"object": obj, "active_only": active_only},
                    "result": {"ok": True, "items": []},
                }
            ],
            final_answer=f"No {qualifier}record-triggered flows found in repo metadata for object {obj}.",
        )

    lines: List[str] = []
    qualifier = "active " if active_only else ""
    lines.append(f"{len(items)} {qualifier}record-triggered flow(s) found in repo metadata for object {obj}:")
    for item in items:
        details = [item["status"]]
        if item.get("trigger_type"):
            details.append(item["trigger_type"])
        if item.get("record_trigger_type"):
            details.append(item["record_trigger_type"])
        lines.append(f"- {item['label']} ({', '.join(details)})")
        lines.append(f"  {item['path']}")

    return AskResponse(
        intent="FLOW_INVENTORY",
        needs_approval=False,
        tool_results=[
            {
                "tool": "flow_inventory",
                "args": {"object": obj, "active_only": active_only},
                "result": {"ok": True, "items": items},
            }
        ],
        final_answer="\n".join(lines),
    )


def run_agent(user_prompt: str, model_override: Optional[str], use_sfdc: bool, hybrid: bool, k: int) -> AskResponse:
    # Build plan with LLM
    ollama = get_ollama_client(model_override)
    plan: ActionPlan = build_plan_with_llm(user_prompt, ollama)

    # Execute tools
    sf_client = SalesforceClient.from_env(dry_run=True) if use_sfdc else None
    if not use_sfdc:
        metadata_calls = [tc for tc in plan.tool_calls if tc.tool == "search_metadata"]
        if not metadata_calls:
            metadata_calls = [ToolCall("search_metadata", {"query": user_prompt})]
        plan.tool_calls = metadata_calls
    # Inject hybrid flag and k into search calls
    for tc in plan.tool_calls:
        if tc.tool == "search_metadata":
            _ensure_metadata_indexes()
            tc.args.setdefault("hybrid", hybrid)
            tc.args.setdefault("k", k)
    results = execute_plan(plan, sf_client=sf_client)

    # Final answer from LLM
    final_answer = build_final_with_llm(user_prompt, results, ollama)
    return AskResponse(
        intent=plan.intent,
        needs_approval=plan.needs_approval,
        tool_results=results,
        final_answer=final_answer,
    )


def run_evidence_prompt(
    *,
    question: str,
    model_override: Optional[str],
    evidence: Dict[str, Any],
) -> AskResponse:
    ollama = get_ollama_client(model_override)

    evidence_steps = evidence.get("steps", [])
    rows_summary: Dict[str, int] = {}
    if isinstance(evidence_steps, list):
        for step in evidence_steps:
            if isinstance(step, dict):
                key = str(step.get("key") or step.get("name") or "step")
                rows = step.get("rows")
                try:
                    rows_summary[key] = int(rows) if rows is not None else 0
                except Exception:
                    rows_summary[key] = 0

    prompt = (
        "You are a Salesforce sales operations analyst.\n"
        "Use ONLY the provided evidence JSON.\n"
        "Do not call Salesforce or ask for credentials.\n"
        "If evidence has zero rows, clearly state no matching data in the evidence.\n"
        "Do not invent records.\n\n"
        f"Question:\n{question}\n\n"
        f"Evidence JSON:\n{json.dumps(evidence, ensure_ascii=False)}"
    )
    final_answer = ollama.chat(prompt)

    return AskResponse(
        intent="EVIDENCE_PROMPT",
        needs_approval=False,
        tool_results=[
            {
                "tool": "provided_evidence",
                "args": {"evidence_only": True},
                "result": {"ok": True, "rows_by_step": rows_summary},
            }
        ],
        final_answer=final_answer,
    )


def run_feature_explain(prompt_text: str, payload: Any, model_override: Optional[str]) -> FeatureExplainResponse:
    ollama = get_ollama_client(model_override)
    if isinstance(payload, str):
        data_text = payload
    else:
        data_text = json.dumps(payload, ensure_ascii=False)

    # Direct prompt+data pass-through mode: no retrieval, no index lookup, no tool execution.
    llm_input = (
        f"{prompt_text}\n\n"
        "DATA:\n"
        f"{data_text}"
    )
    response = ollama.chat(llm_input)
    return FeatureExplainResponse(prompt=prompt_text, response=response, model=ollama.model)


def _to_json_text(payload: Any) -> str:
    if isinstance(payload, str):
        return payload
    return json.dumps(payload, ensure_ascii=False)


def _retrieve_components(query_text: str, *, k: int, hybrid: bool) -> List[Dict[str, Any]]:
    _ensure_metadata_indexes()
    hits = search_metadata(query_text, k=k, hybrid=hybrid)
    out: List[Dict[str, Any]] = []
    for h in hits:
        out.append(
            {
                "kind": h.kind,
                "name": h.name,
                "path": h.path,
                "doc_id": h.doc_id,
                "snippet": (h.text or "")[:1500],
            }
        )
    return out


def _components_block(components: List[Dict[str, Any]]) -> str:
    if not components:
        return "No components retrieved from metadata model."
    lines: List[str] = []
    for c in components:
        lines.append(f"- {c.get('kind')} | {c.get('name')} | {c.get('path')}")
        snippet = c.get("snippet") or ""
        if snippet:
            lines.append(f"  snippet: {snippet[:300]}")
    return "\n".join(lines)


def run_user_story_analysis(req: UserStoryAnalyzeRequest) -> UserStoryAnalyzeResponse:
    ollama = get_ollama_client(req.model)
    logs_text = _to_json_text(req.logs) if req.logs is not None else "No logs provided."

    first_prompt = (
        "You are a Salesforce architect.\n"
        "Analyze the user story and optional logs.\n"
        "Return concise analysis with likely impacted component keywords and risk/test notes.\n\n"
        f"USER STORY:\n{req.story}\n\n"
        f"LOGS:\n{logs_text}"
    )
    initial_analysis = ollama.chat(first_prompt)

    retrieval_query = f"{req.story}\n{initial_analysis}"
    components = _retrieve_components(retrieval_query, k=req.k, hybrid=req.hybrid)
    comp_text = _components_block(components)

    second_prompt = (
        "You are a Salesforce architect.\n"
        "Use the user story, first analysis, and retrieved components to produce an implementation plan.\n"
        "Include impacted components, why they are impacted, likely root cause/risks, and resolution steps.\n"
        "If data is insufficient, say what is missing.\n\n"
        f"USER STORY:\n{req.story}\n\n"
        f"FIRST ANALYSIS:\n{initial_analysis}\n\n"
        f"RETRIEVED COMPONENTS:\n{comp_text}"
    )
    final_answer = ollama.chat(second_prompt)
    return UserStoryAnalyzeResponse(
        story=req.story,
        model=ollama.model,
        initial_analysis=initial_analysis,
        components=components,
        final_answer=final_answer,
    )


def run_debug_analysis(req: DebugAnalyzeRequest) -> DebugAnalyzeResponse:
    ollama = get_ollama_client(req.model)
    logs_text = _to_json_text(req.logs)

    first_prompt = (
        "You are a Salesforce production support engineer.\n"
        "Analyze the error/symptom and logs.\n"
        "Identify likely failure point, suspected component keywords, and probable cause categories.\n\n"
        f"INPUT:\n{req.input_text}\n\n"
        f"LOGS:\n{logs_text}"
    )
    initial_analysis = ollama.chat(first_prompt)

    retrieval_query = f"{req.input_text}\n{initial_analysis}"
    components = _retrieve_components(retrieval_query, k=req.k, hybrid=req.hybrid)
    comp_text = _components_block(components)

    second_prompt = (
        "You are a Salesforce production support engineer.\n"
        "Given logs, initial analysis, and retrieved components, provide:\n"
        "1) probable error location\n"
        "2) why it is happening\n"
        "3) concrete fix steps\n"
        "4) validation tests.\n\n"
        f"INPUT:\n{req.input_text}\n\n"
        f"INITIAL ANALYSIS:\n{initial_analysis}\n\n"
        f"RETRIEVED COMPONENTS:\n{comp_text}\n\n"
        f"LOGS:\n{logs_text}"
    )
    final_answer = ollama.chat(second_prompt)
    return DebugAnalyzeResponse(
        input_text=req.input_text,
        model=ollama.model,
        initial_analysis=initial_analysis,
        components=components,
        final_answer=final_answer,
    )


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _project_dir_or_default(project_dir: Optional[str]) -> str:
    return str(Path(project_dir).resolve()) if project_dir else str(default_project_dir())


def _work_item_response(row: Dict[str, Any]) -> WorkItemResponse:
    return WorkItemResponse(
        work_item_id=row["work_item_id"],
        title=row.get("title"),
        story=row["story"],
        status=row["status"],
        llm_model=row.get("llm_model"),
        metadata_project_dir=row.get("metadata_project_dir"),
        target_org_alias=row.get("target_org_alias"),
        analysis=row.get("analysis_json"),
        impacted_components=row.get("impacted_components_json"),
        changed_components=row.get("changed_components_json"),
        deployment_result=row.get("deployment_result_json"),
        test_result=row.get("test_result_json"),
        debug_result=row.get("debug_result_json"),
        final_summary=row.get("final_summary"),
        created_ts=row["created_ts"],
        updated_ts=row["updated_ts"],
    )


def _execution_response(row: Dict[str, Any]) -> WorkItemExecutionResponse:
    return WorkItemExecutionResponse(
        execution_id=row["execution_id"],
        work_item_id=row.get("work_item_id"),
        operation_type=row["operation_type"],
        status=row["status"],
        command_summary=row.get("command_summary"),
        request=row.get("request_json"),
        result=row.get("result_json"),
        exit_code=row.get("exit_code"),
        created_ts=row["created_ts"],
        updated_ts=row["updated_ts"],
    )


def _development_next_actions(*, work_item: WorkItemResponse, generation: Optional[WorkItemGenerateResponse] = None, stages: Optional[List[Dict[str, Any]]] = None) -> List[str]:
    actions: List[str] = []
    if not work_item.analysis:
        actions.append("Run development analysis to identify impacted metadata and likely implementation targets.")
        return actions
    if generation is None and not work_item.changed_components:
        actions.append("Run development plan to create a file-level implementation plan before applying changes.")
    if generation is not None:
        if str(generation.status).upper() == "AWAITING_APPROVAL":
            actions.append("Review the generation plan and then approve it with /sf-repo-ai/work-items/{id}/approve-generation or rerun in apply mode.")
        elif str(generation.status).upper() in {"GENERATED", "COMPLETED"}:
            actions.append("Review generated files under data/work_items, then approve deployment with /sf-repo-ai/work-items/{id}/approve-deploy before running deploy.")
    if stages:
        stage_names = {str(s.get("stage") or "") for s in stages}
        if "deploy" not in stage_names:
            actions.append("After generation approval, run /sf-repo-ai/work-items/{id}/approve-deploy, then deploy via /sf-repo-ai/sf-cli/deploy using the same work_item_id.")
        if "test" not in stage_names:
            actions.append("Run targeted Apex tests or local validation for the impacted components before promotion.")
    if not actions:
        actions.append("Review the work item, validations, and execution history before promoting the change.")
    return actions




def _is_applied_generation_execution(execution: Dict[str, Any]) -> bool:
    operation = str(execution.get("operation_type") or "").strip().lower()
    status = str(execution.get("status") or "").strip().upper()
    if status not in {"GENERATED", "COMPLETED"}:
        return False
    if operation == "approve_generation":
        return True
    if operation == "generate_or_update_components":
        request_json = execution.get("request_json") or {}
        return str(request_json.get("mode") or "").strip().lower() == "apply"
    return False


def _latest_applied_generation_execution(executions: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    for execution in executions:
        if _is_applied_generation_execution(execution):
            return execution
    return None


def _latest_deploy_approval_execution(executions: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    for execution in executions:
        if str(execution.get("operation_type") or "").strip().lower() == "approve_deploy" and str(
            execution.get("status") or ""
        ).strip().upper() == "APPROVED":
            return execution
    return None


def _ensure_deploy_gate_approved(store: OrchestrationStore, work_item_id: str) -> Dict[str, Any]:
    row = store.get_work_item(work_item_id)
    executions = store.list_executions(work_item_id=work_item_id, limit=500)
    latest_applied_generation = _latest_applied_generation_execution(executions)
    if not latest_applied_generation:
        raise HTTPException(
            status_code=400,
            detail="Deploy is blocked. No applied generation found. Required sequence: plan -> approve generation -> approve deploy -> deploy.",
        )
    latest_deploy_approval = _latest_deploy_approval_execution(executions)
    if not latest_deploy_approval:
        raise HTTPException(
            status_code=400,
            detail="Deploy is blocked. Missing deploy approval. Run /sf-repo-ai/work-items/{id}/approve-deploy first.",
        )
    approval_ts = str(latest_deploy_approval.get("updated_ts") or latest_deploy_approval.get("created_ts") or "")
    generation_ts = str(latest_applied_generation.get("updated_ts") or latest_applied_generation.get("created_ts") or "")
    if approval_ts < generation_ts:
        raise HTTPException(
            status_code=400,
            detail="Deploy is blocked. Latest generated changes were not approved for deploy. Run /sf-repo-ai/work-items/{id}/approve-deploy again.",
        )
    return row

def _resolve_or_create_work_item(
    *,
    store: OrchestrationStore,
    work_item_id: Optional[str],
    title: Optional[str],
    story: Optional[str],
    model: Optional[str],
    metadata_project_dir: Optional[str],
    target_org_alias: Optional[str],
) -> Dict[str, Any]:
    if work_item_id:
        return store.get_work_item(work_item_id)
    if not (story or "").strip():
        raise HTTPException(status_code=400, detail="story is required when work_item_id is not provided")
    return store.create_work_item(
        story=story.strip(),
        title=title,
        llm_model=model or os.getenv("OLLAMA_MODEL", "gpt-oss:20b"),
        metadata_project_dir=_project_dir_or_default(metadata_project_dir),
        target_org_alias=target_org_alias,
        created_ts=_utc_now_iso(),
    )


def _normalize_source_dir(project_dir: Path, rel_path: str) -> str:
    path = (project_dir / rel_path).resolve()
    relative = path.relative_to(project_dir)
    parts = relative.parts
    for bundle_dir in ("lwc", "aura"):
        if bundle_dir in parts:
            idx = parts.index(bundle_dir)
            if len(parts) > idx + 1:
                return str(Path(*parts[: idx + 2]))
    return str(relative)


def _derive_source_dirs_from_changed_components(project_dir: Path, changed_components: List[Dict[str, Any]]) -> List[str]:
    source_dirs: List[str] = []
    seen: set[str] = set()
    for item in changed_components:
        rel_path = str(item.get("path") or "").strip()
        if not rel_path:
            continue
        normalized = _normalize_source_dir(project_dir, rel_path)
        key = normalized.lower()
        if key in seen:
            continue
        seen.add(key)
        source_dirs.append(normalized)
    return source_dirs


def _run_cli_operation(
    *,
    operation_type: str,
    work_item_id: Optional[str],
    request_payload: Dict[str, Any],
    runner: Callable[[], Any],
    store: Optional[OrchestrationStore] = None,
) -> SfCliCommandResponse:
    db = store or OrchestrationStore()
    created_ts = _utc_now_iso()
    execution = db.create_execution(
        operation_type=operation_type,
        work_item_id=work_item_id,
        created_ts=created_ts,
        request_payload=request_payload,
    )
    try:
        result = runner()
        result_payload = {
            "status": result.status,
            "command": result.command,
            "workdir": result.workdir,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "data": result.data,
        }
        execution = db.update_execution(
            execution["execution_id"],
            status=result.status,
            updated_ts=_utc_now_iso(),
            command_summary=result.command,
            result_payload=result_payload,
            exit_code=result.exit_code,
        )
        return SfCliCommandResponse(
            execution_id=execution["execution_id"],
            work_item_id=execution.get("work_item_id"),
            operation_type=execution["operation_type"],
            status=execution["status"],
            exit_code=execution.get("exit_code"),
            command=result.command,
            workdir=result.workdir,
            data=result.data,
            stdout=result.stdout,
            stderr=result.stderr,
            created_ts=execution["created_ts"],
            updated_ts=execution["updated_ts"],
        )
    except Exception as exc:
        execution = db.update_execution(
            execution["execution_id"],
            status="FAILED",
            updated_ts=_utc_now_iso(),
            result_payload={"error": str(exc)},
        )
        raise HTTPException(
            status_code=500,
            detail={
                "execution_id": execution["execution_id"],
                "operation_type": operation_type,
                "error": str(exc),
            },
        )



app = FastAPI(title="SF Agent API")


@app.post("/agent", response_model=AskResponse)
def ask(req: AskRequest, api_key: str = Depends(get_api_key)):
    try:
        user_prompt = _require_non_empty_text(req.user_prompt, "user_prompt")
        return run_agent(
            user_prompt=user_prompt,
            model_override=req.model,
            use_sfdc=req.use_sfdc,
            hybrid=req.hybrid,
            k=req.k,
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/repo/search-explain", response_model=RepoSearchResponse)
def repo_search_explain(req: RepoSearchRequest, api_key: str = Depends(get_api_key)):
    try:
        query = _require_non_empty_text(req.query, "query")
        ollama = get_ollama_client(req.model)
        context, source = auto_context(
            query,
            max_lines=req.max_lines,
            k=req.k,
            hybrid=req.hybrid,
        )
        context_text = "\n".join(context)
        prompt = (
            "You are analyzing the active Salesforce metadata repo. "
            "Based ONLY on the context snippets, explain where the query appears "
            "and what it likely does. If the query is not in context, say so.\n\n"
            f"Query: {query}\n\nContext snippets (file:line):\n{context_text}"
        )
        explanation = ollama.chat(prompt)
        return RepoSearchResponse(
            query=query,
            context_source=source,
            context_lines=len(context),
            explanation=explanation,
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/repo/user-story", response_model=UserStoryResponse)
def repo_user_story(req: UserStoryRequest, api_key: str = Depends(get_api_key)):
    try:
        story = _require_non_empty_text(req.story, "story")
        ollama = get_ollama_client(req.model)
        context, source = auto_context(
            story,
            max_lines=req.max_lines,
            k=req.k,
            hybrid=req.hybrid,
        )
        context_text = "\n".join(context)
        prompt = (
            "You are analyzing the active Salesforce metadata repo. "
            "Given the user story and ONLY the context snippets, list impacted components "
            "(flows, Apex classes/triggers, LWCs, objects, layouts, approvals) and "
            "recommend next steps, risks, and tests. If context is insufficient, say so.\n\n"
            f"User story: {story}\n\nContext snippets (file:line):\n{context_text}"
        )
        recommendations = ollama.chat(prompt)
        return UserStoryResponse(
            story=story,
            context_source=source,
            context_lines=len(context),
            recommendations=recommendations,
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/repo/data-prompt", response_model=DataPromptResponse)
def repo_data_prompt(req: DataPromptRequest, api_key: str = Depends(get_api_key)):
    try:
        prompt_text = _require_non_empty_text(req.prompt, "prompt")
        ollama = get_ollama_client(req.model)
        prompt = (
            "Use ONLY the data provided to answer the prompt. "
            "If data is insufficient, say so.\n\n"
            f"Prompt: {prompt_text}\n\nData:\n{req.data}"
        )
        response = ollama.chat(prompt)
        return DataPromptResponse(prompt=prompt_text, response=response)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/feature-explain", response_model=FeatureExplainResponse)
def sf_repo_ai_feature_explain(req: FeatureExplainRequest, api_key: str = Depends(get_api_key)):
    try:
        prompt_text = req.prompt if req.prompt is not None else req.question
        payload = req.data if req.data is not None else req.evidence
        if prompt_text is None or payload is None:
            raise HTTPException(
                status_code=400,
                detail="Provide prompt/question and data/evidence.",
            )
        prompt_text = _require_non_empty_text(prompt_text, "prompt")
        return run_feature_explain(prompt_text, payload, req.model)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/user-story-analyze", response_model=UserStoryAnalyzeResponse)
def sf_repo_ai_user_story_analyze(req: UserStoryAnalyzeRequest, api_key: str = Depends(get_api_key)):
    try:
        req.story = _require_non_empty_text(req.story, "story")
        return run_user_story_analysis(req)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/debug-analyze", response_model=DebugAnalyzeResponse)
def sf_repo_ai_debug_analyze(req: DebugAnalyzeRequest, api_key: str = Depends(get_api_key)):
    try:
        req.input_text = _require_non_empty_text(req.input_text, "input_text")
        return run_debug_analysis(req)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/development/analyze", response_model=DevelopmentAnalyzeResponse)
def sf_repo_ai_development_analyze(req: DevelopmentAnalyzeRequest, api_key: str = Depends(get_api_key)):
    try:
        req.story = _require_non_empty_text(req.story, "story")
        store = OrchestrationStore()
        row = _resolve_or_create_work_item(
            store=store,
            work_item_id=req.work_item_id,
            title=req.title,
            story=req.story,
            model=req.model,
            metadata_project_dir=req.metadata_project_dir,
            target_org_alias=req.target_org_alias,
        )
        analyzed = sf_repo_ai_work_item_analyze(
            row["work_item_id"],
            WorkItemAnalyzeRequest(model=req.model, k=req.k, hybrid=req.hybrid, logs=req.logs),
            api_key="",
        )
        return DevelopmentAnalyzeResponse(
            work_item=analyzed,
            next_actions=_development_next_actions(work_item=analyzed),
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/development/plan", response_model=DevelopmentPlanResponse)
def sf_repo_ai_development_plan(req: DevelopmentPlanRequest, api_key: str = Depends(get_api_key)):
    try:
        req.story = _require_non_empty_text(req.story, "story")
        store = OrchestrationStore()
        row = _resolve_or_create_work_item(
            store=store,
            work_item_id=req.work_item_id,
            title=req.title,
            story=req.story,
            model=req.model,
            metadata_project_dir=req.metadata_project_dir,
            target_org_alias=req.target_org_alias,
        )
        if not row.get("analysis_json"):
            sf_repo_ai_work_item_analyze(
                row["work_item_id"],
                WorkItemAnalyzeRequest(model=req.model, k=req.k, hybrid=req.hybrid, logs=req.logs),
                api_key="",
            )
        generated = sf_repo_ai_work_item_generate_or_update_components(
            row["work_item_id"],
            WorkItemGenerateRequest(
                model=req.model,
                mode="plan_only",
                target_components=req.target_components,
                instructions=req.instructions,
                create_missing_components=req.create_missing_components,
                run_local_validation=req.run_local_validation,
                run_org_validation=req.run_org_validation,
                org_validation_test_level=req.org_validation_test_level,
                write_changes=False,
                max_targets=req.max_targets,
            ),
            api_key="",
        )
        refreshed = _work_item_response(store.get_work_item(row["work_item_id"]))
        return DevelopmentPlanResponse(
            work_item=refreshed,
            generation=generated,
            next_actions=_development_next_actions(work_item=refreshed, generation=generated),
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/development/run", response_model=DevelopmentRunResponse)
def sf_repo_ai_development_run(req: DevelopmentRunRequest, api_key: str = Depends(get_api_key)):
    try:
        req.story = _require_non_empty_text(req.story, "story")
        result = sf_repo_ai_work_item_run(req, api_key="")
        return DevelopmentRunResponse(
            work_item=result.work_item,
            stages=result.stages,
            next_actions=_development_next_actions(work_item=result.work_item, stages=result.stages),
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))



@app.post("/sf-repo-ai/work-items", response_model=WorkItemResponse)
def sf_repo_ai_work_item_create(req: WorkItemCreateRequest, api_key: str = Depends(get_api_key)):
    try:
        row = OrchestrationStore().create_work_item(
            story=req.story,
            title=req.title,
            llm_model=req.model or os.getenv("OLLAMA_MODEL", "gpt-oss:20b"),
            metadata_project_dir=_project_dir_or_default(req.metadata_project_dir),
            target_org_alias=req.target_org_alias,
            created_ts=_utc_now_iso(),
        )
        return _work_item_response(row)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/sf-repo-ai/work-items", response_model=WorkItemListResponse)
def sf_repo_ai_work_item_list(limit: int = 50, api_key: str = Depends(get_api_key)):
    try:
        rows = OrchestrationStore().list_work_items(limit=limit)
        return WorkItemListResponse(items=[_work_item_response(r) for r in rows])
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/sf-repo-ai/work-items/{work_item_id}", response_model=WorkItemResponse)
def sf_repo_ai_work_item_get(work_item_id: str, api_key: str = Depends(get_api_key)):
    try:
        row = OrchestrationStore().get_work_item(work_item_id)
        return _work_item_response(row)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/sf-repo-ai/work-items/{work_item_id}/executions", response_model=WorkItemExecutionListResponse)
def sf_repo_ai_work_item_executions(work_item_id: str, limit: int = 100, api_key: str = Depends(get_api_key)):
    try:
        rows = OrchestrationStore().list_executions(work_item_id=work_item_id, limit=limit)
        return WorkItemExecutionListResponse(executions=[_execution_response(r) for r in rows])
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/work-items/{work_item_id}/analyze", response_model=WorkItemResponse)
def sf_repo_ai_work_item_analyze(
    work_item_id: str,
    req: WorkItemAnalyzeRequest,
    api_key: str = Depends(get_api_key),
):
    try:
        store = OrchestrationStore()
        row = store.get_work_item(work_item_id)
        analysis = run_user_story_analysis(
            UserStoryAnalyzeRequest(
                story=row["story"],
                model=req.model or row.get("llm_model"),
                k=req.k,
                hybrid=req.hybrid,
                logs=req.logs,
            )
        )
        updated = store.update_work_item(
            work_item_id,
            updated_ts=_utc_now_iso(),
            status="ANALYZED",
            llm_model=analysis.model,
            analysis_json={
                "model": analysis.model,
                "initial_analysis": analysis.initial_analysis,
                "final_answer": analysis.final_answer,
            },
            impacted_components_json=analysis.components,
        )
        return _work_item_response(updated)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post(
    "/sf-repo-ai/work-items/{work_item_id}/generate-or-update-components",
    response_model=WorkItemGenerateResponse,
)
def sf_repo_ai_work_item_generate_or_update_components(
    work_item_id: str,
    req: WorkItemGenerateRequest,
    api_key: str = Depends(get_api_key),
):
    store = OrchestrationStore()
    try:
        row = store.get_work_item(work_item_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc))

    mode = (req.mode or "apply").strip().lower()
    if mode not in {"apply", "plan_only"}:
        raise HTTPException(status_code=400, detail="mode must be one of: apply, plan_only")

    if not row.get("analysis_json"):
        raise HTTPException(
            status_code=400,
            detail="Work item analysis is required before generation. Run /work-items/{id}/analyze first.",
        )

    if not row.get("impacted_components_json") and not req.target_components:
        raise HTTPException(
            status_code=400,
            detail="No impacted components are available. Provide target_components or run analysis again.",
        )

    project_dir = Path(row.get("metadata_project_dir") or _project_dir_or_default(None)).resolve()
    if not project_dir.exists():
        raise HTTPException(status_code=400, detail=f"Metadata project directory not found: {project_dir}")

    created_ts = _utc_now_iso()
    command_summary = f"model={req.model or row.get('llm_model') or os.getenv('OLLAMA_MODEL', 'gpt-oss:20b')} mode={mode}"
    execution = store.create_execution(
        operation_type="generate_or_update_components",
        work_item_id=work_item_id,
        created_ts=created_ts,
        command_summary=command_summary,
        request_payload=req.model_dump(),
    )

    artifact_root = Path("data/work_items") / work_item_id / "generation" / execution["execution_id"]
    store.update_work_item(
        work_item_id,
        updated_ts=_utc_now_iso(),
        status="GENERATING",
    )

    try:
        result = generate_or_update_components(
            project_dir=project_dir,
            work_item=row,
            model=req.model or row.get("llm_model"),
            mode=mode,
            target_components=req.target_components,
            instructions=req.instructions,
            create_missing_components=req.create_missing_components,
            run_local_validation=req.run_local_validation,
            run_org_validation=req.run_org_validation,
            org_validation_test_level=req.org_validation_test_level,
            write_changes=req.write_changes,
            artifact_root=artifact_root,
            target_org_alias=row.get("target_org_alias"),
            max_targets=req.max_targets,
        )

        result_payload = {
            "model": result.model,
            "status": result.status,
            "generation_summary": result.generation_summary,
            "changed_components": result.changed_components,
            "artifacts": result.artifacts,
            "validation": result.validation,
            "plan": result.plan,
        }
        store.update_execution(
            execution["execution_id"],
            status=result.status,
            updated_ts=_utc_now_iso(),
            command_summary=command_summary,
            result_payload=result_payload,
            exit_code=0 if result.status != "GENERATION_FAILED" else 1,
        )
        updated = store.update_work_item(
            work_item_id,
            updated_ts=_utc_now_iso(),
            status=result.status,
            llm_model=result.model,
            changed_components_json=result.changed_components,
            final_summary=result.generation_summary,
        )
        return WorkItemGenerateResponse(
            work_item_id=work_item_id,
            status=result.status,
            model=result.model,
            generation_summary=result.generation_summary,
            changed_components=result.changed_components,
            artifacts=result.artifacts,
            validation=result.validation,
            plan=result.plan,
            updated_work_item=_work_item_response(updated),
        )
    except Exception as exc:
        store.update_execution(
            execution["execution_id"],
            status="FAILED",
            updated_ts=_utc_now_iso(),
            command_summary=command_summary,
            result_payload={"error": str(exc), "artifact_root": str(artifact_root)},
            exit_code=1,
        )
        store.update_work_item(
            work_item_id,
            updated_ts=_utc_now_iso(),
            status="GENERATION_FAILED",
        )
        raise HTTPException(
            status_code=500,
            detail={
                "execution_id": execution["execution_id"],
                "operation_type": "generate_or_update_components",
                "error": str(exc),
            },
        )


@app.post(
    "/sf-repo-ai/work-items/{work_item_id}/approve-generation",
    response_model=WorkItemGenerateResponse,
)
def sf_repo_ai_work_item_approve_generation(
    work_item_id: str,
    req: WorkItemApproveGenerationRequest,
    api_key: str = Depends(get_api_key),
):
    store = OrchestrationStore()
    try:
        row = store.get_work_item(work_item_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc))

    try:
        selected_execution: Optional[Dict[str, Any]] = None
        if req.execution_id:
            selected_execution = store.get_execution(req.execution_id)
            if selected_execution.get("work_item_id") != work_item_id:
                raise HTTPException(status_code=400, detail="Execution does not belong to the specified work item.")
        else:
            for execution in store.list_executions(work_item_id=work_item_id, limit=100):
                request_json = execution.get("request_json") or {}
                result_json = execution.get("result_json") or {}
                if execution.get("operation_type") != "generate_or_update_components":
                    continue
                if str(request_json.get("mode") or "").lower() != "plan_only":
                    continue
                if not result_json.get("plan"):
                    continue
                selected_execution = execution
                break

        if not selected_execution:
            raise HTTPException(
                status_code=404,
                detail="No plan-only generation execution found to approve.",
            )

        request_json = selected_execution.get("request_json") or {}
        result_json = selected_execution.get("result_json") or {}
        plan = result_json.get("plan")
        if not isinstance(plan, dict) or not isinstance(plan.get("changes"), list):
            raise HTTPException(status_code=400, detail="Selected execution does not contain an approvable plan.")

        project_dir = Path(row.get("metadata_project_dir") or _project_dir_or_default(None)).resolve()
        if not project_dir.exists():
            raise HTTPException(status_code=400, detail=f"Metadata project directory not found: {project_dir}")

        created_ts = _utc_now_iso()
        command_summary = f"approve execution={selected_execution['execution_id']}"
        execution = store.create_execution(
            operation_type="approve_generation",
            work_item_id=work_item_id,
            created_ts=created_ts,
            command_summary=command_summary,
            request_payload={
                "source_execution_id": selected_execution["execution_id"],
                "run_local_validation": req.run_local_validation,
                "run_org_validation": req.run_org_validation,
                "org_validation_test_level": req.org_validation_test_level,
            },
        )
        artifact_root = Path("data/work_items") / work_item_id / "generation" / execution["execution_id"]
        store.update_work_item(work_item_id, updated_ts=_utc_now_iso(), status="GENERATING")
        try:
            result = generate_or_update_components(
                project_dir=project_dir,
                work_item=row,
                model=req.model or request_json.get("model") or row.get("llm_model"),
                mode="apply",
                target_components=request_json.get("target_components"),
                instructions=request_json.get("instructions"),
                create_missing_components=bool(request_json.get("create_missing_components", True)),
                run_local_validation=req.run_local_validation,
                run_org_validation=req.run_org_validation,
                org_validation_test_level=req.org_validation_test_level or request_json.get("org_validation_test_level"),
                write_changes=True,
                artifact_root=artifact_root,
                target_org_alias=row.get("target_org_alias"),
                plan_override=plan,
                max_targets=int(request_json.get("max_targets") or 12),
            )

            result_payload = {
                "model": result.model,
                "status": result.status,
                "generation_summary": result.generation_summary,
                "changed_components": result.changed_components,
                "artifacts": result.artifacts,
                "validation": result.validation,
                "plan": result.plan,
                "source_execution_id": selected_execution["execution_id"],
            }
            store.update_execution(
                execution["execution_id"],
                status=result.status,
                updated_ts=_utc_now_iso(),
                command_summary=command_summary,
                result_payload=result_payload,
                exit_code=0 if result.status != "GENERATION_FAILED" else 1,
            )
            updated = store.update_work_item(
                work_item_id,
                updated_ts=_utc_now_iso(),
                status=result.status,
                llm_model=result.model,
                changed_components_json=result.changed_components,
                final_summary=result.generation_summary,
            )
            return WorkItemGenerateResponse(
                work_item_id=work_item_id,
                status=result.status,
                model=result.model,
                generation_summary=result.generation_summary,
                changed_components=result.changed_components,
                artifacts=result.artifacts,
                validation=result.validation,
                plan=result.plan,
                updated_work_item=_work_item_response(updated),
            )
        except Exception as exc:
            store.update_execution(
                execution["execution_id"],
                status="FAILED",
                updated_ts=_utc_now_iso(),
                command_summary=command_summary,
                result_payload={"error": str(exc), "artifact_root": str(artifact_root)},
                exit_code=1,
            )
            store.update_work_item(
                work_item_id,
                updated_ts=_utc_now_iso(),
                status="GENERATION_FAILED",
            )
            raise
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))




@app.post("/sf-repo-ai/work-items/{work_item_id}/approve-deploy", response_model=WorkItemResponse)
def sf_repo_ai_work_item_approve_deploy(
    work_item_id: str,
    req: WorkItemApproveDeployRequest,
    api_key: str = Depends(get_api_key),
):
    store = OrchestrationStore()
    try:
        store.get_work_item(work_item_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc))

    executions = store.list_executions(work_item_id=work_item_id, limit=500)
    selected_generation: Optional[Dict[str, Any]] = None
    if req.execution_id:
        try:
            selected_generation = store.get_execution(req.execution_id)
        except KeyError as exc:
            raise HTTPException(status_code=404, detail=str(exc))
        if selected_generation.get("work_item_id") != work_item_id:
            raise HTTPException(status_code=400, detail="Execution does not belong to the specified work item.")
        if not _is_applied_generation_execution(selected_generation):
            raise HTTPException(
                status_code=400,
                detail="Selected execution is not an applied generation. Approve a successful apply generation first.",
            )
    else:
        selected_generation = _latest_applied_generation_execution(executions)
        if not selected_generation:
            raise HTTPException(
                status_code=400,
                detail="No applied generation found. Required sequence: plan -> approve generation -> approve deploy -> deploy.",
            )

    created_ts = _utc_now_iso()
    execution = store.create_execution(
        operation_type="approve_deploy",
        work_item_id=work_item_id,
        created_ts=created_ts,
        status="APPROVED",
        command_summary=f"approve_deploy source_execution={selected_generation['execution_id']}",
        request_payload={
            "source_execution_id": selected_generation["execution_id"],
            "notes": req.notes,
        },
    )
    store.update_execution(
        execution["execution_id"],
        status="APPROVED",
        updated_ts=_utc_now_iso(),
        result_payload={
            "message": "Deploy approved for latest generated changes.",
            "source_execution_id": selected_generation["execution_id"],
        },
        exit_code=0,
    )
    updated = store.update_work_item(
        work_item_id,
        updated_ts=_utc_now_iso(),
        status="DEPLOY_APPROVED",
    )
    return _work_item_response(updated)


@app.post("/sf-repo-ai/work-items/run", response_model=WorkItemRunResponse)
def sf_repo_ai_work_item_run(req: WorkItemRunRequest, api_key: str = Depends(get_api_key)):
    if req.generate and not req.analyze:
        raise HTTPException(status_code=400, detail="analyze must be true when generate is requested on a new work item")
    if req.generate and req.generate_mode.strip().lower() != "plan_only":
        raise HTTPException(
            status_code=400,
            detail="Only plan_only generation is allowed in /work-items/run. Use /work-items/{id}/approve-generation to apply approved changes.",
        )
    if req.auto_approve_generation:
        raise HTTPException(
            status_code=400,
            detail="auto_approve_generation is disabled. Explicit human approval is required via /work-items/{id}/approve-generation.",
        )
    if req.deploy:
        raise HTTPException(
            status_code=400,
            detail="Direct deploy from /work-items/run is disabled. Required sequence: plan -> approve generation -> approve deploy -> deploy.",
        )
    if req.retrieve_before_deploy:
        raise HTTPException(
            status_code=400,
            detail="retrieve_before_deploy is disabled in /work-items/run for gated workflow. Use retrieve endpoint explicitly when needed.",
        )
    store = OrchestrationStore()
    row = store.create_work_item(
        story=req.story,
        title=req.title,
        llm_model=req.model or os.getenv("OLLAMA_MODEL", "gpt-oss:20b"),
        metadata_project_dir=_project_dir_or_default(req.metadata_project_dir),
        target_org_alias=req.target_org_alias,
        created_ts=_utc_now_iso(),
    )
    work_item_id = row["work_item_id"]
    stages: List[Dict[str, Any]] = []

    try:
        if req.analyze:
            analyzed = sf_repo_ai_work_item_analyze(
                work_item_id,
                WorkItemAnalyzeRequest(model=req.model, k=12, hybrid=True),
                api_key="",
            )
            stages.append(
                {
                    "stage": "analyze",
                    "status": analyzed.status,
                    "analysis_model": analyzed.llm_model,
                    "impacted_components": len(analyzed.impacted_components or []),
                }
            )

        generated_response: Optional[WorkItemGenerateResponse] = None
        if req.generate:
            generate_response = sf_repo_ai_work_item_generate_or_update_components(
                work_item_id,
                WorkItemGenerateRequest(
                    model=req.model,
                    mode=req.generate_mode,
                    target_components=req.target_components,
                    instructions=req.instructions,
                    create_missing_components=req.create_missing_components,
                    run_local_validation=req.run_local_validation,
                    run_org_validation=req.run_org_validation,
                    org_validation_test_level=req.org_validation_test_level,
                    write_changes=req.generate_mode.strip().lower() != "plan_only",
                ),
                api_key="",
            )
            stages.append(
                {
                    "stage": "generate",
                    "status": generate_response.status,
                    "changed_components": len(generate_response.changed_components or []),
                    "validation": generate_response.validation,
                    "artifacts": generate_response.artifacts,
                }
            )
            generated_response = generate_response


        project_dir = Path(_project_dir_or_default(req.metadata_project_dir)).resolve()
        if req.retrieve_before_deploy:
            if not req.target_org_alias:
                raise HTTPException(status_code=400, detail="target_org_alias is required for retrieve_before_deploy")
            retrieve_response = sf_repo_ai_cli_retrieve(
                SfCliRetrieveRequest(
                    work_item_id=work_item_id,
                    target_org=req.target_org_alias,
                    project_dir=str(project_dir),
                    source_dirs=req.retrieve_source_dirs,
                    metadata=req.retrieve_metadata,
                    manifest=req.retrieve_manifest,
                    wait_minutes=req.retrieve_wait_minutes,
                    ignore_conflicts=True,
                ),
                api_key="",
            )
            stages.append(
                {
                    "stage": "retrieve",
                    "status": retrieve_response.status,
                    "execution_id": retrieve_response.execution_id,
                    "stderr": retrieve_response.stderr,
                }
            )

        if req.deploy:
            if not req.target_org_alias:
                raise HTTPException(status_code=400, detail="target_org_alias is required for deploy")
            deploy_source_dirs = req.deploy_source_dirs
            current = store.get_work_item(work_item_id)
            if not deploy_source_dirs and current.get("changed_components_json"):
                deploy_source_dirs = _derive_source_dirs_from_changed_components(
                    Path(current.get("metadata_project_dir") or str(project_dir)),
                    current.get("changed_components_json") or [],
                )
            if not deploy_source_dirs and not req.deploy_metadata and not req.deploy_manifest:
                raise HTTPException(
                    status_code=400,
                    detail="No deployable source paths found. Provide deploy_source_dirs/metadata/manifest or generate and approve changes first.",
                )
            deploy_response = sf_repo_ai_cli_deploy(
                SfCliDeployRequest(
                    work_item_id=work_item_id,
                    target_org=req.target_org_alias,
                    project_dir=str(project_dir),
                    source_dirs=deploy_source_dirs,
                    metadata=req.deploy_metadata,
                    manifest=req.deploy_manifest,
                    wait_minutes=req.deploy_wait_minutes,
                    dry_run=req.deploy_dry_run,
                    ignore_conflicts=req.deploy_ignore_conflicts,
                    test_level=req.deploy_test_level,
                    tests=req.deploy_tests,
                ),
                api_key="",
            )
            stages.append(
                {
                    "stage": "deploy",
                    "status": deploy_response.status,
                    "execution_id": deploy_response.execution_id,
                    "command": deploy_response.command,
                    "stderr": deploy_response.stderr,
                }
            )

        if req.run_tests:
            if not req.target_org_alias:
                raise HTTPException(status_code=400, detail="target_org_alias is required for run_tests")
            test_response = sf_repo_ai_cli_test(
                SfCliTestRequest(
                    work_item_id=work_item_id,
                    target_org=req.target_org_alias,
                    project_dir=str(project_dir),
                    wait_minutes=req.test_wait_minutes,
                    test_level=req.test_level,
                    tests=req.test_names,
                    class_names=req.test_class_names,
                    suite_names=req.test_suite_names,
                    code_coverage=True,
                ),
                api_key="",
            )
            stages.append(
                {
                    "stage": "test",
                    "status": test_response.status,
                    "execution_id": test_response.execution_id,
                    "command": test_response.command,
                    "stderr": test_response.stderr,
                }
            )

        final_row = store.get_work_item(work_item_id)
        final_status = final_row.get("status")
        if stages and all(str(stage.get("status") or "").upper() in {"ANALYZED", "AWAITING_APPROVAL", "GENERATED", "DEPLOYED", "TESTED", "SUCCEEDED"} for stage in stages):
            if final_status in {"GENERATED", "DEPLOYED", "TESTED"}:
                final_row = store.update_work_item(
                    work_item_id,
                    updated_ts=_utc_now_iso(),
                    status="COMPLETED",
                )
        return WorkItemRunResponse(work_item=_work_item_response(final_row), stages=stages)
    except HTTPException as exc:
        raise HTTPException(
            status_code=exc.status_code,
            detail={
                "work_item_id": work_item_id,
                "stages": stages,
                "error": exc.detail,
            },
        )
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail={
                "work_item_id": work_item_id,
                "stages": stages,
                "error": str(exc),
            },
        )



@app.get("/sf-repo-ai/sf-cli/orgs", response_model=WorkItemExecutionResponse)
def sf_repo_ai_cli_orgs(api_key: str = Depends(get_api_key)):
    response = _run_cli_operation(
        operation_type="sf_cli_list_orgs",
        work_item_id=None,
        request_payload={"all_orgs": True},
        runner=lambda: list_orgs(all_orgs=True),
    )
    return WorkItemExecutionResponse(
        execution_id=response.execution_id,
        work_item_id=response.work_item_id,
        operation_type=response.operation_type,
        status=response.status,
        command_summary=response.command,
        request={"all_orgs": True},
        result={
            "workdir": response.workdir,
            "data": response.data,
            "stdout": response.stdout,
            "stderr": response.stderr,
        },
        exit_code=response.exit_code,
        created_ts=response.created_ts,
        updated_ts=response.updated_ts,
    )



@app.post("/sf-repo-ai/sf-cli/deploy", response_model=SfCliCommandResponse)
def sf_repo_ai_cli_deploy(req: SfCliDeployRequest, api_key: str = Depends(get_api_key)):
    store = OrchestrationStore()
    if not req.work_item_id:
        raise HTTPException(
            status_code=400,
            detail="work_item_id is required for deploy. Required sequence: plan -> approve generation -> approve deploy -> deploy.",
        )
    row = _ensure_deploy_gate_approved(store, req.work_item_id)
    if row.get("target_org_alias") and row.get("target_org_alias") != req.target_org:
        raise HTTPException(
            status_code=400,
            detail=f"Deploy target org mismatch. Work item expects '{row.get('target_org_alias')}', received '{req.target_org}'.",
        )
    response = _run_cli_operation(
        operation_type="sf_cli_deploy",
        work_item_id=req.work_item_id,
        request_payload=req.model_dump(),
        runner=lambda: deploy_start(
            target_org=req.target_org,
            project_dir=Path(_project_dir_or_default(req.project_dir)),
            source_dirs=req.source_dirs,
            metadata=req.metadata,
            manifest=req.manifest,
            wait_minutes=req.wait_minutes,
            api_version=req.api_version,
            dry_run=req.dry_run,
            ignore_conflicts=req.ignore_conflicts,
            ignore_warnings=req.ignore_warnings,
            ignore_errors=req.ignore_errors,
            test_level=req.test_level,
            tests=req.tests,
        ),
        store=store,
    )
    if req.work_item_id:
        store.update_work_item(
            req.work_item_id,
            updated_ts=_utc_now_iso(),
            status="DEPLOYED" if response.status == "SUCCEEDED" else "DEPLOY_FAILED",
            target_org_alias=req.target_org,
            metadata_project_dir=_project_dir_or_default(req.project_dir),
            deployment_result_json={
                "execution_id": response.execution_id,
                "status": response.status,
                "exit_code": response.exit_code,
                "command": response.command,
                "workdir": response.workdir,
                "data": response.data,
                "stderr": response.stderr,
            },
        )
    return response


@app.post("/sf-repo-ai/sf-cli/retrieve", response_model=SfCliCommandResponse)
def sf_repo_ai_cli_retrieve(req: SfCliRetrieveRequest, api_key: str = Depends(get_api_key)):
    return _run_cli_operation(
        operation_type="sf_cli_retrieve",
        work_item_id=req.work_item_id,
        request_payload=req.model_dump(),
        runner=lambda: retrieve_start(
            target_org=req.target_org,
            project_dir=Path(_project_dir_or_default(req.project_dir)),
            source_dirs=req.source_dirs,
            metadata=req.metadata,
            manifest=req.manifest,
            output_dir=req.output_dir,
            wait_minutes=req.wait_minutes,
            api_version=req.api_version,
            ignore_conflicts=req.ignore_conflicts,
        ),
        store=OrchestrationStore(),
    )


@app.post("/sf-repo-ai/sf-cli/test", response_model=SfCliCommandResponse)
def sf_repo_ai_cli_test(req: SfCliTestRequest, api_key: str = Depends(get_api_key)):
    store = OrchestrationStore()
    response = _run_cli_operation(
        operation_type="sf_cli_test",
        work_item_id=req.work_item_id,
        request_payload=req.model_dump(),
        runner=lambda: apex_run_test(
            target_org=req.target_org,
            project_dir=Path(_project_dir_or_default(req.project_dir)),
            wait_minutes=req.wait_minutes,
            api_version=req.api_version,
            test_level=req.test_level,
            tests=req.tests,
            class_names=req.class_names,
            suite_names=req.suite_names,
            code_coverage=req.code_coverage,
            detailed_coverage=req.detailed_coverage,
            synchronous=req.synchronous,
            output_dir=req.output_dir,
        ),
        store=store,
    )
    if req.work_item_id:
        store.update_work_item(
            req.work_item_id,
            updated_ts=_utc_now_iso(),
            status="TESTED" if response.status == "SUCCEEDED" else "TEST_FAILED",
            test_result_json={
                "execution_id": response.execution_id,
                "status": response.status,
                "exit_code": response.exit_code,
                "command": response.command,
                "workdir": response.workdir,
                "data": response.data,
                "stderr": response.stderr,
            },
        )
    return response


@app.get("/sf-repo-ai/repos/connect/bitbucket/status", response_model=BitbucketConnectStatusResponse)
def sf_repo_ai_bitbucket_connect_status(api_key: str = Depends(get_api_key)):
    return _bitbucket_connection_snapshot()


@app.post("/sf-repo-ai/repos/connect/bitbucket/start", response_model=BitbucketConnectStatusResponse)
def sf_repo_ai_bitbucket_connect_start(api_key: str = Depends(get_api_key)):
    return BitbucketConnectStatusResponse(**bitbucket_start_connect_flow())


@app.get("/sf-repo-ai/repos/connect/bitbucket/callback", response_class=HTMLResponse)
def sf_repo_ai_bitbucket_connect_callback(code: Optional[str] = None, state: Optional[str] = None, error: Optional[str] = None, error_description: Optional[str] = None):
    if error:
        detail = escape(error_description or error)
        return HTMLResponse(f"<html><body><h1>Bitbucket connection failed</h1><p>{detail}</p></body></html>", status_code=400)
    try:
        result = bitbucket_complete_connect_flow(code or "", state)
        message = escape(str(result.get("message") or "Bitbucket connection completed."))
        return HTMLResponse(f"<html><body><h1>Bitbucket connected</h1><p>{message}</p><p>You can close this window and return to Salesforce.</p></body></html>")
    except Exception as exc:
        return HTMLResponse(f"<html><body><h1>Bitbucket connection failed</h1><p>{escape(str(exc))}</p></body></html>", status_code=400)


@app.post("/sf-repo-ai/repos/initialize", response_model=RepoInitializeResponse)
def sf_repo_ai_initialize_repo(req: RepoInitializeRequest, api_key: str = Depends(get_api_key)):
    provider = (req.provider or "bitbucket").strip().lower()
    connection = _bitbucket_connection_snapshot() if provider == "bitbucket" else None
    missing_inputs: List[str] = []
    next_actions: List[str] = []

    clone_url = (req.clone_url or "").strip()
    if not clone_url:
        missing_inputs.append("clone_url")
        next_actions.append("Provide the repository clone URL.")

    local_git_access = None
    if clone_url:
        local_git_access = probe_clone_access(clone_url=clone_url, provider=provider)

    if provider == "bitbucket" and not _clone_url_has_inline_credentials(clone_url):
        if not (local_git_access and local_git_access.get("ok")) and connection and not connection.connected:
            missing_inputs.append("bitbucket_connection")
            if connection.login_url:
                next_actions.append("Start Bitbucket connect and complete SSO/OAuth before cloning the repo.")
            else:
                next_actions.append("Configure backend Bitbucket credentials or connect URL before cloning a private Bitbucket repo.")

    defaults = {
        "provider": provider,
        "branch": (req.branch or "").strip() or None,
        "name": (req.name or "").strip() or _suggest_repo_name(clone_url),
        "sync_enabled": req.sync_enabled,
        "sync_interval_minutes": req.sync_interval_minutes,
        "active": req.active,
    }

    if missing_inputs:
        return RepoInitializeResponse(
            status="MISSING_INPUTS",
            provider=provider,
            connected=bool(connection.connected) if connection else True,
            missing_inputs=missing_inputs,
            message="Repo initialization is blocked until the missing setup inputs are provided.",
            defaults=defaults,
        next_actions=next_actions,
        source=None,
    )

    row = register_and_sync_repo(
        clone_url=clone_url,
        branch=defaults["branch"],
        provider=provider,
        name=defaults["name"],
        active=req.active,
        sync_enabled=req.sync_enabled,
        sync_interval_minutes=req.sync_interval_minutes,
    )
    return RepoInitializeResponse(
        status="INITIALIZED",
        provider=provider,
        connected=bool(connection.connected) if connection else True,
        missing_inputs=[],
        message="Repository registered, synced, and processed successfully.",
        defaults=defaults,
        next_actions=["Review repo status in the console.", "Start metadata-dependent analysis or development flows."],
        source=_repo_source_response(row),
    )


@app.get("/sf-repo-ai/repos/active", response_model=ActiveRepoResponse)
def sf_repo_ai_active_repo(api_key: str = Depends(get_api_key)):
    return _active_repo_response()


@app.post("/sf-repo-ai/setup/start", response_model=EnvironmentSetupStatusResponse)
def sf_repo_ai_environment_setup_start(req: EnvironmentSetupRequest, api_key: str = Depends(get_api_key)):
    if req.run_id:
        payload = continue_environment_setup(
            run_id=req.run_id,
            provider=req.provider,
            clone_url=req.clone_url,
            branch=req.branch,
            name=req.name,
            project_namespace=req.project_namespace,
            start_ngrok=req.start_ngrok,
        )
    else:
        payload = start_environment_setup(
            provider=req.provider or "bitbucket",
            clone_url=req.clone_url,
            branch=req.branch,
            name=req.name,
            project_namespace=req.project_namespace,
            start_ngrok=req.start_ngrok,
        )
    return _environment_setup_response(payload)


@app.get("/sf-repo-ai/setup/status", response_model=EnvironmentSetupStatusResponse)
def sf_repo_ai_environment_setup_status(run_id: Optional[str] = None, project_namespace: Optional[str] = None, api_key: str = Depends(get_api_key)):
    return _environment_setup_response(get_environment_setup_status(run_id, project_namespace))


@app.post("/sf-repo-ai/projects/{project_namespace}/setup/start", response_model=EnvironmentSetupStatusResponse)
def sf_repo_ai_project_environment_setup_start(project_namespace: str, req: EnvironmentSetupRequest, api_key: str = Depends(get_api_key)):
    request = req.model_copy(update={"project_namespace": project_namespace})
    return sf_repo_ai_environment_setup_start(request, api_key)


@app.get("/sf-repo-ai/projects/{project_namespace}/setup/status", response_model=EnvironmentSetupStatusResponse)
def sf_repo_ai_project_environment_setup_status(project_namespace: str, run_id: Optional[str] = None, api_key: str = Depends(get_api_key)):
    return _environment_setup_response(get_environment_setup_status(run_id, project_namespace))


@app.get("/sf-repo-ai/projects/{project_namespace}/health", response_model=EnvironmentSetupStatusResponse)
def sf_repo_ai_project_health(project_namespace: str, api_key: str = Depends(get_api_key)):
    return _environment_setup_response(get_environment_setup_status(None, project_namespace))


@app.get("/sf-repo-ai/repos", response_model=RepoSourceListResponse)
def sf_repo_ai_list_repos(api_key: str = Depends(get_api_key)):
    registry = RepoRegistry()
    rows = registry.list_sources()
    return RepoSourceListResponse(
        active_repo_path=str(resolve_active_repo()),
        sources=[_repo_source_response(row) for row in rows],
    )


@app.post("/sf-repo-ai/repos/register", response_model=RepoSourceResponse)
def sf_repo_ai_register_repo(req: RepoSourceRegisterRequest, api_key: str = Depends(get_api_key)):
    row = register_and_sync_repo(
        clone_url=req.clone_url,
        branch=req.branch,
        provider=req.provider,
        name=req.name,
        active=req.active,
        sync_enabled=req.sync_enabled,
        sync_interval_minutes=req.sync_interval_minutes,
    )
    return _repo_source_response(row)


@app.post("/sf-repo-ai/repos/register/bitbucket", response_model=RepoSourceResponse)
def sf_repo_ai_register_bitbucket_repo(req: RepoSourceRegisterRequest, api_key: str = Depends(get_api_key)):
    row = register_and_sync_repo(
        clone_url=req.clone_url,
        branch=req.branch,
        provider=req.provider or "bitbucket",
        name=req.name,
        active=req.active,
        sync_enabled=req.sync_enabled,
        sync_interval_minutes=req.sync_interval_minutes,
    )
    return _repo_source_response(row)


@app.post("/sf-repo-ai/repos/{source_id}/activate", response_model=RepoSourceResponse)
def sf_repo_ai_activate_repo(source_id: str, api_key: str = Depends(get_api_key)):
    registry = RepoRegistry()
    row = registry.get_source(source_id)
    repo_path = Path(row["local_path"]).resolve()
    if not repo_path.exists():
        raise HTTPException(status_code=400, detail=f"Local repo path not found: {repo_path}")
    validation = validate_repo_structure(repo_path)
    if validation.get("validation_status") != "VALID":
        updated = registry.update_source(
            source_id,
            updated_ts=_utc_now_iso(),
            validation_status=validation.get("validation_status"),
            validation_error=validation.get("validation_error"),
            last_index_status="FAILED",
            last_index_error=validation.get("validation_error"),
        )
        raise HTTPException(status_code=400, detail={"message": "Repo validation failed", "source": _repo_source_response(updated).model_dump()})
    index_info = ensure_runtime_indexes(repo_path=repo_path, rebuild=True)
    set_active_repo(repo_path)
    updated = registry.update_source(
        source_id,
        updated_ts=_utc_now_iso(),
        is_active=1,
        last_sync_error=None,
        repo_kind=validation.get("repo_kind"),
        has_sfdx_project=1 if validation.get("has_sfdx_project") else 0,
        has_force_app=1 if validation.get("has_force_app") else 0,
        metadata_root=validation.get("metadata_root"),
        validation_status=validation.get("validation_status"),
        validation_error=validation.get("validation_error"),
        objects_count=int(validation.get("objects_count") or 0),
        fields_count=int(validation.get("fields_count") or 0),
        classes_count=int(validation.get("classes_count") or 0),
        triggers_count=int(validation.get("triggers_count") or 0),
        flows_count=int(validation.get("flows_count") or 0),
        last_indexed_ts=_utc_now_iso(),
        last_indexed_commit=row.get("last_synced_commit"),
        last_index_status="SUCCEEDED",
        last_index_error=None,
        docs_count=int(index_info.get("docs_count") or 0),
        meta_files=int(index_info.get("meta_files") or 0),
        graph_nodes=int(index_info.get("graph_nodes") or 0),
        graph_edges=int(index_info.get("graph_edges") or 0),
    )
    return _repo_source_response(updated)


@app.post("/sf-repo-ai/repos/{source_id}/sync", response_model=RepoSourceResponse)
def sf_repo_ai_sync_repo(source_id: str, api_key: str = Depends(get_api_key)):
    row = sync_repo_by_id(source_id, registry=RepoRegistry())
    return _repo_source_response(row)


@app.post("/sf-repo-ai/repos/sync-due", response_model=RepoSourceListResponse)
def sf_repo_ai_sync_due(api_key: str = Depends(get_api_key)):
    registry = RepoRegistry()
    sync_due_repos(registry=registry)
    rows = registry.list_sources()
    return RepoSourceListResponse(
        active_repo_path=str(resolve_active_repo()),
        sources=[_repo_source_response(row) for row in rows],
    )


@app.post("/sf-repo-ai/repos/cleanup", response_model=RepoCleanupResponse)
def sf_repo_ai_cleanup_repos(req: RepoCleanupRequest, api_key: str = Depends(get_api_key)):
    registry = RepoRegistry()
    removed = registry.cleanup_inactive_sources(max_age_days=req.max_age_days, delete_local=req.delete_local)
    return RepoCleanupResponse(removed=[_repo_source_response(row) for row in removed])


@app.get("/sf-repo-ai/index/stats", response_model=IndexStatsResponse)
def sf_repo_ai_index_stats(api_key: str = Depends(get_api_key)):
    return _active_index_stats()


@app.get("/sf-repo-ai/index/metadata", response_model=MetadataInventoryResponse)
def sf_repo_ai_index_metadata(api_key: str = Depends(get_api_key)):
    return _active_metadata_inventory()


@app.get("/sf-repo-ai/index/objects", response_model=IndexedObjectsResponse)
def sf_repo_ai_index_objects(api_key: str = Depends(get_api_key)):
    repo_path = resolve_active_repo()
    objs = [IndexedObjectResponse(**item) for item in list_objects(repo_path)]
    return IndexedObjectsResponse(active_repo_path=str(repo_path), total=len(objs), objects=objs)


@app.get("/sf-repo-ai/index/objects/{object_api_name}/fields", response_model=IndexedFieldsResponse)
def sf_repo_ai_index_object_fields(object_api_name: str, api_key: str = Depends(get_api_key)):
    repo_path = resolve_active_repo()
    fields = [IndexedFieldResponse(**item) for item in list_fields(repo_path, object_api_name)]
    return IndexedFieldsResponse(active_repo_path=str(repo_path), object_api_name=object_api_name, total=len(fields), fields=fields)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/sf-repo-ai/health")
def sf_repo_ai_health():
    return {"status": "ok", "service": "sf-repo-ai-adapter"}


@app.post("/sf-repo-ai/ask", response_model=SfRepoAskResponse)
def sf_repo_ai_ask(req: SfRepoAskRequest, api_key: str = Depends(get_api_key)):
    try:
        req.question = _require_non_empty_text(req.question, "question")
        object_hint = req.object_api_name if req.object_api_name else None
        ap_inventory = _approval_process_inventory_response(req.question, object_hint=object_hint)
        if ap_inventory is not None:
            response = ap_inventory
        else:
            flow_inventory = _flow_inventory_response(req.question, object_hint=object_hint)
            if flow_inventory is not None:
                response = flow_inventory
            elif req.evidence_only and req.evidence is not None:
                response = run_evidence_prompt(
                    question=req.question,
                    model_override=req.model,
                    evidence=req.evidence,
                )
            else:
                response = run_agent(
                    user_prompt=req.question,
                    model_override=req.model,
                    use_sfdc=req.use_sfdc,
                    hybrid=req.hybrid,
                    k=req.k,
                )
        return SfRepoAskResponse(
            question=req.question,
            record_id=req.record_id,
            object_api_name=req.object_api_name,
            intent=response.intent,
            needs_approval=response.needs_approval,
            tool_results=response.tool_results,
            final_answer=response.final_answer,
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))
