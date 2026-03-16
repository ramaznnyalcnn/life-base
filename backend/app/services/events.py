"""Event and reminder domain helpers."""

from __future__ import annotations

from datetime import datetime, time, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models import Event, Reminder
from app.schemas import CalendarDashboard, CalendarReminderItem, EventCreate, EventRead, EventUpdate, ReminderCreate
from app.services.auth import ensure_default_user
from app.services.recurring_events import expand_recurring_events, list_recurring_events


DEFAULT_REMINDER_OFFSETS_MINUTES: tuple[int, ...] = (1440, 180, 60)


def _resolve_user_id(session: Session, user_id: int | None) -> int:
    return user_id if user_id is not None else ensure_default_user(session).id


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _normalize_all_day_start(value: datetime) -> datetime:
    base = _as_utc(value)
    return datetime.combine(base.date(), time(hour=12), tzinfo=timezone.utc)


def list_events(session: Session, user_id: int | None = None, device_id: str | None = None) -> list[Event]:
    """Return events sorted by start time with reminders eagerly loaded."""

    owner_id = _resolve_user_id(session, user_id)
    query = (
        select(Event)
        .options(selectinload(Event.reminders))
        .where(Event.user_id == owner_id)
        .order_by(Event.starts_at.asc(), Event.id.asc())
    )
    if device_id:
        query = query.where(Event.device_id == device_id)
    return list(session.scalars(query).all())


def get_event_or_raise(
    session: Session,
    event_id: int,
    user_id: int | None = None,
    device_id: str | None = None,
) -> Event:
    """Fetch an event or raise a domain error."""

    owner_id = _resolve_user_id(session, user_id)
    query = select(Event).options(selectinload(Event.reminders)).where(Event.id == event_id, Event.user_id == owner_id)
    if device_id:
        query = query.where(Event.device_id == device_id)
    event = session.scalar(query)
    if event is None:
        raise ValueError("Etkinlik bulunamadi.")
    return event


def _build_offset_reminders(event: Event, offsets: list[int]) -> list[Reminder]:
    reminders: list[Reminder] = []
    for minutes in sorted(set(offsets), reverse=True):
        if minutes <= 0:
            continue
        reminders.append(
            Reminder(
                event=event,
                remind_at=event.starts_at - timedelta(minutes=minutes),
            )
        )
    return reminders


def create_event(session: Session, payload: EventCreate, *, user_id: int | None = None) -> Event:
    """Create an event and any requested relative reminders."""

    owner_id = _resolve_user_id(session, user_id)
    event = Event(
        user_id=owner_id,
        device_id=payload.device_id,
        title=payload.title,
        description=payload.description,
        starts_at=_normalize_all_day_start(payload.starts_at) if payload.is_all_day else payload.starts_at,
        ends_at=payload.ends_at,
        is_all_day=payload.is_all_day,
        is_important=payload.is_important,
        is_completed=payload.is_completed,
    )
    session.add(event)
    session.flush()

    offsets = (
        []
        if payload.is_all_day and payload.reminder_offsets_minutes is None
        else list(DEFAULT_REMINDER_OFFSETS_MINUTES)
        if payload.reminder_offsets_minutes is None
        else payload.reminder_offsets_minutes
    )
    reminders = _build_offset_reminders(event, offsets)
    session.add_all(reminders)
    session.commit()
    session.expire_all()
    return get_event_or_raise(session, event.id, owner_id, payload.device_id)


def update_event(
    session: Session,
    event_id: int,
    payload: EventUpdate,
    user_id: int | None = None,
    device_id: str | None = None,
) -> Event:
    """Update an event and optionally replace reminder offsets."""

    owner_id = _resolve_user_id(session, user_id)
    event = get_event_or_raise(session, event_id, owner_id, device_id)
    updates = payload.model_dump(exclude_unset=True)
    reminder_offsets = updates.pop("reminder_offsets_minutes", None)

    for field, value in updates.items():
        if field == "starts_at" and value is not None and event.is_all_day:
            value = _normalize_all_day_start(value)
        setattr(event, field, value)

    if "is_all_day" in updates and event.is_all_day:
        event.starts_at = _normalize_all_day_start(event.starts_at)
        event.ends_at = None

    if reminder_offsets is not None:
        for reminder in list(event.reminders):
            session.delete(reminder)
        session.flush()
        session.add_all(_build_offset_reminders(event, reminder_offsets))

    session.commit()
    session.expire_all()
    return get_event_or_raise(session, event.id, owner_id, device_id)


