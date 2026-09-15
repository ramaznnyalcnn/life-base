from datetime import date, datetime, timezone
from decimal import Decimal

import pytest
from sqlalchemy.exc import IntegrityError

from app.models import (
    Account,
    AccountType,
    ActivityTemplate,
    ActivityTemplateKind,
    AgendaRevision,
    OperationExecution,
    Reminder,
    ScheduledPayment,
    Task,
)
from app.services.auth import ensure_default_user


def test_task_keeps_selected_template_and_title_snapshot(db_session):
    owner = ensure_default_user(db_session)
    template = ActivityTemplate(
        user_id=owner.id,
        kind=ActivityTemplateKind.TASK,
        label="Alisveris",
    )
    task = Task(
        user_id=owner.id,
        template=template,
        title="Haftalik market",
        due_on=date(2026, 9, 15),
        scheduled_at=datetime(2026, 9, 15, 16, 0, tzinfo=timezone.utc),
    )
    db_session.add(task)
    db_session.commit()

    template.label = "Market"
    db_session.commit()

    assert task.template_id == template.id
    assert task.title == "Haftalik market"
    assert task.is_completed is False


def test_scheduled_payment_links_completion_transfer_without_mutating_balance_early(db_session):
    owner = ensure_default_user(db_session)
    source = Account(
        user_id=owner.id,
        name="Banka",
        type=AccountType.BANK,
        currency="TRY",
        balance=Decimal("5000.00"),
    )
    destination = Account(
        user_id=owner.id,
        name="Kart",
        type=AccountType.CREDIT_CARD,
        currency="TRY",
        balance=Decimal("1000.00"),
        credit_limit=Decimal("10000.00"),
    )
    payment = ScheduledPayment(
        user_id=owner.id,
        source_account=source,
        destination_account=destination,
        amount=Decimal("750.00"),
        due_at=datetime(2026, 9, 20, 9, 0, tzinfo=timezone.utc),
    )
    db_session.add(payment)
    db_session.commit()

    assert payment.is_completed is False
    assert payment.completed_transfer_id is None
    assert source.balance == Decimal("5000.00")
    assert destination.balance == Decimal("1000.00")


def test_scheduled_payment_rejects_same_account_at_database_boundary(db_session):
    owner = ensure_default_user(db_session)
    account = Account(
        user_id=owner.id,
        name="Banka",
        type=AccountType.BANK,
        currency="TRY",
        balance=Decimal("5000.00"),
    )
    payment = ScheduledPayment(
        user_id=owner.id,
        source_account=account,
        destination_account=account,
        amount=Decimal("750.00"),
        due_at=datetime(2026, 9, 20, 9, 0, tzinfo=timezone.utc),
    )
    db_session.add(payment)

    with pytest.raises(IntegrityError):
        db_session.commit()


def test_reminder_requires_exactly_one_source(db_session):
    owner = ensure_default_user(db_session)
    reminder = Reminder(
        remind_at=datetime(2026, 9, 15, 8, 0, tzinfo=timezone.utc),
    )
    db_session.add(reminder)

    with pytest.raises(IntegrityError):
        db_session.commit()


def test_operation_execution_and_agenda_revision_are_user_scoped(db_session):
    owner = ensure_default_user(db_session)
    execution = OperationExecution(
        user_id=owner.id,
        request_id="f3da5962-507b-4cc1-8061-acd756a0d79b",
        operation_key="planning.task.create",
        request_hash="a" * 64,
        response_payload={"entities": [{"kind": "task", "id": 7}]},
    )
    revision = AgendaRevision(user_id=owner.id, version=3)
    db_session.add_all([execution, revision])
    db_session.commit()

    assert execution.response_payload["entities"][0]["id"] == 7
    assert revision.version == 3
