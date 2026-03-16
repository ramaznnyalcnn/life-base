"""Transaction endpoints."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.db import get_db
from app.models import Transaction, TransactionType, User
from app.schemas import (
    SummaryPeriod,
    TransactionCreate,
    TransactionRead,
    TransactionSummary,
    TransactionUpdate,
)
from app.services.bootstrap import ensure_default_categories
from app.services.finance import (
    build_transaction_summary,
    create_transaction,
    delete_transaction,
    update_transaction,
)


router = APIRouter(prefix="/transactions", tags=["transactions"])


@router.get("", response_model=list[TransactionRead])
def list_transactions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    account_id: Annotated[int | None, Query()] = None,
    type: Annotated[TransactionType | None, Query()] = None,
    search: Annotated[str | None, Query(min_length=1)] = None,
):
    current_user = resolve_route_user(current_user, db)
    ensure_default_categories(db)
    query = (
        select(Transaction)
        .where(Transaction.user_id == current_user.id)
        .order_by(Transaction.occurred_at.desc(), Transaction.id.desc())
    )
    if account_id is not None:
        query = query.where(Transaction.account_id == account_id)
    if type is not None:
        query = query.where(Transaction.type == type)
    if search:
        query = query.where(Transaction.description.ilike(f"%{search.strip()}%"))
    return list(db.scalars(query).all())


@router.post("", response_model=TransactionRead, status_code=status.HTTP_201_CREATED)
def create_transaction_endpoint(
    payload: TransactionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    ensure_default_categories(db)
    try:
        return create_transaction(db, payload, user_id=current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/summary", response_model=TransactionSummary)
def get_transaction_summary(
    period: SummaryPeriod = Query(default=SummaryPeriod.MONTH),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    return build_transaction_summary(db, period, user_id=current_user.id)


@router.put("/{transaction_id}", response_model=TransactionRead)
def update_transaction_endpoint(
    transaction_id: int,
    payload: TransactionUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    ensure_default_categories(db)
    try:
        return update_transaction(db, transaction_id, payload, user_id=current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_transaction_endpoint(
    transaction_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    try:
        delete_transaction(db, transaction_id, user_id=current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
