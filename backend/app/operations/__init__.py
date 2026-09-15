"""Class-based application operation kernel."""

from app.operations.base import HandlerResult, OperationContext, OperationHandler
from app.operations.executor import OperationConflictError, OperationExecutor
from app.operations.registry import OperationRegistry

__all__ = [
    "HandlerResult",
    "OperationContext",
    "OperationHandler",
    "OperationConflictError",
    "OperationExecutor",
    "OperationRegistry",
]
