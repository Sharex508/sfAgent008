from __future__ import annotations

import json
import os
import re
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional

from fastapi import FastAPI, HTTPException, Header, Security, Depends, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
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
from orchestration import (
    GenerationResult,
    OrchestrationStore,
    apex_run_test,
    default_project_dir,
    deploy_start,
    generate_or_update_components,
    list_orgs,
    login_access_token,
    retrieve_start,
)
from process.capture import ingest_video, record_ui_event, save_process, start_capture, stop_capture
from process.storage import CaptureStore
from retrieval.vector_store import search_metadata
from sfdc.client import SalesforceClient
from sfdc.tooling_client import SalesforceToolingClient
from server.repo_context import auto_context

API_KEY_NAME = "X-API-Key"
api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=False)

def get_api_key(api_key: str = Security(api_key_header)):
    expected_key = os.getenv("AGENT_API_KEY")
    if expected_key and api_key != expected_key:
        raise HTTPException(status_code=403, detail="Could not validate API Key")
    return api_key

class AskRequest(BaseModel):
    user_prompt: str = Field(..., description="Natural language request")
    model: Optional[str] = Field(None, description="Ollama model name, e.g., llama3.1:8b or gpt-oss:20b")
    use_sfdc: bool = Field(False, description="Enable Salesforce tools (env creds required)")
    hybrid: bool = Field(True, description="Use hybrid retrieval for metadata search")
    k: int = Field(8, description="Number of retrieval results")
    single_llm_pass: bool = Field(
        True,
        description="If true, skip LLM planning and run deterministic metadata retrieval + one final LLM synthesis.",
    )
    use_final_llm: bool = Field(
        False,
        description="If true, run a final LLM synthesis step. Keep false for fastest/stable responses.",
    )


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
    single_llm_pass: bool = Field(
        True,
        description="If true, skip LLM planning and run deterministic metadata retrieval + one final LLM synthesis.",
    )
    use_final_llm: bool = Field(
        False,
        description="If true, run a final LLM synthesis step. Keep false for fastest/stable responses.",
    )
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


class SfAuthRequest(BaseModel):
    login_url: Optional[str] = Field(None, description="Salesforce login URL, e.g. https://test.salesforce.com")
    username: Optional[str] = Field(None, description="Salesforce username")
    password: Optional[str] = Field(None, description="Salesforce password (without token)")
    token: Optional[str] = Field(None, description="Salesforce security token")
    client_id: Optional[str] = Field(None, description="Connected app client id (consumer key)")
    client_secret: Optional[str] = Field(None, description="Connected app client secret")
    auth_mode: Optional[str] = Field(
        None,
        description="Auth mode: soap | oauth_password | oauth_client_credentials (auto by default).",
    )
    api_version: Optional[str] = Field(None, description="Salesforce API version, e.g. 60.0")


class TraceEnableRequest(SfAuthRequest):
    user: Optional[str] = Field(None, description="Optional Salesforce username or user Id (005...) to trace")
    minutes: int = Field(30, description="Trace expiration in minutes")
    level: str = Field("FINEST", description="Debug level label hint")


class TraceEnableResponse(BaseModel):
    user_id: str
    debug_level_id: str
    trace_flag_id: str
    minutes: int


class TraceDisableRequest(SfAuthRequest):
    user: Optional[str] = Field(None, description="Optional Salesforce username or user Id (005...) to trace")


class TraceDisableResponse(BaseModel):
    user_id: str
    trace_flags_updated: int


class ProcessCaptureStartRequest(SfAuthRequest):
    user: Optional[str] = Field(None, description="Optional Salesforce username or user Id (005...) to trace")
    minutes: int = Field(10, description="Trace capture duration in minutes")
    tail_seconds: int = Field(120, description="Extra seconds after stop for async logs")
    filter_text: Optional[str] = Field(None, description="Optional keyword filter for stop-time analysis")


class ProcessCaptureStartResponse(BaseModel):
    capture_id: str
    marker_text: str
    start_ts: str
    trace_flag_id: str
    debug_level_id: str
    execute_anonymous: Dict[str, Any]


class ProcessCaptureStepMarkerRequest(SfAuthRequest):
    capture_id: str = Field(..., description="Capture id returned by process-capture/start")
    step_name: str = Field(..., description="Human-readable step name, e.g. Create Account")


class ProcessCaptureStepMarkerResponse(BaseModel):
    capture_id: str
    step_name: str
    execute_anonymous: Dict[str, Any]


class ProcessCaptureUiEventRequest(BaseModel):
    capture_id: str = Field(..., description="Capture id returned by process-capture/start")
    event_type: str = Field(..., description="UI event type, e.g. LWC_CONNECTED, BUTTON_CLICK, NAVIGATE")
    component_name: Optional[str] = Field(None, description="Component or bundle name, e.g. c:createNattOppLwc")
    action_name: Optional[str] = Field(None, description="Action label, e.g. Submit or Next")
    element_label: Optional[str] = Field(None, description="Clicked element label or identifier")
    page_url: Optional[str] = Field(None, description="Browser page URL at the time of the event")
    record_id: Optional[str] = Field(None, description="Optional current Salesforce record id")
    details: Optional[Dict[str, Any]] = Field(None, description="Optional JSON payload with extra UI context")
    event_ts: Optional[str] = Field(None, description="Optional ISO timestamp from the browser/client")


class ProcessCaptureUiEventResponse(BaseModel):
    event_id: str
    capture_id: str
    event_ts: str
    event_type: str
    component_name: Optional[str]
    action_name: Optional[str]
    element_label: Optional[str]
    page_url: Optional[str]
    record_id: Optional[str]
    details: Dict[str, Any]


class ProcessCaptureStopRequest(SfAuthRequest):
    capture_id: str = Field(..., description="Capture id returned by process-capture/start")
    analyze: bool = Field(True, description="Parse logs and generate trace artifacts")
    llm: bool = Field(False, description="Generate optional LLM narration from trace artifacts")
    llm_model: str = Field("gpt-oss:20b", description="Ollama model for narration")
    ollama_host: Optional[str] = Field(None, description="Ollama host override, e.g. http://localhost:11434")


