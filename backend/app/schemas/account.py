"""Pydantic schemas for account payloads."""

from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.models import AccountType


class AccountBase(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    type: AccountType
    currency: str = Field(default="TRY", min_length=3, max_length=3)
    balance: Decimal = Field(default=Decimal("0.00"), ge=0)
    credit_limit: Decimal | None = Field(default=None, ge=0)
    statement_day: int | None = Field(default=None, ge=1, le=31)
    due_day: int | None = Field(default=None, ge=1, le=31)
    issuer: str | None = Field(default=None, max_length=120)
    is_active: bool = True

    @model_validator(mode="after")
    def validate_credit_card_fields(self):
        if self.type == AccountType.CREDIT_CARD and self.credit_limit is None:
            raise ValueError("Kredi karti icin credit_limit zorunludur.")
        return self


class AccountCreate(AccountBase):
    pass


class AccountUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    currency: str | None = Field(default=None, min_length=3, max_length=3)
    balance: Decimal | None = Field(default=None, ge=0)
    credit_limit: Decimal | None = Field(default=None, ge=0)
    statement_day: int | None = Field(default=None, ge=1, le=31)
    due_day: int | None = Field(default=None, ge=1, le=31)
    issuer: str | None = Field(default=None, max_length=120)
    is_active: bool | None = None


class AccountRead(AccountBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
