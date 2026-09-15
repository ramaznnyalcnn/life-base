"""Class-based medication operations."""

from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from app.models import MedicationDoseStatus
from app.operations.base import HandlerResult, OperationContext, OperationHandler
from app.operations.definitions import definition, field
from app.schemas import EntityRef, OperationFieldKind
from app.schemas.operation_inputs import MedicationScheduleInput, MedicationSnoozeInput, MedicationTakeInput
from app.services.medications import _get_or_create_dose_log, _serialize_times, _serialize_weekdays, get_medication_or_raise


def _as_utc(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


class MedicationScheduleOperation(OperationHandler[MedicationScheduleInput]):
    key = "health.medication.schedule"
    input_model = MedicationScheduleInput
    definition = definition(key, "health", "Ilac programla", [
        field("medication_id", "Ilac", OperationFieldKind.CHOICE, source="medications"),
        field("schedule_mode", "Program", OperationFieldKind.CHOICE, source="medication.schedule_modes"),
        field("weekdays", "Gunler", OperationFieldKind.CHOICE, required=False, source="weekdays"),
        field("interval_days", "Gun araligi", OperationFieldKind.DURATION, required=False, min_value=1, max_value=365),
        field("dose_times", "Saatler", OperationFieldKind.TIME),
        field("starts_on", "Baslangic", OperationFieldKind.DATE),
        field("ends_on", "Bitis", OperationFieldKind.DATE, required=False),
    ])

    def execute(self, context: OperationContext, payload: MedicationScheduleInput) -> HandlerResult:
        try:
            ZoneInfo(payload.timezone)
        except ZoneInfoNotFoundError as exc:
            raise ValueError("Timezone gecersiz.") from exc
        medication = get_medication_or_raise(context.session, payload.medication_id, context.user_id)
        medication.schedule_mode = payload.schedule_mode
        medication.weekdays = _serialize_weekdays(payload.weekdays)
        medication.interval_days = payload.interval_days
        medication.dose_times = _serialize_times(payload.dose_times)
        medication.starts_on = payload.starts_on
        medication.ends_on = payload.ends_on
        medication.timezone = payload.timezone
        medication.is_active = True
        return HandlerResult(entities=[EntityRef(kind="medication", id=medication.id)], affects_agenda=True)


class MedicationTakeOperation(OperationHandler[MedicationTakeInput]):
    key = "health.medication.take"
    input_model = MedicationTakeInput
    definition = definition(key, "health", "Ilaci al", [
        field("medication_id", "Ilac", OperationFieldKind.CHOICE, source="medications"),
        field("scheduled_for", "Doz", OperationFieldKind.CHOICE, source="medication_doses.pending"),
    ])

    def execute(self, context: OperationContext, payload: MedicationTakeInput) -> HandlerResult:
        medication = get_medication_or_raise(context.session, payload.medication_id, context.user_id)
        log = _get_or_create_dose_log(context.session, medication, payload.scheduled_for)
        log.status = MedicationDoseStatus.TAKEN
        log.taken_at = _as_utc(payload.taken_at or context.now)
        log.snoozed_until = None
        context.session.flush()
        return HandlerResult(entities=[EntityRef(kind="medication_dose_log", id=log.id)], affects_agenda=True)


class MedicationSnoozeOperation(OperationHandler[MedicationSnoozeInput]):
    key = "health.medication.snooze"
    input_model = MedicationSnoozeInput
    definition = definition(key, "health", "Ilaci ertele", [
        field("medication_id", "Ilac", OperationFieldKind.CHOICE, source="medications"),
        field("scheduled_for", "Doz", OperationFieldKind.CHOICE, source="medication_doses.pending"),
        field("snooze_minutes", "Erteleme", OperationFieldKind.DURATION, min_value=5, max_value=120),
    ])

    def execute(self, context: OperationContext, payload: MedicationSnoozeInput) -> HandlerResult:
        medication = get_medication_or_raise(context.session, payload.medication_id, context.user_id)
        log = _get_or_create_dose_log(context.session, medication, payload.scheduled_for)
        log.status = MedicationDoseStatus.SNOOZED
        log.taken_at = None
        log.snoozed_until = context.now + timedelta(minutes=payload.snooze_minutes)
        context.session.flush()
        return HandlerResult(entities=[EntityRef(kind="medication_dose_log", id=log.id)], affects_agenda=True)
