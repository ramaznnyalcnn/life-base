"""Route modules for the Life OS backend."""

from app.api.routes.ai import router as ai_router
from app.api.routes.accounts import router as accounts_router
from app.api.routes.auth import router as auth_router
from app.api.routes.events import router as events_router
from app.api.routes.medications import router as medications_router
from app.api.routes.notifications import router as notifications_router
from app.api.routes.recurring_events import router as recurring_events_router
from app.api.routes.transfers import router as transfers_router
from app.api.routes.transactions import router as transactions_router
from app.api.routes.wallet import router as wallet_router

__all__ = [
    "auth_router",
    "ai_router",
    "accounts_router",
    "transactions_router",
    "transfers_router",
    "events_router",
    "medications_router",
    "recurring_events_router",
    "wallet_router",
    "notifications_router",
]
