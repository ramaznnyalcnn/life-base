"""Wallet dashboard endpoints."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.db import get_db
from app.models import User
from app.schemas import CardStatementSummary, WalletSummary
from app.services.wallet import build_card_statements, build_wallet_summary


router = APIRouter(prefix="/wallet", tags=["wallet"])


@router.get("/summary", response_model=WalletSummary)
def get_wallet_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    return build_wallet_summary(db, user_id=current_user.id)


@router.get("/statements", response_model=list[CardStatementSummary])
def list_card_statements(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    return build_card_statements(db, user_id=current_user.id)
