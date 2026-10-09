"""Operation idempotency journal and agenda revision models."""

from __future__ import annotations

from sqlalchemy import BigInteger, ForeignKey, JSON, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base, TimestampMixin


class OperationExecution(TimestampMixin, Base):
    __tablename__ = "operation_executions"
    __table_args__ = (
        UniqueConstraint("user_id", "request_id", name="uq_operation_executions_user_request_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    request_id: Mapped[str] = mapped_column(String(36), index=True)
    operation_key: Mapped[str] = mapped_column(String(120), index=True)
    request_hash: Mapped[str] = mapped_column(String(64))
    response_payload: Mapped[dict] = mapped_column(JSON)

    user = relationship("User", back_populates="operation_executions")


class AgendaRevision(TimestampMixin, Base):
    __tablename__ = "agenda_revisions"

    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), primary_key=True)
    version: Mapped[int] = mapped_column(BigInteger, default=0)

    user = relationship("User", back_populates="agenda_revision")
