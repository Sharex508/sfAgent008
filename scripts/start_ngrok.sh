#!/usr/bin/env bash
set -euo pipefail

PORT="${1:-8001}"
HEALTH_PATH="${HEALTH_PATH:-/sf-repo-ai/health}"
BASE_URL="http://127.0.0.1:${PORT}"
HEALTH_URL="${BASE_URL}${HEALTH_PATH}"

if ! command -v ngrok >/dev/null 2>&1; then
  echo "ngrok not found. Install first: brew install ngrok/ngrok/ngrok"
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl not found. Install curl and retry."
  exit 1
fi

echo "Checking local API at ${HEALTH_URL} ..."
if ! curl -fsS --max-time 3 "${HEALTH_URL}" >/dev/null 2>&1; then
  echo "Local API is not reachable at ${HEALTH_URL}."
  echo "Start API first in another terminal:"
  echo "  cd /Users/harshavardhansarrabu/Downloads/Agent008"
  echo "  ./scripts/start_api.sh"
  exit 1
fi

echo "Starting ngrok tunnel for localhost:${PORT}"
echo "Once running, use the forwarding URL for Salesforce Remote Site Setting / Named Credential."
exec ngrok http "${PORT}"
