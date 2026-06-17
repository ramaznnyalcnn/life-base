"""Schemas for credit card statement summaries."""

from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel


class CardStatementSummary(BaseModel):
    account_id: int
    account_name: str
    issuer: str | None
    statement_month: date
    period_start: date
    period_end: date
    due_date: date | None
    auto_resets_at: datetime
    statement_amount: Decimal
    payment_activity: Decimal
    transaction_count: int
