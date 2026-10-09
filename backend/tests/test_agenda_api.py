from datetime import date, datetime, timezone
from decimal import Decimal

from app.models import Account, AccountType, Event, RecurringEvent, ScheduledPayment, Task
from app.services.auth import ensure_default_user
from tests.conftest import api_request


def test_today_agenda_groups_overdue_tasks_and_hourly_timeline(setup_database):
    with setup_database() as session:
        owner = ensure_default_user(session)
        source = Account(user_id=owner.id, name="Banka", type=AccountType.BANK, balance=Decimal("1000"))
        target = Account(user_id=owner.id, name="Kart", type=AccountType.CREDIT_CARD, balance=Decimal("0"))
        session.add_all([source, target])
        session.flush()
        session.add_all([
            Task(user_id=owner.id, title="Geciken", due_on=date(2026, 9, 14)),
            Task(user_id=owner.id, title="Saatli gorev", due_on=date(2026, 9, 15), scheduled_at=datetime(2026, 9, 15, 7, 30, tzinfo=timezone.utc)),
            Event(user_id=owner.id, title="Toplanti", starts_at=datetime(2026, 9, 15, 8, 0, tzinfo=timezone.utc)),
            ScheduledPayment(user_id=owner.id, source_account_id=source.id, destination_account_id=target.id, amount=Decimal("250"), due_at=datetime(2026, 9, 15, 9, 0, tzinfo=timezone.utc)),
        ])
        session.commit()

    response = api_request("GET", "/api/v2/agenda/today?date=2026-09-15&timezone=Europe/Istanbul")

    assert response.status_code == 200
    body = response.json()
    assert [item["title"] for item in body["overdue"]] == ["Geciken"]
    assert [item["title"] for item in body["timeline"]] == ["Saatli gorev", "Toplanti", "250.00 TRY odeme"]
    assert body["date"] == "2026-09-15"


def test_agenda_range_returns_calendar_exportable_items(setup_database):
    with setup_database() as session:
        owner = ensure_default_user(session)
        session.add(Event(user_id=owner.id, title="Randevu", starts_at=datetime(2026, 9, 16, 10, 0, tzinfo=timezone.utc)))
        session.commit()

    response = api_request("GET", "/api/v2/agenda/range?from=2026-09-15&to=2026-09-17&timezone=Europe/Istanbul")

    assert response.status_code == 200
    assert response.json()["items"][0]["title"] == "Randevu"
    assert response.json()["items"][0]["calendar_exportable"] is True


def test_agenda_rejects_invalid_range():
    response = api_request("GET", "/api/v2/agenda/range?from=2026-09-18&to=2026-09-15")

    assert response.status_code == 400


def test_recurring_clock_time_is_interpreted_in_requested_timezone(setup_database):
    with setup_database() as session:
        owner = ensure_default_user(session)
        session.add(RecurringEvent(
            user_id=owner.id, title="Sabah rutini", weekdays="2", starts_on=date(2026, 9, 15),
            start_time=datetime.strptime("08:00", "%H:%M").time(), is_all_day=False,
        ))
        session.commit()

    response = api_request("GET", "/api/v2/agenda/range?from=2026-09-16&to=2026-09-16&timezone=Europe/Istanbul")

    assert response.status_code == 200
    assert response.json()["items"][0]["starts_at"] == "2026-09-16T05:00:00Z"
