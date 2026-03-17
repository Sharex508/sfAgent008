# SF Agent 008 API Runbook

## Purpose
This document gives the exact commands to:
- start the API server (`uvicorn`)
- start `ngrok` when a public URL is needed
- call the main API endpoints
- understand which endpoints are used for health, orchestration, Salesforce CLI, process capture, and analysis

## Project Location
- Repo: `C:\Users\narendra\Downloads\sf\sfAgent008`
- Metadata project: `C:\Users\narendra\Downloads\sf\sfAgent008\NATTQA-ENV`

## Terminal 1: Start Uvicorn
```powershell
cd C:\Users\narendra\Downloads\sf\sfAgent008
$env:OLLAMA_HOST="http://127.0.0.1:11434"
$env:OLLAMA_MODEL="gpt-oss:20b"
.\.venv\Scripts\python.exe -m uvicorn server.app:app --host 0.0.0.0 --port 8001
```

## Terminal 2: Start ngrok
Use `ngrok` only when you want a public URL.

```powershell
ngrok http 8001
```

If `ngrok` is not on PATH, use:
```powershell
& "C:\Program Files\ngrok\ngrok.exe" http 8001
```

## Local and Public Base URLs
- Local: `http://127.0.0.1:8001`
- Public: `https://<your-ngrok-domain>`

Replace `<BASE_URL>` in examples with either the local URL or the `ngrok` URL.

## Health Check
```bash
curl "<BASE_URL>/sf-repo-ai/health"
```

## Main End-To-End Endpoint
This is the single endpoint that can run the generic flow.

### Endpoint
- `POST /sf-repo-ai/work-items/run`

### Example cURL
```bash
curl -X POST "<BASE_URL>/sf-repo-ai/work-items/run" ^
  -H "Content-Type: application/json" ^
  -d "{\"title\":\"Generic Salesforce Story\",\"story\":\"As a business user, I want a Salesforce enhancement analyzed, generated, validated, deployed, and tested.\",\"model\":\"gpt-oss:20b\",\"metadata_project_dir\":\"C:\\Users\\narendra\\Downloads\\sf\\sfAgent008\\NATTQA-ENV\",\"target_org_alias\":\"nattqa\",\"analyze\":true,\"generate\":true,\"generate_mode\":\"plan_only\",\"auto_approve_generation\":true,\"run_local_validation\":true,\"run_org_validation\":false,\"deploy\":false,\"run_tests\":false}"
```

### Direct Generate + Deploy + Test Example
```bash
curl -X POST "<BASE_URL>/sf-repo-ai/work-items/run" ^
  -H "Content-Type: application/json" ^
  -d "{\"title\":\"Generic Salesforce Story\",\"story\":\"As a business user, I want a Salesforce enhancement analyzed, generated, validated, deployed, and tested.\",\"model\":\"gpt-oss:20b\",\"metadata_project_dir\":\"C:\\Users\\narendra\\Downloads\\sf\\sfAgent008\\NATTQA-ENV\",\"target_org_alias\":\"nattqa\",\"analyze\":true,\"generate\":true,\"generate_mode\":\"apply\",\"run_local_validation\":true,\"run_org_validation\":true,\"org_validation_test_level\":\"RunLocalTests\",\"deploy\":true,\"deploy_wait_minutes\":30,\"deploy_test_level\":\"RunLocalTests\",\"run_tests\":true,\"test_wait_minutes\":30,\"test_level\":\"RunLocalTests\"}"
```

## Common API Groups

### Health
- `GET /health`
- `GET /sf-repo-ai/health`

### General AI / Repo Analysis
- `POST /agent`
- `POST /repo/search-explain`
- `POST /repo/user-story`
- `POST /repo/data-prompt`
- `POST /sf-repo-ai/feature-explain`
- `POST /sf-repo-ai/user-story-analyze`
- `POST /sf-repo-ai/debug-analyze`
- `POST /sf-repo-ai/ask`

### Salesforce Trace / Apex
- `POST /sf-repo-ai/logs/trace/enable`
- `POST /sf-repo-ai/logs/trace/disable`
- `POST /sf-repo-ai/apex/execute-anonymous`

### Process Capture / UI / Logs
- `POST /sf-repo-ai/process-capture/start`
- `POST /sf-repo-ai/process-capture/mark-step`
- `POST /sf-repo-ai/process-capture/ui-event`
- `POST /sf-repo-ai/process-capture/stop`
- `POST /sf-repo-ai/process/save`
- `GET /sf-repo-ai/processes`
- `GET /sf-repo-ai/processes/{process_name}/runs`
- `GET /sf-repo-ai/process-runs/{run_id}`
- `GET /sf-repo-ai/process-runs/{run_id}/components-readable`
- `GET /sf-repo-ai/process-runs/{run_id}/created-records`
- `POST /sf-repo-ai/process-runs/{run_id}/ui-invoker`
- `POST /sf-repo-ai/process/video-ingest`
- `POST /sf-repo-ai/process/video-upload`

### Work Item Orchestration
- `POST /sf-repo-ai/work-items`
- `GET /sf-repo-ai/work-items`
- `GET /sf-repo-ai/work-items/{work_item_id}`
- `GET /sf-repo-ai/work-items/{work_item_id}/executions`
- `POST /sf-repo-ai/work-items/{work_item_id}/analyze`
- `POST /sf-repo-ai/work-items/{work_item_id}/generate-or-update-components`
- `POST /sf-repo-ai/work-items/{work_item_id}/approve-generation`
- `POST /sf-repo-ai/work-items/run`

### Salesforce CLI Orchestration
- `GET /sf-repo-ai/sf-cli/orgs`
- `POST /sf-repo-ai/sf-cli/login`
- `POST /sf-repo-ai/sf-cli/retrieve`
- `POST /sf-repo-ai/sf-cli/deploy`
- `POST /sf-repo-ai/sf-cli/test`

## Typical Generic Flow
1. Start `uvicorn`
2. Start `ngrok` only if public access is needed
3. Call `GET /sf-repo-ai/health`
4. Call `POST /sf-repo-ai/work-items/run`
5. Review the returned `work_item` and `stages`
6. If needed, inspect execution history using `GET /sf-repo-ai/work-items/{work_item_id}/executions`

## Useful One-Liners

### Health
```bash
curl "http://127.0.0.1:8001/sf-repo-ai/health"
```

### List Work Items
```bash
curl "http://127.0.0.1:8001/sf-repo-ai/work-items"
```

### List CLI Orgs
```bash
curl "http://127.0.0.1:8001/sf-repo-ai/sf-cli/orgs"
```

## Notes
- `uvicorn` is the API server. If you say "uv cron", in this project that means starting `uvicorn`.
- `ngrok` is optional. Use it only when a public URL is required.
- The default model used in the server is `gpt-oss:20b`.
- The default local port is `8001`.
