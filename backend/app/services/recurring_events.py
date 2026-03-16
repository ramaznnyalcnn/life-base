"""Recurring event domain helpers."""

from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import RecurringEvent
from app.schemas import EventRead, RecurringEventCreate, RecurringEventRead
from app.services.auth import ensure_default_user


def _resolve_user_id(session: Session, user_id: int | None) -> int:
    return user_id if user_id is not None else ensure_default_user(session).id


def _serialize_weekdays(days: list[int]) -> str:
    return ",".join(str(day) for day in sorted(set(days)))


def _parse_weekdays(value: str) -> list[int]:
    if not value:
        return []
    return [int(part) for part in value.split(",") if part]


def create_recurring_event(
    session: Session,
    payload: RecurringEventCreate,
    *,
    user_id: int | None = None,
) -> RecurringEvent:
    owner_id = _resolve_user_id(session, user_id)
    rule = RecurringEvent(
        user_id=owner_id,
        device_id=payload.device_id,
        title=payload.title,
        description=payload.description,
        weekdays=_serialize_weekdays(payload.weekdays),
        starts_on=payload.starts_on,
        ends_on=payload.ends_on,
        start_time=payload.start_time,
        end_time=payload.end_time,
        is_all_day=payload.is_all_day,
        is_important=payload.is_important,
        is_active=payload.is_active,
        interval_weeks=payload.interval_weeks,
    )
    session.add(rule)
    session.commit()
    session.refresh(rule)
    return rule


def list_recurring_events(
    session: Session,
    *,
    user_id: int | None = None,
    device_id: str | None = None,
    active_only: bool = True,
) -> list[RecurringEvent]:
    owner_id = _resolve_user_id(session, user_id)
    query = select(RecurringEvent).where(RecurringEvent.user_id == owner_id)
    if active_only:
        query = query.where(RecurringEvent.is_active.is_(True))
    if device_id:
        query = query.where(RecurringEvent.device_id == device_id)
    query = query.order_by(RecurringEvent.id.asc())
    return list(session.scalars(query).all())


def read_recurring_rule(rule: RecurringEvent) -> RecurringEventRead:
    return RecurringEventRead(
        id=rule.id,
        device_id=rule.device_id,
        title=rule.title,
        description=rule.description,
        weekdays=_parse_weekdays(rule.weekdays),
        starts_on=rule.starts_on,
        ends_on=rule.ends_on,
        start_time=rule.start_time,
        end_time=rule.end_time,
        is_all_day=rule.is_all_day,
        is_important=rule.is_important,
        is_active=rule.is_active,
        interval_weeks=rule.interval_weeks,
    )


def _combine_occurrence_datetime(value: date, at: time | None, *, is_all_day: bool) -> datetime:
    if is_all_day or at is None:
        return datetime.combine(value, time(hour=12), tzinfo=timezone.utc)
    return datetime.combine(value, at, tzinfo=timezone.utc)


def _matches_rule(rule: RecurringEvent, value: date) -> bool:
    if value < rule.starts_on:
        return False
    if rule.ends_on is not None and value > rule.ends_on:
        return False
    if value.weekday() not in _parse_weekdays(rule.weekdays):
        return False

    anchor_monday = rule.starts_on - timedelta(days=rule.starts_on.weekday())
    current_monday = value - timedelta(days=value.weekday())
    diff_weeks = (current_monday - anchor_monday).days // 7
    return diff_weeks % max(rule.interval_weeks, 1) == 0


def expand_recurring_events(
    rules: list[RecurringEvent],
    *,
    range_start: datetime,
    range_end: datetime,
) -> list[EventRead]:
    occurrences: list[EventRead] = []
    current_day = range_start.date()
    last_day = range_end.date()

    while current_day <= last_day:
        for rule in rules:
            if not _matches_rule(rule, current_day):
                continue

            starts_at = _combine_occurrence_datetime(current_day, rule.start_time, is_all_day=rule.is_all_day)
            ends_at = (
                _combine_occurrence_datetime(current_day, rule.end_time, is_all_day=False)
                if rule.end_time is not None and not rule.is_all_day
                else None
            )
            occurrence_id = -((rule.id * 100000) + current_day.toordinal())
            occurrences.append(
                EventRead(
                    id=occurrence_id,
                    title=rule.title,
                    description=rule.description,
                    starts_at=starts_at,
                    ends_at=ends_at,
                    is_all_day=rule.is_all_day,
                    is_important=rule.is_important,
                    is_completed=False,
                    is_recurring=True,
                    recurring_rule_id=rule.id,
                    reminders=[],
                )
            )
        current_day += timedelta(days=1)

    occurrences.sort(key=lambda event: (event.starts_at, event.id))
    return occurrences