class ProcessCaptureStopResponse(BaseModel):
    capture_id: str
    start_ts: str
    end_ts: str
    fetched_logs: int
    analyzed_logs: int
    marker_matched_logs: int
    artifact_paths: List[str]
    graph_hash: str
    llm_used: bool
    llm_model: Optional[str]
    narration_path: Optional[str]
    llm_error: Optional[str]


class ProcessSaveRequest(BaseModel):
    capture_id: str = Field(..., description="Capture id that already has TRACE_JSON artifact")
    name: str = Field(..., description="Process name to save/version")
    description: Optional[str] = Field(None, description="Optional process description")


class ProcessSaveResponse(BaseModel):
    process_id: str
    name: str
    version: int
    latest_capture_id: str
    graph_hash: str


class ProcessListItem(BaseModel):
    process_id: str
    name: str
    description: Optional[str]
    entry_points: List[str]
    latest_capture_id: Optional[str]
    graph_hash: Optional[str]
    version: int
    last_verified_at: str


class ProcessListResponse(BaseModel):
    processes: List[ProcessListItem]


class ProcessRunListItem(BaseModel):
    run_id: str
    process_name: str
    capture_id: str
    trace_json_path: str
    created_ts: str
    ui_invoker: Optional[str] = None
    ui_invoker_source: Optional[str] = None
    ui_invoker_confidence: Optional[str] = None
    step_count: int
    component_count: int


class ProcessRunListResponse(BaseModel):
    process_name: Optional[str]
    runs: List[ProcessRunListItem]


class ProcessRunSequenceStep(BaseModel):
    seq_no: int
    log_id: Optional[str]
    details: Dict[str, Any]


class ProcessRunSequenceComponent(BaseModel):
    seq_no: int
    component_type: str
    component_name: str
    log_id: Optional[str]
    confidence: Optional[str]


class ProcessRunSequenceResponse(BaseModel):
    run_id: str
    process_name: str
    capture_id: str
    trace_json_path: str
    created_ts: str
    ui_invoker: Optional[str] = None
    ui_invoker_source: Optional[str] = None
    ui_invoker_confidence: Optional[str] = None
    steps: List[ProcessRunSequenceStep]
    components: List[ProcessRunSequenceComponent]


class CreatedRecordItem(BaseModel):
    step_no: int
    log_id: Optional[str]
    object_api_name: Optional[str]
    record_id: str
    source_key: str
    confidence: str


class ProcessRunCreatedRecordsResponse(BaseModel):
    run_id: str
    capture_id: str
    ui_invoker: Optional[str] = None
    ui_invoker_source: Optional[str] = None
    ui_invoker_confidence: Optional[str] = None
    created_records: List[CreatedRecordItem]
    count: int


class ProcessRunReadableComponentItem(BaseModel):
    seq_no: int
    step_no: int
    step_label: Optional[str]
    start_time: Optional[str]
    operation: Optional[str]
    location: Optional[str]
    component_type: str
    component_name: str
    log_id: Optional[str]
    confidence: Optional[str]


class ProcessRunReadableComponentsResponse(BaseModel):
    run_id: str
    capture_id: str
    ui_invoker: Optional[str]
    ui_invoker_source: Optional[str]
    ui_invoker_confidence: Optional[str]
    components: List[ProcessRunReadableComponentItem]
    count: int


class ProcessRunInvokerUpdateRequest(BaseModel):
    ui_invoker: str = Field(..., description="Invoker component name, e.g. c:createNattOppLwc")
    ui_invoker_source: str = Field("manual", description="Source label, e.g. manual|artifact_explicit|artifact_heuristic")
    ui_invoker_confidence: str = Field("HIGH", description="Confidence label, e.g. HIGH|MED|LOW")
    notes: Optional[str] = Field(None, description="Optional notes")


class ProcessRunInvokerUpdateResponse(BaseModel):
    run_id: str
    ui_invoker: Optional[str]
    ui_invoker_source: Optional[str]
    ui_invoker_confidence: Optional[str]
    notes: Optional[str]
    updated_ts: str


class ApexExecuteAnonymousRequest(SfAuthRequest):
    anonymous_body: str = Field(..., description="Apex anonymous block to execute.")


class ApexExecuteAnonymousResponse(BaseModel):
    result: Dict[str, Any]


class ProcessVideoIngestRequest(BaseModel):
    capture_id: str = Field(..., description="Capture id for which video is attached")
    video_path: str = Field(..., description="Local video path (phase-2 stub)")
    analyze: bool = Field(True, description="Run video-to-steps analysis")
    llm_model: str = Field("gpt-oss:20b", description="Text model for step synthesis")
    vision_model: Optional[str] = Field(None, description="Optional vision model override")
    ollama_host: Optional[str] = Field(None, description="Ollama host override")
    interval_seconds: int = Field(5, description="Frame sample interval in seconds")
    max_frames: int = Field(80, description="Max sampled frames")


class ProcessVideoIngestResponse(BaseModel):
    capture_id: str
    artifact_path: str
    status: str
    step_count: int
    vision_used: bool
    vision_model: Optional[str]
    llm_model: Optional[str]


class ProcessVideoUploadResponse(BaseModel):
    capture_id: str
    uploaded_file_path: str
    uploaded_file_name: str
    uploaded_size_bytes: int
    artifact_path: str
    status: str
    step_count: int
    vision_used: bool
    vision_model: Optional[str]
    llm_model: Optional[str]


class WorkItemCreateRequest(BaseModel):
    title: Optional[str] = Field(None, description="Short work item title")
    story: str = Field(..., description="User story or enhancement request")
    model: Optional[str] = Field(None, description="Ollama model override")
    metadata_project_dir: Optional[str] = Field(None, description="SFDX project directory; defaults to NATTQA-ENV")
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


class WorkItemRunRequest(BaseModel):
    title: Optional[str] = Field(None, description="Optional work item title")
    story: str = Field(..., description="User story or implementation request")
    model: Optional[str] = Field(None, description="Ollama model override")
    metadata_project_dir: Optional[str] = Field(None, description="Metadata project directory")
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


class SfCliLoginRequest(SfAuthRequest):
    alias: str = Field(..., description="CLI alias to create/update")
    set_default: bool = Field(False, description="Set the alias as default org in CLI")


