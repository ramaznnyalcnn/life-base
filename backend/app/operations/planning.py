"""Class-based planning operations."""

from datetime import datetime, time, timedelta, timezone

from sqlalchemy import select

from app.models import ActivityTemplate, ActivityTemplateKind, Event, RecurringEvent, Reminder, Task
from app.operations.base import HandlerResult, OperationContext, OperationHandler
from app.operations.definitions import definition, field
from app.operations.daily import _bump, _check
from app.schemas import EntityRef, OperationFieldKind
from app.schemas.operation_inputs import EventCreateInput, RoutineCreateInput, TaskCompleteInput, TaskCreateInput


def _template(context: OperationContext, template_id: int, kind: ActivityTemplateKind) -> ActivityTemplate:
    template = context.session.scalar(
        select(ActivityTemplate).where(
            ActivityTemplate.id == template_id,
            ActivityTemplate.kind == kind,
            ActivityTemplate.is_active.is_(True),
            (ActivityTemplate.user_id == context.user_id) | (ActivityTemplate.user_id.is_(None)),
        )
    )
    if template is None:
        raise ValueError("Etkinlik sablonu bulunamadi.")
    return template


def _title(template: ActivityTemplate, custom_title: str | None) -> str:
    return custom_title.strip() if custom_title and custom_title.strip() else template.label


def _reminders(source, at: datetime, offsets: list[int]) -> list[Reminder]:
    return [
        Reminder(**source, remind_at=at - timedelta(minutes=minutes))
        for minutes in sorted(set(offsets), reverse=True)
        if minutes > 0
    ]


class TaskCreateOperation(OperationHandler[TaskCreateInput]):
    key = "planning.task.create"
    input_model = TaskCreateInput
    definition = definition(key, "planning", "Gorev olustur", [
        field("template_id", "Gorev", OperationFieldKind.CHOICE, source="activity_templates.task"),
        field("custom_title", "Kisa baslik", OperationFieldKind.SHORT_TEXT, required=False, max_length=160),
        field("due_on", "Gun", OperationFieldKind.DATE),
        field("scheduled_at", "Saat", OperationFieldKind.DATETIME, required=False),
        field("is_important", "Onemli", OperationFieldKind.BOOLEAN, required=False),
        field("reminder_offsets_minutes", "Hatirlatmalar", OperationFieldKind.DURATION, required=False),
    ])

    def execute(self, context: OperationContext, payload: TaskCreateInput) -> HandlerResult:
        template = _template(context, payload.template_id, ActivityTemplateKind.TASK)
        task = Task(
            user_id=context.user_id,
            device_id=context.device_id,
            template_id=template.id,
            title=_title(template, payload.custom_title),
            due_on=payload.due_on,
            scheduled_at=payload.scheduled_at,
            is_important=payload.is_important,
        )
        context.session.add(task)
        context.session.flush()
        if payload.scheduled_at:
            context.session.add_all(_reminders({"task_id": task.id}, payload.scheduled_at, payload.reminder_offsets_minutes))
        return HandlerResult(entities=[EntityRef(kind="task", id=task.id)], affects_agenda=True)


class TaskCompleteOperation(OperationHandler[TaskCompleteInput]):
    key = "planning.task.complete"
    input_model = TaskCompleteInput
    versioned_model = Task
    versioned_id_field = "task_id"
    definition = definition(key, "planning", "Gorevi tamamla", [
        field("task_id", "Gorev", OperationFieldKind.CHOICE, source="tasks.pending"),
        field("expected_version", "Surum", OperationFieldKind.DURATION),
    ])

    def execute(self, context: OperationContext, payload: TaskCompleteInput) -> HandlerResult:
        task = context.session.scalar(select(Task).where(Task.id == payload.task_id, Task.user_id == context.user_id))
        if task is None:
            raise ValueError("Gorev bulunamadi.")
        _check(task, payload)
        task.is_completed = True
        task.completed_at = context.now
        _bump(task)
        return HandlerResult(entities=[EntityRef(kind="task", id=task.id)], affects_agenda=True)


class EventCreateOperation(OperationHandler[EventCreateInput]):
    key = "planning.event.create"
    input_model = EventCreateInput
    definition = definition(key, "planning", "Etkinlik olustur", [
        field("template_id", "Etkinlik", OperationFieldKind.CHOICE, source="activity_templates.event"),
        field("custom_title", "Kisa baslik", OperationFieldKind.SHORT_TEXT, required=False, max_length=160),
        field("starts_at", "Baslangic", OperationFieldKind.DATETIME),
        field("ends_at", "Bitis", OperationFieldKind.DATETIME, required=False),
        field("is_all_day", "Tum gun", OperationFieldKind.BOOLEAN, required=False),
        field("is_important", "Onemli", OperationFieldKind.BOOLEAN, required=False),
        field("reminder_offsets_minutes", "Hatirlatmalar", OperationFieldKind.DURATION, required=False),
    ])

    def execute(self, context: OperationContext, payload: EventCreateInput) -> HandlerResult:
        template = _template(context, payload.template_id, ActivityTemplateKind.EVENT)
        starts_at = payload.starts_at
        if payload.is_all_day:
            starts_at = datetime.combine(payload.starts_at.date(), time(hour=12), tzinfo=timezone.utc)
        event = Event(
            user_id=context.user_id,
            device_id=context.device_id,
            template_id=template.id,
            title=_title(template, payload.custom_title),
            starts_at=starts_at,
            ends_at=None if payload.is_all_day else payload.ends_at,
            is_all_day=payload.is_all_day,
            is_important=payload.is_important,
        )
        context.session.add(event)
        context.session.flush()
        context.session.add_all(_reminders({"event_id": event.id}, starts_at, payload.reminder_offsets_minutes))
        return HandlerResult(entities=[EntityRef(kind="event", id=event.id)], affects_agenda=True)


class RoutineCreateOperation(OperationHandler[RoutineCreateInput]):
    key = "planning.routine.create"
    input_model = RoutineCreateInput
    definition = definition(key, "planning", "Rutin olustur", [
        field("template_id", "Rutin", OperationFieldKind.CHOICE, source="activity_templates.routine"),
        field("custom_title", "Kisa baslik", OperationFieldKind.SHORT_TEXT, required=False, max_length=160),
        field("weekdays", "Gunler", OperationFieldKind.CHOICE, source="weekdays", multiple=True),
        field("starts_on", "Baslangic gunu", OperationFieldKind.DATE),
        field("ends_on", "Bitis gunu", OperationFieldKind.DATE, required=False),
        field("start_time", "Saat", OperationFieldKind.TIME, required=False),
        field("is_all_day", "Tum gun", OperationFieldKind.BOOLEAN, required=False),
    ])

    def execute(self, context: OperationContext, payload: RoutineCreateInput) -> HandlerResult:
        template = _template(context, payload.template_id, ActivityTemplateKind.ROUTINE)
        rule = RecurringEvent(
            user_id=context.user_id,
            device_id=context.device_id,
            template_id=template.id,
            title=_title(template, payload.custom_title),
            weekdays=",".join(str(day) for day in sorted(set(payload.weekdays))),
            starts_on=payload.starts_on,
            ends_on=payload.ends_on,
            start_time=None if payload.is_all_day else payload.start_time,
            end_time=None if payload.is_all_day else payload.end_time,
            is_all_day=payload.is_all_day,
            is_important=payload.is_important,
            is_active=True,
            interval_weeks=payload.interval_weeks,
        )
        context.session.add(rule)
        context.session.flush()
        return HandlerResult(entities=[EntityRef(kind="recurring_event", id=rule.id)], affects_agenda=True)
