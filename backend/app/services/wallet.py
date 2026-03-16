"""Wallet dashboard aggregation helpers."""

from __future__ import annotations

from calendar import monthrange
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Account, AccountType, Transfer, Transaction, TransactionType
from app.schemas import CardStatementSummary, SummaryPeriod, WalletAccountCard, WalletSummary
from app.services.bootstrap import ensure_default_cash_account
from app.services.auth import ensure_default_user
from app.services.finance import build_summary_for_bounds, build_transaction_summary


ZERO = Decimal("0.00")


def _resolve_user_id(session: Session, user_id: int | None) -> int:
    return user_id if user_id is not None else ensure_default_user(session).id


def _month_start(year: int, month: int) -> date:
    return date(year, month, 1)


def _shift_month(month_value: date, offset: int) -> date:
    month_index = (month_value.year * 12 + month_value.month - 1) + offset
    year, month = divmod(month_index, 12)
    return date(year, month + 1, 1)


def _safe_month_day(year: int, month: int, day: int) -> date:
    return date(year, month, min(day, monthrange(year, month)[1]))


def _current_statement_month(now: date, statement_day: int) -> date:
    if now.day <= statement_day:
        return _month_start(now.year, now.month)
    return _shift_month(_month_start(now.year, now.month), 1)


def _statement_period(bucket: date, statement_day: int) -> tuple[date, date]:
    period_end = _safe_month_day(bucket.year, bucket.month, statement_day)
    previous_month = _shift_month(bucket, -1)
    previous_close = _safe_month_day(previous_month.year, previous_month.month, statement_day)
    period_start = previous_close + timedelta(days=1)
    return period_start, period_end


def _statement_due_date(bucket: date, due_day: int | None) -> date | None:
    if due_day is None:
        return None
    next_month = _shift_month(bucket, 1)
    return _safe_month_day(next_month.year, next_month.month, due_day)


def _to_card_summary(account: Account) -> WalletAccountCard:
    if account.type != AccountType.CREDIT_CARD or account.credit_limit is None:
        return WalletAccountCard(
            id=account.id,
            name=account.name,
            type=account.type,
            currency=account.currency,
            balance=account.balance,
            credit_limit=account.credit_limit,
            issuer=account.issuer,
            statement_day=account.statement_day,
            due_day=account.due_day,
            is_active=account.is_active,
            available_credit=None,
            used_credit=None,
            utilization_ratio=None,
        )

    available_credit = max(account.balance, ZERO)
    used_credit = max(account.credit_limit - available_credit, ZERO)
    utilization_ratio = (
        (used_credit / account.credit_limit).quantize(Decimal("0.0001"))
        if account.credit_limit > ZERO
        else ZERO
    )

    return WalletAccountCard(
        id=account.id,
        name=account.name,
        type=account.type,
        currency=account.currency,
        balance=account.balance,
        credit_limit=account.credit_limit,
        issuer=account.issuer,
        statement_day=account.statement_day,
        due_day=account.due_day,
        is_active=account.is_active,
        available_credit=available_credit,
        used_credit=used_credit,
        utilization_ratio=utilization_ratio,
    )


