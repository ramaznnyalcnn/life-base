"""Base types for class-based application operations."""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime
from typing import Generic, TypeVar

from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.schemas import EntityRef, OperationDefinition


InputT = TypeVar("InputT", bound=BaseModel)


@dataclass(frozen=True, slots=True)
class OperationContext:
    session: Session
    user_id: int
    device_id: str | None
    now: datetime


@dataclass(frozen=True, slots=True)
class HandlerResult:
    entities: list[EntityRef]
    affects_agenda: bool = False


class OperationHandler(ABC, Generic[InputT]):
    key: str
    input_model: type[InputT]
    definition: OperationDefinition

    @abstractmethod
    def execute(self, context: OperationContext, payload: InputT) -> HandlerResult:
        """Run the operation without committing the database transaction."""
