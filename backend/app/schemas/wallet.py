"""Schemas for wallet dashboard responses."""

from decimal import Decimal

from pydantic import BaseModel, ConfigDict

from app.models import AccountType
from app.schemas.transaction import TransactionSummary


class WalletAccountCard(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    type: AccountType
    currency: str
    balance: Decimal
    credit_limit: Decimal | None
    issuer: str | None
    statement_day: int | None
    due_day: int | None
    is_active: bool
    available_credit: Decimal | None
    used_credit: Decimal | None
    utilization_ratio: Decimal | None


class WalletSummary(BaseModel):
    liquid_balance: Decimal
    total_card_available: Decimal
    total_card_used: Decimal
    total_credit_limit: Decimal
    net_worth: Decimal
    previous_month_net: Decimal
    previous_year_net: Decimal
    active_account_count: int
    active_card_count: int
    weekly_flow: TransactionSummary
    monthly_flow: TransactionSummary
    accounts: list[WalletAccountCard]
