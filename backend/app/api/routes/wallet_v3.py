"""Pull the server-authoritative wallet (writes go through /api/v2/operations)."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.db import get_db
from app.models import User
from app.services.wallet_feed import pull


router = APIRouter(prefix="/wallet", tags=["wallet-v3"])


@router.get("/pull")
def pull_wallet(
    since: int = Query(default=0, ge=0),
    scope: str | None = Query(default=None, max_length=24),
    limit: int = Query(default=1000, ge=1, le=5000),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    return pull(db, current_user.id, since=since, scope=scope, limit=limit)
