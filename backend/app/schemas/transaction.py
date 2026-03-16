"""Pydantic schemas for transactions and summaries."""

from datetime import date, datetime
from decimal import Decimal
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field

from app.models import TransactionType


class SummaryPeriod(str, Enum):
    WEEK = "week"
    MONTH = "month"
    ALL = "all"


class TransactionCreate(BaseModel):
    account_id: int
    category_id: int | None = None
    category_name: str | None = Field(default=None, min_length=2, max_length=80)
    type: TransactionType
    amount: Decimal = Field(gt=0)
    description: str = Field(min_length=2, max_length=160)
    note: str | None = None
    occurred_at: datetime | None = None


class TransactionUpdate(BaseModel):
    account_id: int | None = None
    category_id: int | None = None
    category_name: str | None = Field(default=None, min_length=2, max_length=80)
    type: TransactionType | None = None
    amount: Decimal | None = Field(default=None, gt=0)
    description: str | None = Field(default=None, min_length=2, max_length=160)
    note: str | None = None
    occurred_at: datetime | None = None


class TransactionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    account_id: int
    category_id: int | None
    category_name: str | None = None
    type: TransactionType
    amount: Decimal
    description: str
    note: str | None
    occurred_at: datetime
    statement_month: date | None


class TransactionSummary(BaseModel):
    period: SummaryPeriod
    period_start: datetime | None
    period_end: datetime | None
    total_income: Decimal
    total_expense: Decimal
    total_payments: Decimal
    net_flow: Decimal
    transaction_count: int
