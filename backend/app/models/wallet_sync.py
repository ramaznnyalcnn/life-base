"""Change feed and statement marks for the server-authoritative wallet."""

from __future__ import annotations

from datetime import date, datetime, timezone

from sqlalchemy import BigInteger, Boolean, Date, DateTime, ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, EntityVersionMixin, TimestampMixin


class WalletChange(Base):
    """One changed wallet record, numbered within its scope.

    Scope is ``h:<household id>`` for household members and ``u:<user id>``
    otherwise; clients pull "since seq" and get the current state of every
    changed record they may see (or a tombstone).
    """

    __tablename__ = "wallet_changes"
    __table_args__ = (Index("ix_wallet_changes_scope_seq", "scope", "seq"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    scope: Mapped[str] = mapped_column(String(24))
    seq: Mapped[int] = mapped_column(BigInteger)
    kind: Mapped[str] = mapped_column(String(20))
    client_id: Mapped[str] = mapped_column(String(64))
    deleted: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class WalletCursor(Base):
    """Per-scope counter; taken with UPDATE … RETURNING so seq order is commit order."""

    __tablename__ = "wallet_cursors"

    scope: Mapped[str] = mapped_column(String(24), primary_key=True)
    last_seq: Mapped[int] = mapped_column(BigInteger, default=0)


class StatementMark(EntityVersionMixin, TimestampMixin, Base):
    """Manual "paid" override for one card statement (month bucket)."""

    __tablename__ = "statement_marks"
    __table_args__ = (UniqueConstraint("account_id", "statement_month", name="uq_statement_marks_account_month"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    account_id: Mapped[int] = mapped_column(ForeignKey("accounts.id"), index=True)
    statement_month: Mapped[date] = mapped_column(Date)
    paid: Mapped[bool] = mapped_column(Boolean)
    updated_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
