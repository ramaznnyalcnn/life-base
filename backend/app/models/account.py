"""Account and category models."""

from __future__ import annotations

from decimal import Decimal
from enum import Enum

from sqlalchemy import Boolean, Enum as SqlEnum, ForeignKey, Numeric, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, EntityVersionMixin, TimestampMixin


def enum_values(enum_cls: type[Enum]) -> list[str]:
    return [member.value for member in enum_cls]


class AccountType(str, Enum):
    CASH = "cash"
    BANK = "bank"
    CREDIT_CARD = "credit_card"


class CategoryType(str, Enum):
    INCOME = "income"
    EXPENSE = "expense"


class Account(EntityVersionMixin, TimestampMixin, Base):
    """Financial accounts and cards."""

    __tablename__ = "accounts"
    __table_args__ = (UniqueConstraint("user_id", "name", name="uq_accounts_user_id_name"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    name: Mapped[str] = mapped_column(String(120), index=True)
    type: Mapped[AccountType] = mapped_column(
        SqlEnum(AccountType, values_callable=enum_values, name="accounttype"),
        index=True,
    )
    currency: Mapped[str] = mapped_column(String(3), default="TRY")
    balance: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0.00"))
    credit_limit: Mapped[Decimal | None] = mapped_column(Numeric(12, 2), nullable=True)
    statement_day: Mapped[int | None] = mapped_column(nullable=True)
    due_day: Mapped[int | None] = mapped_column(nullable=True)
    issuer: Mapped[str | None] = mapped_column(String(120), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    # Wallet v3. Card balances are minus the debt (0 = nothing owed), so
    # available credit is credit_limit + balance.
    client_id: Mapped[str | None] = mapped_column(String(64), unique=True, nullable=True)
    household_id: Mapped[int | None] = mapped_column(ForeignKey("households.id"), nullable=True, index=True)
    visibility: Mapped[str] = mapped_column(String(10), default="personal")
    opening_balance: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0.00"))
    last4: Mapped[str | None] = mapped_column(String(4), nullable=True)
    network: Mapped[str | None] = mapped_column(String(12), nullable=True)
    color: Mapped[str | None] = mapped_column(String(20), nullable=True)
    iban: Mapped[str | None] = mapped_column(String(34), nullable=True)

    user = relationship("User", back_populates="accounts")
    transactions = relationship("Transaction", back_populates="account")
    outgoing_transfers = relationship(
        "Transfer",
        foreign_keys="Transfer.source_account_id",
        back_populates="source_account",
    )
    incoming_transfers = relationship(
        "Transfer",
        foreign_keys="Transfer.destination_account_id",
        back_populates="destination_account",
    )


class Category(EntityVersionMixin, TimestampMixin, Base):
    """Transaction categories."""

    __tablename__ = "categories"
    __table_args__ = (UniqueConstraint("user_id", "name", name="uq_categories_user_id_name"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    name: Mapped[str] = mapped_column(String(80), index=True)
    type: Mapped[CategoryType] = mapped_column(
        SqlEnum(CategoryType, values_callable=enum_values, name="categorytype"),
        index=True,
    )
    is_system: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)

    user = relationship("User", back_populates="categories")
    transactions = relationship("Transaction", back_populates="category")
