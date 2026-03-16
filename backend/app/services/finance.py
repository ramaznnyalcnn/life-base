"""Finance domain helpers used by the API layer."""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models import Account, AccountType, Category, CategoryType, Transaction, TransactionType
from app.schemas import SummaryPeriod, TransactionCreate, TransactionSummary, TransactionUpdate
from app.services.auth import ensure_default_user
from app.services.transfers import sum_card_payment_transfers


ZERO = Decimal("0.00")


def _resolve_user_id(session: Session, user_id: int | None) -> int:
    return user_id if user_id is not None else ensure_default_user(session).id


def calculate_statement_month(occurred_at: datetime, statement_day: int | None) -> date | None:
    """Calculate the statement month bucket for card transactions."""

    if statement_day is None:
        return None

    year = occurred_at.year
    month = occurred_at.month
    if occurred_at.day > statement_day:
        if month == 12:
            year += 1
            month = 1
        else:
            month += 1
    return date(year, month, 1)


def resolve_category(
    session: Session,
    payload: TransactionCreate,
    user_id: int | None = None,
) -> Category | None:
    """Resolve category by id or name, creating a user category when needed."""
    owner_id = _resolve_user_id(session, user_id)

    if payload.category_id is not None:
        return session.scalar(
            select(Category).where(
                Category.id == payload.category_id,
                (Category.user_id == owner_id) | (Category.user_id.is_(None)),
            )
        )

    if not payload.category_name:
        return None

    category = session.scalar(
        select(Category).where(
            Category.name == payload.category_name,
            (Category.user_id == owner_id) | (Category.user_id.is_(None)),
        )
    )
    if category:
        return category

    category_type = (
        CategoryType.INCOME
        if payload.type == TransactionType.INCOME
        else CategoryType.EXPENSE
    )
    category = Category(name=payload.category_name, type=category_type, is_system=False, user_id=owner_id)
    session.add(category)
    session.flush()
    return category


def resolve_account(
    session: Session,
    account_name: str | None,
    user_id: int | None = None,
) -> Account | None:
    """Resolve an account by explicit name or single-account fallback."""
    owner_id = _resolve_user_id(session, user_id)

    if account_name:
        normalized = account_name.strip()
        exact = session.scalar(
            select(Account).where(
                func.lower(Account.name) == normalized.lower(),
                Account.is_active.is_(True),
                Account.user_id == owner_id,
            )
        )
        if exact is not None:
            return exact

        partial_matches = list(
            session.scalars(
                select(Account).where(
                    Account.name.ilike(f"%{normalized}%"),
                    Account.is_active.is_(True),
                    Account.user_id == owner_id,
                )
            ).all()
        )
        if len(partial_matches) == 1:
            return partial_matches[0]
        return None

    accounts = list(
        session.scalars(
            select(Account)
            .where(Account.is_active.is_(True), Account.user_id == owner_id)
            .order_by(Account.id.asc())
        ).all()
    )
    if len(accounts) == 1:
        return accounts[0]
    return None


def apply_transaction_to_account(account: Account, payload: TransactionCreate) -> None:
    """Apply transaction impact to account balance."""

    if payload.type == TransactionType.INCOME:
        account.balance += payload.amount
        return

    if payload.type == TransactionType.PAYMENT:
        account.balance += payload.amount
        return

    account.balance -= payload.amount


def revert_transaction_from_account(account: Account, transaction: Transaction) -> None:
    """Revert transaction impact from account balance."""

    if transaction.type == TransactionType.INCOME:
        account.balance -= transaction.amount
        return

    if transaction.type == TransactionType.PAYMENT:
        account.balance -= transaction.amount
        return

    account.balance += transaction.amount


def create_transaction(session: Session, payload: TransactionCreate, *, user_id: int | None = None) -> Transaction:
    """Create a transaction and update related account state."""
    owner_id = _resolve_user_id(session, user_id)

    account = session.scalar(select(Account).where(Account.id == payload.account_id, Account.user_id == owner_id))
    if account is None:
        raise ValueError("Hesap bulunamadi.")

    category = resolve_category(session, payload, owner_id)
    occurred_at = payload.occurred_at or datetime.now(timezone.utc)

    transaction = Transaction(
        user_id=owner_id,
        account_id=account.id,
        category_id=category.id if category else None,
        type=payload.type,
        amount=payload.amount,
        description=payload.description,
        note=payload.note,
        occurred_at=occurred_at,
        statement_month=(
            calculate_statement_month(occurred_at, account.statement_day)
            if account.type == AccountType.CREDIT_CARD
            else None
        ),
    )

    apply_transaction_to_account(account, payload)

    session.add(transaction)
    session.commit()
    session.refresh(transaction)
    session.refresh(account)
    return transaction