class SfCliDeployRequest(BaseModel):
    work_item_id: Optional[str] = Field(None, description="Optional work item to attach execution to")
    target_org: str = Field(..., description="Salesforce CLI alias or username")
    project_dir: Optional[str] = Field(None, description="SFDX project directory; defaults to NATTQA-ENV")
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
    project_dir: Optional[str] = Field(None, description="SFDX project directory; defaults to NATTQA-ENV")
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
    project_dir: Optional[str] = Field(None, description="SFDX project directory; defaults to NATTQA-ENV")
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


def get_ollama_client(model_override: Optional[str] = None) -> OllamaClient:
    host = os.getenv("OLLAMA_HOST", "http://localhost:11434")
    model = model_override or os.getenv("OLLAMA_MODEL", "gpt-oss:20b")
    return OllamaClient(host=host, model=model)


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


def get_tooling_client(auth: SfAuthRequest) -> SalesforceToolingClient:
    login_url = auth.login_url or os.getenv("SF_LOGIN_URL") or "https://login.salesforce.com"
    api_version = auth.api_version or os.getenv("SF_API_VERSION") or "60.0"
    auth_mode = (auth.auth_mode or "").strip().lower()

    if not auth_mode:
        if (auth.client_id or os.getenv("SF_CLIENT_ID")) and (auth.client_secret or os.getenv("SF_CLIENT_SECRET")):
            if auth.username or os.getenv("SF_USERNAME"):
                auth_mode = "oauth_password"
            else:
                auth_mode = "oauth_client_credentials"
        else:
            auth_mode = "soap"

    if auth_mode == "oauth_password":
        return SalesforceToolingClient.from_oauth_password(
            login_url=login_url,
            client_id=auth.client_id or os.getenv("SF_CLIENT_ID"),
            client_secret=auth.client_secret or os.getenv("SF_CLIENT_SECRET"),
            username=auth.username or os.getenv("SF_USERNAME"),
            password=auth.password or os.getenv("SF_PASSWORD"),
            token=auth.token if auth.token is not None else os.getenv("SF_SECURITY_TOKEN"),
            api_version=api_version,
        )
    if auth_mode == "oauth_client_credentials":
        return SalesforceToolingClient.from_oauth_client_credentials(
            login_url=login_url,
            client_id=auth.client_id or os.getenv("SF_CLIENT_ID"),
            client_secret=auth.client_secret or os.getenv("SF_CLIENT_SECRET"),
            api_version=api_version,
        )

    return SalesforceToolingClient.from_soap_login(
        login_url=login_url,
        username=auth.username or os.getenv("SF_USERNAME"),
        password=auth.password or os.getenv("SF_PASSWORD"),
        token=auth.token if auth.token is not None else os.getenv("SF_SECURITY_TOKEN"),
        api_version=api_version,
    )


def _resolve_trace_user(client: SalesforceToolingClient, auth: SfAuthRequest, requested_user: Optional[str]) -> str:
    if requested_user and requested_user.strip():
        return requested_user.strip()
    if auth.username and auth.username.strip():
        return auth.username.strip()
    env_user = os.getenv("SF_USERNAME")
    if env_user and env_user.strip():
        return env_user.strip()
    me = client.get_current_user()
    uid = str(me.get("id") or "").strip()
    if uid:
        return uid
    raise RuntimeError("Unable to resolve trace user. Provide `user` once or use oauth_password with username.")


def _infer_object_from_source_key(source_key: str) -> Optional[str]:
    u = (source_key or "").upper()
    if "ACCOUNT" in u:
        return "Account"
    if "OPPORTUNITY" in u:
        return "Opportunity"
    if "QUOTE" in u:
        return "SBQQ__Quote__c"
    if "CASE" in u:
        return "Case"
    if "CONTACT" in u:
        return "Contact"
    if "LEAD" in u:
        return "Lead"
    if "ORDER" in u:
        return "Order"
    return None


def _extract_created_records_for_run(run_data: Dict[str, Any]) -> List[Dict[str, Any]]:
    trace_path = Path(str(run_data.get("trace_json_path") or ""))
    if not trace_path.exists():
        return []

    log_to_step: Dict[str, int] = {}
    for s in run_data.get("steps") or []:
        log_id = str(s.get("log_id") or "")
        if log_id:
            log_to_step[log_id] = int(s.get("seq_no") or 0)

    payload = json.loads(trace_path.read_text(encoding="utf-8"))
    logs = payload.get("logs") or []
    ui_events = payload.get("ui_events") or []
    out: List[Dict[str, Any]] = []
    seen: set[tuple[int, str, str]] = set()

    for lg in logs:
        if not isinstance(lg, dict):
            continue
        log_id = str(lg.get("log_id") or "")
        step_no = int(log_to_step.get(log_id, 0))

        # High-confidence: explicit debug markers like VIDEO_REPRO_ACCOUNT_ID=001...
        for item in lg.get("debug_ids") or []:
            if not isinstance(item, dict):
                continue
            source_key = str(item.get("key") or "").strip()
            record_id = str(item.get("record_id") or "").strip()
            if not record_id:
                continue
            k = (step_no, log_id, record_id)
            if k in seen:
                continue
            seen.add(k)
            out.append(
                {
                    "step_no": step_no,
                    "log_id": log_id or None,
                    "object_api_name": _infer_object_from_source_key(source_key),
                    "record_id": record_id,
                    "source_key": source_key or "DEBUG_ID",
                    "confidence": "HIGH",
                }
            )

    for ev in ui_events:
        if not isinstance(ev, dict):
            continue
        event_id = str(ev.get("event_id") or "").strip()
        log_id = f"UI:{event_id}" if event_id else ""
        step_no = int(log_to_step.get(log_id, 0))
        details = ev.get("details") or {}
        if not isinstance(details, dict):
            details = {}

        explicit_pairs: List[tuple[Optional[str], str, str]] = []
        record_id = str(ev.get("record_id") or "").strip()
        if record_id:
            explicit_pairs.append((str(details.get("objectApiName") or "").strip() or None, record_id, "UI_EVENT_RECORD_ID"))
        created_record_id = str(details.get("createdRecordId") or "").strip()
        if created_record_id:
            explicit_pairs.append(
                (
                    str(details.get("createdObjectApiName") or details.get("objectApiName") or "").strip() or None,
                    created_record_id,
                    "UI_EVENT_CREATED_RECORD_ID",
                )
            )

        for object_api_name, explicit_record_id, source_key in explicit_pairs:
            k = (step_no, log_id, explicit_record_id)
            if k in seen:
                continue
            seen.add(k)
            out.append(
                {
                    "step_no": step_no,
                    "log_id": log_id or None,
                    "object_api_name": object_api_name,
                    "record_id": explicit_record_id,
                    "source_key": source_key,
                    "confidence": "HIGH",
                }
            )

    out.sort(key=lambda r: (int(r.get("step_no") or 0), str(r.get("log_id") or ""), str(r.get("record_id") or "")))
    return out


