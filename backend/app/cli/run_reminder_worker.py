"""Run reminder dispatch on a schedule."""

from __future__ import annotations

import argparse
import json
import sys
import time
from collections.abc import Sequence
from datetime import datetime, timezone

from app.core.config import get_settings
from app.cli.dispatch_reminders import run_dispatch_reminders


def build_parser() -> argparse.ArgumentParser:
    settings = get_settings()
    parser = argparse.ArgumentParser(description="Run the Life OS reminder dispatcher on a loop.")
    parser.add_argument("--device-id", default=None, help="Only dispatch reminders for a specific device.")
    parser.add_argument(
        "--limit",
        type=int,
        default=settings.reminder_dispatch_limit,
        help="Maximum number of reminders to scan per iteration.",
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=settings.reminder_dispatch_interval_seconds,
        help="Sleep interval between iterations in seconds.",
    )
    parser.add_argument(
        "--max-runs",
        type=int,
        default=0,
        help="Stop after N iterations. Use 0 to run forever.",
    )
    return parser


def run_worker(
    *,
    device_id: str | None = None,
    limit: int,
    interval: int,
    max_runs: int = 0,
) -> int:
    run_count = 0

    while True:
        run_count += 1
        try:
            payload = run_dispatch_reminders(device_id=device_id, limit=limit)
        except ValueError as exc:
            print(str(exc), file=sys.stderr)
            return 2

        print(
            json.dumps(
                {
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "run": run_count,
                    "result": payload,
                },
                ensure_ascii=True,
            )
        )

        if max_runs and run_count >= max_runs:
            return 0

        time.sleep(max(interval, 1))


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return run_worker(
        device_id=args.device_id,
        limit=args.limit,
        interval=args.interval,
        max_runs=args.max_runs,
    )


if __name__ == "__main__":
    raise SystemExit(main())
