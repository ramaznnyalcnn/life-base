"""Class-based finance operations."""

from datetime import timedelta, timezone

from sqlalchemy import select

from app.models import (
    Account,
    AccountType,
    Category,
    CategoryType,
    Reminder,
    ScheduledPayment,
    Transaction,
    TransactionType,
    Transfer,
)
from app.operations.base import HandlerResult, OperationContext, OperationHandler
from app.operations.definitions import definition, field
from app.operations.executor import EntityVersionConflictError
from app.schemas import EntityRef, OperationFieldKind
from app.schemas.operation_inputs import (
    ExpenseRecordInput,
    IncomeRecordInput,
    PaymentCompleteInput,
    PaymentScheduleInput,
    TransferRecordInput,
)
from app.services.finance import calculate_statement_month


def _owned_account(context: OperationContext, account_id: int) -> Account:
    account = context.session.scalar(
        select(Account).where(Account.id == account_id, Account.user_id == context.user_id, Account.is_active.is_(True))
    )
    if account is None:
        raise ValueError("Hesap bulunamadi.")
    return account


def _transaction_fields(category_source: str):
    return [
        field("account_id", "Hesap", OperationFieldKind.CHOICE, source="accounts"),
        field("category_id", "Kategori", OperationFieldKind.CHOICE, source=category_source),
        field("amount", "Tutar", OperationFieldKind.MONEY),
        field("occurred_at", "Zaman", OperationFieldKind.DATE, required=False),
    ]


class _TransactionOperation(OperationHandler):
    transaction_type: TransactionType
    category_type: CategoryType

    def execute(self, context: OperationContext, payload) -> HandlerResult:
        account = _owned_account(context, payload.account_id)
        category = context.session.scalar(
            select(Category).where(
                Category.id == payload.category_id,
                Category.type == self.category_type,
                (Category.user_id == context.user_id) | (Category.user_id.is_(None)),
            )
        )
        if category is None:
            raise ValueError("Kategori bulunamadi.")
        occurred_at = payload.occurred_at or context.now
        transaction = Transaction(
            user_id=context.user_id,
            account_id=account.id,
            category_id=category.id,
            type=self.transaction_type,
            amount=payload.amount,
            description=category.name,
            occurred_at=occurred_at,
            statement_month=(
                calculate_statement_month(occurred_at, account.statement_day)
                if account.type == AccountType.CREDIT_CARD
                else None
            ),
        )
        account.balance += payload.amount if self.transaction_type == TransactionType.INCOME else -payload.amount
        context.session.add(transaction)
        context.session.flush()
        return HandlerResult(entities=[EntityRef(kind="transaction", id=transaction.id)])


class ExpenseRecordOperation(_TransactionOperation):
    key = "finance.expense.record"
    input_model = ExpenseRecordInput
    transaction_type = TransactionType.EXPENSE
    category_type = CategoryType.EXPENSE
    definition = definition(key, "finance", "Harcama kaydet", _transaction_fields("categories.expense"))


class IncomeRecordOperation(_TransactionOperation):
    key = "finance.income.record"
    input_model = IncomeRecordInput
    transaction_type = TransactionType.INCOME
    category_type = CategoryType.INCOME
    definition = definition(key, "finance", "Gelir kaydet", _transaction_fields("categories.income"))


class TransferRecordOperation(OperationHandler[TransferRecordInput]):
    key = "finance.transfer.record"
    input_model = TransferRecordInput
    definition = definition(key, "finance", "Transfer", [
        field("source_account_id", "Kaynak hesap", OperationFieldKind.CHOICE, source="accounts"),
        field("destination_account_id", "Hedef hesap", OperationFieldKind.CHOICE, source="accounts"),
        field("amount", "Tutar", OperationFieldKind.MONEY),
        field("occurred_at", "Zaman", OperationFieldKind.DATE, required=False),
    ])

    def execute(self, context: OperationContext, payload: TransferRecordInput) -> HandlerResult:
        source = _owned_account(context, payload.source_account_id)
        destination = _owned_account(context, payload.destination_account_id)
        if source.id == destination.id:
            raise ValueError("Kaynak ve hedef hesap ayni olamaz.")
        transfer = Transfer(
            user_id=context.user_id,
            source_account_id=source.id,
            destination_account_id=destination.id,
            amount=payload.amount,
            description="Hesap transferi",
            occurred_at=payload.occurred_at or context.now,
        )
        source.balance -= payload.amount
        destination.balance += payload.amount
        context.session.add(transfer)
        context.session.flush()
        return HandlerResult(entities=[EntityRef(kind="transfer", id=transfer.id)])


