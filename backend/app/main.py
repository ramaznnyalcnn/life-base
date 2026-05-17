"""FastAPI entrypoint for the Life OS backend."""

from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from psycopg.errors import UndefinedColumn
from sqlalchemy.exc import ProgrammingError

from app.api.routes import (
    ai_router,
    accounts_router,
    auth_router,
    events_router,
    medications_router,
    notifications_router,
    recurring_events_router,
    transfers_router,
    transactions_router,
    wallet_router,
)
from app.core.config import get_settings


settings = get_settings()
logger = logging.getLogger(__name__)


def _is_missing_column_error(exc: ProgrammingError) -> bool:
    original = getattr(exc, "orig", None)
    if isinstance(original, UndefinedColumn):
        return True
    return "does not exist" in str(exc).lower()


def _database_error_detail(exc: ProgrammingError) -> str:
    if _is_missing_column_error(exc):
        return (
            "Veritabani semasi guncel degil. "
            "backend dizininde '../.venv/bin/alembic -c alembic.ini upgrade head' calistirin."
        )
    return "Veritabani sorgusu calisirken beklenmeyen bir hata olustu."


@asynccontextmanager
async def lifespan(_: FastAPI):
    """Application startup and shutdown hooks."""

    yield


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix=settings.api_v1_prefix)
app.include_router(ai_router, prefix=settings.api_v1_prefix)
app.include_router(accounts_router, prefix=settings.api_v1_prefix)
app.include_router(events_router, prefix=settings.api_v1_prefix)
app.include_router(medications_router, prefix=settings.api_v1_prefix)
app.include_router(recurring_events_router, prefix=settings.api_v1_prefix)
app.include_router(notifications_router, prefix=settings.api_v1_prefix)
app.include_router(transfers_router, prefix=settings.api_v1_prefix)
app.include_router(transactions_router, prefix=settings.api_v1_prefix)
app.include_router(wallet_router, prefix=settings.api_v1_prefix)


@app.exception_handler(ProgrammingError)
async def handle_programming_error(request: Request, exc: ProgrammingError) -> JSONResponse:
    """Return a structured response for database schema/runtime query failures."""

    logger.exception(
        "Database programming error on %s %s",
        request.method,
        request.url.path,
        exc_info=exc,
    )
    status_code = 503 if _is_missing_column_error(exc) else 500
    return JSONResponse(status_code=status_code, content={"detail": _database_error_detail(exc)})


@app.get("/")
async def root() -> dict[str, str]:
    """Basic root response for uptime checks."""

    return {
        "name": settings.app_name,
        "environment": settings.environment,
        "status": "ok",
    }


@app.get("/health")
async def health() -> dict[str, object]:
    """Operational health response for platforms and probes."""

    return {
        "status": "healthy",
        "database": "pending",
        "notifications": {
            "web_push": settings.enable_web_push,
            "vapid_configured": bool(settings.vapid_public_key and settings.vapid_private_key),
        },
        "security": {
            "app_token_enabled": bool(settings.app_api_token),
        },
        "ai": {
            "provider": "openrouter",
            "model": settings.openrouter_model,
            "configured": bool(settings.openrouter_api_key),
        },
        "mode": {
            "single_user": settings.single_user_mode,
            "locale": settings.app_locale,
        },
    }
