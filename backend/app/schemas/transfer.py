"""Schemas for account transfers."""

from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class TransferCreate(BaseModel):
    source_account_id: int
    destination_account_id: int
    amount: Decimal = Field(gt=0)
    description: str = Field(min_length=2, max_length=160)
    note: str | None = None
    occurred_at: datetime | None = None


class TransferUpdate(BaseModel):
    source_account_id: int | None = None
    destination_account_id: int | None = None
    amount: Decimal | None = Field(default=None, gt=0)
    description: str | None = Field(default=None, min_length=2, max_length=160)
    note: str | None = None
    occurred_at: datetime | None = None


class TransferRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    source_account_id: int
    destination_account_id: int
    source_account_name: str | None = None
    destination_account_name: str | None = None
    amount: Decimal
    description: str
    note: str | None
    occurred_at: datetime
