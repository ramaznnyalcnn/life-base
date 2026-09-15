"""Typed payloads accepted by the structured operation endpoint."""

from __future__ import annotations

from datetime import date, datetime, time
from decimal import Decimal
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


class OperationInput(BaseModel):
    request_id: UUID
    operation_key: str


class ExpenseRecordInput(OperationInput):
    operation_key: Literal["finance.expense.record"] = "finance.expense.record"
    account_id: int
    category_id: int
    amount: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    occurred_at: datetime | None = None


class IncomeRecordInput(OperationInput):
    operation_key: Literal["finance.income.record"] = "finance.income.record"
    account_id: int
    category_id: int
    amount: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    occurred_at: datetime | None = None


class TransferRecordInput(OperationInput):
    operation_key: Literal["finance.transfer.record"] = "finance.transfer.record"
    source_account_id: int
    destination_account_id: int
    amount: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    occurred_at: datetime | None = None


class PaymentScheduleInput(OperationInput):
    operation_key: Literal["finance.payment.schedule"] = "finance.payment.schedule"
    source_account_id: int
    destination_account_id: int
    amount: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    due_at: datetime
    reminder_offsets_minutes: list[int] = Field(default_factory=lambda: [1440, 180, 60])


class PaymentCompleteInput(OperationInput):
    operation_key: Literal["finance.payment.complete"] = "finance.payment.complete"
    scheduled_payment_id: int


class TemplateInput(OperationInput):
    template_id: int
    custom_title: str | None = Field(default=None, min_length=1, max_length=160)


class TaskCreateInput(TemplateInput):
    operation_key: Literal["planning.task.create"] = "planning.task.create"
    due_on: date
    scheduled_at: datetime | None = None
    is_important: bool = False
    reminder_offsets_minutes: list[int] = Field(default_factory=list)


class TaskCompleteInput(OperationInput):
    operation_key: Literal["planning.task.complete"] = "planning.task.complete"
    task_id: int


class EventCreateInput(TemplateInput):
    operation_key: Literal["planning.event.create"] = "planning.event.create"
    starts_at: datetime
    ends_at: datetime | None = None
    is_all_day: bool = False
    is_important: bool = False
    reminder_offsets_minutes: list[int] = Field(default_factory=lambda: [1440, 180, 60])

    @model_validator(mode="after")
    def validate_range(self):
        if self.ends_at is not None and self.ends_at < self.starts_at:
            raise ValueError("Bitis zamani baslangictan once olamaz.")
        return self


class RoutineCreateInput(TemplateInput):
    operation_key: Literal["planning.routine.create"] = "planning.routine.create"
    weekdays: list[int] = Field(min_length=1)
    starts_on: date
    ends_on: date | None = None
    start_time: time | None = None
    end_time: time | None = None
    is_all_day: bool = False
    is_important: bool = False
    interval_weeks: int = Field(default=1, ge=1, le=12)

    @model_validator(mode="after")
    def validate_rule(self):
        if any(day < 0 or day > 6 for day in self.weekdays):
            raise ValueError("Gunler 0 ile 6 arasinda olmali.")
        if self.ends_on is not None and self.ends_on < self.starts_on:
            raise ValueError("Bitis tarihi baslangictan once olamaz.")
        if not self.is_all_day and self.start_time and self.end_time and self.end_time <= self.start_time:
            raise ValueError("Bitis saati baslangictan sonra olmali.")
        return self


class MedicationScheduleInput(OperationInput):
    operation_key: Literal["health.medication.schedule"] = "health.medication.schedule"
    medication_id: int
    schedule_mode: Literal["weekdays", "interval"] = "weekdays"
    weekdays: list[int] = Field(default_factory=list)
    interval_days: int | None = Field(default=None, ge=1, le=365)
    dose_times: list[time] = Field(min_length=1)
    starts_on: date
    ends_on: date | None = None
    timezone: str = Field(default="Europe/Istanbul", min_length=1, max_length=64)

    @model_validator(mode="after")
    def validate_schedule(self):
        if self.schedule_mode == "weekdays" and (not self.weekdays or self.interval_days is not None):
            raise ValueError("Gun programinda gun secimi zorunludur.")
        if self.schedule_mode == "interval" and (self.weekdays or self.interval_days is None):
            raise ValueError("Aralikli program gecersiz.")
        if any(day < 0 or day > 6 for day in self.weekdays):
            raise ValueError("Gunler 0 ile 6 arasinda olmali.")
        if self.ends_on is not None and self.ends_on < self.starts_on:
            raise ValueError("Bitis tarihi baslangictan once olamaz.")
        return self


class MedicationTakeInput(OperationInput):
    operation_key: Literal["health.medication.take"] = "health.medication.take"
    medication_id: int
    scheduled_for: datetime
    taken_at: datetime | None = None


class MedicationSnoozeInput(OperationInput):
    operation_key: Literal["health.medication.snooze"] = "health.medication.snooze"
    medication_id: int
    scheduled_for: datetime
    snooze_minutes: int = Field(default=10, ge=5, le=120)


OperationExecuteInput = Annotated[
    ExpenseRecordInput
    | IncomeRecordInput
    | TransferRecordInput
    | PaymentScheduleInput
    | PaymentCompleteInput
    | TaskCreateInput
    | TaskCompleteInput
    | EventCreateInput
    | RoutineCreateInput
    | MedicationScheduleInput
    | MedicationTakeInput
    | MedicationSnoozeInput,
    Field(discriminator="operation_key"),
]
