"""Authentication and ownership helpers."""

from __future__ import annotations

from base64 import urlsafe_b64decode, urlsafe_b64encode
from datetime import datetime, timezone
from hashlib import scrypt, sha256
from secrets import compare_digest, token_bytes, token_urlsafe

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.models import AccessToken, User


SCRYPT_N = 2**14
SCRYPT_R = 8
SCRYPT_P = 1
SCRYPT_KEY_LENGTH = 64


def hash_access_token(raw_token: str) -> str:
    return sha256(raw_token.encode("utf-8")).hexdigest()


def _encode_password_bytes(value: bytes) -> str:
    return urlsafe_b64encode(value).decode("ascii")


def _decode_password_bytes(value: str) -> bytes:
    return urlsafe_b64decode(value.encode("ascii"))


def hash_password(raw_password: str) -> str:
    salt = token_bytes(16)
    derived_key = scrypt(
        raw_password.encode("utf-8"),
        salt=salt,
        n=SCRYPT_N,
        r=SCRYPT_R,
        p=SCRYPT_P,
        dklen=SCRYPT_KEY_LENGTH,
    )
    return f"scrypt${_encode_password_bytes(salt)}${_encode_password_bytes(derived_key)}"


def verify_password(raw_password: str, password_hash: str | None) -> bool:
    if not raw_password or not password_hash:
        return False

    scheme, _, payload = password_hash.partition("$")
    if scheme != "scrypt" or "$" not in payload:
        return False

    salt_token, _, digest_token = payload.partition("$")
    derived_key = scrypt(
        raw_password.encode("utf-8"),
        salt=_decode_password_bytes(salt_token),
        n=SCRYPT_N,
        r=SCRYPT_R,
        p=SCRYPT_P,
        dklen=SCRYPT_KEY_LENGTH,
    )
    return compare_digest(_encode_password_bytes(derived_key), digest_token)


def ensure_default_user(session: Session, settings: Settings | None = None) -> User:
    settings = settings or get_settings()
    existing = session.scalar(select(User).where(User.email == settings.default_owner_email))
    if existing is not None:
        updated = False
        if existing.display_name != settings.default_owner_name:
            existing.display_name = settings.default_owner_name
            updated = True
        if not existing.is_admin:
            existing.is_admin = True
            updated = True
        if settings.default_owner_password and not verify_password(
            settings.default_owner_password,
            existing.password_hash,
        ):
            existing.password_hash = hash_password(settings.default_owner_password)
            updated = True
        if updated:
            session.commit()
            session.refresh(existing)
        return existing

    user = User(
        email=settings.default_owner_email,
        display_name=settings.default_owner_name,
        password_hash=hash_password(settings.default_owner_password) if settings.default_owner_password else "",
        is_active=True,
        is_admin=True,
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


def authenticate_user_password(
    session: Session,
    *,
    email: str,
    password: str,
) -> User | None:
    user = session.scalar(select(User).where(User.email == email.strip().lower()))
    if user is None or not user.is_active:
        return None
    if not verify_password(password, user.password_hash):
        return None
    return user


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
    password: str | None = None,
    is_admin: bool = False,
) -> User:
    normalized_email = email.strip().lower()
    existing = session.scalar(select(User).where(User.email == normalized_email))
    if existing is not None:
        updated = False
        if existing.display_name != display_name:
            existing.display_name = display_name
            updated = True
        if is_admin and not existing.is_admin:
            existing.is_admin = True
            updated = True
        if password and not verify_password(password, existing.password_hash):
            existing.password_hash = hash_password(password)
            updated = True
        if updated:
            session.commit()
            session.refresh(existing)
        return existing

    user = User(
        email=normalized_email,
        display_name=display_name,
        password_hash=hash_password(password) if password else "",
        is_active=True,
        is_admin=is_admin,
    )
    session.add(user)
    session.commit()
    session.refresh(user)
    return user
