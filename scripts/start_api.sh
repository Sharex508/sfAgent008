#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8001}"
APP_MODULE="${APP_MODULE:-server.app:app}"
PREWARM_INDEX="${PREWARM_INDEX:-1}"

cd "${ROOT_DIR}"

if [[ -f ".env" ]]; then
  # shellcheck disable=SC1091
  source .env
fi

if [[ ! -f "${ROOT_DIR}/server/app.py" ]]; then
  echo "Missing API entrypoint: ${ROOT_DIR}/server/app.py"
  exit 1
fi

PYTHON_BIN="python3"
if [[ -x "${ROOT_DIR}/.venv/bin/python" ]]; then
  PYTHON_BIN="${ROOT_DIR}/.venv/bin/python"
fi

if [[ "${PREWARM_INDEX}" == "1" ]]; then
  echo "Prewarming metadata indexes (safe no-op if already built)..."
  if ! "${PYTHON_BIN}" - <<'PY'
from repo_index import ensure_indexes
docs, db = ensure_indexes(rebuild=False)
print(f"Metadata indexes ready: docs={docs} db={db}")
PY
  then
    echo "Index prewarm failed; continuing with lazy on-demand indexing."
  fi
fi

echo "Starting sf_repo_ai API on ${HOST}:${PORT} (${APP_MODULE})"
exec "${PYTHON_BIN}" -m uvicorn "${APP_MODULE}" --host "${HOST}" --port "${PORT}"
