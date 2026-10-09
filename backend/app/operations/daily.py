"""Daily CRUD operations used by the offline-first Android client."""

from __future__ import annotations

from datetime import date, datetime, time, timezone
from decimal import Decimal

from fastapi.encoders import jsonable_encoder
from sqlalchemy import select

from app.models import (
    Account, Category, CategoryType, Event, Medication, MedicationDoseLog,
    RecurringEvent, ScheduledPayment, Task,
)
from app.operations.base import HandlerResult, OperationContext, OperationHandler
from app.operations.definitions import definition, field
from app.operations.executor import EntityVersionConflictError
from app.schemas import EntityRef, OperationFieldKind
from app.schemas.operation_inputs import (
    CategoryCreateInput,
    CategoryToggleInput,
    CategoryUpdateInput,
    EventCompleteInput,
    EventDeleteInput,
    EventReopenInput,
    EventUpdateInput,
    MedicationCreateInput,
    MedicationToggleInput,
    MedicationUndoTakeInput,
    MedicationUpdateInput,
    OperationInput,
    PaymentCancelInput,
    PaymentUpdateInput,
    RoutineDeleteInput,
    RoutineToggleInput,
    RoutineUpdateInput,
    TaskDeleteInput,
    TaskReopenInput,
    TaskUpdateInput,
    VersionedOperationInput,
)
from app.services.medications import _parse_times, _parse_weekdays, _serialize_times, _serialize_weekdays


def _owned(context: OperationContext, model, entity_id: int):
    entity = context.session.scalar(select(model).where(model.id == entity_id, model.user_id == context.user_id))
    if entity is None:
        raise ValueError("Kayit bulunamadi.")
    return entity


def _owned_category(
    context: OperationContext,
    category_id: int,
    category_type: CategoryType,
) -> Category:
    category = context.session.scalar(
        select(Category).where(
            Category.id == category_id,
            Category.type == category_type,
            (Category.user_id == context.user_id) | (Category.user_id.is_(None)),
        )
    )
    if category is None:
        raise ValueError("Kategori bulunamadi.")
    return category


def _snapshot(entity) -> dict[str, object]:
    return jsonable_encoder({
        column.name: getattr(entity, column.name)
        for column in entity.__table__.columns
        if column.name not in {"created_at", "updated_at"}
    })


def _check(entity, payload: OperationInput) -> None:
    expected = getattr(payload, "expected_version", None)
    if expected is not None and expected != entity.entity_version:
        raise EntityVersionConflictError(_snapshot(entity))


def _bump(entity) -> None:
    entity.entity_version += 1


def _amount(value) -> Decimal:
    result = Decimal(str(value))
    if result <= 0:
        raise ValueError("Tutar sifirdan buyuk olmali.")
    return result


def _date(value) -> date:
    return date.fromisoformat(value) if isinstance(value, str) else value


def _datetime(value) -> datetime:
    return datetime.fromisoformat(value) if isinstance(value, str) else value


def _time(value) -> time:
    return time.fromisoformat(value) if isinstance(value, str) else value


