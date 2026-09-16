from datetime import date, datetime, timezone
from decimal import Decimal
from uuid import uuid4

from sqlalchemy import select

from app.models import (
    Account,
    AccountType,
    Category,
    CategoryType,
    Event,
    Medication,
    MedicationDoseLog,
    RecurringEvent,
    ScheduledPayment,
    Task,
    Transaction,
)
from app.services.auth import ensure_default_user
from tests.conftest import api_request


def test_catalog_and_context_expose_selection_driven_mobile_contract():
    catalog = api_request("GET", "/api/v2/operations/catalog")
    context = api_request("GET", "/api/v2/operations/context")

    assert catalog.status_code == 200
    assert len(catalog.json()) >= 38
    assert {item["key"] for item in catalog.json()} >= {
        "planning.task.create",
        "finance.expense.record",
        "health.medication.take",
    }
    assert context.status_code == 200
    sources = context.json()["sources"]
    assert len(sources["activity_templates.task"]) >= 6
    assert sources["weekdays"][0] == {"value": 0, "label": "Pazartesi", "enabled": True, "metadata": {}}


def test_execute_creates_task_and_replays_same_request(setup_database):
    template_id = api_request("GET", "/api/v2/operations/context").json()["sources"]["activity_templates.task"][0]["value"]
    request_id = str(uuid4())
    payload = {
        "request_id": request_id,
        "operation_key": "planning.task.create",
        "template_id": template_id,
        "due_on": "2026-09-15",
        "scheduled_at": "2026-09-15T16:00:00+03:00",
        "is_important": True,
    }

    first = api_request("POST", "/api/v2/operations/execute", json=payload)
    second = api_request("POST", "/api/v2/operations/execute", json=payload)

    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json()["agenda_version"] == 1
    assert second.json()["replayed"] is True
    with setup_database() as session:
        tasks = list(session.scalars(select(Task)).all())
        assert len(tasks) == 1
        assert tasks[0].due_on == date(2026, 9, 15)


def test_execute_records_decimal_expense_from_selected_account_and_category(setup_database):
    with setup_database() as session:
        owner = ensure_default_user(session)
        account = Account(user_id=owner.id, name="Banka", type=AccountType.BANK, balance=Decimal("1000.00"))
        category = Category(user_id=owner.id, name="Market", type=CategoryType.EXPENSE)
        session.add_all([account, category])
        session.commit()
        account_id, category_id = account.id, category.id

    response = api_request("POST", "/api/v2/operations/execute", json={
        "request_id": str(uuid4()),
        "operation_key": "finance.expense.record",
        "account_id": account_id,
        "category_id": category_id,
        "amount": "125.45",
    })

    assert response.status_code == 200
    with setup_database() as session:
        transaction = session.scalar(select(Transaction))
        account = session.get(Account, account_id)
        assert transaction.amount == Decimal("125.45")
        assert transaction.description == "Market"
        assert account.balance == Decimal("874.55")


def test_execute_returns_conflict_for_changed_idempotent_request():
    template_id = api_request("GET", "/api/v2/operations/context").json()["sources"]["activity_templates.task"][0]["value"]
    request_id = str(uuid4())
    base = {
        "request_id": request_id,
        "operation_key": "planning.task.create",
        "template_id": template_id,
        "due_on": "2026-09-15",
    }
    assert api_request("POST", "/api/v2/operations/execute", json=base).status_code == 200

    changed = api_request("POST", "/api/v2/operations/execute", json={**base, "due_on": "2026-09-16"})

    assert changed.status_code == 409


