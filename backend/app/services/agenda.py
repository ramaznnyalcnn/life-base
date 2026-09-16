"""Read model that merges all calendar-relevant domains."""

from __future__ import annotations

from datetime import date, datetime, time, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import AgendaRevision, Event, ScheduledPayment, Task
from app.schemas.agenda import AgendaItem, AgendaRange, AgendaToday
from app.services.medications import build_medication_schedule
from app.services.recurring_events import expand_recurring_events, list_recurring_events


MAX_RANGE_DAYS = 92


def _zone(name: str) -> ZoneInfo:
    try:
        return ZoneInfo(name)
    except ZoneInfoNotFoundError as exc:
        raise ValueError("Timezone gecersiz.") from exc


def _aware(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def _local_day(value: datetime, zone: ZoneInfo) -> date:
    return _aware(value).astimezone(zone).date()


def _sort_key(item: AgendaItem):
    at = _aware(item.starts_at) if item.starts_at else datetime.combine(item.day, time.max, tzinfo=timezone.utc)
    return (at.astimezone(timezone.utc), item.id)


def _version(session: Session, user_id: int) -> int:
    revision = session.get(AgendaRevision, user_id)
    return revision.version if revision else 0


def build_agenda_range(
    session: Session,
    *,
    user_id: int,
    from_date: date,
    to_date: date,
    timezone_name: str = "Europe/Istanbul",
    now: datetime | None = None,
) -> AgendaRange:
    if to_date < from_date or (to_date - from_date).days > MAX_RANGE_DAYS:
        raise ValueError("Gundem tarih araligi gecersiz.")
    zone = _zone(timezone_name)
    current_time = _aware(now or datetime.now(timezone.utc))
    items: list[AgendaItem] = []

    for event in session.scalars(select(Event).where(Event.user_id == user_id)).all():
        day = _local_day(event.starts_at, zone)
        if from_date <= day <= to_date:
            items.append(AgendaItem(
                id=f"event:{event.id}", source_id=event.id, kind="event", title=event.title,
                day=day, starts_at=_aware(event.starts_at), ends_at=_aware(event.ends_at) if event.ends_at else None,
                is_all_day=event.is_all_day, is_important=event.is_important,
                is_completed=event.is_completed, status="completed" if event.is_completed else "pending",
                reminders=[_aware(item.remind_at) for item in event.reminders],
            ))

    range_start = datetime.combine(from_date, time.min, tzinfo=zone).astimezone(timezone.utc)
    range_end = datetime.combine(to_date, time.max, tzinfo=zone).astimezone(timezone.utc)
    recurring = expand_recurring_events(
        list_recurring_events(session, user_id=user_id),
        range_start=range_start,
        range_end=range_end,
        timezone_name=timezone_name,
    )
    for event in recurring:
        day = _local_day(event.starts_at, zone)
        if from_date <= day <= to_date:
            items.append(AgendaItem(
                id=f"recurring:{event.recurring_rule_id}:{day.isoformat()}",
                source_id=event.recurring_rule_id or event.id, kind="routine", title=event.title,
                day=day, starts_at=_aware(event.starts_at), ends_at=_aware(event.ends_at) if event.ends_at else None,
                is_all_day=event.is_all_day, is_important=event.is_important,
            ))

    for task in session.scalars(select(Task).where(Task.user_id == user_id)).all():
        if from_date <= task.due_on <= to_date:
            items.append(AgendaItem(
                id=f"task:{task.id}", source_id=task.id, kind="task", title=task.title,
                day=task.due_on, starts_at=_aware(task.scheduled_at) if task.scheduled_at else None,
                is_important=task.is_important, is_completed=task.is_completed,
                status="completed" if task.is_completed else "pending",
                metadata={"entity_version": task.entity_version},
                reminders=[_aware(item.remind_at) for item in task.reminders],
            ))

    for payment in session.scalars(select(ScheduledPayment).where(ScheduledPayment.user_id == user_id)).all():
        day = _local_day(payment.due_at, zone)
        if from_date <= day <= to_date:
            items.append(AgendaItem(
                id=f"scheduled_payment:{payment.id}", source_id=payment.id, kind="scheduled_payment",
                title=f"{payment.amount:.2f} {payment.source_account.currency} odeme", day=day,
                starts_at=_aware(payment.due_at), is_completed=payment.is_completed,
                status="completed" if payment.is_completed else "pending",
                metadata={
                    "source_account_id": payment.source_account_id,
                    "destination_account_id": payment.destination_account_id,
                    "entity_version": payment.entity_version,
                },
                reminders=[_aware(item.remind_at) for item in payment.reminders],
            ))

    doses = build_medication_schedule(
        session, from_date=from_date, to_date=to_date, user_id=user_id, now=current_time
    )
    for dose in doses:
        day = _local_day(dose.scheduled_for, zone)
        if from_date <= day <= to_date:
            items.append(AgendaItem(
                id=f"medication:{dose.medication_id}:{dose.scheduled_for.isoformat()}",
                source_id=dose.medication_id, kind="medication", title=f"{dose.medication_name} · {dose.dosage}",
                day=day, starts_at=dose.notify_at, is_completed=dose.status == "taken", status=dose.status,
                metadata={"scheduled_for": dose.scheduled_for.isoformat()},
                reminders=[dose.notify_at],
            ))

    items.sort(key=_sort_key)
    return AgendaRange(
        from_date=from_date, to_date=to_date, timezone=timezone_name,
        version=_version(session, user_id), items=items,
    )


def build_today_agenda(
    session: Session,
    *,
    user_id: int,
    value: date,
    timezone_name: str = "Europe/Istanbul",
    now: datetime | None = None,
) -> AgendaToday:
    zone = _zone(timezone_name)
    current_time = _aware(now or datetime.now(timezone.utc))
    agenda_range = build_agenda_range(
        session, user_id=user_id, from_date=value, to_date=value,
        timezone_name=timezone_name, now=current_time,
    )
    tasks = [item for item in agenda_range.items if item.kind == "task"]
    timeline = [item for item in agenda_range.items if item.starts_at is not None]
    overdue = [AgendaItem(
        id=f"task:{task.id}", source_id=task.id, kind="task", title=task.title, day=task.due_on,
        starts_at=_aware(task.scheduled_at) if task.scheduled_at else None,
        is_important=task.is_important, status="overdue",
    ) for task in session.scalars(select(Task).where(
        Task.user_id == user_id, Task.is_completed.is_(False), Task.due_on < value
    )).all()]
    for payment in session.scalars(select(ScheduledPayment).where(
        ScheduledPayment.user_id == user_id, ScheduledPayment.is_completed.is_(False)
    )).all():
        day = _local_day(payment.due_at, zone)
        if day < value:
            overdue.append(AgendaItem(
                id=f"scheduled_payment:{payment.id}", source_id=payment.id, kind="scheduled_payment",
                title=f"{payment.amount:.2f} {payment.source_account.currency} odeme", day=day,
                starts_at=_aware(payment.due_at), status="overdue",
            ))
    overdue.sort(key=_sort_key)
    next_item = next(
        (item for item in timeline if not item.is_completed and _aware(item.starts_at) >= current_time), None
    )
    return AgendaToday(
        date=value, timezone=timezone_name, version=agenda_range.version,
        overdue=overdue, tasks=tasks, timeline=timeline, next_item=next_item,
    )
