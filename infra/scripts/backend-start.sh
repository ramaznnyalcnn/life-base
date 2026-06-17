#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-/opt/lifeos}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"
WORKERS="${WORKERS:-1}"

cd "$ROOT_DIR"
export PYTHONPATH="${PYTHONPATH:-$ROOT_DIR/backend}"

UVICORN_BIN="${ROOT_DIR}/.venv/bin/uvicorn"
if [[ ! -x "$UVICORN_BIN" ]]; then
  UVICORN_BIN="$(command -v uvicorn)"
fi

exec "$UVICORN_BIN" \
  app.main:app \
  --host "$HOST" \
  --port "$PORT" \
  --workers "$WORKERS"
