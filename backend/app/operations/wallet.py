"""Wallet writes from the mobile outbox (household-aware, race-safe).

Every handler resolves records by client id, checks the caller may use the
accounts involved, locks the accounts it edits in id order, undoes the old
effect and applies the new one through the ledger, and notes what changed for
the pull feed. An outdated ``expected_version`` is a 409 carrying the current
record, so the client can offer "yours / theirs".
"""

from __future__ import annotations

from calendar import monthrange
from collections import defaultdict
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import select

from app.models import Account, AccountType, Category, StatementMark, Transaction, TransactionType, Transfer
from app.operations.base import HandlerResult, OperationContext, OperationHandler
from app.operations.definitions import definition, field
from app.operations.executor import EntityVersionConflictError
from app.schemas import EntityRef, OperationFieldKind
from app.schemas.wallet_ops import (
    AccountArchiveInput,
    AccountSaveInput,
    StatementMarkInput,
    TransactionDeleteInput,
    TransactionSaveInput,
    TransferDeleteInput,
    TransferSaveInput,
)
from app.services.finance import calculate_statement_month
from app.services.ledger import (
    SHARED,
    Viewer,
    WalletAccessError,
    account_by_client_id,
    apply_balance_deltas,
    lock_accounts,
    owner_scope,
    record_change,
    transaction_effect,
)
from app.services.wallet_feed import account_json, mark_id, transaction_json, transfer_json


CENT = Decimal("0.01")


def split_amount(amount: Decimal, parts: int) -> list[Decimal]:
    """Equal parts in kuruş; the remainder goes to the first part."""

    cents = int((amount / CENT).to_integral_value())
    base, remainder = divmod(cents, parts)
    return [Decimal(base + (remainder if index == 0 else 0)) * CENT for index in range(parts)]


def part_id(group_id: str, index: int) -> str:
    return group_id if index == 1 else f"{group_id}~{index}"


def add_months(value: datetime, months: int) -> datetime:
    index = value.year * 12 + value.month - 1 + months
    year, month = divmod(index, 12)
    month += 1
    return value.replace(year=year, month=month, day=min(value.day, monthrange(year, month)[1]))


def _conflict(current: dict[str, object] | None) -> EntityVersionConflictError:
    return EntityVersionConflictError(current or {})


def _check_version(entity, expected: int | None, current: dict[str, object]) -> None:
    if expected is not None and expected != entity.entity_version:
        raise _conflict(current)


def _usable(context: OperationContext, viewer: Viewer, account_id: int) -> Account:
    account = context.session.get(Account, account_id)
    if account is None or not viewer.can_use(account):
        raise WalletAccessError("Bu kayda erisimin yok.")
    return account


def _note_accounts(context: OperationContext, accounts: dict[int, Account], deltas: dict[int, Decimal]) -> None:
    for account_id in deltas:
        account = accounts[account_id]
        record_change(context.session, owner_scope(context.session, account), "account", account.client_id)


class _WalletOperation(OperationHandler):
    def viewer(self, context: OperationContext) -> Viewer:
        return Viewer.of(context.session, context.user_id)


# Accounts ---------------------------------------------------------------


class AccountSaveOperation(_WalletOperation):
    key = "wallet.account.save"
    input_model = AccountSaveInput
    definition = definition(key, "wallet", "Hesap kaydet", [field("account", "Hesap", OperationFieldKind.SHORT_TEXT)])

    def current_snapshot(self, context, payload):
        account = context.session.scalar(select(Account).where(Account.client_id == payload.account.id))
        return account_json(account) if account is not None else {}

    def execute(self, context: OperationContext, payload: AccountSaveInput) -> HandlerResult:
        session, viewer, fields = context.session, self.viewer(context), payload.account
        account = session.scalar(select(Account).where(Account.client_id == fields.id))
        if account is not None:
            if account.user_id != viewer.user_id:
                raise WalletAccessError("Hesabi yalnizca sahibi duzenleyebilir.")
            _check_version(account, payload.expected_version, account_json(account))
            account = lock_accounts(session, [account.id])[account.id]
            if account.type.value != fields.type:
                raise ValueError("Hesap turu degistirilemez.")
        if fields.visibility == SHARED and viewer.household_id is None:
            raise ValueError("Ortak hesap icin once bir haneye katil.")
        duplicate = session.scalar(
            select(Account.id).where(Account.user_id == viewer.user_id, Account.name == fields.name, Account.client_id != fields.id)
        )
        if duplicate is not None:
            raise ValueError("Bu adla bir hesabin zaten var.")

        deltas: dict[int, Decimal] = {}
        if account is None:
            account = Account(
                client_id=fields.id,
                user_id=viewer.user_id,
                type=AccountType(fields.type),
                currency="TRY",
                balance=fields.opening_balance,
                opening_balance=fields.opening_balance,
                is_active=True,
            )
            session.add(account)
        elif fields.opening_balance != account.opening_balance:
            deltas[account.id] = fields.opening_balance - account.opening_balance
            account.opening_balance = fields.opening_balance
        account.name = fields.name
        account.issuer = fields.bank
        account.visibility = fields.visibility
        account.household_id = viewer.household_id if fields.visibility == SHARED else None
        is_card = account.type == AccountType.CREDIT_CARD
        account.credit_limit = fields.credit_limit if is_card else None
        account.statement_day = fields.statement_day if is_card else None
        account.due_day = fields.due_day if is_card else None
        account.last4 = fields.last4 if is_card else None
        account.network = fields.network if is_card else None
        account.color = fields.color
        account.iban = fields.iban if account.type == AccountType.BANK else None
        session.flush()
        apply_balance_deltas(session, deltas)
        record_change(session, owner_scope(session, account), "account", account.client_id)
        return HandlerResult([EntityRef(kind="account", id=account.client_id)])


