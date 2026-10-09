"""Composition root for all supported operation handlers."""

from app.operations.finance import PaymentCompleteOperation, PaymentScheduleOperation
from app.operations.health import MedicationScheduleOperation, MedicationSnoozeOperation, MedicationTakeOperation
from app.operations.planning import EventCreateOperation, RoutineCreateOperation, TaskCompleteOperation, TaskCreateOperation
from app.operations.registry import OperationRegistry
from app.operations.daily import DAILY_OPERATIONS
from app.operations.wallet import WALLET_OPERATIONS


def build_operation_registry() -> OperationRegistry:
    return OperationRegistry([
        PaymentScheduleOperation(),
        PaymentCompleteOperation(),
        TaskCreateOperation(),
        TaskCompleteOperation(),
        EventCreateOperation(),
        RoutineCreateOperation(),
        MedicationScheduleOperation(),
        MedicationTakeOperation(),
        MedicationSnoozeOperation(),
        *(operation() for operation in DAILY_OPERATIONS),
        *(operation() for operation in WALLET_OPERATIONS),
    ])
