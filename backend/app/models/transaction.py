"""Transaction model."""

from __future__ import annotations

from datetime import date, datetime, timezone
from decimal import Decimal
from enum import Enum

from sqlalchemy import Date, DateTime, Enum as SqlEnum, ForeignKey, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, EntityVersionMixin, TimestampMixin


def enum_values(enum_cls: type[Enum]) -> list[str]:
    return [member.value for member in enum_cls]


class TransactionType(str, Enum):
    EXPENSE = "expense"
    INCOME = "income"
    PAYMENT = "payment"


class Transaction(EntityVersionMixin, TimestampMixin, Base):
    """Money movement records."""

    __tablename__ = "transactions"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    account_id: Mapped[int] = mapped_column(ForeignKey("accounts.id"), index=True)
    category_id: Mapped[int | None] = mapped_column(ForeignKey("categories.id"), nullable=True)
    type: Mapped[TransactionType] = mapped_column(
        SqlEnum(TransactionType, values_callable=enum_values, name="transactiontype"),
        index=True,
    )
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    description: Mapped[str] = mapped_column(String(160))
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        index=True,
    )
    statement_month: Mapped[date | None] = mapped_column(Date, nullable=True, index=True)
    client_id: Mapped[str | None] = mapped_column(String(64), unique=True, nullable=True)
    created_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    # Installment parts share a group (the first part's client id), 1-based.
    installment_group: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    installment_index: Mapped[int | None] = mapped_column(nullable=True)
    installment_count: Mapped[int | None] = mapped_column(nullable=True)

    user = relationship("User", back_populates="transactions", foreign_keys=[user_id])
    account = relationship("Account", back_populates="transactions")
    category = relationship("Category", back_populates="transactions")

    @property
    def category_name(self) -> str | None:
        return self.category.name if self.category is not None else None