class AccountArchiveOperation(_WalletOperation):
    key = "wallet.account.archive"
    input_model = AccountArchiveInput
    definition = definition(key, "wallet", "Hesabi arsivle", [field("account_id", "Hesap", OperationFieldKind.SHORT_TEXT)])

    def current_snapshot(self, context, payload):
        account = context.session.scalar(select(Account).where(Account.client_id == payload.account_id))
        return account_json(account) if account is not None else {}

    def execute(self, context: OperationContext, payload: AccountArchiveInput) -> HandlerResult:
        viewer = self.viewer(context)
        account = account_by_client_id(context.session, viewer, payload.account_id)
        if account.user_id != viewer.user_id:
            raise WalletAccessError("Hesabi yalnizca sahibi arsivleyebilir.")
        _check_version(account, payload.expected_version, account_json(account))
        account.is_active = not payload.archived
        context.session.flush()
        record_change(context.session, owner_scope(context.session, account), "account", account.client_id)
        return HandlerResult([EntityRef(kind="account", id=account.client_id)])


# Transactions -----------------------------------------------------------


def _installment_group(context: OperationContext, transaction: Transaction) -> list[Transaction]:
    if transaction.installment_group is None:
        return [transaction]
    return list(
        context.session.scalars(
            select(Transaction)
            .where(Transaction.installment_group == transaction.installment_group)
            .order_by(Transaction.installment_index)
        )
    )


def _transaction_snapshot(context: OperationContext, client_id: str) -> dict[str, object]:
    row = context.session.scalar(select(Transaction).where(Transaction.client_id == client_id))
    return transaction_json(row, context.session.get(Account, row.account_id)) if row is not None else {}


