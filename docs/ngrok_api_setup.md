# Salesforce -> ngrok -> Agent API Setup

This setup exposes a stable endpoint for Salesforce callouts:

- `POST /sf-repo-ai/ask`
- `GET /sf-repo-ai/health`

## 1) Install dependencies

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
brew install ngrok/ngrok/ngrok
```

## 2) Start the API

```bash
./scripts/start_api.sh
```

Default API URL: `http://127.0.0.1:8001`

## 3) Start ngrok tunnel

In another terminal:

```bash
./scripts/start_ngrok.sh 8001
```

Copy the `https://<id>.ngrok-free.app` forwarding URL.

## 4) Configure Salesforce

Use either of these:

- Remote Site Setting `Ngrok_API` -> ngrok URL
- Named Credential -> ngrok URL

If using Apex direct endpoint callout, include the full path:

- `https://<id>.ngrok-free.app/sf-repo-ai/ask`

## 5) Payload contract

### Request

```json
{
  "question": "where is Account.Status__c used?",
  "record_id": "001xx00000ABCDe",
  "object_api_name": "Account",
  "use_sfdc": false,
  "hybrid": true,
  "k": 8
}
```

### Response (shape)

```json
{
  "question": "...",
  "record_id": "...",
  "object_api_name": "...",
  "intent": "...",
  "needs_approval": false,
  "tool_results": [],
  "final_answer": "..."
}
```

## 6) Smoke test locally

```bash
./scripts/smoke_test_endpoint.sh http://127.0.0.1:8001
```

## Notes

- If `AGENT_API_KEY` is set in `.env`, Salesforce must pass `X-API-Key`.
- If ngrok shows `ERR_NGROK_3200`, tunnel is offline; restart ngrok.
