from fastapi import HTTPException
from app.api.routes.auth import get_me, login
from app.core.config import get_settings
from app.schemas.auth import LoginRequest


def test_login_returns_access_token(monkeypatch, db_session):
    monkeypatch.setenv("DEFAULT_OWNER_PASSWORD", "owner-password-123")
    get_settings.cache_clear()

    try:
        result = login(
            LoginRequest(email="owner@lifeos.local", password="owner-password-123"),
            db_session,
            user_agent=None,
        )
    finally:
        get_settings.cache_clear()

    assert result.token_type == "bearer"
    assert result.access_token
    assert result.user.email == "owner@lifeos.local"
    assert result.user.is_admin is True


def test_get_me_returns_authenticated_user(monkeypatch, db_session):
    monkeypatch.setenv("DEFAULT_OWNER_PASSWORD", "owner-password-123")
    get_settings.cache_clear()

    try:
        session = login(
            LoginRequest(email="owner@lifeos.local", password="owner-password-123"),
            db_session,
            user_agent=None,
        )
        payload = get_me(session.user, db_session)
    finally:
        get_settings.cache_clear()

    assert payload.email == "owner@lifeos.local"
    assert payload.is_admin is True


def test_a_username_signs_in_through_its_alias(monkeypatch, db_session):
    monkeypatch.setenv("DEFAULT_OWNER_PASSWORD", "owner-password-123")
    monkeypatch.setenv("LOGIN_ALIASES", "Ali:owner@lifeos.local")
    get_settings.cache_clear()
    try:
        by_name = login(LoginRequest(email=" ali ", password="owner-password-123"), db_session, user_agent=None)
        by_email = login(LoginRequest(email="owner@lifeos.local", password="owner-password-123"), db_session, user_agent=None)
        assert by_name.user.email == by_email.user.email == "owner@lifeos.local"
        try:
            login(LoginRequest(email="ayse", password="owner-password-123"), db_session, user_agent=None)
        except HTTPException as error:
            assert error.status_code == 401
        else:
            raise AssertionError("an unknown username must not sign in")
    finally:
        get_settings.cache_clear()
