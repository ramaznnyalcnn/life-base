import asyncio

import pytest
from fastapi import HTTPException

from app.api.security import require_app_token
from app.core.config import Settings, get_settings
from app.main import app, health, root


def test_settings_defaults():
    settings = Settings()

    assert settings.single_user_mode is True
    assert settings.app_locale == "tr-TR"
    assert settings.database_url.startswith("postgresql+psycopg://")
    assert settings.openrouter_base_url == "https://openrouter.ai/api/v1"
    assert isinstance(settings.vapid_public_key, str)
    assert isinstance(settings.app_api_token, str)
    assert "http://localhost:5173" in settings.cors_origins


def test_settings_parse_json_list_and_web_app_origin(monkeypatch):
    monkeypatch.setenv(
        "OPENROUTER_MODELS",
        '["stepfun/step-3.5-flash:free", "openrouter/free"]',
    )
    monkeypatch.setenv(
        "CORS_ORIGINS",
        "https://admin.example.com,https://api.example.com",
    )
    monkeypatch.setenv("WEB_APP_URL", "https://app.example.com/dashboard")
    get_settings.cache_clear()

    try:
        settings = Settings()

        assert settings.openrouter_models == [
            "stepfun/step-3.5-flash:free",
            "openrouter/free",
        ]
        assert settings.cors_origins == [
            "https://admin.example.com",
            "https://api.example.com",
            "https://app.example.com",
        ]
    finally:
        get_settings.cache_clear()


def test_root_endpoint():
    body = asyncio.run(root())

    assert body["status"] == "ok"
    assert app.title == "Life OS API"


def test_health_endpoint_reports_expected_backend_mode():
    body = asyncio.run(health())

    assert body["status"] == "healthy"
    assert body["ai"]["provider"] == "openrouter"
    assert body["mode"]["single_user"] is True
    assert body["mode"]["locale"] == "tr-TR"
    assert isinstance(body["notifications"]["vapid_configured"], bool)
    assert isinstance(body["security"]["app_token_enabled"], bool)


def test_api_requires_app_token_when_configured(monkeypatch):
    monkeypatch.setenv("APP_API_TOKEN", "secret-token")
    get_settings.cache_clear()

    try:
        require_app_token(x_app_token="secret-token")
        require_app_token(authorization="Bearer secret-token")

        with pytest.raises(HTTPException) as exc:
            require_app_token()
        assert exc.value.status_code == 401

        with pytest.raises(HTTPException) as exc:
            require_app_token(x_app_token="wrong-token")
        assert exc.value.status_code == 401
    finally:
        get_settings.cache_clear()
