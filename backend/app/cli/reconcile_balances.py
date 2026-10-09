"""Report (and with --fix, correct) accounts whose balance drifted from their history.

    python -m app.cli.reconcile_balances [--fix]

Exit status 1 when drift was found and not fixed, so it can run from cron.
"""

from __future__ import annotations

import argparse
import sys
from collections.abc import Sequence

from app.db.session import SessionLocal
from app.services.reconcile import find_drift, fix_drift


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Check account balances against opening balance + history.")
    parser.add_argument("--fix", action="store_true", help="Correct drifting balances.")
    args = parser.parse_args(argv)
    with SessionLocal() as session:
        drifts = fix_drift(session) if args.fix else find_drift(session)
        if args.fix:
            session.commit()
    for drift in drifts:
        print(f"{drift.account_id}\t{drift.name}\tstored={drift.stored}\texpected={drift.expected}\tdiff={drift.difference}")
    if not drifts:
        print("All balances match.")
    return 1 if drifts and not args.fix else 0


if __name__ == "__main__":
    sys.exit(main())
