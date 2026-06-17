"""Shared API security dependencies."""

from __future__ import annotations

from secrets import compare_digest

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db import get_db
from app.models import User
from app.services.auth import authenticate_access_token, ensure_default_user


def _header_value(value: object) -> str | None:
    return value if isinstance(value, str) else None


def _extract_bearer_token(authorization: str | None) -> str | None:
    if not authorization:
        return None

    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        return None
    return token.strip()


def require_app_token(
    x_app_token: str | None = Header(default=None, alias="X-App-Token"),
    authorization: str | None = Header(default=None, alias="Authorization"),
) -> None:
    """Require the configured app token when one is enabled."""

    settings = get_settings()
    if not settings.app_api_token:
        return

    provided_token = _header_value(x_app_token) or _extract_bearer_token(_header_value(authorization))
    if provided_token and compare_digest(provided_token, settings.app_api_token):
        return

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Yetkisiz erisim.",
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_user(
    db: Session = Depends(get_db),
    x_app_token: str | None = Header(default=None, alias="X-App-Token"),
    authorization: str | None = Header(default=None, alias="Authorization"),
) -> User:
    """Resolve the active user from the configured auth strategy."""

    settings = get_settings()
    provided_token = _header_value(x_app_token) or _extract_bearer_token(_header_value(authorization))

    if provided_token:
        user = authenticate_access_token(db, provided_token, settings=settings)
        if user is not None:
            return user

    if settings.app_api_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Yetkisiz erisim.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if settings.single_user_mode:
        return ensure_default_user(db, settings)

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Kimlik dogrulamasi gerekiyor.",
        headers={"WWW-Authenticate": "Bearer"},
    )


def resolve_route_user(current_user: object, db: Session) -> User:
    """Normalize direct route calls in tests and scripts."""

    if isinstance(current_user, User):
        return current_user
    return ensure_default_user(db)
