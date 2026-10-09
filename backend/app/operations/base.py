"""Base types for class-based application operations."""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime
from typing import Generic, TypeVar

from fastapi.encoders import jsonable_encoder
from pydantic import BaseModel
from sqlalchemy import select
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
    versioned_model: type | None = None
    versioned_id_field: str | None = None

    def current_snapshot(self, context: OperationContext, payload: InputT) -> dict[str, object]:
        """Reload the entity used for an optimistic-concurrency conflict."""
        if self.versioned_model is None or self.versioned_id_field is None:
            return {}
        entity_id = getattr(payload, self.versioned_id_field)
        entity = context.session.scalar(
            select(self.versioned_model).where(
                self.versioned_model.id == entity_id,
                self.versioned_model.user_id == context.user_id,
            )
        )
        if entity is None:
            return {}
        return jsonable_encoder({
            column.name: getattr(entity, column.name)
            for column in entity.__table__.columns
            if column.name not in {"created_at", "updated_at"}
        })

    @abstractmethod
    def execute(self, context: OperationContext, payload: InputT) -> HandlerResult:
        """Run the operation without committing the database transaction."""