def build_wallet_summary(
    session: Session,
    *,
    user_id: int | None = None,
    now: datetime | None = None,
) -> WalletSummary:
    """Build a wallet-centric summary for the mobile dashboard."""

    owner_id = _resolve_user_id(session, user_id)
    ensure_default_cash_account(session, owner_id)
    current_time = now or datetime.now(timezone.utc)
    current_month_start = datetime(current_time.year, current_time.month, 1, tzinfo=timezone.utc)
    previous_month_end = current_month_start - timedelta(microseconds=1)
    previous_month_start = datetime(previous_month_end.year, previous_month_end.month, 1, tzinfo=timezone.utc)
    previous_year_start = datetime(current_time.year - 1, 1, 1, tzinfo=timezone.utc)
    previous_year_end = datetime(current_time.year - 1, 12, 31, 23, 59, 59, 999999, tzinfo=timezone.utc)

    accounts = list(
        session.scalars(
            select(Account)
            .where(Account.is_active.is_(True), Account.user_id == owner_id)
            .order_by(Account.type.asc(), Account.name.asc())
        ).all()
    )
    account_cards = [_to_card_summary(account) for account in accounts]

    liquid_balance = sum(
        (
            account.balance
            for account in accounts
            if account.type in {AccountType.CASH, AccountType.BANK}
        ),
        start=ZERO,
    )
    total_credit_limit = sum(
        (
            account.credit_limit
            for account in accounts
            if account.type == AccountType.CREDIT_CARD and account.credit_limit is not None
        ),
        start=ZERO,
    )
    total_card_available = sum(
        (
            card.available_credit
            for card in account_cards
            if card.type == AccountType.CREDIT_CARD and card.available_credit is not None
        ),
        start=ZERO,
    )
    total_card_used = sum(
        (
            card.used_credit
            for card in account_cards
            if card.type == AccountType.CREDIT_CARD and card.used_credit is not None
        ),
        start=ZERO,
    )
    previous_month_flow = build_summary_for_bounds(
        session,
        user_id=owner_id,
        start=previous_month_start,
        end=previous_month_end,
    )
    previous_year_flow = build_summary_for_bounds(
        session,
        user_id=owner_id,
        start=previous_year_start,
        end=previous_year_end,
    )

    return WalletSummary(
        liquid_balance=liquid_balance,
        total_card_available=total_card_available,
        total_card_used=total_card_used,
        total_credit_limit=total_credit_limit,
        net_worth=liquid_balance - total_card_used,
        previous_month_net=previous_month_flow.net_flow,
        previous_year_net=previous_year_flow.net_flow,
        active_account_count=len(accounts),
        active_card_count=sum(1 for account in accounts if account.type == AccountType.CREDIT_CARD),
        weekly_flow=build_transaction_summary(session, SummaryPeriod.WEEK, user_id=owner_id),
        monthly_flow=build_transaction_summary(session, SummaryPeriod.MONTH, user_id=owner_id),
        accounts=account_cards,
    )


def build_card_statements(
    session: Session,
    *,
    user_id: int | None = None,
    now: datetime | None = None,
) -> list[CardStatementSummary]:
    """Build current statement summaries for all active credit cards."""

    owner_id = _resolve_user_id(session, user_id)
    current_time = now or datetime.now(timezone.utc)
    today = current_time.date()
    cards = list(
        session.scalars(
            select(Account)
            .where(
                Account.is_active.is_(True),
                Account.type == AccountType.CREDIT_CARD,
                Account.user_id == owner_id,
            )
            .order_by(Account.name.asc())
        ).all()
    )

    statements: list[CardStatementSummary] = []
    for card in cards:
        if card.statement_day is None:
            continue

        statement_month = _current_statement_month(today, card.statement_day)
        period_start, period_end = _statement_period(statement_month, card.statement_day)
        statement_rows = list(
            session.scalars(
                select(Transaction).where(
                    Transaction.user_id == owner_id,
                    Transaction.account_id == card.id,
                    Transaction.statement_month == statement_month,
                )
            ).all()
        )
        transfer_start = datetime.combine(period_start, time.min, tzinfo=timezone.utc)
        transfer_end = datetime.combine(period_end, time.max, tzinfo=timezone.utc)
        transfer_rows = list(
            session.scalars(
                select(Transfer).where(
                    Transfer.user_id == owner_id,
                    Transfer.destination_account_id == card.id,
                    Transfer.occurred_at >= transfer_start,
                    Transfer.occurred_at <= transfer_end,
                )
            ).all()
        )
        statement_amount = sum(
            (tx.amount for tx in statement_rows if tx.type == TransactionType.EXPENSE),
            start=ZERO,
        )
        payment_activity = sum(
            (tx.amount for tx in statement_rows if tx.type == TransactionType.PAYMENT),
            start=ZERO,
        )
        payment_activity += sum((transfer.amount for transfer in transfer_rows), start=ZERO)
        auto_resets_at = datetime.combine(period_end + timedelta(days=1), time.min, tzinfo=timezone.utc)

        statements.append(
            CardStatementSummary(
                account_id=card.id,
                account_name=card.name,
                issuer=card.issuer,
                statement_month=statement_month,
                period_start=period_start,
                period_end=period_end,
                due_date=_statement_due_date(statement_month, card.due_day),
                auto_resets_at=auto_resets_at,
                statement_amount=statement_amount,
                payment_activity=payment_activity,
                transaction_count=len(statement_rows),
            )
        )

    return statements