def _format_dep(dep: Dict[str, Any]) -> str:
    kind = str(dep.get("kind") or "").strip() or "Unknown"
    name = str(dep.get("name") or dep.get("doc_id") or "").strip() or "Unknown"
    return f"{kind}:{name}"


def _edge_lines(prefix: str, deps: List[Dict[str, Any]], *, max_items_per_edge: int = 8) -> List[str]:
    grouped: Dict[str, List[str]] = {}
    for dep in deps:
        edge = str(dep.get("edge_kind") or "related_to").strip() or "related_to"
        grouped.setdefault(edge, []).append(_format_dep(dep))

    lines: List[str] = []
    for edge in sorted(grouped.keys()):
        vals = grouped[edge]
        shown = vals[:max_items_per_edge]
        suffix = ""
        if len(vals) > len(shown):
            suffix = f", +{len(vals) - len(shown)} more"
        lines.append(f"{prefix}.{edge}: {', '.join(shown)}{suffix}")
    return lines


def _display_path(path_text: str) -> str:
    if not path_text:
        return ""
    try:
        p = Path(path_text)
        if p.is_absolute():
            return str(p.resolve().relative_to(Path.cwd().resolve()))
        return str(p)
    except Exception:
        return path_text


def _build_dependency_appendix(
    tool_results: List[Dict[str, Any]],
    *,
    max_components: int = 8,
    max_neighbors: int = 10,
) -> str:
    components: List[Dict[str, Any]] = []
    seen: set[tuple[str, str]] = set()
    for tr in tool_results:
        if tr.get("tool") != "search_metadata":
            continue
        result = tr.get("result") or {}
        if not isinstance(result, dict) or not result.get("ok"):
            continue
        for item in result.get("results") or []:
            if not isinstance(item, dict):
                continue
            deps = item.get("dependencies") or {}
            outbound = deps.get("outbound") or []
            inbound = deps.get("inbound") or []
            if not outbound and not inbound:
                continue
            key = (str(item.get("kind") or ""), str(item.get("name") or ""))
            if key in seen:
                continue
            seen.add(key)
            components.append(
                {
                    "kind": str(item.get("kind") or ""),
                    "name": str(item.get("name") or ""),
                    "path": _display_path(str(item.get("path") or "")),
                    "outbound": outbound[:max_neighbors],
                    "inbound": inbound[:max_neighbors],
                }
            )

    if not components:
        return ""

    def _edge_kinds(comp: Dict[str, Any]) -> List[str]:
        out_kinds = [str(d.get("edge_kind") or "") for d in (comp.get("outbound") or [])]
        in_kinds = [str(d.get("edge_kind") or "") for d in (comp.get("inbound") or [])]
        return [k for k in out_kinds + in_kinds if k]

    non_security = [c for c in components if c.get("kind") not in {"Profile", "PermSet"}]
    if non_security:
        filtered: List[Dict[str, Any]] = []
        for c in components:
            kinds = _edge_kinds(c)
            only_grants = bool(kinds) and all(k == "grants" for k in kinds)
            if c.get("kind") in {"Profile", "PermSet"} and only_grants:
                continue
            filtered.append(c)
        if filtered:
            components = filtered

    kind_rank = {
        "ApprovalProcess": 0,
        "Flow": 1,
        "ApexTrigger": 2,
        "ApexClass": 3,
        "Object": 4,
    }
    components = sorted(
        components,
        key=lambda c: (kind_rank.get(str(c.get("kind") or ""), 99), str(c.get("name") or "")),
    )

    shown = components[:max_components]
    lines: List[str] = [
        "### Dependency Map (metadata graph)",
        f"- Components shown: {len(shown)} of {len(components)}",
        "- Graph file: `data/metadata/graph.edgelist`",
    ]
    for idx, comp in enumerate(shown, start=1):
        title = f"{idx}. **{comp.get('kind') or 'Unknown'}: {comp.get('name') or 'Unknown'}**"
        lines.append(title)
        if comp.get("path"):
            lines.append(f"- Path: `{comp.get('path')}`")
        outbound = comp.get("outbound") or []
        inbound = comp.get("inbound") or []
        if outbound:
            lines.append("- Outbound:")
            lines.extend([f"  - {line.replace('outbound.', '', 1)}" for line in _edge_lines("outbound", outbound)])
        if inbound:
            lines.append("- Inbound:")
            lines.extend([f"  - {line.replace('inbound.', '', 1)}" for line in _edge_lines("inbound", inbound)])
        lines.append("")

    return "\n".join(lines).rstrip()


def _build_component_appendix(tool_results: List[Dict[str, Any]], *, max_components: int = 8) -> str:
    rows: List[Dict[str, Any]] = []
    for tr in tool_results:
        if tr.get("tool") != "search_metadata":
            continue
        result = tr.get("result") or {}
        if not isinstance(result, dict) or not result.get("ok"):
            continue
        for item in result.get("results") or []:
            if not isinstance(item, dict):
                continue
            rows.append(
                {
                    "kind": str(item.get("kind") or "Unknown"),
                    "name": str(item.get("name") or "Unknown"),
                    "path": _display_path(str(item.get("path") or "")),
                }
            )
    if not rows:
        return "### Retrieved Components\nNo metadata components found."

    lines = ["### Retrieved Components", "| # | Type | Name | Path |", "|---|---|---|---|"]
    for i, row in enumerate(rows[:max_components], start=1):
        path_val = row["path"] or "-"
        lines.append(f"| {i} | {row['kind']} | {row['name']} | `{path_val}` |")
    if len(rows) > max_components:
        lines.append(f"... and {len(rows) - max_components} more")
    return "\n".join(lines)


