#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${ROOT_DIR:-/opt/lifeos}"
cd "$ROOT_DIR/backend"

export PYTHONPATH="${PYTHONPATH:-$ROOT_DIR/backend}"

ALEMBIC_BIN="${ROOT_DIR}/.venv/bin/alembic"
if [[ ! -x "$ALEMBIC_BIN" ]]; then
  ALEMBIC_BIN="$(command -v alembic)"
fi

"$ALEMBIC_BIN" -c "alembic.ini" upgrade head
