"""Authentication endpoints."""

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.core.config import get_settings
from app.db import get_db
from app.models import User
from app.schemas.auth import AuthSessionRead, LoginRequest, UserRead
from app.services.auth import (
    authenticate_user_password,
    ensure_default_user,
    issue_access_token,
)


router = APIRouter(prefix="/auth", tags=["auth"])


def _header_value(value: object) -> str | None:
    return value if isinstance(value, str) else None


@router.post("/login", response_model=AuthSessionRead)
def login(
    payload: LoginRequest,
    db: Session = Depends(get_db),
    user_agent: str | None = Header(default=None, alias="User-Agent"),
):
    settings = get_settings()
    ensure_default_user(db, settings)
    user = authenticate_user_password(
        db,
        email=payload.email,
        password=payload.password,
    )
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="E-posta veya sifre hatali.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token, raw_token = issue_access_token(
        db,
        user,
        label="Web oturumu",
        note=_header_value(user_agent),
    )
    db.refresh(token.user)
    return AuthSessionRead(access_token=raw_token, user=token.user)


@router.get("/me", response_model=UserRead)
def get_me(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return resolve_route_user(current_user, db)
