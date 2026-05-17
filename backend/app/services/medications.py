"""Medication reminder domain helpers."""

from __future__ import annotations

from datetime import datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.models import Medication, MedicationDoseLog, MedicationDoseStatus
from app.schemas import (
    MedicationCreate,
    MedicationDashboard,
    MedicationDoseItem,
    MedicationDoseSnooze,
    MedicationDoseTaken,
    MedicationRead,
    MedicationUpdate,
)
from app.services.auth import ensure_default_user


DEFAULT_SCHEDULE_DAYS = 30


def _resolve_user_id(session: Session, user_id: int | None) -> int:
    return user_id if user_id is not None else ensure_default_user(session).id


def _as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def _serialize_weekdays(days: list[int]) -> str:
    return ",".join(str(day) for day in sorted(set(days)))


def _parse_weekdays(value: str) -> list[int]:
    if not value:
        return []
    return [int(part) for part in value.split(",") if part]


def _serialize_times(values: list[time]) -> str:
    normalized = sorted({value.replace(second=0, microsecond=0).strftime("%H:%M") for value in values})
    return ",".join(normalized)


def _parse_times(value: str) -> list[time]:
    if not value:
        return []
    return [time.fromisoformat(part) for part in value.split(",") if part]


def read_medication(medication: Medication) -> MedicationRead:
    return MedicationRead(
        id=medication.id,
        device_id=medication.device_id,
        name=medication.name,
        dosage=medication.dosage,
        instructions=medication.instructions,
        weekdays=_parse_weekdays(medication.weekdays),
        dose_times=_parse_times(medication.dose_times),
        starts_on=medication.starts_on,
        ends_on=medication.ends_on,
        timezone=medication.timezone,
        is_active=medication.is_active,
    )


def list_medications(
    session: Session,
    *,
    user_id: int | None = None,
    device_id: str | None = None,
    active_only: bool = False,
) -> list[Medication]:
    owner_id = _resolve_user_id(session, user_id)
    query = select(Medication).where(Medication.user_id == owner_id).order_by(Medication.name.asc(), Medication.id.asc())
    if device_id:
        query = query.where(Medication.device_id == device_id)
    if active_only:
        query = query.where(Medication.is_active.is_(True))
    return list(session.scalars(query).all())


def get_medication_or_raise(
    session: Session,
    medication_id: int,
    user_id: int | None = None,
    device_id: str | None = None,
) -> Medication:
    owner_id = _resolve_user_id(session, user_id)
    query = (
        select(Medication)
        .options(selectinload(Medication.dose_logs))
        .where(Medication.id == medication_id, Medication.user_id == owner_id)
    )
    if device_id:
        query = query.where(Medication.device_id == device_id)
    medication = session.scalar(query)
    if medication is None:
        raise ValueError("Ilac bulunamadi.")
    return medication


def create_medication(session: Session, payload: MedicationCreate, *, user_id: int | None = None) -> Medication:
    owner_id = _resolve_user_id(session, user_id)
    medication = Medication(
        user_id=owner_id,
        device_id=payload.device_id,
        name=payload.name,
        dosage=payload.dosage,
        instructions=payload.instructions,
        weekdays=_serialize_weekdays(payload.weekdays),
        dose_times=_serialize_times(payload.dose_times),
        starts_on=payload.starts_on,
        ends_on=payload.ends_on,
        timezone=payload.timezone,
        is_active=payload.is_active,
    )
    session.add(medication)
    session.commit()
    session.refresh(medication)
    return medication


def update_medication(
    session: Session,
    medication_id: int,
    payload: MedicationUpdate,
    *,
    user_id: int | None = None,
    device_id: str | None = None,
) -> Medication:
    medication = get_medication_or_raise(session, medication_id, user_id, device_id)
    updates = payload.model_dump(exclude_unset=True)
    if "weekdays" in updates and updates["weekdays"] is not None:
        updates["weekdays"] = _serialize_weekdays(updates["weekdays"])
    if "dose_times" in updates and updates["dose_times"] is not None:
        updates["dose_times"] = _serialize_times(updates["dose_times"])

    starts_on = updates.get("starts_on", medication.starts_on)
    ends_on = updates.get("ends_on", medication.ends_on)
    if ends_on is not None and starts_on is not None and ends_on < starts_on:
        raise ValueError("Bitis tarihi baslangictan once olamaz.")

    for field, value in updates.items():
        setattr(medication, field, value)

    session.commit()
    session.refresh(medication)
    return medication