def _build_deterministic_answer(user_prompt: str, tool_results: List[Dict[str, Any]]) -> str:
    parts = [f"Question: {user_prompt}", _build_component_appendix(tool_results)]
    deps = _build_dependency_appendix(tool_results)
    if deps:
        parts.append(deps)
    return "\n\n".join(parts)


def _infer_object_scope(user_prompt: str, object_api_name: Optional[str]) -> Optional[str]:
    if object_api_name and str(object_api_name).strip():
        return str(object_api_name).strip()

    q = f" {user_prompt.lower()} "
    # Keep this conservative: auto-scope only for explicit object phrases.
    if " approval process" in q or " approval processes" in q:
        if re.search(r"\b(on|for)\s+(the\s+)?case\b", q) or " case approval process" in q or " case approval processes" in q:
            return "Case"
    return None


def _infer_kind_scope(user_prompt: str) -> Optional[set[str]]:
    q = f" {user_prompt.lower()} "
    if re.search(r"\bapproval process(es)?\b", q):
        # If user explicitly asks for approval processes, default to that kind only.
        return {"ApprovalProcess"}
    return None


def _matches_object_scope(item: Dict[str, Any], scope: str) -> bool:
    scope = scope.strip()
    scope_variants = {scope, f"{scope}__c" if not scope.endswith("__c") else scope}

    kind = str(item.get("kind") or "")
    name = str(item.get("name") or "")
    doc_id = str(item.get("doc_id") or "")
    deps = item.get("dependencies") or {}
    inbound = deps.get("inbound") or []
    outbound = deps.get("outbound") or []

    if kind == "ApprovalProcess":
        for v in scope_variants:
            if name.startswith(f"{v}.") or doc_id.startswith(f"ApprovalProcess:{v}."):
                return True

    # Generic dependency-based scope match.
    for dep in inbound + outbound:
        if str(dep.get("kind") or "") == "Object" and str(dep.get("name") or "") in scope_variants:
            return True

    return False


def _apply_object_scope_filter(
    tool_results: List[Dict[str, Any]],
    object_scope: Optional[str],
    kind_scope: Optional[set[str]] = None,
) -> List[Dict[str, Any]]:
    if not object_scope and not kind_scope:
        return tool_results

    scoped_results: List[Dict[str, Any]] = []
    for tr in tool_results:
        if tr.get("tool") != "search_metadata":
            scoped_results.append(tr)
            continue
        result = tr.get("result") or {}
        if not isinstance(result, dict) or not result.get("ok"):
            scoped_results.append(tr)
            continue
        items = result.get("results") or []
        filtered: List[Dict[str, Any]] = []
        for it in items:
            if not isinstance(it, dict):
                continue
            if kind_scope and str(it.get("kind") or "") not in kind_scope:
                continue
            if object_scope and not _matches_object_scope(it, object_scope):
                continue
            filtered.append(it)
        scoped_results.append(
            {
                **tr,
                "result": {
                    **result,
                    "results": filtered,
                    "object_scope_applied": object_scope,
                    "kind_scope_applied": sorted(kind_scope) if kind_scope else None,
                },
            }
        )
    return scoped_results


def run_agent(
    user_prompt: str,
    model_override: Optional[str],
    use_sfdc: bool,
    hybrid: bool,
    k: int,
    single_llm_pass: bool = True,
    use_final_llm: bool = False,
    object_api_name: Optional[str] = None,
) -> AskResponse:
    ollama = get_ollama_client(model_override)
    sf_client = SalesforceClient.from_env(dry_run=True) if use_sfdc else None
    object_scope = _infer_object_scope(user_prompt, object_api_name)
    kind_scope = _infer_kind_scope(user_prompt)

    # Default path for repo QA: deterministic retrieval + single synthesis call.
    if single_llm_pass and not use_sfdc:
        effective_k = max(k * 2, 12) if object_scope else k
        retrieval_query = user_prompt
        if object_scope and kind_scope == {"ApprovalProcess"}:
            retrieval_query = f"approval process for {object_scope}"
        elif object_scope:
            retrieval_query = f"{user_prompt} object {object_scope}"
        plan = ActionPlan(
            intent="METADATA_QA",
            tool_calls=[
                ToolCall(
                    "search_metadata",
                    {
                        "query": retrieval_query,
                        "hybrid": hybrid,
                        "k": effective_k,
                        "dependency_neighbors": 8,
                    },
                )
            ],
            needs_approval=False,
        )
    else:
        # Fallback to two-pass orchestration when SFDC tools/planning are needed.
        plan = build_plan_with_llm(user_prompt, ollama)
        for tc in plan.tool_calls:
            if tc.tool == "search_metadata":
                tc.args.setdefault("hybrid", hybrid)
                tc.args.setdefault("k", k)
                tc.args.setdefault("dependency_neighbors", 8)

    results = execute_plan(plan, sf_client=sf_client)
    results = _apply_object_scope_filter(results, object_scope, kind_scope)

    if use_final_llm:
        try:
            final_answer = build_final_with_llm(user_prompt, results, ollama)
            dep_appendix = _build_dependency_appendix(results)
            if dep_appendix:
                final_answer = f"{final_answer}\n\n{dep_appendix}"
        except Exception as exc:
            final_answer = (
                _build_deterministic_answer(user_prompt, results)
                + f"\n\nNote: final LLM synthesis failed, returned deterministic output. Error: {exc}"
            )
    else:
        final_answer = _build_deterministic_answer(user_prompt, results)
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


