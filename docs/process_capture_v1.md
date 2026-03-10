# Process Capture v1

## API Endpoints

- `POST /sf-repo-ai/logs/trace/enable`
- `POST /sf-repo-ai/logs/trace/disable`
- `POST /sf-repo-ai/process-capture/start`
- `POST /sf-repo-ai/process-capture/stop`
- `POST /sf-repo-ai/process/save`
- `POST /sf-repo-ai/process/video-ingest` (stub)
- `POST /sf-repo-ai/process/video-upload` (multipart upload + attach to capture)

## Example: Start Capture

```bash
curl -X POST http://127.0.0.1:8001/sf-repo-ai/process-capture/start \
  -H "Content-Type: application/json" \
  -d '{
    "login_url": "https://test.salesforce.com",
    "username": "user@example.com.sandbox",
    "password": "***",
    "token": "***",
    "user": "user@example.com.sandbox",
    "minutes": 10,
    "tail_seconds": 120
  }'
```

## Example: Stop + Analyze

```bash
curl -X POST http://127.0.0.1:8001/sf-repo-ai/process-capture/stop \
  -H "Content-Type: application/json" \
  -d '{
    "login_url": "https://test.salesforce.com",
    "username": "user@example.com.sandbox",
    "password": "***",
    "token": "***",
    "capture_id": "<capture-id>",
    "analyze": true,
    "llm": true,
    "llm_model": "gpt-oss:20b"
  }'
```

Artifacts are written under `data/artifacts/<capture-id>/`.
If `llm=true`, `narration.md` is also generated from `trace.json`.

## Example: Upload + Analyze Video File (from user machine)

```bash
curl -X POST http://127.0.0.1:8001/sf-repo-ai/process/video-upload \
  -F "capture_id=<capture-id>" \
  -F "video=@/absolute/path/to/process-recording.mp4" \
  -F "analyze=true" \
  -F "llm_model=gpt-oss:20b" \
  -F "interval_seconds=5" \
  -F "max_frames=80"
```

Uploaded file is stored under `data/uploads/<capture-id>/`.
Generated steps are written to `data/artifacts/<capture-id>/video_steps.json`.
If no vision model is installed in Ollama, steps are timeline placeholders only.
Install one (example): `ollama pull llava:7b`.