def test_schedule_then_complete_payment_changes_balances_only_on_completion(setup_database):
    with setup_database() as session:
        owner = ensure_default_user(session)
        source = Account(user_id=owner.id, name="Banka", type=AccountType.BANK, balance=Decimal("1000"))
        target = Account(user_id=owner.id, name="Kart", type=AccountType.CREDIT_CARD, balance=Decimal("100"))
        session.add_all([source, target])
        session.commit()
        source_id, target_id = source.id, target.id

    scheduled = api_request("POST", "/api/v2/operations/execute", json={
        "request_id": str(uuid4()), "operation_key": "finance.payment.schedule",
        "source_account_id": source_id, "destination_account_id": target_id,
        "amount": "250.00", "due_at": "2026-09-20T09:00:00+03:00",
    })
    assert scheduled.status_code == 200
    payment_id = scheduled.json()["entities"][0]["id"]
    with setup_database() as session:
        assert session.get(Account, source_id).balance == Decimal("1000.00")

    completed = api_request("POST", "/api/v2/operations/execute", json={
        "request_id": str(uuid4()), "operation_key": "finance.payment.complete",
        "scheduled_payment_id": payment_id, "expected_version": 1,
    })
    assert completed.status_code == 200
    with setup_database() as session:
        assert session.get(Account, source_id).balance == Decimal("750.00")
        assert session.get(Account, target_id).balance == Decimal("350.00")
        assert session.get(ScheduledPayment, payment_id).completed_transfer_id is not None


def test_event_and_routine_operations_use_selected_template(setup_database):
    sources = api_request("GET", "/api/v2/operations/context").json()["sources"]
    event_template = sources["activity_templates.event"][0]
    routine_template = sources["activity_templates.routine"][0]

    event_response = api_request("POST", "/api/v2/operations/execute", json={
        "request_id": str(uuid4()), "operation_key": "planning.event.create",
        "template_id": event_template["value"], "starts_at": "2026-09-16T14:00:00+03:00",
    })
    routine_response = api_request("POST", "/api/v2/operations/execute", json={
        "request_id": str(uuid4()), "operation_key": "planning.routine.create",
        "template_id": routine_template["value"], "weekdays": [0, 2, 4],
        "starts_on": "2026-09-15", "start_time": "08:00:00",
    })

    assert event_response.status_code == 200
    assert routine_response.status_code == 200
    with setup_database() as session:
        event = session.scalar(select(Event))
        routine = session.scalar(select(RecurringEvent))
        assert event.title == event_template["label"]
        assert event.template_id == event_template["value"]
        assert routine.title == routine_template["label"]
        assert routine.weekdays == "0,2,4"


def test_medication_schedule_take_and_snooze_operations(setup_database):
    with setup_database() as session:
        owner = ensure_default_user(session)
        medication = Medication(
            user_id=owner.id, name="Vitamin", dosage="1 tablet", schedule_mode="weekdays",
            weekdays="0", dose_times="09:00", starts_on=date(2026, 9, 1), timezone="Europe/Istanbul",
        )
        session.add(medication)
        session.commit()
        medication_id = medication.id

    scheduled = api_request("POST", "/api/v2/operations/execute", json={
        "request_id": str(uuid4()), "operation_key": "health.medication.schedule",
        "medication_id": medication_id, "schedule_mode": "interval", "weekdays": [],
        "interval_days": 2, "dose_times": ["08:30:00"], "starts_on": "2026-09-15",
        "expected_version": 1,
    })
    assert scheduled.status_code == 200
    dose_time = datetime(2026, 9, 15, 5, 30, tzinfo=timezone.utc).isoformat()
    taken = api_request("POST", "/api/v2/operations/execute", json={
        "request_id": str(uuid4()), "operation_key": "health.medication.take",
        "medication_id": medication_id, "scheduled_for": dose_time,
    })
    assert taken.status_code == 200
    snoozed = api_request("POST", "/api/v2/operations/execute", json={
        "request_id": str(uuid4()), "operation_key": "health.medication.snooze",
        "medication_id": medication_id, "scheduled_for": "2026-09-17T05:30:00+00:00", "snooze_minutes": 15,
    })
    assert snoozed.status_code == 200
    with setup_database() as session:
        medication = session.get(Medication, medication_id)
        logs = list(session.scalars(select(MedicationDoseLog).order_by(MedicationDoseLog.scheduled_for)).all())
        assert medication.schedule_mode == "interval"
        assert medication.interval_days == 2
        assert [log.status.value for log in logs] == ["taken", "snoozed"]


