"""Build selection values required by mobile operation forms."""

from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import (
    Account,
    ActivityTemplateKind,
    AgendaRevision,
    Category,
    CategoryType,
    Medication,
    ScheduledPayment,
    Task,
)
from app.schemas import ChoiceOption, OperationContextResponse
from app.services.activity_templates import ensure_system_activity_templates, list_activity_templates
from app.services.bootstrap import ensure_default_cash_account, ensure_default_categories
from app.services.medications import build_medication_schedule


WEEKDAYS = ("Pazartesi", "Sali", "Carsamba", "Persembe", "Cuma", "Cumartesi", "Pazar")


def _options(rows, label):
    return [ChoiceOption(value=row.id, label=label(row)) for row in rows]


def build_operation_context(session: Session, *, user_id: int, now: datetime | None = None) -> OperationContextResponse:
    ensure_default_categories(session)
    ensure_default_cash_account(session, user_id)
    ensure_system_activity_templates(session)
    current_time = now or datetime.now(timezone.utc)

    accounts = list(session.scalars(select(Account).where(Account.user_id == user_id, Account.is_active.is_(True)).order_by(Account.name)).all())
    expense_categories = list(session.scalars(select(Category).where(Category.type == CategoryType.EXPENSE, (Category.user_id == user_id) | (Category.user_id.is_(None))).order_by(Category.name)).all())
    income_categories = list(session.scalars(select(Category).where(Category.type == CategoryType.INCOME, (Category.user_id == user_id) | (Category.user_id.is_(None))).order_by(Category.name)).all())
    tasks = list(session.scalars(select(Task).where(Task.user_id == user_id, Task.is_completed.is_(False)).order_by(Task.due_on, Task.id)).all())
    payments = list(session.scalars(select(ScheduledPayment).where(ScheduledPayment.user_id == user_id, ScheduledPayment.is_completed.is_(False)).order_by(ScheduledPayment.due_at, ScheduledPayment.id)).all())
    medications = list(session.scalars(select(Medication).where(Medication.user_id == user_id, Medication.is_active.is_(True)).order_by(Medication.name)).all())
    local_today = current_time.astimezone(ZoneInfo("Europe/Istanbul")).date()
    doses = build_medication_schedule(
        session,
        from_date=local_today,
        to_date=local_today + timedelta(days=30),
        user_id=user_id,
        now=current_time,
    )
    pending_doses = [dose for dose in doses if dose.status != "taken"]
    revision = session.get(AgendaRevision, user_id)

    sources: dict[str, list[ChoiceOption]] = {
        "accounts": [ChoiceOption(value=item.id, label=item.name, metadata={"currency": item.currency, "type": item.type.value}) for item in accounts],
        "categories.expense": _options(expense_categories, lambda item: item.name),
        "categories.income": _options(income_categories, lambda item: item.name),
        "tasks.pending": _options(tasks, lambda item: item.title),
        "scheduled_payments.pending": [ChoiceOption(value=item.id, label=f"{item.amount} {item.source_account.name} → {item.destination_account.name}") for item in payments],
        "medications": _options(medications, lambda item: f"{item.name} · {item.dosage}"),
        "medication_doses.pending": [ChoiceOption(value=item.scheduled_for.isoformat(), label=f"{item.medication_name} · {item.notify_at.isoformat()}", metadata={"medication_id": item.medication_id}) for item in pending_doses],
        "medication.schedule_modes": [ChoiceOption(value="weekdays", label="Haftanin gunleri"), ChoiceOption(value="interval", label="Gun araligi")],
        "weekdays": [ChoiceOption(value=index, label=label) for index, label in enumerate(WEEKDAYS)],
    }
    for kind in ActivityTemplateKind:
        templates = list_activity_templates(session, user_id=user_id, kind=kind)
        sources[f"activity_templates.{kind.value}"] = _options(templates, lambda item: item.label)

    return OperationContextResponse(agenda_version=revision.version if revision else 0, sources=sources)
