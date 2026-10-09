"""Typed payloads accepted by the structured operation endpoint."""

from __future__ import annotations

from datetime import date, datetime, time
from decimal import Decimal
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator


class OperationInput(BaseModel):
    model_config = ConfigDict(extra="allow")
    request_id: UUID
    operation_key: str


class VersionedOperationInput(OperationInput):
    expected_version: int = Field(ge=1)


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


class PaymentCompleteInput(VersionedOperationInput):
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


class TaskCompleteInput(VersionedOperationInput):
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


class MedicationScheduleInput(VersionedOperationInput):
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


class AccountCreateInput(OperationInput):
    operation_key: Literal["finance.account.create"] = "finance.account.create"
    name: str = Field(min_length=1, max_length=120)
    type: Literal["cash", "bank", "credit_card"]
    currency: Literal["TRY", "USD", "EUR"]


class AccountUpdateInput(VersionedOperationInput):
    operation_key: Literal["finance.account.update"] = "finance.account.update"
    account_id: int
    name: str | None = Field(default=None, min_length=1, max_length=120)
    currency: Literal["TRY", "USD", "EUR"] | None = None


class AccountToggleInput(VersionedOperationInput):
    operation_key: Literal["finance.account.toggle"] = "finance.account.toggle"
    account_id: int


class CategoryCreateInput(OperationInput):
    operation_key: Literal["finance.category.create"] = "finance.category.create"
    name: str = Field(min_length=1, max_length=80)
    type: Literal["expense", "income"]


class CategoryUpdateInput(VersionedOperationInput):
    operation_key: Literal["finance.category.update"] = "finance.category.update"
    category_id: int
    name: str = Field(min_length=1, max_length=80)


class CategoryToggleInput(VersionedOperationInput):
    operation_key: Literal["finance.category.toggle"] = "finance.category.toggle"
    category_id: int


class TransactionUpdateInput(VersionedOperationInput):
    operation_key: Literal["finance.transaction.update"] = "finance.transaction.update"
    transaction_id: int
    account_id: int | None = None
    category_id: int | None = None
    amount: Decimal | None = Field(default=None, gt=0, max_digits=12, decimal_places=2)
    occurred_at: datetime | None = None


class TransactionDeleteInput(VersionedOperationInput):
    operation_key: Literal["finance.transaction.delete"] = "finance.transaction.delete"
    transaction_id: int


class TransferUpdateDailyInput(VersionedOperationInput):
    operation_key: Literal["finance.transfer.update"] = "finance.transfer.update"
    transfer_id: int
    source_account_id: int | None = None
    destination_account_id: int | None = None
    amount: Decimal | None = Field(default=None, gt=0, max_digits=12, decimal_places=2)
    occurred_at: datetime | None = None


class TransferDeleteInput(VersionedOperationInput):
    operation_key: Literal["finance.transfer.delete"] = "finance.transfer.delete"
    transfer_id: int


class PaymentUpdateInput(VersionedOperationInput):
    operation_key: Literal["finance.payment.update"] = "finance.payment.update"
    scheduled_payment_id: int
    source_account_id: int | None = None
    destination_account_id: int | None = None
    amount: Decimal | None = Field(default=None, gt=0, max_digits=12, decimal_places=2)
    due_at: datetime | None = None


class PaymentCancelInput(VersionedOperationInput):
    operation_key: Literal["finance.payment.cancel"] = "finance.payment.cancel"
    scheduled_payment_id: int


class TaskUpdateInput(VersionedOperationInput):
    operation_key: Literal["planning.task.update"] = "planning.task.update"
    task_id: int
    title: str | None = Field(default=None, min_length=1, max_length=160)
    due_on: date | None = None
    scheduled_at: datetime | None = None
    is_important: bool | None = None


class TaskReopenInput(VersionedOperationInput):
    operation_key: Literal["planning.task.reopen"] = "planning.task.reopen"
    task_id: int


class TaskDeleteInput(VersionedOperationInput):
    operation_key: Literal["planning.task.delete"] = "planning.task.delete"
    task_id: int


class EventUpdateInput(VersionedOperationInput):
    operation_key: Literal["planning.event.update"] = "planning.event.update"
    event_id: int
    title: str | None = Field(default=None, min_length=1, max_length=160)
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    is_all_day: bool | None = None
    is_important: bool | None = None


class EventCompleteInput(VersionedOperationInput):
    operation_key: Literal["planning.event.complete"] = "planning.event.complete"
    event_id: int


class EventReopenInput(VersionedOperationInput):
    operation_key: Literal["planning.event.reopen"] = "planning.event.reopen"
    event_id: int


class EventDeleteInput(VersionedOperationInput):
    operation_key: Literal["planning.event.delete"] = "planning.event.delete"
    event_id: int


class RoutineUpdateInput(VersionedOperationInput):
    operation_key: Literal["planning.routine.update"] = "planning.routine.update"
    routine_id: int
    title: str | None = Field(default=None, min_length=1, max_length=160)
    weekdays: list[int] | None = None
    starts_on: date | None = None
    ends_on: date | None = None
    start_time: time | None = None
    end_time: time | None = None
    is_all_day: bool | None = None
    is_important: bool | None = None
    interval_weeks: int | None = Field(default=None, ge=1, le=12)

    @model_validator(mode="after")
    def validate_weekdays(self):
        if self.weekdays is not None and any(day < 0 or day > 6 for day in self.weekdays):
            raise ValueError("Gunler 0 ile 6 arasinda olmali.")
        return self


class RoutineToggleInput(VersionedOperationInput):
    operation_key: Literal["planning.routine.toggle"] = "planning.routine.toggle"
    routine_id: int


class RoutineDeleteInput(VersionedOperationInput):
    operation_key: Literal["planning.routine.delete"] = "planning.routine.delete"
    routine_id: int


class MedicationCreateInput(OperationInput):
    operation_key: Literal["health.medication.create"] = "health.medication.create"
    name: str = Field(min_length=1, max_length=120)
    dosage: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    dosage_unit: Literal["mg", "ml", "tablet", "IU"]
    schedule_mode: Literal["weekdays", "interval"]
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


class MedicationUpdateInput(VersionedOperationInput):
    operation_key: Literal["health.medication.update"] = "health.medication.update"
    medication_id: int
    name: str | None = Field(default=None, min_length=1, max_length=120)
    dosage: Decimal | None = Field(default=None, gt=0, max_digits=12, decimal_places=2)
    dosage_unit: Literal["mg", "ml", "tablet", "IU"] | None = None
    schedule_mode: Literal["weekdays", "interval"] | None = None
    weekdays: list[int] | None = None
    interval_days: int | None = Field(default=None, ge=1, le=365)
    dose_times: list[time] | None = None
    starts_on: date | None = None
    ends_on: date | None = None


class MedicationToggleInput(VersionedOperationInput):
    operation_key: Literal["health.medication.toggle"] = "health.medication.toggle"
    medication_id: int


class MedicationUndoTakeInput(OperationInput):
    operation_key: Literal["health.medication.undo_take"] = "health.medication.undo_take"
    medication_id: int
    scheduled_for: datetime


OperationExecuteInput = OperationInput