class TransactionSaveOperation(_WalletOperation):
    """Create or edit an expense/income; installments split it over statements."""

    key = "wallet.transaction.save"
    input_model = TransactionSaveInput
    definition = definition(key, "wallet", "Hareket kaydet", [
        field("account_id", "Hesap", OperationFieldKind.SHORT_TEXT),
        field("amount", "Tutar", OperationFieldKind.MONEY),
    ])

    def current_snapshot(self, context, payload):
        return _transaction_snapshot(context, payload.id)

    def _category(self, context, viewer: Viewer, payload: TransactionSaveInput, existing: Transaction | None) -> Category | None:
        if payload.category_id is None:
            return None
        category = context.session.get(Category, payload.category_id)
        unchanged = existing is not None and existing.category_id == payload.category_id
        if category is None or category.type.value != payload.kind or (
            category.user_id not in (None, viewer.user_id) and not unchanged
        ):
            raise ValueError("Kategori bulunamadi.")
        return category

    def execute(self, context: OperationContext, payload: TransactionSaveInput) -> HandlerResult:
        session, viewer = context.session, self.viewer(context)
        existing = session.scalar(select(Transaction).where(Transaction.client_id == payload.id))
        group: list[Transaction] = []
        root = payload.id
        if existing is not None:
            _usable(context, viewer, existing.account_id)
            _check_version(existing, payload.expected_version, _transaction_snapshot(context, payload.id))
            group = _installment_group(context, existing)
            root = existing.installment_group or existing.client_id
        target = account_by_client_id(session, viewer, payload.account_id)
        category = self._category(context, viewer, payload, existing)
        accounts = lock_accounts(session, {row.account_id for row in group} | {target.id})
        target = accounts[target.id]
        if payload.installments > 1 and (payload.kind != "expense" or target.type != AccountType.CREDIT_CARD):
            raise ValueError("Taksit yalnizca kredi karti harcamasinda olur.")

        kind = TransactionType(payload.kind)
        deltas: dict[int, Decimal] = defaultdict(Decimal)
        for row in group:
            deltas[row.account_id] -= transaction_effect(row.type, row.amount)
        rows = {row.client_id: row for row in group}
        count = payload.installments
        touched: list[str] = []
        for index, amount in enumerate(split_amount(payload.amount, count), start=1):
            client_id = part_id(root, index)
            row = rows.pop(client_id, None)
            if row is None:
                row = Transaction(client_id=client_id, created_by_user_id=viewer.user_id)
                session.add(row)
            occurred_at = add_months(payload.occurred_at, index - 1)
            row.user_id = target.user_id
            row.account_id = target.id
            row.category_id = category.id if category else None
            row.type = kind
            row.amount = amount
            row.description = category.name if category else ("Gelir" if kind == TransactionType.INCOME else "Gider")
            row.note = (payload.note or "").strip() or None
            row.occurred_at = occurred_at
            row.statement_month = (
                calculate_statement_month(occurred_at, target.statement_day) if target.type == AccountType.CREDIT_CARD else None
            )
            row.installment_group = root if count > 1 else None
            row.installment_index = index if count > 1 else None
            row.installment_count = count if count > 1 else None
            deltas[target.id] += transaction_effect(kind, amount)
            touched.append(client_id)
        scope = owner_scope(session, target)
        for leftover in rows.values():
            record_change(session, scope, "transaction", leftover.client_id, deleted=True)
            session.delete(leftover)
        session.flush()
        apply_balance_deltas(session, deltas)
        for client_id in touched:
            record_change(session, scope, "transaction", client_id)
        _note_accounts(context, accounts, deltas)
        return HandlerResult([EntityRef(kind="transaction", id=client_id) for client_id in touched])


class TransactionDeleteOperation(_WalletOperation):
    """Deleting any installment deletes the whole purchase."""

    key = "wallet.transaction.delete"
    input_model = TransactionDeleteInput
    definition = definition(key, "wallet", "Hareketi sil", [field("id", "Hareket", OperationFieldKind.SHORT_TEXT)])

    def current_snapshot(self, context, payload):
        return _transaction_snapshot(context, payload.id)

    def execute(self, context: OperationContext, payload: TransactionDeleteInput) -> HandlerResult:
        session, viewer = context.session, self.viewer(context)
        existing = session.scalar(select(Transaction).where(Transaction.client_id == payload.id))
        if existing is None:
            return HandlerResult([])  # Already gone (e.g. deleted on the other phone).
        _usable(context, viewer, existing.account_id)
        _check_version(existing, payload.expected_version, _transaction_snapshot(context, payload.id))
        group = _installment_group(context, existing)
        accounts = lock_accounts(session, {row.account_id for row in group})
        deltas: dict[int, Decimal] = defaultdict(Decimal)
        for row in group:
            deltas[row.account_id] -= transaction_effect(row.type, row.amount)
            record_change(session, owner_scope(session, accounts[row.account_id]), "transaction", row.client_id, deleted=True)
            session.delete(row)
        session.flush()
        apply_balance_deltas(session, deltas)
        _note_accounts(context, accounts, deltas)
        return HandlerResult([EntityRef(kind="transaction", id=row.client_id) for row in group])


# Transfers --------------------------------------------------------------


def _transfer_snapshot(context: OperationContext, client_id: str) -> dict[str, object]:
    row = context.session.scalar(select(Transfer).where(Transfer.client_id == client_id))
    if row is None:
        return {}
    return transfer_json(row, context.session.get(Account, row.source_account_id), context.session.get(Account, row.destination_account_id))