def delete_event(session: Session, event_id: int, user_id: int | None = None, device_id: str | None = None) -> None:
    """Delete an event and cascading reminders."""

    event = get_event_or_raise(session, event_id, _resolve_user_id(session, user_id), device_id)
    session.delete(event)
    session.commit()


def list_reminders(
    session: Session,
    event_id: int,
    user_id: int | None = None,
    device_id: str | None = None,
) -> list[Reminder]:
    """Return reminders for a specific event."""

    get_event_or_raise(session, event_id, _resolve_user_id(session, user_id), device_id)
    query = (
        select(Reminder)
        .where(Reminder.event_id == event_id)
        .order_by(Reminder.remind_at.asc(), Reminder.id.asc())
    )
    return list(session.scalars(query).all())


def add_reminder(
    session: Session,
    event_id: int,
    payload: ReminderCreate,
    user_id: int | None = None,
    device_id: str | None = None,
) -> Reminder:
    """Add an explicit reminder to an event."""

    event = get_event_or_raise(session, event_id, _resolve_user_id(session, user_id), device_id)
    reminder = Reminder(
        event_id=event.id,
        remind_at=payload.remind_at,
        channel=payload.channel,
    )
    session.add(reminder)
    session.commit()
    session.refresh(reminder)
    return reminder


def delete_reminder(
    session: Session,
    event_id: int,
    reminder_id: int,
    user_id: int | None = None,
    device_id: str | None = None,
) -> None:
    """Delete a reminder from an event."""

    owner_id = _resolve_user_id(session, user_id)
    reminder = session.scalar(
        select(Reminder)
        .join(Event, Event.id == Reminder.event_id)
        .where(
            Reminder.id == reminder_id,
            Reminder.event_id == event_id,
            Event.user_id == owner_id,
            Event.device_id == device_id if device_id else True,
        )
    )
    if reminder is None:
        raise ValueError("Hatirlatma bulunamadi.")
    session.delete(reminder)
    session.commit()


def build_calendar_dashboard(
    session: Session,
    *,
    user_id: int | None = None,
    device_id: str | None = None,
    include_past: bool = False,
    event_limit: int = 120,
    reminder_limit: int = 8,
    now: datetime | None = None,
) -> CalendarDashboard:
    """Build an event dashboard optimized for the calendar screen."""

    owner_id = _resolve_user_id(session, user_id)
    current_time = now or datetime.now(timezone.utc)
    events = [EventRead.model_validate(event) for event in list_events(session, user_id=owner_id, device_id=device_id)]
    recurring_rules = list_recurring_events(session, user_id=owner_id, device_id=device_id)
    recurring_events = expand_recurring_events(
        recurring_rules,
        range_start=current_time - timedelta(days=31),
        range_end=current_time + timedelta(days=90),
    )
    combined_events = sorted(
        [*events, *recurring_events],
        key=lambda event: (_as_utc(event.starts_at), event.id),
    )

    upcoming_events = [
        event for event in combined_events if not event.is_completed and _as_utc(event.starts_at) >= current_time
    ]
    past_events = [
        event for event in combined_events if event.is_completed or _as_utc(event.starts_at) < current_time
    ]
    focus_event = upcoming_events[0] if upcoming_events else None

    reminder_rows = list(
        session.scalars(
            select(Reminder)
            .options(selectinload(Reminder.event))
            .where(
                Reminder.is_sent.is_(False),
                Reminder.remind_at >= current_time,
                Reminder.event.has(Event.user_id == owner_id),
                Reminder.event.has(Event.device_id == device_id) if device_id else True,
            )
            .order_by(Reminder.remind_at.asc(), Reminder.id.asc())
            .limit(reminder_limit)
        ).all()
    )

    return CalendarDashboard(
        focus_event=focus_event,
        upcoming_events=upcoming_events[:event_limit],
        past_events=past_events[:event_limit] if include_past else [],
        pending_reminders=[
            CalendarReminderItem(
                id=reminder.id,
                event_id=reminder.event_id,
                event_title=reminder.event.title,
                remind_at=reminder.remind_at,
                is_sent=reminder.is_sent,
            )
            for reminder in reminder_rows
        ],
    )
