"""Explicit registry for selectable operation handlers."""

from collections.abc import Iterable

from app.operations.base import OperationHandler
from app.schemas import OperationDefinition


class OperationRegistry:
    def __init__(self, handlers: Iterable[OperationHandler]):
        self._handlers: dict[str, OperationHandler] = {}
        for handler in handlers:
            if handler.key in self._handlers:
                raise ValueError(f"Duplicate operation key: {handler.key}")
            self._handlers[handler.key] = handler

    def get(self, key: str) -> OperationHandler:
        try:
            return self._handlers[key]
        except KeyError as exc:
            raise KeyError(f"Unknown operation key: {key}") from exc

    def definitions(self) -> list[OperationDefinition]:
        return [self._handlers[key].definition for key in sorted(self._handlers)]