app = FastAPI(title="SF Agent API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def warmup_metadata_retrieval() -> None:
    # Preload embedding/runtime bits to reduce first-request latency.
    if os.getenv("WARMUP_RETRIEVAL", "true").lower() not in {"1", "true", "yes", "on"}:
        return
    try:
        # Warm both vector and lexical paths so first user query avoids cold-start timeout.
        search_metadata("warmup", k=2, hybrid=True)
    except Exception:
        # Best-effort warmup only.
        pass


@app.post("/agent", response_model=AskResponse)
def ask(req: AskRequest, api_key: str = Depends(get_api_key)):
    try:
        return run_agent(
            user_prompt=req.user_prompt,
            model_override=req.model,
            use_sfdc=req.use_sfdc,
            hybrid=req.hybrid,
            k=req.k,
            single_llm_pass=req.single_llm_pass,
            use_final_llm=req.use_final_llm,
            object_api_name=None,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/repo/search-explain", response_model=RepoSearchResponse)
def repo_search_explain(req: RepoSearchRequest, api_key: str = Depends(get_api_key)):
    try:
        ollama = get_ollama_client(req.model)
        context, source = auto_context(
            req.query,
            max_lines=req.max_lines,
            k=req.k,
            hybrid=req.hybrid,
        )
        context_text = "\n".join(context)
        prompt = (
            "You are analyzing the NATTQA-ENV Salesforce repo. "
            "Based ONLY on the context snippets, explain where the query appears "
            "and what it likely does. If the query is not in context, say so.\n\n"
            f"Query: {req.query}\n\nContext snippets (file:line):\n{context_text}"
        )
        explanation = ollama.chat(prompt)
        return RepoSearchResponse(
            query=req.query,
            context_source=source,
            context_lines=len(context),
            explanation=explanation,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/repo/user-story", response_model=UserStoryResponse)
def repo_user_story(req: UserStoryRequest, api_key: str = Depends(get_api_key)):
    try:
        ollama = get_ollama_client(req.model)
        context, source = auto_context(
            req.story,
            max_lines=req.max_lines,
            k=req.k,
            hybrid=req.hybrid,
        )
        context_text = "\n".join(context)
        prompt = (
            "You are analyzing the NATTQA-ENV Salesforce repo. "
            "Given the user story and ONLY the context snippets, list impacted components "
            "(flows, Apex classes/triggers, LWCs, objects, layouts, approvals) and "
            "recommend next steps, risks, and tests. If context is insufficient, say so.\n\n"
            f"User story: {req.story}\n\nContext snippets (file:line):\n{context_text}"
        )
        recommendations = ollama.chat(prompt)
        return UserStoryResponse(
            story=req.story,
            context_source=source,
            context_lines=len(context),
            recommendations=recommendations,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/repo/data-prompt", response_model=DataPromptResponse)
def repo_data_prompt(req: DataPromptRequest, api_key: str = Depends(get_api_key)):
    try:
        ollama = get_ollama_client(req.model)
        prompt = (
            "Use ONLY the data provided to answer the prompt. "
            "If data is insufficient, say so.\n\n"
            f"Prompt: {req.prompt}\n\nData:\n{req.data}"
        )
        response = ollama.chat(prompt)
        return DataPromptResponse(prompt=req.prompt, response=response)
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
        return run_feature_explain(prompt_text, payload, req.model)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/user-story-analyze", response_model=UserStoryAnalyzeResponse)
def sf_repo_ai_user_story_analyze(req: UserStoryAnalyzeRequest, api_key: str = Depends(get_api_key)):
    try:
        return run_user_story_analysis(req)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/debug-analyze", response_model=DebugAnalyzeResponse)
def sf_repo_ai_debug_analyze(req: DebugAnalyzeRequest, api_key: str = Depends(get_api_key)):
    try:
        return run_debug_analysis(req)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/logs/trace/enable", response_model=TraceEnableResponse)
def sf_repo_ai_trace_enable(req: TraceEnableRequest, api_key: str = Depends(get_api_key)):
    try:
        client = get_tooling_client(req)
        user_to_trace = _resolve_trace_user(client, req, req.user)
        user_id = client.resolve_user_id(user_to_trace)
        debug_level_id = client.upsert_debug_level("SF_REPO_AI_FINEST")
        trace_flag_id = client.upsert_trace_flag(user_id=user_id, debug_level_id=debug_level_id, minutes=req.minutes)
        return TraceEnableResponse(
            user_id=user_id,
            debug_level_id=debug_level_id,
            trace_flag_id=trace_flag_id,
            minutes=req.minutes,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/apex/execute-anonymous", response_model=ApexExecuteAnonymousResponse)
def sf_repo_ai_execute_anonymous(req: ApexExecuteAnonymousRequest, api_key: str = Depends(get_api_key)):
    try:
        client = get_tooling_client(req)
        result = client.execute_anonymous(req.anonymous_body)
        return ApexExecuteAnonymousResponse(result=result)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/logs/trace/disable", response_model=TraceDisableResponse)
def sf_repo_ai_trace_disable(req: TraceDisableRequest, api_key: str = Depends(get_api_key)):
    try:
        client = get_tooling_client(req)
        user_to_trace = _resolve_trace_user(client, req, req.user)
        user_id = client.resolve_user_id(user_to_trace)
        updated = client.disable_trace_flag(user_id)
        return TraceDisableResponse(user_id=user_id, trace_flags_updated=updated)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/process-capture/start", response_model=ProcessCaptureStartResponse)
def sf_repo_ai_process_capture_start(req: ProcessCaptureStartRequest, api_key: str = Depends(get_api_key)):
    try:
        client = get_tooling_client(req)
        user_to_trace = _resolve_trace_user(client, req, req.user)
        result = start_capture(
            client=client,
            user=user_to_trace,
            minutes=req.minutes,
            filter_text=req.filter_text,
            tail_seconds=req.tail_seconds,
            store=CaptureStore(),
        )
        return ProcessCaptureStartResponse(
            capture_id=result.capture_id,
            marker_text=result.marker_text,
            start_ts=result.start_ts,
            trace_flag_id=result.trace_flag_id,
            debug_level_id=result.debug_level_id,
            execute_anonymous=result.execute_anonymous,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/process-capture/mark-step", response_model=ProcessCaptureStepMarkerResponse)
def sf_repo_ai_process_capture_mark_step(req: ProcessCaptureStepMarkerRequest, api_key: str = Depends(get_api_key)):
    try:
        client = get_tooling_client(req)
        cap = CaptureStore().get_capture(req.capture_id)
        step = (req.step_name or "").strip()
        if not step:
            raise HTTPException(status_code=400, detail="step_name is required")
        safe_step = step.replace("'", "\\'")
        anon = (
            f"System.debug('{cap.marker_text}');"
            f"System.debug('PROCESS_STEP={safe_step}');"
        )
        result = client.execute_anonymous(anon)
        return ProcessCaptureStepMarkerResponse(
            capture_id=req.capture_id,
            step_name=step,
            execute_anonymous=result,
        )
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/process-capture/ui-event", response_model=ProcessCaptureUiEventResponse)
def sf_repo_ai_process_capture_ui_event(req: ProcessCaptureUiEventRequest, api_key: str = Depends(get_api_key)):
    try:
        result = record_ui_event(
            capture_id=req.capture_id,
            event_type=req.event_type,
            component_name=req.component_name,
            action_name=req.action_name,
            element_label=req.element_label,
            page_url=req.page_url,
            record_id=req.record_id,
            details=req.details,
            event_ts=req.event_ts,
            store=CaptureStore(),
        )
        return ProcessCaptureUiEventResponse(**result.__dict__)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/process-capture/stop", response_model=ProcessCaptureStopResponse)
def sf_repo_ai_process_capture_stop(req: ProcessCaptureStopRequest, api_key: str = Depends(get_api_key)):
    try:
        client = get_tooling_client(req)
        result = stop_capture(
            client=client,
            capture_id=req.capture_id,
            analyze=req.analyze,
            llm=req.llm,
            llm_model=req.llm_model,
            ollama_host=req.ollama_host,
            store=CaptureStore(),
        )
        return ProcessCaptureStopResponse(
            capture_id=result.capture_id,
            start_ts=result.start_ts,
            end_ts=result.end_ts,
            fetched_logs=result.fetched_logs,
            analyzed_logs=result.analyzed_logs,
            marker_matched_logs=result.marker_matched_logs,
            artifact_paths=result.artifact_paths,
            graph_hash=result.graph_hash,
            llm_used=result.llm_used,
            llm_model=result.llm_model,
            narration_path=result.narration_path,
            llm_error=result.llm_error,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/process/save", response_model=ProcessSaveResponse)
def sf_repo_ai_process_save(req: ProcessSaveRequest, api_key: str = Depends(get_api_key)):
    try:
        saved = save_process(
            capture_id=req.capture_id,
            name=req.name,
            description=req.description,
            store=CaptureStore(),
        )
        return ProcessSaveResponse(**saved)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/sf-repo-ai/process-runs/{run_id}/components-readable", response_model=ProcessRunReadableComponentsResponse)
def sf_repo_ai_process_run_components_readable(run_id: str, api_key: str = Depends(get_api_key)):
    try:
        data = CaptureStore().get_process_run_sequence(run_id)
        log_map: Dict[str, Dict[str, Any]] = {}
        for s in data.get("steps", []):
            details = s.get("details") or {}
            log_id = str(s.get("log_id") or details.get("log_id") or "")
            if not log_id:
                continue
            log_map[log_id] = {
                "step_no": int(s.get("seq_no") or 0),
                "step_label": details.get("step_label"),
                "start_time": details.get("start_time"),
                "operation": details.get("operation"),
                "location": details.get("location"),
            }

        items: List[ProcessRunReadableComponentItem] = []
        for c in data.get("components", []):
            log_id = str(c.get("log_id") or "")
            ctx = log_map.get(log_id, {})
            items.append(
                ProcessRunReadableComponentItem(
                    seq_no=int(c.get("seq_no") or 0),
                    step_no=int(ctx.get("step_no") or 0),
                    step_label=ctx.get("step_label"),
                    start_time=ctx.get("start_time"),
                    operation=ctx.get("operation"),
                    location=ctx.get("location"),
                    component_type=str(c.get("component_type") or ""),
                    component_name=str(c.get("component_name") or ""),
                    log_id=c.get("log_id"),
                    confidence=c.get("confidence"),
                )
            )
        return ProcessRunReadableComponentsResponse(
            run_id=data["run_id"],
            capture_id=data["capture_id"],
            ui_invoker=data.get("ui_invoker"),
            ui_invoker_source=data.get("ui_invoker_source"),
            ui_invoker_confidence=data.get("ui_invoker_confidence"),
            components=items,
            count=len(items),
        )
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/sf-repo-ai/processes", response_model=ProcessListResponse)
def sf_repo_ai_process_list(api_key: str = Depends(get_api_key)):
    try:
        rows = CaptureStore().list_process_definitions()
        return ProcessListResponse(processes=[ProcessListItem(**r) for r in rows])
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/sf-repo-ai/processes/{process_name}/runs", response_model=ProcessRunListResponse)
def sf_repo_ai_process_runs(
    process_name: str,
    limit: int = 50,
    api_key: str = Depends(get_api_key),
):
    try:
        rows = CaptureStore().list_process_runs(process_name=process_name, limit=limit)
        return ProcessRunListResponse(
            process_name=process_name,
            runs=[ProcessRunListItem(**r) for r in rows],
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/sf-repo-ai/process-runs/{run_id}", response_model=ProcessRunSequenceResponse)
def sf_repo_ai_process_run_detail(run_id: str, api_key: str = Depends(get_api_key)):
    try:
        data = CaptureStore().get_process_run_sequence(run_id)
        return ProcessRunSequenceResponse(
            run_id=data["run_id"],
            process_name=data["process_name"],
            capture_id=data["capture_id"],
            trace_json_path=data["trace_json_path"],
            created_ts=data["created_ts"],
            ui_invoker=data.get("ui_invoker"),
            ui_invoker_source=data.get("ui_invoker_source"),
            ui_invoker_confidence=data.get("ui_invoker_confidence"),
            steps=[ProcessRunSequenceStep(**s) for s in data["steps"]],
            components=[ProcessRunSequenceComponent(**c) for c in data["components"]],
        )
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/sf-repo-ai/process-runs/{run_id}/created-records", response_model=ProcessRunCreatedRecordsResponse)
def sf_repo_ai_process_run_created_records(run_id: str, api_key: str = Depends(get_api_key)):
    try:
        data = CaptureStore().get_process_run_sequence(run_id)
        records = _extract_created_records_for_run(data)
        return ProcessRunCreatedRecordsResponse(
            run_id=data["run_id"],
            capture_id=data["capture_id"],
            ui_invoker=data.get("ui_invoker"),
            ui_invoker_source=data.get("ui_invoker_source"),
            ui_invoker_confidence=data.get("ui_invoker_confidence"),
            created_records=[CreatedRecordItem(**r) for r in records],
            count=len(records),
        )
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/process-runs/{run_id}/ui-invoker", response_model=ProcessRunInvokerUpdateResponse)
def sf_repo_ai_process_run_set_invoker(
    run_id: str,
    req: ProcessRunInvokerUpdateRequest,
    api_key: str = Depends(get_api_key),
):
    try:
        # Ensure run exists first.
        _ = CaptureStore().get_process_run_sequence(run_id)
        row = CaptureStore().upsert_process_run_context(
            run_id=run_id,
            ui_invoker=req.ui_invoker,
            source=req.ui_invoker_source,
            confidence=req.ui_invoker_confidence,
            notes=req.notes,
            updated_ts=datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        )
        return ProcessRunInvokerUpdateResponse(
            run_id=row["run_id"],
            ui_invoker=row.get("ui_invoker"),
            ui_invoker_source=row.get("ui_invoker_source"),
            ui_invoker_confidence=row.get("ui_invoker_confidence"),
            notes=row.get("notes"),
            updated_ts=row["updated_ts"],
        )
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/process/video-ingest", response_model=ProcessVideoIngestResponse)
def sf_repo_ai_process_video_ingest(req: ProcessVideoIngestRequest, api_key: str = Depends(get_api_key)):
    try:
        result = ingest_video(
            capture_id=req.capture_id,
            video_path=req.video_path,
            analyze=req.analyze,
            llm_model=req.llm_model,
            vision_model=req.vision_model,
            ollama_host=req.ollama_host,
            interval_seconds=req.interval_seconds,
            max_frames=req.max_frames,
            store=CaptureStore(),
        )
        return ProcessVideoIngestResponse(**result)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/process/video-upload", response_model=ProcessVideoUploadResponse)
def sf_repo_ai_process_video_upload(
    capture_id: str = Form(...),
    video: UploadFile = File(...),
    analyze: bool = Form(True),
    llm_model: str = Form("gpt-oss:20b"),
    vision_model: Optional[str] = Form(None),
    ollama_host: Optional[str] = Form(None),
    interval_seconds: int = Form(5),
    max_frames: int = Form(80),
    api_key: str = Depends(get_api_key),
):
    try:
        safe_name = Path(video.filename or "upload.mp4").name
        uploads_dir = Path("data/uploads") / capture_id
        uploads_dir.mkdir(parents=True, exist_ok=True)
        target_path = uploads_dir / safe_name

        with target_path.open("wb") as out:
            shutil.copyfileobj(video.file, out)

        size_bytes = target_path.stat().st_size
        result = ingest_video(
            capture_id=capture_id,
            video_path=str(target_path),
            analyze=analyze,
            llm_model=llm_model,
            vision_model=vision_model,
            ollama_host=ollama_host,
            interval_seconds=interval_seconds,
            max_frames=max_frames,
            store=CaptureStore(),
        )
        return ProcessVideoUploadResponse(
            capture_id=capture_id,
            uploaded_file_path=str(target_path),
            uploaded_file_name=safe_name,
            uploaded_size_bytes=size_bytes,
            artifact_path=result["artifact_path"],
            status=result["status"],
            step_count=result.get("step_count", 0),
            vision_used=bool(result.get("vision_used", False)),
            vision_model=result.get("vision_model"),
            llm_model=result.get("llm_model"),
        )
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


@app.post("/sf-repo-ai/work-items/run", response_model=WorkItemRunResponse)
def sf_repo_ai_work_item_run(req: WorkItemRunRequest, api_key: str = Depends(get_api_key)):
    if req.generate and not req.analyze:
        raise HTTPException(status_code=400, detail="analyze must be true when generate is requested on a new work item")
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

            if req.generate_mode.strip().lower() == "plan_only" and req.auto_approve_generation:
                approved = sf_repo_ai_work_item_approve_generation(
                    work_item_id,
                    WorkItemApproveGenerationRequest(
                        run_local_validation=req.run_local_validation,
                        run_org_validation=req.run_org_validation,
                        org_validation_test_level=req.org_validation_test_level,
                    ),
                    api_key="",
                )
                stages.append(
                    {
                        "stage": "approve_generation",
                        "status": approved.status,
                        "changed_components": len(approved.changed_components or []),
                        "validation": approved.validation,
                        "artifacts": approved.artifacts,
                    }
                )
                generated_response = approved

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


@app.post("/sf-repo-ai/sf-cli/login", response_model=SfCliCommandResponse)
def sf_repo_ai_cli_login(req: SfCliLoginRequest, api_key: str = Depends(get_api_key)):
    try:
        client = get_tooling_client(req)
        response = _run_cli_operation(
            operation_type="sf_cli_login",
            work_item_id=None,
            request_payload={
                "alias": req.alias,
                "instance_url": client.cfg.instance_url,
                "set_default": req.set_default,
            },
            runner=lambda: login_access_token(
                alias=req.alias,
                instance_url=client.cfg.instance_url,
                access_token=client.cfg.session_id,
                set_default=req.set_default,
            ),
        )
        return response
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/sf-cli/deploy", response_model=SfCliCommandResponse)
def sf_repo_ai_cli_deploy(req: SfCliDeployRequest, api_key: str = Depends(get_api_key)):
    store = OrchestrationStore()
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


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/sf-repo-ai/health")
def sf_repo_ai_health():
    return {"status": "ok", "service": "sf-repo-ai-adapter"}


@app.post("/sf-repo-ai/ask", response_model=SfRepoAskResponse)
def sf_repo_ai_ask(req: SfRepoAskRequest, api_key: str = Depends(get_api_key)):
    try:
        if req.evidence_only and req.evidence is not None:
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
                single_llm_pass=req.single_llm_pass,
                use_final_llm=req.use_final_llm,
                object_api_name=req.object_api_name,
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
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))
