"""Create or update a Life OS user from the terminal."""

from __future__ import annotations

import argparse
import json
from collections.abc import Sequence

from app.db.session import SessionLocal
from app.services.auth import get_or_create_user


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Create or update a Life OS user.")
    parser.add_argument("--email", required=True, help="User email.")
    parser.add_argument("--name", required=True, help="Display name.")
    parser.add_argument("--password", required=True, help="Initial or replacement password.")
    parser.add_argument("--admin", action="store_true", help="Create the user as admin.")
    return parser


def create_user_from_cli(*, email: str, display_name: str, password: str, is_admin: bool = False) -> dict[str, object]:
    session = SessionLocal()
    try:
        user = get_or_create_user(
            session,
            email=email,
            display_name=display_name,
            password=password,
            is_admin=is_admin,
        )
        return {
            "user_id": user.id,
            "email": user.email,
            "display_name": user.display_name,
            "is_admin": user.is_admin,
            "is_active": user.is_active,
        }
    finally:
        session.close()


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    payload = create_user_from_cli(
        email=args.email,
        display_name=args.name,
        password=args.password,
        is_admin=args.admin,
    )
    print(json.dumps(payload, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
