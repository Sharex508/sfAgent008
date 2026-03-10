#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8001}"
APP_MODULE="${APP_MODULE:-server.app:app}"

cd "${ROOT_DIR}"

if [[ -f ".env" ]]; then
  # shellcheck disable=SC1091
  source .env
fi

echo "Starting API on ${HOST}:${PORT} (${APP_MODULE})"
PYTHON_BIN="python3"
if [[ -x "${ROOT_DIR}/.venv/bin/python" ]]; then
  PYTHON_BIN="${ROOT_DIR}/.venv/bin/python"
fi

exec "${PYTHON_BIN}" -m uvicorn "${APP_MODULE}" --host "${HOST}" --port "${PORT}"
