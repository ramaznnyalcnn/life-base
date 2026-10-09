"""Payloads of the wallet operations sent by the mobile outbox.

Records are named by client-generated ids, so a client can create an account
offline and add expenses to it before the server has seen either.
"""

from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, Field, field_validator

from app.schemas.operation_inputs import OperationInput


ClientId = Field(min_length=1, max_length=64)
Money = Field(gt=0, max_digits=12, decimal_places=2)


class WalletAccountFields(BaseModel):
    id: str = ClientId
    name: str = Field(min_length=1, max_length=120)
    type: Literal["cash", "bank", "credit_card"]
    bank: str | None = Field(default=None, max_length=120)
    visibility: Literal["personal", "shared"] = "personal"
    opening_balance: Decimal = Field(default=Decimal("0"), max_digits=12, decimal_places=2)
    credit_limit: Decimal | None = Field(default=None, ge=0, max_digits=12, decimal_places=2)
    statement_day: int | None = Field(default=None, ge=1, le=31)
    due_day: int | None = Field(default=None, ge=1, le=31)
    last4: str | None = Field(default=None, pattern=r"^\d{4}$")
    network: Literal["visa", "mastercard", "troy", "amex"] | None = None
    color: str | None = Field(default=None, max_length=20)
    iban: str | None = Field(default=None, max_length=34)

    @field_validator("name")
    @classmethod
    def _name(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("Hesap adi gerekli.")
        return value.strip()

    @field_validator("bank", "iban")
    @classmethod
    def _optional(cls, value: str | None) -> str | None:
        return (value or "").strip() or None


class AccountSaveInput(OperationInput):
    operation_key: Literal["wallet.account.save"] = "wallet.account.save"
    account: WalletAccountFields
    expected_version: int | None = Field(default=None, ge=1)


class AccountArchiveInput(OperationInput):
    operation_key: Literal["wallet.account.archive"] = "wallet.account.archive"
    account_id: str = ClientId
    archived: bool
    expected_version: int | None = Field(default=None, ge=1)


class TransactionSaveInput(OperationInput):
    operation_key: Literal["wallet.transaction.save"] = "wallet.transaction.save"
    id: str = ClientId
    account_id: str = ClientId
    kind: Literal["expense", "income"]
    category_id: int | None = None
    amount: Decimal = Money
    occurred_at: datetime
    note: str | None = Field(default=None, max_length=500)
    installments: int = Field(default=1, ge=1, le=36)
    expected_version: int | None = Field(default=None, ge=1)


class TransactionDeleteInput(OperationInput):
    operation_key: Literal["wallet.transaction.delete"] = "wallet.transaction.delete"
    id: str = ClientId
    expected_version: int | None = Field(default=None, ge=1)


class TransferSaveInput(OperationInput):
    operation_key: Literal["wallet.transfer.save"] = "wallet.transfer.save"
    id: str = ClientId
    from_account_id: str = ClientId
    to_account_id: str = ClientId
    amount: Decimal = Money
    occurred_at: datetime
    note: str | None = Field(default=None, max_length=500)
    expected_version: int | None = Field(default=None, ge=1)


class TransferDeleteInput(OperationInput):
    operation_key: Literal["wallet.transfer.delete"] = "wallet.transfer.delete"
    id: str = ClientId
    expected_version: int | None = Field(default=None, ge=1)


class StatementMarkInput(OperationInput):
    operation_key: Literal["wallet.statement.mark"] = "wallet.statement.mark"
    account_id: str = ClientId
    month: date
    # None returns the statement to the automatic rule.
    paid: bool | None