def deactivate_medication(
    session: Session,
    medication_id: int,
    *,
    user_id: int | None = None,
    device_id: str | None = None,
) -> None:
    medication = get_medication_or_raise(session, medication_id, user_id, device_id)
    medication.is_active = False
    session.commit()


def _dose_item_from_log(
    medication: Medication,
    scheduled_for: datetime,
    log: MedicationDoseLog | None,
    now: datetime,
) -> MedicationDoseItem:
    taken_at = _as_utc(log.taken_at) if log and log.taken_at else None
    snoozed_until = _as_utc(log.snoozed_until) if log and log.snoozed_until else None
    status = "pending"
    notify_at = scheduled_for

    if taken_at is not None:
        status = "taken"
    elif snoozed_until is not None:
        status = "snoozed"
        notify_at = snoozed_until if snoozed_until > now else scheduled_for

    return MedicationDoseItem(
        medication_id=medication.id,
        medication_name=medication.name,
        dosage=medication.dosage,
        instructions=medication.instructions,
        scheduled_for=scheduled_for,
        notify_at=notify_at,
        status=status,
        taken_at=taken_at,
        snoozed_until=snoozed_until,
    )


def _generate_dose_times(medication: Medication, *, now: datetime, days: int) -> list[datetime]:
    if not medication.is_active:
        return []

    tz = ZoneInfo(medication.timezone)
    local_today = now.astimezone(tz).date()
    last_day = local_today + timedelta(days=days)
    weekdays = set(_parse_weekdays(medication.weekdays))
    dose_times = _parse_times(medication.dose_times)
    scheduled: list[datetime] = []
    current_day = local_today

    while current_day <= last_day:
        if current_day >= medication.starts_on and (medication.ends_on is None or current_day <= medication.ends_on):
            if current_day.weekday() in weekdays:
                for dose_time in dose_times:
                    local_dt = datetime.combine(current_day, dose_time, tzinfo=tz)
                    scheduled.append(local_dt.astimezone(timezone.utc))
        current_day += timedelta(days=1)

    return sorted(scheduled)


def _load_dose_logs(
    session: Session,
    medications: list[Medication],
    *,
    now: datetime,
    days: int,
) -> dict[tuple[int, datetime], MedicationDoseLog]:
    medication_ids = [medication.id for medication in medications]
    if not medication_ids:
        return {}

    start = now - timedelta(days=1)
    end = now + timedelta(days=days + 1)
    logs = list(
        session.scalars(
            select(MedicationDoseLog).where(
                MedicationDoseLog.medication_id.in_(medication_ids),
                MedicationDoseLog.scheduled_for >= start,
                MedicationDoseLog.scheduled_for <= end,
            )
        ).all()
    )
    return {(log.medication_id, _as_utc(log.scheduled_for)): log for log in logs}


def build_medication_dose_items(
    session: Session,
    medications: list[Medication],
    *,
    now: datetime | None = None,
    days: int = DEFAULT_SCHEDULE_DAYS,
) -> list[MedicationDoseItem]:
    current_time = _as_utc(now or datetime.now(timezone.utc))
    safe_days = max(0, min(days, 90))
    logs = _load_dose_logs(session, medications, now=current_time, days=safe_days)
    items: list[MedicationDoseItem] = []

    for medication in medications:
        for scheduled_for in _generate_dose_times(medication, now=current_time, days=safe_days):
            log = logs.get((medication.id, _as_utc(scheduled_for)))
            items.append(_dose_item_from_log(medication, _as_utc(scheduled_for), log, current_time))

    items.sort(key=lambda item: (item.notify_at, item.medication_id, item.scheduled_for))
    return items