class TransferSaveOperation(_WalletOperation):
    """Money between two accounts; into a card it is a card payment."""

    key = "wallet.transfer.save"
    input_model = TransferSaveInput
    definition = definition(key, "wallet", "Transfer kaydet", [
        field("from_account_id", "Kaynak", OperationFieldKind.SHORT_TEXT),
        field("to_account_id", "Hedef", OperationFieldKind.SHORT_TEXT),
        field("amount", "Tutar", OperationFieldKind.MONEY),
    ])

    def current_snapshot(self, context, payload):
        return _transfer_snapshot(context, payload.id)

    def execute(self, context: OperationContext, payload: TransferSaveInput) -> HandlerResult:
        session, viewer = context.session, self.viewer(context)
        existing = session.scalar(select(Transfer).where(Transfer.client_id == payload.id))
        old_ids: set[int] = set()
        if existing is not None:
            _usable(context, viewer, existing.source_account_id)
            _usable(context, viewer, existing.destination_account_id)
            _check_version(existing, payload.expected_version, _transfer_snapshot(context, payload.id))
            old_ids = {existing.source_account_id, existing.destination_account_id}
        source = account_by_client_id(session, viewer, payload.from_account_id)
        destination = account_by_client_id(session, viewer, payload.to_account_id)
        if source.id == destination.id:
            raise ValueError("Kaynak ve hedef hesap ayni olamaz.")
        accounts = lock_accounts(session, old_ids | {source.id, destination.id})
        deltas: dict[int, Decimal] = defaultdict(Decimal)
        if existing is None:
            existing = Transfer(client_id=payload.id, created_by_user_id=viewer.user_id, description="Transfer")
            session.add(existing)
        else:
            deltas[existing.source_account_id] += existing.amount
            deltas[existing.destination_account_id] -= existing.amount
        existing.user_id = source.user_id
        existing.source_account_id = source.id
        existing.destination_account_id = destination.id
        existing.amount = payload.amount
        existing.occurred_at = payload.occurred_at
        existing.note = (payload.note or "").strip() or None
        existing.description = "Kart odemesi" if destination.type == AccountType.CREDIT_CARD else "Transfer"
        deltas[source.id] -= payload.amount
        deltas[destination.id] += payload.amount
        session.flush()
        apply_balance_deltas(session, deltas)
        record_change(session, owner_scope(session, source), "transfer", existing.client_id)
        _note_accounts(context, accounts, deltas)
        return HandlerResult([EntityRef(kind="transfer", id=existing.client_id)])


class TransferDeleteOperation(_WalletOperation):
    key = "wallet.transfer.delete"
    input_model = TransferDeleteInput
    definition = definition(key, "wallet", "Transferi sil", [field("id", "Transfer", OperationFieldKind.SHORT_TEXT)])

    def current_snapshot(self, context, payload):
        return _transfer_snapshot(context, payload.id)

    def execute(self, context: OperationContext, payload: TransferDeleteInput) -> HandlerResult:
        session, viewer = context.session, self.viewer(context)
        existing = session.scalar(select(Transfer).where(Transfer.client_id == payload.id))
        if existing is None:
            return HandlerResult([])
        _usable(context, viewer, existing.source_account_id)
        _usable(context, viewer, existing.destination_account_id)
        _check_version(existing, payload.expected_version, _transfer_snapshot(context, payload.id))
        accounts = lock_accounts(session, {existing.source_account_id, existing.destination_account_id})
        deltas = {existing.source_account_id: existing.amount, existing.destination_account_id: -existing.amount}
        record_change(session, owner_scope(session, accounts[existing.source_account_id]), "transfer", existing.client_id, deleted=True)
        session.delete(existing)
        session.flush()
        apply_balance_deltas(session, deltas)
        _note_accounts(context, accounts, deltas)
        return HandlerResult([EntityRef(kind="transfer", id=payload.id)])


# Statements -------------------------------------------------------------


class StatementMarkOperation(_WalletOperation):
    """Manual "paid" for one statement; ``paid=None`` returns it to automatic."""

    key = "wallet.statement.mark"
    input_model = StatementMarkInput
    definition = definition(key, "wallet", "Ekstreyi isaretle", [field("account_id", "Kart", OperationFieldKind.SHORT_TEXT)])

    def execute(self, context: OperationContext, payload: StatementMarkInput) -> HandlerResult:
        session, viewer = context.session, self.viewer(context)
        account = account_by_client_id(session, viewer, payload.account_id)
        if account.type != AccountType.CREDIT_CARD:
            raise ValueError("Ekstre yalnizca kredi kartinda olur.")
        month = date(payload.month.year, payload.month.month, 1)
        mark = session.scalar(
            select(StatementMark).where(StatementMark.account_id == account.id, StatementMark.statement_month == month).with_for_update()
        )
        if payload.paid is None:
            if mark is not None:
                session.delete(mark)
        elif mark is None:
            session.add(StatementMark(account_id=account.id, statement_month=month, paid=payload.paid, updated_by_user_id=viewer.user_id))
        else:
            mark.paid = payload.paid
            mark.updated_by_user_id = viewer.user_id
        session.flush()
        key = mark_id(account.client_id, month)
        record_change(session, owner_scope(session, account), "statement_mark", key)
        return HandlerResult([EntityRef(kind="statement_mark", id=key)])


WALLET_OPERATIONS = (
    AccountSaveOperation,
    AccountArchiveOperation,
    TransactionSaveOperation,
    TransactionDeleteOperation,
    TransferSaveOperation,
    TransferDeleteOperation,
    StatementMarkOperation,
)
