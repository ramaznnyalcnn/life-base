"""Transfer domain helpers."""

from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models import Account, AccountType, Transfer
from app.schemas import TransferCreate, TransferUpdate
from app.services.auth import ensure_default_user


ZERO = Decimal("0.00")


def _resolve_user_id(session: Session, user_id: int | None) -> int:
    return user_id if user_id is not None else ensure_default_user(session).id


def _get_owned_account(session: Session, account_id: int, owner_id: int) -> Account:
    account = session.scalar(select(Account).where(Account.id == account_id, Account.user_id == owner_id))
    if account is None:
        raise ValueError("Hesap bulunamadi.")
    return account


def _apply_transfer(source_account: Account, destination_account: Account, amount: Decimal) -> None:
    source_account.balance -= amount
    destination_account.balance += amount


def _revert_transfer(source_account: Account, destination_account: Account, amount: Decimal) -> None:
    source_account.balance += amount
    destination_account.balance -= amount


def _transfer_query(owner_id: int):
    return (
        select(Transfer)
        .options(
            selectinload(Transfer.source_account),
            selectinload(Transfer.destination_account),
        )
        .where(Transfer.user_id == owner_id)
        .order_by(Transfer.occurred_at.desc(), Transfer.id.desc())
    )


def list_transfers(
    session: Session,
    *,
    user_id: int | None = None,
    source_account_id: int | None = None,
    destination_account_id: int | None = None,
) -> list[Transfer]:
    """Return owned transfers ordered from newest to oldest."""

    owner_id = _resolve_user_id(session, user_id)
    query = _transfer_query(owner_id)
    if source_account_id is not None:
        query = query.where(Transfer.source_account_id == source_account_id)
    if destination_account_id is not None:
        query = query.where(Transfer.destination_account_id == destination_account_id)
    return list(session.scalars(query).all())


def create_transfer(session: Session, payload: TransferCreate, *, user_id: int | None = None) -> Transfer:
    """Create a transfer and update both account balances."""

    owner_id = _resolve_user_id(session, user_id)
    source_account = _get_owned_account(session, payload.source_account_id, owner_id)
    destination_account = _get_owned_account(session, payload.destination_account_id, owner_id)
    if source_account.id == destination_account.id:
        raise ValueError("Kaynak ve hedef hesap ayni olamaz.")

    occurred_at = payload.occurred_at or datetime.now(timezone.utc)
    transfer = Transfer(
        user_id=owner_id,
        source_account_id=source_account.id,
        destination_account_id=destination_account.id,
        amount=payload.amount,
        description=payload.description,
        note=payload.note,
        occurred_at=occurred_at,
    )

    _apply_transfer(source_account, destination_account, payload.amount)
    session.add(transfer)
    session.commit()
    session.refresh(transfer)
    return session.scalar(_transfer_query(owner_id).where(Transfer.id == transfer.id))


def update_transfer(
    session: Session,
    transfer_id: int,
    payload: TransferUpdate,
    *,
    user_id: int | None = None,
) -> Transfer:
    """Update a transfer and keep both account balances consistent."""

    owner_id = _resolve_user_id(session, user_id)
    transfer = session.scalar(_transfer_query(owner_id).where(Transfer.id == transfer_id))
    if transfer is None:
        raise ValueError("Transfer bulunamadi.")

    original_source = _get_owned_account(session, transfer.source_account_id, owner_id)
    original_destination = _get_owned_account(session, transfer.destination_account_id, owner_id)
    _revert_transfer(original_source, original_destination, transfer.amount)

    updates = payload.model_dump(exclude_unset=True)
    next_source = _get_owned_account(session, updates.get("source_account_id", transfer.source_account_id), owner_id)
    next_destination = _get_owned_account(
        session,
        updates.get("destination_account_id", transfer.destination_account_id),
        owner_id,
    )
    if next_source.id == next_destination.id:
        raise ValueError("Kaynak ve hedef hesap ayni olamaz.")

    transfer.source_account_id = next_source.id
    transfer.destination_account_id = next_destination.id
    transfer.amount = updates.get("amount", transfer.amount)
    transfer.description = updates.get("description", transfer.description)
    transfer.note = updates.get("note", transfer.note)
    transfer.occurred_at = updates.get("occurred_at", transfer.occurred_at)

    _apply_transfer(next_source, next_destination, transfer.amount)
    session.commit()
    return session.scalar(_transfer_query(owner_id).where(Transfer.id == transfer.id))


def delete_transfer(session: Session, transfer_id: int, *, user_id: int | None = None) -> None:
    """Delete a transfer and revert both account balances."""

    owner_id = _resolve_user_id(session, user_id)
    transfer = session.scalar(_transfer_query(owner_id).where(Transfer.id == transfer_id))
    if transfer is None:
        raise ValueError("Transfer bulunamadi.")

    source_account = _get_owned_account(session, transfer.source_account_id, owner_id)
    destination_account = _get_owned_account(session, transfer.destination_account_id, owner_id)
    _revert_transfer(source_account, destination_account, transfer.amount)
    session.delete(transfer)
    session.commit()


def sum_card_payment_transfers(
    session: Session,
    *,
    user_id: int,
    start: datetime | None = None,
    end: datetime | None = None,
) -> Decimal:
    """Sum transfers whose destination account is a credit card."""

    query = (
        select(Transfer)
        .join(Account, Account.id == Transfer.destination_account_id)
        .where(
            Transfer.user_id == user_id,
            Account.type == AccountType.CREDIT_CARD,
        )
    )
    if start is not None:
        query = query.where(Transfer.occurred_at >= start)
    if end is not None:
        query = query.where(Transfer.occurred_at <= end)

    return sum((transfer.amount for transfer in session.scalars(query).all()), start=ZERO)
