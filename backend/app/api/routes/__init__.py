"""Route modules for the Life OS backend."""

from app.api.routes.accounts import router as accounts_router
from app.api.routes.activity_templates_v2 import router as activity_templates_v2_router
from app.api.routes.agenda_v2 import router as agenda_v2_router
from app.api.routes.daily_v2 import router as daily_v2_router
from app.api.routes.auth import router as auth_router
from app.api.routes.events import router as events_router
from app.api.routes.medications import router as medications_router
from app.api.routes.notifications import router as notifications_router
from app.api.routes.operations_v2 import router as operations_v2_router
from app.api.routes.recurring_events import router as recurring_events_router
from app.api.routes.transfers import router as transfers_router
from app.api.routes.transactions import router as transactions_router
from app.api.routes.wallet import router as wallet_router

__all__ = [
    "auth_router",
    "activity_templates_v2_router",
    "agenda_v2_router",
    "daily_v2_router",
    "accounts_router",
    "transactions_router",
    "transfers_router",
    "events_router",
    "medications_router",
    "recurring_events_router",
    "wallet_router",
    "notifications_router",
    "operations_v2_router",
]
