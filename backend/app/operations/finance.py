"""Class-based finance operations."""

from datetime import timedelta, timezone
from uuid import uuid4

from sqlalchemy import select

from app.models import Account, Reminder, ScheduledPayment, Transfer
from app.operations.base import HandlerResult, OperationContext, OperationHandler
from app.operations.definitions import definition, field
from app.operations.executor import EntityVersionConflictError
from app.schemas import EntityRef, OperationFieldKind
from app.schemas.operation_inputs import PaymentCompleteInput, PaymentScheduleInput
from app.services.ledger import apply_balance_deltas, lock_accounts, owner_scope, record_change


def _owned_account(context: OperationContext, account_id: int) -> Account:
    account = context.session.scalar(
        select(Account).where(Account.id == account_id, Account.user_id == context.user_id, Account.is_active.is_(True))
    )
    if account is None:
        raise ValueError("Hesap bulunamadi.")
    return account


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
        if payment.destination_account_id is None:
            raise ValueError("Bu planli odeme bir gider; mobil cuzdandan tamamlanir.")
        source = _owned_account(context, payment.source_account_id)
        destination = _owned_account(context, payment.destination_account_id)
        accounts = lock_accounts(context.session, [source.id, destination.id])
        transfer = Transfer(
            user_id=context.user_id,
            client_id=str(uuid4()),
            created_by_user_id=context.user_id,
            source_account_id=source.id,
            destination_account_id=destination.id,
            amount=payment.amount,
            description="Planli odeme",
            occurred_at=context.now.astimezone(timezone.utc),
        )
        payment.is_completed = True
        payment.completed_at = context.now
        payment.completed_transfer = transfer
        context.session.add(transfer)
        context.session.flush()
        apply_balance_deltas(context.session, {source.id: -payment.amount, destination.id: payment.amount})
        scope = owner_scope(context.session, source)
        record_change(context.session, scope, "transfer", transfer.client_id)
        for account in accounts.values():
            record_change(context.session, scope, "account", account.client_id)
        return HandlerResult(
            entities=[EntityRef(kind="scheduled_payment", id=payment.id), EntityRef(kind="transfer", id=transfer.id)],
            affects_agenda=True,
        )
