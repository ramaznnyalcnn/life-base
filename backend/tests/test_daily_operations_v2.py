from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from uuid import uuid4

import pytest
from sqlalchemy import select
from sqlalchemy.orm.exc import StaleDataError

from app.models import (
    Account,
    AccountType,
    Category,
    CategoryType,
    Event,
    Medication,
    Reminder,
    ScheduledPayment,
    Task,
    Transaction,
    TransactionType,
    User,
)
from app.operations.catalog import build_operation_registry
from app.operations.executor import EntityVersionConflictError, OperationExecutor
from app.schemas.operation_inputs import OperationInput
from app.services.auth import ensure_default_user
from tests.conftest import api_request


def execute(key: str, **values):
    return api_request("POST", "/api/v2/operations/execute", json={
        "request_id": str(uuid4()),
        "operation_key": key,
        **values,
    })


def test_catalog_describes_wizard_surface_and_daily_crud_operations():
    response = api_request("GET", "/api/v2/operations/catalog")

    assert response.status_code == 200
    catalog = {item["key"]: item for item in response.json()}
    assert {
        "finance.account.create",
        "finance.transaction.update",
        "planning.task.reopen",
        "planning.event.delete",
        "planning.routine.toggle",
        "health.medication.create",
        "health.medication.undo_take",
    } <= catalog.keys()
    assert catalog["planning.task.create"]["surface"] == "wizard"
    assert catalog["planning.task.create"]["steps"] >= 2
    scheduled = next(field for field in catalog["planning.task.create"]["fields"] if field["key"] == "scheduled_at")
    assert scheduled["kind"] == "datetime"


def test_daily_operation_payloads_validate_required_fields():
    response = execute("finance.account.create", type="bank", currency="TRY")

    assert response.status_code == 400
    assert "name" in response.json()["detail"]


def test_every_catalog_operation_uses_a_specific_input_model():
    registry = build_operation_registry()

    assert all(
        registry.get(item.key).input_model is not OperationInput
        for item in registry.definitions()
    )


def test_task_reopen_checks_entity_version_and_returns_current_snapshot(setup_database):
    template_id = api_request("GET", "/api/v2/operations/context").json()["sources"]["activity_templates.task"][0]["value"]
    created = execute("planning.task.create", template_id=template_id, due_on="2026-09-15")
    task_id = created.json()["entities"][0]["id"]
    assert execute("planning.task.complete", task_id=task_id, expected_version=1).status_code == 200

    conflict = execute("planning.task.reopen", task_id=task_id, expected_version=1)
    assert conflict.status_code == 409
    assert conflict.json()["detail"]["current"]["entity_version"] == 2

    reopened = execute("planning.task.reopen", task_id=task_id, expected_version=2)
    assert reopened.status_code == 200
    with setup_database() as session:
        task = session.get(Task, task_id)
        assert task.is_completed is False
        assert task.entity_version == 3


def test_medication_can_be_created_without_free_form_instructions(setup_database):
    response = execute(
        "health.medication.create",
        name="Vitamin D",
        dosage="1000",
        dosage_unit="IU",
        schedule_mode="weekdays",
        weekdays=[0, 2, 4],
        dose_times=["09:00:00"],
        starts_on="2026-09-15",
        timezone="Europe/Istanbul",
    )

    assert response.status_code == 200
    with setup_database() as session:
        medication = session.scalar(select(Medication))
        assert medication.name == "Vitamin D"
        assert medication.dosage == "1000 IU"
        assert medication.instructions is None
        assert medication.entity_version == 1


def test_daily_read_aliases_and_agenda_etag_are_mobile_ready():
    accounts = api_request("GET", "/api/v2/finance/accounts")
    me = api_request("GET", "/api/v2/auth/me")
    agenda = api_request("GET", "/api/v2/agenda/today?date=2026-09-15")

    assert accounts.status_code == 200
    assert accounts.json()[0]["entity_version"] == 1
    assert me.status_code == 200
    assert agenda.headers["etag"].startswith('"agenda-')

    unchanged = api_request(
        "GET",
        "/api/v2/agenda/today?date=2026-09-15",
        headers={"If-None-Match": agenda.headers["etag"]},
    )
    assert unchanged.status_code == 304


def test_legacy_updates_also_advance_entity_version(setup_database):
    account_id = api_request("GET", "/api/v2/finance/accounts").json()[0]["id"]

    response = api_request("PUT", f"/api/v1/accounts/{account_id}", json={"name": "Ana hesap"})

    assert response.status_code == 200
    with setup_database() as session:
        assert session.get(Account, account_id).entity_version == 2


def test_executor_turns_atomic_stale_write_into_version_conflict(setup_database, monkeypatch):
    with setup_database() as session:
        owner = ensure_default_user(session)
        account = Account(user_id=owner.id, name="Banka", type="bank", currency="TRY", balance=0)
        session.add(account)
        session.commit()
        account_id = account.id

    session = setup_database()
    payload = OperationInput.model_validate({
        "request_id": str(uuid4()),
        "operation_key": "finance.account.update",
        "account_id": account_id,
        "name": "Yeni ad",
        "expected_version": 1,
    })
    monkeypatch.setattr(session, "commit", lambda: (_ for _ in ()).throw(StaleDataError("stale")))

    with pytest.raises(EntityVersionConflictError) as conflict:
        OperationExecutor(build_operation_registry()).execute(session, payload, user_id=owner.id)

    assert conflict.value.current["id"] == account_id
    assert conflict.value.current["entity_version"] == 1
    session.close()


