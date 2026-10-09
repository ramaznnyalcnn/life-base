"""Race-safe balance changes, access rules and the change feed of the wallet.

Rules every wallet write follows:
- Balances only move through :func:`apply_balance_deltas`: one atomic
  ``UPDATE … SET balance = balance + :delta`` per account, in id order, inside
  the caller's transaction. Two people adding expenses to the same shared card
  at once both land, and nothing is lost.
- Edits and deletions lock the accounts they touch first (:func:`lock_accounts`,
  ``SELECT … FOR UPDATE`` in id order), then undo the old effect and apply the
  new one.
- Every changed record is noted with :func:`record_change`. Right before the
  commit the notes get the next numbers of their scope's counter, which stays
  locked until the commit, so numbers are handed out in commit order and a
  client pulling "since n" never skips a change. The counter is always the last
  lock taken, after any account, so writers cannot deadlock on it.
"""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from dataclasses import dataclass
from decimal import Decimal

from sqlalchemy import event, select, update
from sqlalchemy.dialects import postgresql, sqlite
from sqlalchemy.orm import Session

from app.models import Account, HouseholdMember, TransactionType, WalletChange, WalletCursor


SHARED = "shared"
PERSONAL = "personal"
_PENDING = "wallet_changes"


class WalletAccessError(PermissionError):
    """The user may not see or change this wallet record."""


def household_id_of(session: Session, user_id: int) -> int | None:
    return session.scalar(select(HouseholdMember.household_id).where(HouseholdMember.user_id == user_id))


def scope_for(household_id: int | None, user_id: int) -> str:
    return f"h:{household_id}" if household_id is not None else f"u:{user_id}"


def scope_of_user(session: Session, user_id: int) -> str:
    return scope_for(household_id_of(session, user_id), user_id)


@dataclass(frozen=True, slots=True)
class Viewer:
    """Who is asking, and the household whose shared accounts they may use."""

    user_id: int
    household_id: int | None

    @classmethod
    def of(cls, session: Session, user_id: int) -> "Viewer":
        return cls(user_id, household_id_of(session, user_id))

    @property
    def scope(self) -> str:
        return scope_for(self.household_id, self.user_id)

    def can_use(self, account: Account) -> bool:
        if account.user_id == self.user_id:
            return True
        return (
            account.visibility == SHARED
            and self.household_id is not None
            and account.household_id == self.household_id
        )


def account_by_client_id(session: Session, viewer: Viewer, client_id: str) -> Account:
    account = session.scalar(select(Account).where(Account.client_id == client_id))
    if account is None:
        raise ValueError("Hesap bulunamadi.")
    if not viewer.can_use(account):
        raise WalletAccessError("Bu hesaba erisimin yok.")
    return account


def lock_accounts(session: Session, account_ids: Iterable[int]) -> dict[int, Account]:
    """Row-lock accounts in id order (no-op on SQLite) and return them fresh."""

    ids = sorted(set(account_ids))
    if not ids:
        return {}
    rows = session.scalars(
        select(Account).where(Account.id.in_(ids)).order_by(Account.id).with_for_update().execution_options(populate_existing=True)
    ).all()
    return {row.id: row for row in rows}


def transaction_effect(kind: TransactionType, amount: Decimal) -> Decimal:
    """What a transaction does to its account balance (a payment into a card raises it)."""

    return amount if kind in (TransactionType.INCOME, TransactionType.PAYMENT) else -amount


def apply_balance_deltas(session: Session, deltas: Mapping[int, Decimal]) -> None:
    """Atomically add each delta to its account balance, in account id order."""

    for account_id in sorted(deltas):
        delta = deltas[account_id]
        if not delta:
            continue
        session.execute(
            update(Account)
            .where(Account.id == account_id)
            .values(balance=Account.balance + delta)
            .execution_options(synchronize_session=False)
        )
    # Loaded accounts now hold stale balances; reload them on next access.
    for obj in session.identity_map.values():
        if isinstance(obj, Account) and obj.id in deltas:
            session.expire(obj, ["balance"])


def apply_balance_delta(session: Session, account_id: int, delta: Decimal) -> None:
    apply_balance_deltas(session, {account_id: delta})


def owner_scope(session: Session, account: Account) -> str:
    """A record's changes are numbered in its account owner's scope."""

    return scope_of_user(session, account.user_id)


def record_change(session: Session, scope: str, kind: str, client_id: str | None, *, deleted: bool = False) -> None:
    if client_id is None:
        return
    pending: dict[tuple[str, str, str], bool] = session.info.setdefault(_PENDING, {})
    pending[(scope, kind, client_id)] = deleted


def _next_seq(session: Session, scope: str) -> int:
    bump = (
        update(WalletCursor)
        .where(WalletCursor.scope == scope)
        .values(last_seq=WalletCursor.last_seq + 1)
        .returning(WalletCursor.last_seq)
    )
    value = session.execute(bump, execution_options={"synchronize_session": False}).scalar_one_or_none()
    if value is not None:
        return value
    dialect = postgresql if session.get_bind().dialect.name == "postgresql" else sqlite
    session.execute(dialect.insert(WalletCursor).values(scope=scope, last_seq=0).on_conflict_do_nothing())
    return session.execute(bump, execution_options={"synchronize_session": False}).scalar_one()


def current_cursor(session: Session, scope: str) -> int:
    return session.scalar(select(WalletCursor.last_seq).where(WalletCursor.scope == scope)) or 0


@event.listens_for(Session, "before_commit")
def _number_wallet_changes(session: Session) -> None:
    pending: dict[tuple[str, str, str], bool] | None = session.info.pop(_PENDING, None)
    if not pending:
        return
    session.flush()
    for (scope, kind, client_id), deleted in sorted(pending.items()):
        session.add(WalletChange(scope=scope, seq=_next_seq(session, scope), kind=kind, client_id=client_id, deleted=deleted))
    session.flush()


@event.listens_for(Session, "after_rollback")
def _forget_wallet_changes(session: Session) -> None:
    session.info.pop(_PENDING, None)