def test_medication_action_rejects_an_occurrence_from_another_medication(setup_database):
    with setup_database() as session:
        owner = ensure_default_user(session)
        monday = Medication(
            user_id=owner.id, name="Monday", dosage="1 tablet", schedule_mode="weekdays",
            weekdays="0", dose_times="09:00", starts_on=date(2026, 9, 1), timezone="Europe/Istanbul",
        )
        tuesday = Medication(
            user_id=owner.id, name="Tuesday", dosage="1 tablet", schedule_mode="weekdays",
            weekdays="1", dose_times="09:00", starts_on=date(2026, 9, 1), timezone="Europe/Istanbul",
        )
        session.add_all([monday, tuesday])
        session.commit()
        monday_id = monday.id

    tuesday_occurrence = datetime(2026, 9, 15, 6, 0, tzinfo=timezone.utc).isoformat()
    response = api_request("POST", "/api/v2/operations/execute", json={
        "request_id": str(uuid4()),
        "operation_key": "health.medication.take",
        "medication_id": monday_id,
        "scheduled_for": tuesday_occurrence,
    })

    assert response.status_code == 400
    with setup_database() as session:
        assert session.scalar(select(MedicationDoseLog)) is None


def test_existing_entity_mutations_require_version_and_context_supplies_it(setup_database):
    with setup_database() as session:
        owner = ensure_default_user(session)
        source = Account(user_id=owner.id, name="Banka", type=AccountType.BANK, balance=Decimal("100"))
        target = Account(user_id=owner.id, name="Kart", type=AccountType.CREDIT_CARD, balance=Decimal("0"))
        medication = Medication(
            user_id=owner.id, name="Vitamin", dosage="1 tablet", schedule_mode="weekdays",
            weekdays="0", dose_times="09:00", starts_on=date(2026, 9, 1), timezone="Europe/Istanbul",
        )
        task = Task(user_id=owner.id, title="Kontrol", due_on=date(2026, 9, 15))
        session.add_all([source, target, medication, task])
        session.flush()
        payment = ScheduledPayment(
            user_id=owner.id,
            source_account_id=source.id,
            destination_account_id=target.id,
            amount=Decimal("10"),
            due_at=datetime(2026, 9, 20, tzinfo=timezone.utc),
        )
        session.add(payment)
        session.commit()
        payment_id = payment.id
        medication_id = medication.id
        task_id = task.id

    payment_response = api_request(
        "POST",
        "/api/v2/operations/execute",
        json={
            "request_id": str(uuid4()),
            "operation_key": "finance.payment.complete",
            "scheduled_payment_id": payment_id,
        },
    )
    task_response = api_request(
        "POST",
        "/api/v2/operations/execute",
        json={
            "request_id": str(uuid4()),
            "operation_key": "planning.task.complete",
            "task_id": task_id,
        },
    )
    medication_response = api_request(
        "POST",
        "/api/v2/operations/execute",
        json={
            "request_id": str(uuid4()),
            "operation_key": "health.medication.schedule",
            "medication_id": medication_id,
            "schedule_mode": "weekdays",
            "weekdays": [0],
            "dose_times": ["09:00:00"],
            "starts_on": "2026-09-15",
        },
    )
    context = api_request("GET", "/api/v2/operations/context").json()["sources"]

    assert payment_response.status_code == 400
    assert task_response.status_code == 400
    assert medication_response.status_code == 400
    payment_option = next(item for item in context["scheduled_payments.pending"] if item["value"] == payment_id)
    assert payment_option["metadata"]["entity_version"] == 1
