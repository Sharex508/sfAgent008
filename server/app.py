from __future__ import annotations

import json
import os
import shutil
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, HTTPException, Header, Security, Depends, UploadFile, File, Form
from fastapi.security import APIKeyHeader
from pydantic import BaseModel, Field

from agent.runtime import (
    ActionPlan,
    build_final_with_llm,
    build_plan_with_llm,
    execute_plan,
)
from llm.ollama_client import OllamaClient
from process.capture import ingest_video, save_process, start_capture, stop_capture
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


class SfAuthRequest(BaseModel):
    login_url: Optional[str] = Field(None, description="Salesforce login URL, e.g. https://test.salesforce.com")
    username: Optional[str] = Field(None, description="Salesforce username")
    password: Optional[str] = Field(None, description="Salesforce password (without token)")
    token: Optional[str] = Field(None, description="Salesforce security token")
    api_version: Optional[str] = Field(None, description="Salesforce API version, e.g. 60.0")


class TraceEnableRequest(SfAuthRequest):
    user: str = Field(..., description="Salesforce username or user Id (005...) to trace")
    minutes: int = Field(30, description="Trace expiration in minutes")
    level: str = Field("FINEST", description="Debug level label hint")


class TraceEnableResponse(BaseModel):
    user_id: str
    debug_level_id: str
    trace_flag_id: str
    minutes: int


class TraceDisableRequest(SfAuthRequest):
    user: str = Field(..., description="Salesforce username or user Id (005...) to trace")


class TraceDisableResponse(BaseModel):
    user_id: str
    trace_flags_updated: int


class ProcessCaptureStartRequest(SfAuthRequest):
    user: str = Field(..., description="Salesforce username or user Id (005...) to trace")
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


def get_ollama_client(model_override: Optional[str] = None) -> OllamaClient:
    host = os.getenv("OLLAMA_HOST", "http://localhost:11434")
    model = model_override or os.getenv("OLLAMA_MODEL", "llama3.1:8b")
    return OllamaClient(host=host, model=model)


def get_tooling_client(auth: SfAuthRequest) -> SalesforceToolingClient:
    return SalesforceToolingClient.from_soap_login(
        login_url=auth.login_url or os.getenv("SF_LOGIN_URL") or "https://login.salesforce.com",
        username=auth.username or os.getenv("SF_USERNAME"),
        password=auth.password or os.getenv("SF_PASSWORD"),
        token=auth.token if auth.token is not None else os.getenv("SF_SECURITY_TOKEN"),
        api_version=auth.api_version or os.getenv("SF_API_VERSION") or "60.0",
    )


def run_agent(user_prompt: str, model_override: Optional[str], use_sfdc: bool, hybrid: bool, k: int) -> AskResponse:
    # Build plan with LLM
    ollama = get_ollama_client(model_override)
    plan: ActionPlan = build_plan_with_llm(user_prompt, ollama)

    # Execute tools
    sf_client = SalesforceClient.from_env(dry_run=True) if use_sfdc else None
    # Inject hybrid flag and k into search calls
    for tc in plan.tool_calls:
        if tc.tool == "search_metadata":
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


@app.post("/agent", response_model=AskResponse)
def ask(req: AskRequest, api_key: str = Depends(get_api_key)):
    try:
        return run_agent(
            user_prompt=req.user_prompt,
            model_override=req.model,
            use_sfdc=req.use_sfdc,
            hybrid=req.hybrid,
            k=req.k,
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
        user_id = client.resolve_user_id(req.user)
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


@app.post("/sf-repo-ai/logs/trace/disable", response_model=TraceDisableResponse)
def sf_repo_ai_trace_disable(req: TraceDisableRequest, api_key: str = Depends(get_api_key)):
    try:
        client = get_tooling_client(req)
        user_id = client.resolve_user_id(req.user)
        updated = client.disable_trace_flag(user_id)
        return TraceDisableResponse(user_id=user_id, trace_flags_updated=updated)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.post("/sf-repo-ai/process-capture/start", response_model=ProcessCaptureStartResponse)
def sf_repo_ai_process_capture_start(req: ProcessCaptureStartRequest, api_key: str = Depends(get_api_key)):
    try:
        client = get_tooling_client(req)
        result = start_capture(
            client=client,
            user=req.user,
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
