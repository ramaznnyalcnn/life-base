"""Public contracts for selectable operation definitions and results."""

from enum import Enum
from uuid import UUID

from pydantic import BaseModel, Field


class OperationFieldKind(str, Enum):
    CHOICE = "choice"
    MONEY = "money"
    DATE = "date"
    DATETIME = "datetime"
    TIME = "time"
    DURATION = "duration"
    BOOLEAN = "boolean"
    SHORT_TEXT = "short_text"


class OperationFieldDefinition(BaseModel):
    key: str
    label: str
    kind: OperationFieldKind
    required: bool = True
    option_source: str | None = None
    min_value: int | None = None
    max_value: int | None = None
    max_length: int | None = None
    multiple: bool = False
    visible_when: dict[str, object] | None = None


class OperationDefinition(BaseModel):
    key: str
    group: str
    label: str
    version: int = Field(ge=1)
    surface: str = "wizard"
    steps: int = Field(default=2, ge=1)
    fields: list[OperationFieldDefinition] = Field(default_factory=list)


class EntityRef(BaseModel):
    kind: str
    id: int | str
    # The record's entity_version after the write (lets an outbox chain edits).
    version: int | None = None


class OperationResult(BaseModel):
    request_id: UUID
    operation_key: str
    replayed: bool = False
    entities: list[EntityRef] = Field(default_factory=list)
    agenda_version: int


class ChoiceOption(BaseModel):
    value: int | str
    label: str
    enabled: bool = True
    metadata: dict[str, object] = Field(default_factory=dict)


class OperationContextResponse(BaseModel):
    agenda_version: int = 0
    sources: dict[str, list[ChoiceOption]] = Field(default_factory=dict)
