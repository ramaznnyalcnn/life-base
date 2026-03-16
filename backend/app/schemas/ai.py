"""Schemas for AI parse requests and responses."""

from datetime import datetime
from decimal import Decimal
from enum import Enum

from pydantic import BaseModel, Field


class AIAction(str, Enum):
    EXPENSE = "expense"
    INCOME = "income"
    PAYMENT = "payment"
    EVENT = "event"
    SUMMARY = "summary"
    UNKNOWN = "unknown"


class SummaryRange(str, Enum):
    TODAY = "today"
    WEEK = "week"
    MONTH = "month"
    ALL = "all"


class SummaryMetric(str, Enum):
    EXPENSE = "expense"
    CASHFLOW = "cashflow"
    BALANCE = "balance"
    STATEMENT = "statement"


class AIParseRequest(BaseModel):
    message: str = Field(min_length=2, max_length=2000)
    current_time: datetime | None = None
    device_id: str | None = Field(default=None, max_length=120)


class AITransactionPayload(BaseModel):
    amount: Decimal | None = None
    account_name: str | None = None
    source_account_name: str | None = None
    destination_account_name: str | None = None
    category_name: str | None = None
    description: str | None = None
    occurred_at: datetime | None = None


class AIEventPayload(BaseModel):
    title: str | None = None
    description: str | None = None
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    is_all_day: bool = False
    is_recurring: bool = False
    recurrence_days: list[int] = Field(default_factory=list)


class AISummaryPayload(BaseModel):
    range: SummaryRange = SummaryRange.MONTH
    metric: SummaryMetric = SummaryMetric.EXPENSE
    account_name: str | None = None


class AIParseResponse(BaseModel):
    action: AIAction
    confidence: float = Field(ge=0, le=1)
    missing_fields: list[str] = Field(default_factory=list)
    assistant_message: str
    transaction: AITransactionPayload | None = None
    event: AIEventPayload | None = None
    summary: AISummaryPayload | None = None
