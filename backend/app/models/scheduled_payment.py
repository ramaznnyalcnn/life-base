"""Planned card or account payment persistence model."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin


class ScheduledPayment(TimestampMixin, Base):
    """Payment reminder that changes balances only after confirmation."""

    __tablename__ = "scheduled_payments"
    __table_args__ = (
        CheckConstraint(
            "source_account_id <> destination_account_id",
            name="ck_scheduled_payments_distinct_accounts",
        ),
        CheckConstraint("amount > 0", name="ck_scheduled_payments_positive_amount"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    device_id: Mapped[str | None] = mapped_column(String(120), nullable=True, index=True)
    source_account_id: Mapped[int] = mapped_column(ForeignKey("accounts.id"), index=True)
    destination_account_id: Mapped[int] = mapped_column(ForeignKey("accounts.id"), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    due_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    completed_transfer_id: Mapped[int | None] = mapped_column(
        ForeignKey("transfers.id"), nullable=True, unique=True
    )

    user = relationship("User", back_populates="scheduled_payments")
    source_account = relationship("Account", foreign_keys=[source_account_id])
    destination_account = relationship("Account", foreign_keys=[destination_account_id])
    completed_transfer = relationship("Transfer", foreign_keys=[completed_transfer_id])
    reminders = relationship(
        "Reminder",
        back_populates="scheduled_payment",
        cascade="all, delete-orphan",
        order_by="Reminder.remind_at",
    )
