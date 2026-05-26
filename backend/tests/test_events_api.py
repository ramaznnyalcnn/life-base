from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from app.api.routes.events import (
    get_calendar_dashboard,
    create_event_endpoint,
    create_event_reminder,
    delete_event_endpoint,
    delete_event_reminder,
    get_event,
    list_event_reminders,
    list_events_endpoint,
    update_event_endpoint,
)
from app.main import app
from app.models import Event, Reminder, ReminderChannel
from app.schemas import EventCreate, EventUpdate, RecurringEventCreate, ReminderCreate
from app.services.events import build_calendar_dashboard
from app.services.recurring_events import create_recurring_event


def test_events_api_creates_event_with_default_reminders(db_session):
    event = create_event_endpoint(
        EventCreate(
            title="Kredi Karti Odeme",
            description="Aylik ekstreden once kontrol",
            starts_at=datetime(2026, 4, 5, 9, 0, tzinfo=timezone.utc),
            is_important=True,
        ),
        db_session,
    )

    assert event.id is not None
    assert event.is_important is True
    assert len(event.reminders) == 3
    assert event.reminders[0].remind_at.replace(tzinfo=None).isoformat() == "2026-04-04T09:00:00"

    rows = list_events_endpoint(db_session)
    assert len(rows) == 1


def test_events_api_updates_event_and_replaces_relative_reminders(db_session):
    event = create_event_endpoint(
        EventCreate(
            title="Haftalik Planlama",
            starts_at=datetime(2026, 3, 11, 8, 0, tzinfo=timezone.utc),
            reminder_offsets_minutes=[120, 30],
        ),
        db_session,
    )

    updated = update_event_endpoint(
        event.id,
        EventUpdate(
            title="Haftalik Planlama Guncel",
            starts_at=datetime(2026, 3, 12, 10, 0, tzinfo=timezone.utc),
            is_important=True,
            reminder_offsets_minutes=[1440],
            is_completed=True,
        ),
        db_session,
    )

    assert updated.title == "Haftalik Planlama Guncel"
    assert updated.is_important is True
    assert updated.is_completed is True
    assert len(updated.reminders) == 1
    assert updated.reminders[0].remind_at.isoformat() == "2026-03-11T10:00:00"


def test_events_api_creates_all_day_event_without_default_reminders(db_session):
    event = create_event_endpoint(
        EventCreate(
            title="Spor Rutini",
            starts_at=datetime(2026, 4, 8, 0, 0, tzinfo=timezone.utc),
            is_all_day=True,
        ),
        db_session,
    )

    assert event.is_all_day is True
    assert event.starts_at.isoformat() == "2026-04-08T12:00:00"
    assert len(event.reminders) == 0


def test_events_api_lists_adds_and_deletes_reminders(db_session):
    event = create_event_endpoint(
        EventCreate(
            title="Doktor Randevusu",
            starts_at=datetime(2026, 5, 2, 13, 30, tzinfo=timezone.utc),
            reminder_offsets_minutes=[],
        ),
        db_session,
    )

    custom_reminder = create_event_reminder(
        event.id,
        ReminderCreate(
            remind_at=event.starts_at - timedelta(minutes=45),
            channel=ReminderChannel.TELEGRAM,
        ),
        db_session,
    )

    reminders = list_event_reminders(event.id, db_session)
    assert len(reminders) == 1
    assert custom_reminder.channel == ReminderChannel.TELEGRAM

    delete_event_reminder(event.id, custom_reminder.id, db_session)
    reminders_after_delete = list_event_reminders(event.id, db_session)
    assert len(reminders_after_delete) == 0


def test_events_api_deletes_event_with_cascade(db_session):
    event = create_event_endpoint(
        EventCreate(
            title="Vergi Hatirlatmasi",
            starts_at=datetime(2026, 6, 1, 12, 0, tzinfo=timezone.utc),
            reminder_offsets_minutes=[60],
        ),
        db_session,
    )

    delete_event_endpoint(event.id, db_session)

    assert db_session.scalar(select(Event).where(Event.id == event.id)) is None
    assert db_session.scalar(select(Reminder)) is None


def test_events_dashboard_splits_upcoming_past_and_pending_reminders(db_session):
    past = create_event_endpoint(
        EventCreate(
            title="Gecmis Fatura",
            starts_at=datetime(2026, 3, 8, 9, 0, tzinfo=timezone.utc),
            reminder_offsets_minutes=[],
        ),
        db_session,
    )
    upcoming = create_event_endpoint(
        EventCreate(
            title="Disci Randevusu",
            starts_at=datetime(2026, 3, 10, 14, 30, tzinfo=timezone.utc),
            reminder_offsets_minutes=[120, 30],
        ),
        db_session,
    )
    later = create_event_endpoint(
        EventCreate(
            title="Haftalik Planlama",
            starts_at=datetime(2026, 3, 11, 8, 0, tzinfo=timezone.utc),
            reminder_offsets_minutes=[60],
        ),
        db_session,
    )

    dashboard = build_calendar_dashboard(
        db_session,
        include_past=True,
        now=datetime(2026, 3, 9, 12, 0, tzinfo=timezone.utc),
    )

    assert dashboard.focus_event is not None
    assert dashboard.focus_event.id == upcoming.id
    assert [event.id for event in dashboard.upcoming_events] == [upcoming.id, later.id]
    assert [event.id for event in dashboard.past_events] == [past.id]
    assert len(dashboard.pending_reminders) == 3
    assert dashboard.pending_reminders[0].event_title == "Disci Randevusu"


def test_events_dashboard_route_shares_records_across_user_devices(db_session):
    create_event_endpoint(
        EventCreate(
            title="Benim Etkinligim",
            starts_at=datetime(2027, 3, 10, 14, 30, tzinfo=timezone.utc),
            reminder_offsets_minutes=[],
            device_id="device-a",
        ),
        db_session,
    )
    create_event_endpoint(
        EventCreate(
            title="Diger Cihaz Etkinligi",
            starts_at=datetime(2027, 3, 10, 16, 0, tzinfo=timezone.utc),
            reminder_offsets_minutes=[],
            device_id="device-b",
        ),
        db_session,
    )

    dashboard = get_calendar_dashboard(
        include_past=False,
        db=db_session,
        x_device_id="device-a",
    )

    assert [event.title for event in dashboard.upcoming_events] == ["Benim Etkinligim", "Diger Cihaz Etkinligi"]


def test_events_dashboard_includes_recurring_occurrences(db_session):
    create_recurring_event(
        db_session,
        RecurringEventCreate(
            title="Spor",
            description="Haftalik rutin",
            weekdays=[0, 2, 4],
            starts_on=datetime(2026, 3, 9, tzinfo=timezone.utc).date(),
            is_all_day=True,
            device_id="device-a",
        ),
    )

    dashboard = build_calendar_dashboard(
        db_session,
        include_past=True,
        device_id="device-a",
        now=datetime(2026, 3, 9, 12, 0, tzinfo=timezone.utc),
    )

    titles = [event.title for event in dashboard.upcoming_events]
    assert "Spor" in titles
    recurring = next(event for event in dashboard.upcoming_events if event.title == "Spor")
    assert recurring.is_recurring is True
    assert recurring.recurring_rule_id is not None


def test_event_routes_are_registered_on_app():
    paths = {route.path for route in app.routes}

    assert "/api/v1/events/dashboard" in paths
    assert "/api/v1/events" in paths
    assert "/api/v1/events/{event_id}" in paths
    assert "/api/v1/events/{event_id}/reminders" in paths