def _utc(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def _shift_reminders(reminders, old_time: datetime, new_time: datetime) -> None:
    delta = _utc(new_time) - _utc(old_time)
    for reminder in reminders:
        reminder.remind_at += delta
        reminder.is_sent = False


class DailyOperation(OperationHandler[OperationInput]):
    input_model = OperationInput


class VersionedDailyOperation(DailyOperation):
    input_model = VersionedOperationInput


class CategoryCreateOperation(DailyOperation):
    key = "finance.category.create"
    input_model = CategoryCreateInput
    definition = definition(key, "finance", "Kategori olustur", [field("name", "Kategori adi", OperationFieldKind.SHORT_TEXT, max_length=80), field("type", "Tur", OperationFieldKind.CHOICE, source="category.types")])
    def execute(self, context, payload):
        entity = Category(user_id=context.user_id, name=payload.name.strip(), type=CategoryType(payload.type), is_system=False, is_active=True)
        context.session.add(entity); context.session.flush(); return HandlerResult([EntityRef(kind="category", id=entity.id)])


class CategoryUpdateOperation(VersionedDailyOperation):
    key = "finance.category.update"
    input_model = CategoryUpdateInput
    versioned_model = Category
    versioned_id_field = "category_id"
    definition = definition(key, "finance", "Kategoriyi duzenle", [field("category_id", "Kategori", OperationFieldKind.CHOICE, source="categories.all"), field("name", "Kategori adi", OperationFieldKind.SHORT_TEXT, max_length=80), field("expected_version", "Surum", OperationFieldKind.DURATION)])
    def execute(self, context, payload):
        entity = _owned(context, Category, payload.category_id); _check(entity, payload)
        if entity.is_system: raise ValueError("Sistem kategorisi duzenlenemez.")
        entity.name = payload.name.strip(); _bump(entity); return HandlerResult([EntityRef(kind="category", id=entity.id)])


class CategoryToggleOperation(VersionedDailyOperation):
    key = "finance.category.toggle"
    input_model = CategoryToggleInput
    versioned_model = Category
    versioned_id_field = "category_id"
    definition = definition(key, "finance", "Kategoriyi ac veya kapat", [field("category_id", "Kategori", OperationFieldKind.CHOICE, source="categories.all"), field("expected_version", "Surum", OperationFieldKind.DURATION)])
    def execute(self, context, payload):
        entity = _owned(context, Category, payload.category_id); _check(entity, payload)
        if entity.is_system: raise ValueError("Sistem kategorisi kapatilamaz.")
        entity.is_active = not entity.is_active; _bump(entity); return HandlerResult([EntityRef(kind="category", id=entity.id)])


class PaymentUpdateOperation(VersionedDailyOperation):
    key = "finance.payment.update"
    input_model = PaymentUpdateInput
    versioned_model = ScheduledPayment
    versioned_id_field = "scheduled_payment_id"
    definition = definition(key, "finance", "Planli odemeyi duzenle", [field("scheduled_payment_id", "Odeme", OperationFieldKind.CHOICE, source="scheduled_payments.pending"), field("source_account_id", "Kaynak hesap", OperationFieldKind.CHOICE, required=False, source="accounts"), field("destination_account_id", "Hedef hesap", OperationFieldKind.CHOICE, required=False, source="accounts"), field("amount", "Tutar", OperationFieldKind.MONEY, required=False), field("due_at", "Zaman", OperationFieldKind.DATETIME, required=False), field("expected_version", "Surum", OperationFieldKind.DURATION)])
    def execute(self, context, payload):
        entity = _owned(context, ScheduledPayment, payload.scheduled_payment_id); _check(entity, payload)
        if entity.is_completed: raise ValueError("Tamamlanan odeme duzenlenemez.")
        if payload.source_account_id is not None:
            entity.source_account_id = _owned(context, Account, payload.source_account_id).id
        if payload.destination_account_id is not None:
            entity.destination_account_id = _owned(context, Account, payload.destination_account_id).id
        if entity.source_account_id == entity.destination_account_id: raise ValueError("Hesaplar ayni olamaz.")
        if payload.amount is not None: entity.amount = _amount(payload.amount)
        if payload.due_at is not None:
            due_at = _datetime(payload.due_at)
            _shift_reminders(entity.reminders, entity.due_at, due_at)
            entity.due_at = due_at
        _bump(entity); return HandlerResult([EntityRef(kind="scheduled_payment", id=entity.id)], True)


class PaymentCancelOperation(VersionedDailyOperation):
    key = "finance.payment.cancel"
    input_model = PaymentCancelInput
    versioned_model = ScheduledPayment
    versioned_id_field = "scheduled_payment_id"
    definition = definition(key, "finance", "Planli odemeyi iptal et", [field("scheduled_payment_id", "Odeme", OperationFieldKind.CHOICE, source="scheduled_payments.pending"), field("expected_version", "Surum", OperationFieldKind.DURATION)])
    def execute(self, context, payload):
        entity = _owned(context, ScheduledPayment, payload.scheduled_payment_id); _check(entity, payload)
        if entity.is_completed: raise ValueError("Tamamlanan odeme iptal edilemez.")
        entity_id = entity.id; context.session.delete(entity); return HandlerResult([EntityRef(kind="scheduled_payment", id=entity_id)], True)


class TaskUpdateOperation(VersionedDailyOperation):
    key = "planning.task.update"
    input_model = TaskUpdateInput
    versioned_model = Task
    versioned_id_field = "task_id"
    definition = definition(key, "planning", "Gorevi duzenle", [field("task_id", "Gorev", OperationFieldKind.CHOICE, source="tasks.all"), field("title", "Kisa baslik", OperationFieldKind.SHORT_TEXT, required=False, max_length=160), field("due_on", "Gun", OperationFieldKind.DATE, required=False), field("scheduled_at", "Saat", OperationFieldKind.DATETIME, required=False), field("is_important", "Onemli", OperationFieldKind.BOOLEAN, required=False), field("expected_version", "Surum", OperationFieldKind.DURATION)])
    def execute(self, context, payload):
        entity = _owned(context, Task, payload.task_id); _check(entity, payload)
        if getattr(payload, "title", None) is not None: entity.title = payload.title
        if getattr(payload, "due_on", None) is not None: entity.due_on = _date(payload.due_on)
        if payload.scheduled_at is not None:
            scheduled_at = _datetime(payload.scheduled_at)
            if entity.scheduled_at is not None:
                _shift_reminders(entity.reminders, entity.scheduled_at, scheduled_at)
            entity.scheduled_at = scheduled_at
        if getattr(payload, "is_important", None) is not None: entity.is_important = payload.is_important
        _bump(entity); return HandlerResult([EntityRef(kind="task", id=entity.id)], True)


class TaskReopenOperation(VersionedDailyOperation):
    key = "planning.task.reopen"
    input_model = TaskReopenInput
    versioned_model = Task
    versioned_id_field = "task_id"
    definition = definition(key, "planning", "Gorevi yeniden ac", [field("task_id", "Gorev", OperationFieldKind.CHOICE, source="tasks.completed"), field("expected_version", "Surum", OperationFieldKind.DURATION)])
    def execute(self, context, payload):
        entity = _owned(context, Task, payload.task_id); _check(entity, payload); entity.is_completed = False; entity.completed_at = None; _bump(entity)
        return HandlerResult([EntityRef(kind="task", id=entity.id)], True)


class TaskDeleteOperation(VersionedDailyOperation):
    key = "planning.task.delete"
    input_model = TaskDeleteInput
    versioned_model = Task
    versioned_id_field = "task_id"
    definition = definition(key, "planning", "Gorevi sil", [field("task_id", "Gorev", OperationFieldKind.CHOICE, source="tasks.all"), field("expected_version", "Surum", OperationFieldKind.DURATION)])
    def execute(self, context, payload):
        entity = _owned(context, Task, payload.task_id); _check(entity, payload); entity_id = entity.id; context.session.delete(entity)
        return HandlerResult([EntityRef(kind="task", id=entity_id)], True)


class EventUpdateOperation(VersionedDailyOperation):
    key = "planning.event.update"
    input_model = EventUpdateInput
    versioned_model = Event
    versioned_id_field = "event_id"
    definition = definition(key, "planning", "Etkinligi duzenle", [field("event_id", "Etkinlik", OperationFieldKind.CHOICE, source="events.all"), field("title", "Kisa baslik", OperationFieldKind.SHORT_TEXT, required=False, max_length=160), field("starts_at", "Baslangic", OperationFieldKind.DATETIME, required=False), field("ends_at", "Bitis", OperationFieldKind.DATETIME, required=False), field("is_all_day", "Tum gun", OperationFieldKind.BOOLEAN, required=False), field("is_important", "Onemli", OperationFieldKind.BOOLEAN, required=False), field("expected_version", "Surum", OperationFieldKind.DURATION)])
    def execute(self, context, payload):
        entity = _owned(context, Event, payload.event_id); _check(entity, payload)
        if getattr(payload, "title", None) is not None: entity.title = payload.title
        if payload.starts_at is not None:
            starts_at = _datetime(payload.starts_at)
            delta = _utc(starts_at) - _utc(entity.starts_at)
            _shift_reminders(entity.reminders, entity.starts_at, starts_at)
            if entity.ends_at is not None and payload.ends_at is None:
                entity.ends_at += delta
            entity.starts_at = starts_at
        if getattr(payload, "ends_at", None) is not None: entity.ends_at = _datetime(payload.ends_at)
        if entity.ends_at is not None and _utc(entity.ends_at) < _utc(entity.starts_at):
            raise ValueError("Bitis zamani baslangictan once olamaz.")
        for name in ("is_all_day", "is_important"):
            if getattr(payload, name, None) is not None: setattr(entity, name, getattr(payload, name))
        _bump(entity); return HandlerResult([EntityRef(kind="event", id=entity.id)], True)


class _EventStatusOperation(VersionedDailyOperation):
    completed = True
    def execute(self, context, payload):
        entity = _owned(context, Event, payload.event_id); _check(entity, payload); entity.is_completed = self.completed; _bump(entity)
        return HandlerResult([EntityRef(kind="event", id=entity.id)], True)


class EventCompleteOperation(_EventStatusOperation):
    input_model = EventCompleteInput
    versioned_model = Event
    versioned_id_field = "event_id"
    key = "planning.event.complete"; definition = definition(key, "planning", "Etkinligi tamamla", [field("event_id", "Etkinlik", OperationFieldKind.CHOICE, source="events.pending"), field("expected_version", "Surum", OperationFieldKind.DURATION)])


class EventReopenOperation(_EventStatusOperation):
    input_model = EventReopenInput
    versioned_model = Event
    versioned_id_field = "event_id"
    key = "planning.event.reopen"; completed = False; definition = definition(key, "planning", "Etkinligi yeniden ac", [field("event_id", "Etkinlik", OperationFieldKind.CHOICE, source="events.completed"), field("expected_version", "Surum", OperationFieldKind.DURATION)])


class EventDeleteOperation(VersionedDailyOperation):
    input_model = EventDeleteInput
    versioned_model = Event
    versioned_id_field = "event_id"
    key = "planning.event.delete"; definition = definition(key, "planning", "Etkinligi sil", [field("event_id", "Etkinlik", OperationFieldKind.CHOICE, source="events.all"), field("expected_version", "Surum", OperationFieldKind.DURATION)])
    def execute(self, context, payload):
        entity = _owned(context, Event, payload.event_id); _check(entity, payload); entity_id = entity.id; context.session.delete(entity)
        return HandlerResult([EntityRef(kind="event", id=entity_id)], True)


class RoutineUpdateOperation(VersionedDailyOperation):
    input_model = RoutineUpdateInput
    versioned_model = RecurringEvent
    versioned_id_field = "routine_id"
    key = "planning.routine.update"; definition = definition(key, "planning", "Rutini duzenle", [field("routine_id", "Rutin", OperationFieldKind.CHOICE, source="routines.all"), field("title", "Kisa baslik", OperationFieldKind.SHORT_TEXT, required=False, max_length=160), field("weekdays", "Gunler", OperationFieldKind.CHOICE, required=False, source="weekdays", multiple=True), field("starts_on", "Baslangic", OperationFieldKind.DATE, required=False), field("ends_on", "Bitis", OperationFieldKind.DATE, required=False), field("start_time", "Saat", OperationFieldKind.TIME, required=False), field("end_time", "Bitis saati", OperationFieldKind.TIME, required=False), field("is_all_day", "Tum gun", OperationFieldKind.BOOLEAN, required=False), field("is_important", "Onemli", OperationFieldKind.BOOLEAN, required=False), field("interval_weeks", "Hafta araligi", OperationFieldKind.DURATION, required=False, min_value=1, max_value=12), field("expected_version", "Surum", OperationFieldKind.DURATION)])
    def execute(self, context, payload):
        entity = _owned(context, RecurringEvent, payload.routine_id); _check(entity, payload)
        if getattr(payload, "weekdays", None) is not None: entity.weekdays = _serialize_weekdays(payload.weekdays)
        if getattr(payload, "title", None) is not None: entity.title = payload.title
        if getattr(payload, "starts_on", None) is not None: entity.starts_on = _date(payload.starts_on)
        if getattr(payload, "ends_on", None) is not None: entity.ends_on = _date(payload.ends_on)
        if getattr(payload, "start_time", None) is not None: entity.start_time = _time(payload.start_time)
        if getattr(payload, "end_time", None) is not None: entity.end_time = _time(payload.end_time)
        for name in ("is_all_day", "is_important", "interval_weeks"):
            if getattr(payload, name, None) is not None: setattr(entity, name, getattr(payload, name))
        _bump(entity); return HandlerResult([EntityRef(kind="recurring_event", id=entity.id)], True)


class RoutineToggleOperation(VersionedDailyOperation):
    input_model = RoutineToggleInput
    versioned_model = RecurringEvent
    versioned_id_field = "routine_id"
    key = "planning.routine.toggle"; definition = definition(key, "planning", "Rutini ac veya kapat", [field("routine_id", "Rutin", OperationFieldKind.CHOICE, source="routines.all"), field("expected_version", "Surum", OperationFieldKind.DURATION)])
    def execute(self, context, payload):
        entity = _owned(context, RecurringEvent, payload.routine_id); _check(entity, payload); entity.is_active = not entity.is_active; _bump(entity)
        return HandlerResult([EntityRef(kind="recurring_event", id=entity.id)], True)


class RoutineDeleteOperation(VersionedDailyOperation):
    input_model = RoutineDeleteInput
    versioned_model = RecurringEvent
    versioned_id_field = "routine_id"
    key = "planning.routine.delete"; definition = definition(key, "planning", "Rutini sil", [field("routine_id", "Rutin", OperationFieldKind.CHOICE, source="routines.all"), field("expected_version", "Surum", OperationFieldKind.DURATION)])
    def execute(self, context, payload):
        entity = _owned(context, RecurringEvent, payload.routine_id); _check(entity, payload); entity_id = entity.id; context.session.delete(entity)
        return HandlerResult([EntityRef(kind="recurring_event", id=entity_id)], True)


class MedicationCreateOperation(DailyOperation):
    key = "health.medication.create"
    input_model = MedicationCreateInput
    definition = definition(key, "health", "Ilac olustur", [
        field("name", "Ilac adi", OperationFieldKind.SHORT_TEXT, max_length=120),
        field("dosage", "Doz", OperationFieldKind.MONEY),
        field("dosage_unit", "Birim", OperationFieldKind.CHOICE, source="medication.dosage_units"),
        field("schedule_mode", "Program", OperationFieldKind.CHOICE, source="medication.schedule_modes"),
        field("weekdays", "Gunler", OperationFieldKind.CHOICE, source="weekdays", multiple=True, visible_when={"schedule_mode": "weekdays"}),
        field("interval_days", "Gun araligi", OperationFieldKind.DURATION, required=False, visible_when={"schedule_mode": "interval"}),
        field("dose_times", "Saatler", OperationFieldKind.TIME, multiple=True),
        field("starts_on", "Baslangic", OperationFieldKind.DATE),
    ], steps=3)
    def execute(self, context, payload):
        medication = Medication(
            user_id=context.user_id, device_id=context.device_id, name=payload.name.strip(),
            dosage=f"{payload.dosage} {payload.dosage_unit}", instructions=None,
            schedule_mode=payload.schedule_mode, weekdays=_serialize_weekdays(getattr(payload, "weekdays", [])),
            interval_days=getattr(payload, "interval_days", None), dose_times=_serialize_times([_time(item) for item in payload.dose_times]),
            starts_on=_date(payload.starts_on), ends_on=_date(payload.ends_on) if getattr(payload, "ends_on", None) else None,
            timezone=getattr(payload, "timezone", "Europe/Istanbul"), is_active=True,
        )
        context.session.add(medication); context.session.flush(); return HandlerResult([EntityRef(kind="medication", id=medication.id)], True)


class MedicationUpdateOperation(VersionedDailyOperation):
    input_model = MedicationUpdateInput
    versioned_model = Medication
    versioned_id_field = "medication_id"
    key = "health.medication.update"; definition = definition(key, "health", "Ilaci duzenle", [field("medication_id", "Ilac", OperationFieldKind.CHOICE, source="medications.all"), field("name", "Ilac adi", OperationFieldKind.SHORT_TEXT, required=False, max_length=120), field("dosage", "Doz", OperationFieldKind.MONEY, required=False), field("dosage_unit", "Birim", OperationFieldKind.CHOICE, required=False, source="medication.dosage_units"), field("schedule_mode", "Program", OperationFieldKind.CHOICE, required=False, source="medication.schedule_modes"), field("weekdays", "Gunler", OperationFieldKind.CHOICE, required=False, source="weekdays", multiple=True), field("interval_days", "Gun araligi", OperationFieldKind.DURATION, required=False), field("dose_times", "Saatler", OperationFieldKind.TIME, required=False, multiple=True), field("starts_on", "Baslangic", OperationFieldKind.DATE, required=False), field("ends_on", "Bitis", OperationFieldKind.DATE, required=False), field("expected_version", "Surum", OperationFieldKind.DURATION)])
    def execute(self, context, payload):
        entity = _owned(context, Medication, payload.medication_id); _check(entity, payload)
        if payload.name is not None:
            entity.name = payload.name

        current_amount, separator, current_unit = entity.dosage.rpartition(" ")
        if not separator:
            current_amount, current_unit = entity.dosage, ""
        if payload.dosage is not None or payload.dosage_unit is not None:
            dosage = str(payload.dosage) if payload.dosage is not None else current_amount
            unit = payload.dosage_unit or current_unit
            if not unit:
                raise ValueError("Doz birimi zorunludur.")
            entity.dosage = f"{dosage} {unit}"

        mode = payload.schedule_mode or entity.schedule_mode
        weekdays = payload.weekdays if payload.weekdays is not None else _parse_weekdays(entity.weekdays)
        interval_days = payload.interval_days if payload.interval_days is not None else entity.interval_days
        if mode == "weekdays":
            if not weekdays:
                raise ValueError("Gun programinda gun secimi zorunludur.")
            if any(day < 0 or day > 6 for day in weekdays):
                raise ValueError("Gunler 0 ile 6 arasinda olmali.")
            interval_days = None
        else:
            if interval_days is None:
                raise ValueError("Aralikli program icin gun araligi zorunludur.")
            weekdays = []

        dose_times = payload.dose_times if payload.dose_times is not None else _parse_times(entity.dose_times)
        if not dose_times:
            raise ValueError("En az bir doz saati zorunludur.")
        starts_on = payload.starts_on or entity.starts_on
        ends_on = payload.ends_on if payload.ends_on is not None else entity.ends_on
        if ends_on is not None and ends_on < starts_on:
            raise ValueError("Bitis tarihi baslangictan once olamaz.")

        entity.schedule_mode = mode
        entity.weekdays = _serialize_weekdays(weekdays)
        entity.interval_days = interval_days
        entity.dose_times = _serialize_times([_time(item) for item in dose_times])
        entity.starts_on = starts_on
        entity.ends_on = ends_on
        _bump(entity); return HandlerResult([EntityRef(kind="medication", id=entity.id)], True)


class MedicationToggleOperation(VersionedDailyOperation):
    input_model = MedicationToggleInput
    versioned_model = Medication
    versioned_id_field = "medication_id"
    key = "health.medication.toggle"; definition = definition(key, "health", "Ilaci ac veya kapat", [field("medication_id", "Ilac", OperationFieldKind.CHOICE, source="medications.all"), field("expected_version", "Surum", OperationFieldKind.DURATION)])
    def execute(self, context, payload):
        entity = _owned(context, Medication, payload.medication_id); _check(entity, payload); entity.is_active = not entity.is_active; _bump(entity)
        return HandlerResult([EntityRef(kind="medication", id=entity.id)], True)


class MedicationUndoTakeOperation(DailyOperation):
    input_model = MedicationUndoTakeInput
    key = "health.medication.undo_take"; definition = definition(key, "health", "Ilac almayi geri al", [field("medication_id", "Ilac", OperationFieldKind.CHOICE, source="medications"), field("scheduled_for", "Doz", OperationFieldKind.CHOICE, source="medication_doses.taken")])
    def execute(self, context, payload):
        medication = _owned(context, Medication, payload.medication_id)
        scheduled_for = datetime.fromisoformat(str(payload.scheduled_for)) if isinstance(payload.scheduled_for, str) else payload.scheduled_for
        log = context.session.scalar(select(MedicationDoseLog).where(MedicationDoseLog.medication_id == medication.id, MedicationDoseLog.scheduled_for == scheduled_for))
        if log is None: raise ValueError("Doz kaydi bulunamadi.")
        log_id = log.id; context.session.delete(log); return HandlerResult([EntityRef(kind="medication_dose_log", id=log_id)], True)


DAILY_OPERATIONS = [
    CategoryCreateOperation, CategoryUpdateOperation, CategoryToggleOperation,
    PaymentUpdateOperation, PaymentCancelOperation, TaskUpdateOperation, TaskReopenOperation, TaskDeleteOperation,
    EventUpdateOperation, EventCompleteOperation, EventReopenOperation, EventDeleteOperation,
    RoutineUpdateOperation, RoutineToggleOperation, RoutineDeleteOperation,
    MedicationCreateOperation, MedicationUpdateOperation, MedicationToggleOperation, MedicationUndoTakeOperation,
]
