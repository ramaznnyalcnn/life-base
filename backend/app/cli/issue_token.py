"""Provision or rotate a user access token."""

from __future__ import annotations

import argparse
import json
from collections.abc import Sequence

from app.core.config import get_settings
from app.db.session import SessionLocal
from app.services.auth import get_or_create_user, issue_access_token


def build_parser() -> argparse.ArgumentParser:
    settings = get_settings()
    parser = argparse.ArgumentParser(description="Create a Life OS access token for a user.")
    parser.add_argument("--email", default=settings.default_owner_email, help="User email.")
    parser.add_argument("--name", default=settings.default_owner_name, help="Display name.")
    parser.add_argument("--label", default="CLI token", help="Token label for auditing.")
    parser.add_argument("--note", default=None, help="Optional token note.")
    return parser


def issue_token_for_user(*, email: str, display_name: str, label: str, note: str | None = None) -> dict[str, object]:
    session = SessionLocal()
    try:
        user = get_or_create_user(session, email=email, display_name=display_name)
        token, raw_token = issue_access_token(session, user, label=label, note=note)
        return {
            "user_id": user.id,
            "email": user.email,
            "display_name": user.display_name,
            "token_id": token.id,
            "label": token.label,
            "token": raw_token,
        }
    finally:
        session.close()


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    payload = issue_token_for_user(
        email=args.email,
        display_name=args.name,
        label=args.label,
        note=args.note,
    )
    print(json.dumps(payload, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