def update_transaction(
    session: Session,
    transaction_id: int,
    payload: TransactionUpdate,
    *,
    user_id: int | None = None,
) -> Transaction:
    """Update a transaction and keep balances consistent."""
    owner_id = _resolve_user_id(session, user_id)

    transaction = session.scalar(
        select(Transaction).where(Transaction.id == transaction_id, Transaction.user_id == owner_id)
    )
    if transaction is None:
        raise ValueError("Islem bulunamadi.")

    original_account = session.scalar(
        select(Account).where(Account.id == transaction.account_id, Account.user_id == owner_id)
    )
    if original_account is None:
        raise ValueError("Orijinal hesap bulunamadi.")

    revert_transaction_from_account(original_account, transaction)

    updates = payload.model_dump(exclude_unset=True)
    next_account_id = updates.get("account_id", transaction.account_id)
    next_account = session.scalar(select(Account).where(Account.id == next_account_id, Account.user_id == owner_id))
    if next_account is None:
        raise ValueError("Hesap bulunamadi.")

    next_type = updates.get("type", transaction.type)
    requested_category_name = updates.get("category_name")
    requested_category_id = updates.get("category_id", transaction.category_id)
    category_payload = TransactionCreate(
        account_id=next_account.id,
        category_id=None if requested_category_name else requested_category_id,
        category_name=requested_category_name,
        type=next_type,
        amount=updates.get("amount", transaction.amount),
        description=updates.get("description", transaction.description),
        note=updates.get("note", transaction.note),
        occurred_at=updates.get("occurred_at", transaction.occurred_at),
    )
    category = resolve_category(session, category_payload, owner_id)

    transaction.user_id = owner_id
    transaction.account_id = next_account.id
    transaction.category_id = category.id if category else None
    transaction.type = next_type
    transaction.amount = category_payload.amount
    transaction.description = category_payload.description
    transaction.note = category_payload.note
    transaction.occurred_at = category_payload.occurred_at or transaction.occurred_at
    transaction.statement_month = (
        calculate_statement_month(transaction.occurred_at, next_account.statement_day)
        if next_account.type == AccountType.CREDIT_CARD
        else None
    )

    apply_transaction_to_account(
        next_account,
        TransactionCreate(
            account_id=next_account.id,
            category_id=transaction.category_id,
            type=transaction.type,
            amount=transaction.amount,
            description=transaction.description,
            note=transaction.note,
            occurred_at=transaction.occurred_at,
        ),
    )

    session.commit()
    session.refresh(transaction)
    return transaction


def delete_transaction(session: Session, transaction_id: int, *, user_id: int | None = None) -> None:
    """Delete a transaction and revert its balance effect."""
    owner_id = _resolve_user_id(session, user_id)

    transaction = session.scalar(
        select(Transaction).where(Transaction.id == transaction_id, Transaction.user_id == owner_id)
    )
    if transaction is None:
        raise ValueError("Islem bulunamadi.")

    account = session.scalar(select(Account).where(Account.id == transaction.account_id, Account.user_id == owner_id))
    if account is None:
        raise ValueError("Hesap bulunamadi.")

    revert_transaction_from_account(account, transaction)
    session.delete(transaction)
    session.commit()


def get_period_bounds(period: SummaryPeriod) -> tuple[datetime | None, datetime | None]:
    """Return UTC period boundaries for summaries."""

    now = datetime.now(timezone.utc)
    if period == SummaryPeriod.ALL:
        return None, None
    if period == SummaryPeriod.WEEK:
        start = now - timedelta(days=now.weekday())
        start = datetime(start.year, start.month, start.day, tzinfo=timezone.utc)
        return start, now
    start = datetime(now.year, now.month, 1, tzinfo=timezone.utc)
    return start, now


def build_transaction_summary(
    session: Session,
    period: SummaryPeriod,
    *,
    user_id: int | None = None,
) -> TransactionSummary:
    """Aggregate transactions for dashboard summaries."""
    owner_id = _resolve_user_id(session, user_id)

    start, end = get_period_bounds(period)
    query = select(Transaction).where(Transaction.user_id == owner_id)

    if start is not None:
        query = query.where(Transaction.occurred_at >= start)
    if end is not None:
        query = query.where(Transaction.occurred_at <= end)

    transactions = list(session.scalars(query.order_by(Transaction.occurred_at.desc())).all())

    total_income = sum(
        (tx.amount for tx in transactions if tx.type == TransactionType.INCOME),
        start=ZERO,
    )
    total_expense = sum(
        (tx.amount for tx in transactions if tx.type == TransactionType.EXPENSE),
        start=ZERO,
    )
    total_payments = sum(
        (tx.amount for tx in transactions if tx.type == TransactionType.PAYMENT),
        start=ZERO,
    )
    total_payments += sum_card_payment_transfers(session, user_id=owner_id, start=start, end=end)

    return TransactionSummary(
        period=period,
        period_start=start,
        period_end=end,
        total_income=total_income,
        total_expense=total_expense,
        total_payments=total_payments,
        net_flow=total_income - total_expense,
        transaction_count=len(transactions),
    )


def build_summary_for_bounds(
    session: Session,
    *,
    user_id: int | None = None,
    start: datetime,
    end: datetime,
    period: SummaryPeriod = SummaryPeriod.ALL,
) -> TransactionSummary:
    """Aggregate transactions for an explicit UTC date range."""
    owner_id = _resolve_user_id(session, user_id)

    transactions = list(
        session.scalars(
            select(Transaction)
            .where(
                Transaction.user_id == owner_id,
                Transaction.occurred_at >= start,
                Transaction.occurred_at <= end,
            )
            .order_by(Transaction.occurred_at.desc())
        ).all()
    )

    total_income = sum(
        (tx.amount for tx in transactions if tx.type == TransactionType.INCOME),
        start=ZERO,
    )
    total_expense = sum(
        (tx.amount for tx in transactions if tx.type == TransactionType.EXPENSE),
        start=ZERO,
    )
    total_payments = sum(
        (tx.amount for tx in transactions if tx.type == TransactionType.PAYMENT),
        start=ZERO,
    )
    total_payments += sum_card_payment_transfers(session, user_id=owner_id, start=start, end=end)

    return TransactionSummary(
        period=period,
        period_start=start,
        period_end=end,
        total_income=total_income,
        total_expense=total_expense,
        total_payments=total_payments,
        net_flow=total_income - total_expense,
        transaction_count=len(transactions),
    )