class PaymentScheduleOperation(OperationHandler[PaymentScheduleInput]):
    key = "finance.payment.schedule"
    input_model = PaymentScheduleInput
    definition = definition(key, "finance", "Odeme planla", [
        field("source_account_id", "Odenecek hesap", OperationFieldKind.CHOICE, source="accounts"),
        field("destination_account_id", "Kart veya hedef", OperationFieldKind.CHOICE, source="accounts"),
        field("amount", "Tutar", OperationFieldKind.MONEY),
        field("due_at", "Odeme zamani", OperationFieldKind.DATE),
        field("reminder_offsets_minutes", "Hatirlatmalar", OperationFieldKind.DURATION, required=False),
    ])

    def execute(self, context: OperationContext, payload: PaymentScheduleInput) -> HandlerResult:
        source = _owned_account(context, payload.source_account_id)
        destination = _owned_account(context, payload.destination_account_id)
        if source.id == destination.id:
            raise ValueError("Kaynak ve hedef hesap ayni olamaz.")
        payment = ScheduledPayment(
            user_id=context.user_id,
            device_id=context.device_id,
            source_account_id=source.id,
            destination_account_id=destination.id,
            amount=payload.amount,
            due_at=payload.due_at,
        )
        context.session.add(payment)
        context.session.flush()
        context.session.add_all([
            Reminder(scheduled_payment_id=payment.id, remind_at=payment.due_at - timedelta(minutes=minutes))
            for minutes in sorted(set(payload.reminder_offsets_minutes), reverse=True)
            if minutes > 0
        ])
        return HandlerResult(entities=[EntityRef(kind="scheduled_payment", id=payment.id)], affects_agenda=True)


class PaymentCompleteOperation(OperationHandler[PaymentCompleteInput]):
    key = "finance.payment.complete"
    input_model = PaymentCompleteInput
    versioned_model = ScheduledPayment
    versioned_id_field = "scheduled_payment_id"
    definition = definition(key, "finance", "Odemeyi tamamla", [
        field("scheduled_payment_id", "Planli odeme", OperationFieldKind.CHOICE, source="scheduled_payments.pending"),
        field("expected_version", "Surum", OperationFieldKind.DURATION),
    ])

    def execute(self, context: OperationContext, payload: PaymentCompleteInput) -> HandlerResult:
        payment = context.session.scalar(
            select(ScheduledPayment).where(
                ScheduledPayment.id == payload.scheduled_payment_id,
                ScheduledPayment.user_id == context.user_id,
            )
        )
        if payment is None:
            raise ValueError("Planli odeme bulunamadi.")
        if payment.entity_version != payload.expected_version:
            raise EntityVersionConflictError(self.current_snapshot(context, payload))
        if payment.is_completed:
            raise ValueError("Planli odeme zaten tamamlandi.")
        source = _owned_account(context, payment.source_account_id)
        destination = _owned_account(context, payment.destination_account_id)
        transfer = Transfer(
            user_id=context.user_id,
            source_account_id=source.id,
            destination_account_id=destination.id,
            amount=payment.amount,
            description="Planli odeme",
            occurred_at=context.now.astimezone(timezone.utc),
        )
        source.balance -= payment.amount
        destination.balance += payment.amount
        payment.is_completed = True
        payment.completed_at = context.now
        payment.completed_transfer = transfer
        context.session.add(transfer)
        context.session.flush()
        return HandlerResult(
            entities=[EntityRef(kind="scheduled_payment", id=payment.id), EntityRef(kind="transfer", id=transfer.id)],
            affects_agenda=True,
        )
