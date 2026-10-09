"""Generic per-user document store backing local-first client data."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import JSON, BigInteger, Boolean, DateTime, ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class SyncDocument(Base):
    """One client-owned record (event, medication, dose log...) as JSON.

    The server never interprets ``body``; it only orders changes (``seq``) and
    resolves conflicts by the client's ``client_updated_at`` (last writer wins).
    """

    __tablename__ = "sync_documents"
    __table_args__ = (
        UniqueConstraint("user_id", "collection", "doc_id", name="uq_sync_documents_user_collection_doc"),
        Index("ix_sync_documents_user_seq", "user_id", "seq"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    collection: Mapped[str] = mapped_column(String(40))
    doc_id: Mapped[str] = mapped_column(String(64))
    body: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    deleted: Mapped[bool] = mapped_column(Boolean, default=False)
    client_updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    seq: Mapped[int] = mapped_column(BigInteger)
    server_updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )


class SyncCursor(Base):
    """Per-user monotonic change counter; every stored change gets the next value."""

    __tablename__ = "sync_cursors"

    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), primary_key=True)
    last_seq: Mapped[int] = mapped_column(BigInteger, default=0)