def test_transaction_and_payment_updates_reject_other_users_references(setup_database):
    with setup_database() as session:
        owner = ensure_default_user(session)
        other = User(email="other@example.com", display_name="Other")
        own_account = Account(user_id=owner.id, name="Own", type=AccountType.BANK, balance=Decimal("100"))
        own_target = Account(user_id=owner.id, name="Target", type=AccountType.BANK, balance=Decimal("0"))
        own_category = Category(user_id=owner.id, name="Own expense", type=CategoryType.EXPENSE)
        session.add_all([other, own_account, own_target, own_category])
        session.flush()
        other_account = Account(user_id=other.id, name="Other", type=AccountType.BANK, balance=Decimal("100"))
        other_category = Category(user_id=other.id, name="Other expense", type=CategoryType.EXPENSE)
        session.add_all([other_account, other_category])
        session.flush()
        transaction = Transaction(
            user_id=owner.id,
            account_id=own_account.id,
            category_id=own_category.id,
            type=TransactionType.EXPENSE,
            amount=Decimal("10"),
            description="Own expense",
            occurred_at=datetime.now(timezone.utc),
        )
        payment = ScheduledPayment(
            user_id=owner.id,
            source_account_id=own_account.id,
            destination_account_id=own_target.id,
            amount=Decimal("10"),
            due_at=datetime.now(timezone.utc),
        )
        session.add_all([transaction, payment])
        session.commit()
        transaction_id = transaction.id
        payment_id = payment.id
        other_account_id = other_account.id
        other_category_id = other_category.id

    wrong_account = execute(
        "finance.transaction.update",
        transaction_id=transaction_id,
        account_id=other_account_id,
        expected_version=1,
    )
    wrong_category = execute(
        "finance.transaction.update",
        transaction_id=transaction_id,
        category_id=other_category_id,
        expected_version=1,
    )
    wrong_payment_account = execute(
        "finance.payment.update",
        scheduled_payment_id=payment_id,
        source_account_id=other_account_id,
        expected_version=1,
    )

    assert wrong_account.status_code == 400
    assert wrong_category.status_code == 400
    assert wrong_payment_account.status_code == 400


def test_schedule_updates_shift_existing_reminders(setup_database):
    base = datetime(2026, 9, 20, 9, 0, tzinfo=timezone.utc)
    with setup_database() as session:
        owner = ensure_default_user(session)
        source = Account(user_id=owner.id, name="Source", type=AccountType.BANK, balance=Decimal("100"))
        target = Account(user_id=owner.id, name="Target", type=AccountType.BANK, balance=Decimal("0"))
        task = Task(user_id=owner.id, title="Task", due_on=base.date(), scheduled_at=base)
        event = Event(user_id=owner.id, title="Event", starts_at=base, ends_at=base + timedelta(hours=1))
        session.add_all([source, target, task, event])
        session.flush()
        payment = ScheduledPayment(
            user_id=owner.id, source_account_id=source.id, destination_account_id=target.id,
            amount=Decimal("10"), due_at=base,
        )
        session.add(payment)
        session.flush()
        session.add_all([
            Reminder(task_id=task.id, remind_at=base - timedelta(hours=1)),
            Reminder(event_id=event.id, remind_at=base - timedelta(hours=2)),
            Reminder(scheduled_payment_id=payment.id, remind_at=base - timedelta(days=1)),
        ])
        session.commit()
        task_id, event_id, payment_id = task.id, event.id, payment.id

    assert execute(
        "planning.task.update", task_id=task_id,
        scheduled_at=(base + timedelta(hours=2)).isoformat(), expected_version=1,
    ).status_code == 200
    assert execute(
        "planning.event.update", event_id=event_id,
        starts_at=(base + timedelta(hours=3)).isoformat(), expected_version=1,
    ).status_code == 200
    assert execute(
        "finance.payment.update", scheduled_payment_id=payment_id,
        due_at=(base + timedelta(days=2)).isoformat(), expected_version=1,
    ).status_code == 200

    with setup_database() as session:
        task = session.get(Task, task_id)
        event = session.get(Event, event_id)
        payment = session.get(ScheduledPayment, payment_id)
        assert task.reminders[0].remind_at.hour == 10
        assert event.reminders[0].remind_at.hour == 10
        assert event.ends_at.hour == 13
        assert payment.reminders[0].remind_at.day == 21


def test_medication_partial_update_preserves_dosage_and_validates_merged_schedule(setup_database):
    with setup_database() as session:
        owner = ensure_default_user(session)
        medication = Medication(
            user_id=owner.id, name="Vitamin", dosage="5 mg", schedule_mode="weekdays",
            weekdays="0", dose_times="09:00", starts_on=date(2026, 9, 1), timezone="Europe/Istanbul",
        )
        session.add(medication)
        session.commit()
        medication_id = medication.id

    assert execute(
        "health.medication.update", medication_id=medication_id, dosage="6", expected_version=1,
    ).status_code == 200
    assert execute(
        "health.medication.update", medication_id=medication_id, dosage_unit="ml", expected_version=2,
    ).status_code == 200
    invalid = execute(
        "health.medication.update", medication_id=medication_id,
        schedule_mode="interval", expected_version=3,
    )

    assert invalid.status_code == 400
    with setup_database() as session:
        medication = session.get(Medication, medication_id)
        assert medication.dosage == "6 ml"
        assert medication.schedule_mode == "weekdays"
