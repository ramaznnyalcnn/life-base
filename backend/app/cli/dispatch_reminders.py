"""Run due reminder dispatch from the command line."""

from __future__ import annotations

import argparse
import json
import sys
from collections.abc import Sequence
from typing import Any

from app.db.session import SessionLocal
from app.services.notifications import dispatch_due_reminders


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Dispatch due Life OS reminders without calling the HTTP API.",
    )
    parser.add_argument("--device-id", default=None, help="Only dispatch reminders for a specific device.")
    parser.add_argument(
        "--limit",
        type=int,
        default=20,
        help="Maximum number of due reminders to scan in one run.",
    )
    return parser


def run_dispatch_reminders(*, device_id: str | None = None, limit: int = 20) -> dict[str, Any]:
    session = SessionLocal()
    try:
        result = dispatch_due_reminders(session, device_id=device_id, limit=limit)
        return result.model_dump()
    finally:
        session.close()


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        result = run_dispatch_reminders(device_id=args.device_id, limit=args.limit)
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 2

    print(json.dumps(result, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