def build_medication_dashboard(
    session: Session,
    *,
    user_id: int | None = None,
    device_id: str | None = None,
    now: datetime | None = None,
    days: int = DEFAULT_SCHEDULE_DAYS,
) -> MedicationDashboard:
    current_time = _as_utc(now or datetime.now(timezone.utc))
    medications = list_medications(session, user_id=user_id, device_id=device_id)
    active_medications = [medication for medication in medications if medication.is_active]
    items = build_medication_dose_items(session, active_medications, now=current_time, days=days)

    today_doses = []
    for item in items:
        medication = next(
            (candidate for candidate in active_medications if candidate.id == item.medication_id),
            None,
        )
        if medication is None:
            continue
        tz = ZoneInfo(medication.timezone)
        if item.scheduled_for.astimezone(tz).date() == current_time.astimezone(tz).date():
            today_doses.append(item)

    upcoming_doses = [
        item
        for item in items
        if item.status != "taken" and item.notify_at >= current_time
    ]

    return MedicationDashboard(
        medications=[read_medication(medication) for medication in medications],
        today_doses=today_doses,
        upcoming_doses=upcoming_doses[:128],
    )


def build_notification_schedule(
    session: Session,
    *,
    user_id: int | None = None,
    device_id: str | None = None,
    now: datetime | None = None,
    days: int = DEFAULT_SCHEDULE_DAYS,
    limit: int = 128,
) -> list[MedicationDoseItem]:
    current_time = _as_utc(now or datetime.now(timezone.utc))
    medications = list_medications(session, user_id=user_id, device_id=device_id, active_only=True)
    items = build_medication_dose_items(session, medications, now=current_time, days=days)
    return [item for item in items if item.status != "taken" and item.notify_at > current_time][: max(1, min(limit, 256))]


def _get_or_create_dose_log(
    session: Session,
    medication: Medication,
    scheduled_for: datetime,
) -> MedicationDoseLog:
    normalized_scheduled_for = _as_utc(scheduled_for)
    log = session.scalar(
        select(MedicationDoseLog).where(
            MedicationDoseLog.medication_id == medication.id,
            MedicationDoseLog.scheduled_for == normalized_scheduled_for,
        )
    )
    if log is not None:
        return log

    log = MedicationDoseLog(
        medication_id=medication.id,
        scheduled_for=normalized_scheduled_for,
        status=MedicationDoseStatus.SNOOZED,
    )
    session.add(log)
    session.flush()
    return log


def mark_medication_dose_taken(
    session: Session,
    medication_id: int,
    payload: MedicationDoseTaken,
    *,
    user_id: int | None = None,
    device_id: str | None = None,
    now: datetime | None = None,
) -> MedicationDoseItem:
    current_time = _as_utc(now or datetime.now(timezone.utc))
    medication = get_medication_or_raise(session, medication_id, user_id, device_id)
    log = _get_or_create_dose_log(session, medication, payload.scheduled_for)
    log.status = MedicationDoseStatus.TAKEN
    log.taken_at = _as_utc(payload.taken_at or current_time)
    log.snoozed_until = None
    session.commit()
    session.refresh(log)
    return _dose_item_from_log(medication, _as_utc(log.scheduled_for), log, current_time)


def snooze_medication_dose(
    session: Session,
    medication_id: int,
    payload: MedicationDoseSnooze,
    *,
    user_id: int | None = None,
    device_id: str | None = None,
    now: datetime | None = None,
) -> MedicationDoseItem:
    current_time = _as_utc(now or datetime.now(timezone.utc))
    medication = get_medication_or_raise(session, medication_id, user_id, device_id)
    log = _get_or_create_dose_log(session, medication, payload.scheduled_for)
    log.status = MedicationDoseStatus.SNOOZED
    log.taken_at = None
    log.snoozed_until = current_time + timedelta(minutes=payload.snooze_minutes)
    session.commit()
    session.refresh(log)
    return _dose_item_from_log(medication, _as_utc(log.scheduled_for), log, current_time)
