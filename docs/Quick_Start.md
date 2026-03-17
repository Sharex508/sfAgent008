# SF Agent 008 Quick Start

## 1. Start the API Server
```powershell
cd C:\Users\narendra\Downloads\sf\sfAgent008
$env:OLLAMA_HOST="http://127.0.0.1:11434"
$env:OLLAMA_MODEL="gpt-oss:20b"
.\.venv\Scripts\python.exe -m uvicorn server.app:app --host 0.0.0.0 --port 8001
```

## 2. Start ngrok
Use this only when you need a public URL.

```powershell
ngrok http 8001
```

If `ngrok` is not on PATH:
```powershell
& "C:\Program Files\ngrok\ngrok.exe" http 8001
```

## 3. Health Check
```bash
curl "http://127.0.0.1:8001/sf-repo-ai/health"
```

## 4. Run One End-To-End API Call
```bash
curl -X POST "http://127.0.0.1:8001/sf-repo-ai/work-items/run" ^
  -H "Content-Type: application/json" ^
  -d "{\"title\":\"Quick Start Story\",\"story\":\"As a business user, I want a Salesforce enhancement analyzed and generated.\",\"model\":\"gpt-oss:20b\",\"metadata_project_dir\":\"C:\\Users\\narendra\\Downloads\\sf\\sfAgent008\\NATTQA-ENV\",\"target_org_alias\":\"nattqa\",\"analyze\":true,\"generate\":true,\"generate_mode\":\"plan_only\",\"auto_approve_generation\":true,\"run_local_validation\":true,\"run_org_validation\":false,\"deploy\":false,\"run_tests\":false}"
```

## 5. Optional Public URL
If you started `ngrok`, replace `http://127.0.0.1:8001` with your `ngrok` URL.

## 6. Main Endpoints
- `GET /sf-repo-ai/health`
- `POST /sf-repo-ai/work-items/run`
- `GET /sf-repo-ai/work-items`
- `GET /sf-repo-ai/work-items/{work_item_id}`
- `GET /sf-repo-ai/work-items/{work_item_id}/executions`
