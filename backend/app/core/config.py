"""Application settings for the Life OS backend."""

import json
from functools import lru_cache
from pathlib import Path
from typing import Annotated
from urllib.parse import urlsplit

from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

ENV_FILE = Path(__file__).resolve().parents[3] / ".env"


def _parse_list_env(value):
    if isinstance(value, str):
        normalized = value.strip()
        if not normalized:
            return []
        if normalized.startswith("["):
            try:
                parsed = json.loads(normalized)
            except json.JSONDecodeError:
                parsed = None
            if isinstance(parsed, list):
                return [item.strip() for item in parsed if isinstance(item, str) and item.strip()]
        return [item.strip() for item in normalized.split(",") if item.strip()]
    return value


class Settings(BaseSettings):
    """Centralized environment-backed settings."""

    model_config = SettingsConfigDict(
        env_file=str(ENV_FILE),
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "Life OS API"
    environment: str = Field(default="development", alias="ENVIRONMENT")
    api_v1_prefix: str = "/api/v1"
    app_locale: str = "tr-TR"
    single_user_mode: bool = True
    app_api_token: str = Field(default="", alias="APP_API_TOKEN")
    default_owner_email: str = Field(default="owner@lifeos.local", alias="DEFAULT_OWNER_EMAIL")
    default_owner_name: str = Field(default="Life OS Owner", alias="DEFAULT_OWNER_NAME")

    database_url: str = Field(
        default="postgresql+psycopg://lifeos:lifeos@localhost:5432/lifeos",
        alias="DATABASE_URL",
    )

    openrouter_api_key: str = Field(default="", alias="OPENROUTER_API_KEY")
    openrouter_base_url: str = Field(
        default="https://openrouter.ai/api/v1",
        alias="OPENROUTER_BASE_URL",
    )
    openrouter_model: str = Field(
        default="stepfun/step-3.5-flash:free",
        alias="OPENROUTER_MODEL",
    )
    openrouter_models: Annotated[list[str], NoDecode] = Field(
        default_factory=lambda: [
            "stepfun/step-3.5-flash:free",
            "arcee-ai/trinity-large-preview:free",
            "nvidia/nemotron-3-nano-30b-a3b:free",
            "arcee-ai/trinity-mini:free",
            "nvidia/nemotron-nano-9b-v2:free",
            "qwen/qwen3-4b:free",
            "liquid/lfm-2.5-1.2b-instruct:free",
            "openrouter/free",
        ],
        alias="OPENROUTER_MODELS",
    )

    web_app_url: str = Field(
        default="http://localhost:5173",
        alias="WEB_APP_URL",
    )
    cors_origins: Annotated[list[str], NoDecode] = Field(
        default_factory=lambda: [
            "http://localhost:3000",
            "http://localhost:5173",
            "http://127.0.0.1:5173",
        ],
        alias="CORS_ORIGINS",
    )

    enable_web_push: bool = Field(default=False, alias="ENABLE_WEB_PUSH")
    vapid_public_key: str = Field(default="", alias="VAPID_PUBLIC_KEY")
    vapid_private_key: str = Field(default="", alias="VAPID_PRIVATE_KEY")
    vapid_subject: str = Field(default="mailto:notify@lifeos.app", alias="VAPID_SUBJECT")
    reminder_dispatch_interval_seconds: int = Field(
        default=60,
        alias="REMINDER_DISPATCH_INTERVAL_SECONDS",
    )
    reminder_dispatch_limit: int = Field(default=20, alias="REMINDER_DISPATCH_LIMIT")

    @field_validator("openrouter_models", mode="before")
    @classmethod
    def parse_openrouter_models(cls, value):
        return _parse_list_env(value)

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, value):
        return _parse_list_env(value)

    @model_validator(mode="after")
    def ensure_web_app_url_in_cors(self):
        if not self.web_app_url:
            return self

        split = urlsplit(self.web_app_url)
        if not split.scheme or not split.netloc:
            return self

        origin = f"{split.scheme}://{split.netloc}"
        if origin not in self.cors_origins:
            self.cors_origins.append(origin)
        return self


@lru_cache
def get_settings() -> Settings:
    """Return a cached settings instance."""

    return Settings()
