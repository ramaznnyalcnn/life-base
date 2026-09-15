"""Composition root for all supported operation handlers."""

from app.operations.finance import (
    ExpenseRecordOperation,
    IncomeRecordOperation,
    PaymentCompleteOperation,
    PaymentScheduleOperation,
    TransferRecordOperation,
)
from app.operations.health import MedicationScheduleOperation, MedicationSnoozeOperation, MedicationTakeOperation
from app.operations.planning import EventCreateOperation, RoutineCreateOperation, TaskCompleteOperation, TaskCreateOperation
from app.operations.registry import OperationRegistry


def build_operation_registry() -> OperationRegistry:
    return OperationRegistry([
        ExpenseRecordOperation(),
        IncomeRecordOperation(),
        TransferRecordOperation(),
        PaymentScheduleOperation(),
        PaymentCompleteOperation(),
        TaskCreateOperation(),
        TaskCompleteOperation(),
        EventCreateOperation(),
        RoutineCreateOperation(),
        MedicationScheduleOperation(),
        MedicationTakeOperation(),
        MedicationSnoozeOperation(),
    ])
