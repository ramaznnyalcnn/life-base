"""Balance reconciliation: balance must equal opening balance plus every effect."""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal

from sqlalchemy import case, func, select
from sqlalchemy.orm import Session

from app.models import Account, Transaction, TransactionType, Transfer
from app.services.ledger import apply_balance_delta, lock_accounts, owner_scope, record_change


ZERO = Decimal("0.00")


@dataclass(frozen=True, slots=True)
class Drift:
    account_id: int
    name: str
    stored: Decimal
    expected: Decimal

    @property
    def difference(self) -> Decimal:
        return self.stored - self.expected


def expected_balances(session: Session) -> dict[int, Decimal]:
    effect = case(
        (Transaction.type.in_([TransactionType.INCOME, TransactionType.PAYMENT]), Transaction.amount),
        else_=-Transaction.amount,
    )
    transactions = dict(session.execute(select(Transaction.account_id, func.sum(effect)).group_by(Transaction.account_id)).all())
    incoming = dict(session.execute(select(Transfer.destination_account_id, func.sum(Transfer.amount)).group_by(Transfer.destination_account_id)).all())
    outgoing = dict(session.execute(select(Transfer.source_account_id, func.sum(Transfer.amount)).group_by(Transfer.source_account_id)).all())
    return {
        account_id: (opening or ZERO)
        + Decimal(transactions.get(account_id) or 0)
        + Decimal(incoming.get(account_id) or 0)
        - Decimal(outgoing.get(account_id) or 0)
        for account_id, opening in session.execute(select(Account.id, Account.opening_balance)).all()
    }


def find_drift(session: Session) -> list[Drift]:
    expected = expected_balances(session)
    rows = session.execute(select(Account.id, Account.name, Account.balance).order_by(Account.id)).all()
    return [
        Drift(account_id, name, balance, expected[account_id])
        for account_id, name, balance in rows
        if balance != expected[account_id]
    ]


def fix_drift(session: Session) -> list[Drift]:
    """Re-check each drifting account under its row lock and correct it atomically."""

    drifts = find_drift(session)
    if not drifts:
        return []
    accounts = lock_accounts(session, [drift.account_id for drift in drifts])
    expected = expected_balances(session)
    fixed = []
    for account_id, account in accounts.items():
        difference = account.balance - expected[account_id]
        if difference:
            apply_balance_delta(session, account_id, -difference)
            record_change(session, owner_scope(session, account), "account", account.client_id)
            fixed.append(Drift(account_id, account.name, account.balance + difference, expected[account_id]))
    return fixed
