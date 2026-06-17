"""Account-to-account transfer model."""

from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin


class Transfer(TimestampMixin, Base):
    """Money moved between owned accounts without creating expense/income."""

    __tablename__ = "transfers"
    __table_args__ = (
        CheckConstraint("source_account_id <> destination_account_id", name="ck_transfers_distinct_accounts"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    source_account_id: Mapped[int] = mapped_column(ForeignKey("accounts.id"), index=True)
    destination_account_id: Mapped[int] = mapped_column(ForeignKey("accounts.id"), index=True)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    description: Mapped[str] = mapped_column(String(160))
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        index=True,
    )

    user = relationship("User", back_populates="transfers")
    source_account = relationship(
        "Account",
        foreign_keys=[source_account_id],
        back_populates="outgoing_transfers",
    )
    destination_account = relationship(
        "Account",
        foreign_keys=[destination_account_id],
        back_populates="incoming_transfers",
    )

    @property
    def source_account_name(self) -> str | None:
        return self.source_account.name if self.source_account is not None else None

    @property
    def destination_account_name(self) -> str | None:
        return self.destination_account.name if self.destination_account is not None else None
