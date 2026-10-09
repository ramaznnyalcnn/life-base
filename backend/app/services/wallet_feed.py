"""What a client mirrors of the wallet, and pulling its changes."""

from __future__ import annotations

from collections.abc import Iterable
from datetime import date, datetime, timezone

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.models import Account, Category, StatementMark, Transaction, Transfer, User, WalletChange
from app.services.bootstrap import ensure_default_categories
from app.services.households import describe
from app.services.ledger import SHARED, Viewer, current_cursor


def _utc(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def mark_id(account_client_id: str, month: date) -> str:
    return f"{account_client_id}:{month:%Y-%m}"


def account_json(account: Account) -> dict[str, object]:
    return {
        "id": account.client_id,
        "server_id": account.id,
        "owner_id": account.user_id,
        "name": account.name,
        "type": account.type.value,
        "bank": account.issuer,
        "currency": account.currency,
        "balance": str(account.balance),
        "opening_balance": str(account.opening_balance),
        "credit_limit": None if account.credit_limit is None else str(account.credit_limit),
        "statement_day": account.statement_day,
        "due_day": account.due_day,
        "visibility": account.visibility,
        "last4": account.last4,
        "network": account.network,
        "color": account.color,
        "iban": account.iban,
        "is_active": account.is_active,
        "version": account.entity_version,
    }


def transaction_json(transaction: Transaction, account: Account) -> dict[str, object]:
    return {
        "id": transaction.client_id,
        "account_id": account.client_id,
        "kind": transaction.type.value,
        "category_id": transaction.category_id,
        "category": transaction.description,
        "amount": str(transaction.amount),
        "occurred_at": _utc(transaction.occurred_at).isoformat(),
        "statement_month": transaction.statement_month.isoformat() if transaction.statement_month else None,
        "note": transaction.note,
        "created_by": transaction.created_by_user_id or transaction.user_id,
        "installment_group": transaction.installment_group,
        "installment_index": transaction.installment_index,
        "installment_count": transaction.installment_count,
        "version": transaction.entity_version,
    }


def transfer_json(transfer: Transfer, source: Account, destination: Account) -> dict[str, object]:
    return {
        "id": transfer.client_id,
        "from_account_id": source.client_id,
        "to_account_id": destination.client_id,
        "amount": str(transfer.amount),
        "occurred_at": _utc(transfer.occurred_at).isoformat(),
        "note": transfer.note,
        "created_by": transfer.created_by_user_id or transfer.user_id,
        "version": transfer.entity_version,
    }


def mark_json(mark: StatementMark, account: Account) -> dict[str, object]:
    return {
        "id": mark_id(account.client_id, mark.statement_month),
        "account_id": account.client_id,
        "month": mark.statement_month.isoformat(),
        "paid": mark.paid,
        "version": mark.entity_version,
    }


def _visible_accounts_query(viewer: Viewer):
    condition = Account.user_id == viewer.user_id
    if viewer.household_id is not None:
        condition = or_(condition, (Account.visibility == SHARED) & (Account.household_id == viewer.household_id))
    return select(Account).where(condition)


def _categories(session: Session, viewer: Viewer) -> list[dict[str, object]]:
    rows = session.scalars(
        select(Category)
        .where((Category.user_id == viewer.user_id) | Category.user_id.is_(None), Category.is_active.is_(True))
        .order_by(Category.type, Category.name)
    ).all()
    return [{"id": row.id, "name": row.name, "kind": row.type.value} for row in rows]


def _empty() -> dict[str, list]:
    return {"accounts": [], "transactions": [], "transfers": [], "statement_marks": [], "deleted": []}


def _fill(session: Session, viewer: Viewer, out: dict[str, list], accounts: Iterable[Account],
          transactions: Iterable[Transaction], transfers: Iterable[Transfer], marks: Iterable[StatementMark]) -> None:
    by_id: dict[int, Account] = {}

    def account(account_id: int) -> Account | None:
        if account_id not in by_id:
            by_id[account_id] = session.get(Account, account_id)
        return by_id[account_id]

    for row in accounts:
        by_id[row.id] = row
        if viewer.can_use(row):
            out["accounts"].append(account_json(row))
        else:
            out["deleted"].append({"kind": "account", "id": row.client_id})
    for row in transactions:
        owner = account(row.account_id)
        if owner is not None and viewer.can_use(owner):
            out["transactions"].append(transaction_json(row, owner))
        else:
            out["deleted"].append({"kind": "transaction", "id": row.client_id})
    for row in transfers:
        source, destination = account(row.source_account_id), account(row.destination_account_id)
        # A transfer shows if either side does; the hidden side is named by id only.
        if source is not None and destination is not None and (viewer.can_use(source) or viewer.can_use(destination)):
            out["transfers"].append(transfer_json(row, source, destination))
        else:
            out["deleted"].append({"kind": "transfer", "id": row.client_id})
    for row in marks:
        owner = account(row.account_id)
        if owner is not None and viewer.can_use(owner):
            out["statement_marks"].append(mark_json(row, owner))


def snapshot(session: Session, viewer: Viewer) -> dict[str, list]:
    out = _empty()
    accounts = session.scalars(_visible_accounts_query(viewer).order_by(Account.id)).all()
    ids = [row.id for row in accounts]
    transactions = session.scalars(
        select(Transaction).where(Transaction.account_id.in_(ids), Transaction.client_id.is_not(None)).order_by(Transaction.id)
    ).all() if ids else []
    transfers = session.scalars(
        select(Transfer)
        .where(or_(Transfer.source_account_id.in_(ids), Transfer.destination_account_id.in_(ids)), Transfer.client_id.is_not(None))
        .order_by(Transfer.id)
    ).all() if ids else []
    marks = session.scalars(select(StatementMark).where(StatementMark.account_id.in_(ids))).all() if ids else []
    _fill(session, viewer, out, accounts, transactions, transfers, marks)
    return out


_MODELS = {"account": Account, "transaction": Transaction, "transfer": Transfer}


def changes_since(session: Session, viewer: Viewer, since: int, limit: int) -> tuple[dict[str, list], int, bool]:
    rows = session.scalars(
        select(WalletChange)
        .where(WalletChange.scope == viewer.scope, WalletChange.seq > since)
        .order_by(WalletChange.seq)
        .limit(limit + 1)
    ).all()
    has_more = len(rows) > limit
    page = rows[:limit]
    latest: dict[tuple[str, str], WalletChange] = {}
    for row in page:
        latest[(row.kind, row.client_id)] = row
    out = _empty()
    found: dict[str, list] = {"account": [], "transaction": [], "transfer": [], "statement_mark": []}
    for (kind, client_id), row in latest.items():
        if kind == "statement_mark":
            account_client_id, month = client_id.rsplit(":", 1)
            mark = session.scalar(
                select(StatementMark)
                .join(Account, Account.id == StatementMark.account_id)
                .where(Account.client_id == account_client_id, StatementMark.statement_month == date.fromisoformat(f"{month}-01"))
            )
            if mark is None:
                out["deleted"].append({"kind": kind, "id": client_id})
            else:
                found[kind].append(mark)
            continue
        model = _MODELS[kind]
        entity = None if row.deleted else session.scalar(select(model).where(model.client_id == client_id))
        if entity is None:
            out["deleted"].append({"kind": kind, "id": client_id})
        else:
            found[kind].append(entity)
    _fill(session, viewer, out, found["account"], found["transaction"], found["transfer"], found["statement_mark"])
    cursor = page[-1].seq if has_more else max(current_cursor(session, viewer.scope), since)
    return out, cursor, has_more


def pull(session: Session, user_id: int, *, since: int, scope: str | None, limit: int = 1000) -> dict[str, object]:
    """Changes since ``since``; a full snapshot when the client is new or its scope changed
    (joined or left a household)."""

    ensure_default_categories(session)
    viewer = Viewer.of(session, user_id)
    reset = since == 0 or scope != viewer.scope
    if reset:
        # Read the cursor first: anything committed meanwhile is pulled again next time.
        cursor = current_cursor(session, viewer.scope)
        data, has_more = snapshot(session, viewer), False
    else:
        data, cursor, has_more = changes_since(session, viewer, since, limit)
    me = session.get(User, user_id)
    household = describe(session, user_id)["household"]
    members = household["members"] if household else [
        {"user_id": user_id, "name": me.display_name, "email": me.email, "role": "owner", "is_me": True}
    ]
    return {
        "scope": viewer.scope,
        "cursor": cursor,
        "reset": reset,
        "has_more": has_more,
        "members": members,
        "categories": _categories(session, viewer),
        **data,
    }
