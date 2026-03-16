"""Schemas for AI-driven action execution."""

from enum import Enum

from pydantic import BaseModel, Field

from app.schemas import AIParseResponse


class AIExecutionStatus(str, Enum):
    COMPLETED = "completed"
    NEEDS_INPUT = "needs_input"
    UNSUPPORTED = "unsupported"


class AIExecutionResponse(BaseModel):
    status: AIExecutionStatus
    parse_result: AIParseResponse
    assistant_message: str
    missing_fields: list[str] = Field(default_factory=list)
    follow_up_question: str | None = None
    transaction_id: int | None = None
    transfer_id: int | None = None
    event_id: int | None = None
    recurring_event_id: int | None = None


class AIClarificationRequest(BaseModel):
    original_message: str = Field(min_length=2, max_length=2000)
    clarification: str = Field(min_length=1, max_length=1000)
    device_id: str | None = Field(default=None, max_length=120)
