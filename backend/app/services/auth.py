"""Authentication and ownership helpers."""

from __future__ import annotations

from datetime import datetime, timezone
from hashlib import sha256
from secrets import compare_digest, token_urlsafe

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.models import AccessToken, User


def hash_access_token(raw_token: str) -> str:
    return sha256(raw_token.encode("utf-8")).hexdigest()


def ensure_default_user(session: Session, settings: Settings | None = None) -> User:
    settings = settings or get_settings()
    existing = session.scalar(select(User).where(User.email == settings.default_owner_email))
    if existing is not None:
        return existing

    user = User(
        email=settings.default_owner_email,
        display_name=settings.default_owner_name,
        is_active=True,
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


def authenticate_access_token(
    session: Session,
    raw_token: str,
    *,
    settings: Settings | None = None,
) -> User | None:
    settings = settings or get_settings()
    if settings.app_api_token and compare_digest(raw_token, settings.app_api_token):
        return ensure_default_user(session, settings)

    token_hash = hash_access_token(raw_token)
    token = session.scalar(
        select(AccessToken)
        .join(User, User.id == AccessToken.user_id)
        .where(
            AccessToken.token_hash == token_hash,
            AccessToken.is_active.is_(True),
            User.is_active.is_(True),
        )
    )
    if token is None:
        return None

    now = datetime.now(timezone.utc)
    if token.expires_at is not None and token.expires_at <= now:
        return None

    token.last_used_at = now
    session.commit()
    session.refresh(token.user)
    return token.user


def issue_access_token(
    session: Session,
    user: User,
    *,
    label: str,
    note: str | None = None,
    raw_token: str | None = None,
) -> tuple[AccessToken, str]:
    token_value = raw_token or token_urlsafe(32)
    token = AccessToken(
        user_id=user.id,
        label=label,
        token_hash=hash_access_token(token_value),
        note=note,
        is_active=True,
    )
    session.add(token)
    session.commit()
    session.refresh(token)
    return token, token_value


def get_or_create_user(
    session: Session,
    *,
    email: str,
    display_name: str,
) -> User:
    existing = session.scalar(select(User).where(User.email == email))
    if existing is not None:
        if existing.display_name != display_name:
            existing.display_name = display_name
            session.commit()
            session.refresh(existing)
        return existing

    user = User(email=email, display_name=display_name, is_active=True)
    session.add(user)
    session.commit()
    session.refresh(user)
    return user
