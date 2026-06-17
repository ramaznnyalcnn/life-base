"""Account endpoints."""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.db import get_db
from app.models import Account, AccountType, User
from app.schemas import AccountCreate, AccountRead, AccountUpdate
from app.services.bootstrap import ensure_default_cash_account


router = APIRouter(prefix="/accounts", tags=["accounts"])


@router.get("", response_model=list[AccountRead])
def list_accounts(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    ensure_default_cash_account(db, current_user.id)
    return list(
        db.scalars(
            select(Account)
            .where(Account.user_id == current_user.id)
            .order_by(Account.type, Account.name)
        ).all()
    )


@router.post("", response_model=AccountRead, status_code=status.HTTP_201_CREATED)
def create_account(
    payload: AccountCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    existing = db.scalar(
        select(Account).where(Account.user_id == current_user.id, Account.name == payload.name)
    )
    if existing:
        raise HTTPException(status_code=409, detail="Bu isimde bir hesap zaten var.")

    account = Account(
        user_id=current_user.id,
        name=payload.name,
        type=payload.type,
        currency=payload.currency,
        balance=payload.balance,
        credit_limit=(
            payload.credit_limit if payload.type == AccountType.CREDIT_CARD else None
        ),
        statement_day=(
            payload.statement_day if payload.type == AccountType.CREDIT_CARD else None
        ),
        due_day=payload.due_day if payload.type == AccountType.CREDIT_CARD else None,
        issuer=payload.issuer,
        is_active=payload.is_active,
    )
    db.add(account)
    db.commit()
    db.refresh(account)
    return account


@router.put("/{account_id}", response_model=AccountRead)
def update_account(
    account_id: int,
    payload: AccountUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    account = db.scalar(select(Account).where(Account.id == account_id, Account.user_id == current_user.id))
    if account is None:
        raise HTTPException(status_code=404, detail="Hesap bulunamadi.")

    updates = payload.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(account, field, value)

    if account.type != AccountType.CREDIT_CARD:
        account.credit_limit = None
        account.statement_day = None
        account.due_day = None

    db.commit()
    db.refresh(account)
    return account
