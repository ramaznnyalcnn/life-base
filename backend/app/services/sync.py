"""Last-writer-wins document sync for local-first client data.

Rules:
- A change replaces the stored copy only if its ``updated_at`` is newer.
- Deletion is final: once a document is a tombstone, later edits from a stale
  device are refused instead of resurrecting it.
- Every stored change gets the user's next ``seq``; clients pull "since seq".
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone

from sqlalchemy import select, update
from sqlalchemy.dialects import postgresql, sqlite
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.sync import SyncCursor, SyncDocument
from app.schemas.sync import SyncChange, SyncDocumentRead


@dataclass
class PushResult:
    applied: list[str] = field(default_factory=list)
    stale: list[SyncDocumentRead] = field(default_factory=list)
    cursor: int = 0


def _utc(value: datetime) -> datetime:
    # SQLite drops tzinfo on the way back; everything is stored as UTC.
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def to_read(document: SyncDocument) -> SyncDocumentRead:
    return SyncDocumentRead(
        collection=document.collection,
        id=document.doc_id,
        updated_at=_utc(document.client_updated_at),
        deleted=document.deleted,
        body=document.body,
        seq=document.seq,
    )


def current_cursor(db: Session, user_id: int) -> int:
    return db.scalar(select(SyncCursor.last_seq).where(SyncCursor.user_id == user_id)) or 0


def _next_seq(db: Session, user_id: int) -> int:
    """Atomically take the user's next sequence number (row-locked in Postgres)."""

    bump = (
        update(SyncCursor)
        .where(SyncCursor.user_id == user_id)
        .values(last_seq=SyncCursor.last_seq + 1)
        .returning(SyncCursor.last_seq)
    )
    value = db.execute(bump, execution_options={"synchronize_session": False}).scalar_one_or_none()
    if value is not None:
        return value
    dialect = postgresql if db.get_bind().dialect.name == "postgresql" else sqlite
    db.execute(dialect.insert(SyncCursor).values(user_id=user_id, last_seq=0).on_conflict_do_nothing())
    return db.execute(bump, execution_options={"synchronize_session": False}).scalar_one()


def _locked(db: Session, user_id: int, change: SyncChange) -> SyncDocument | None:
    return db.scalar(
        select(SyncDocument)
        .where(
            SyncDocument.user_id == user_id,
            SyncDocument.collection == change.collection,
            SyncDocument.doc_id == change.id,
        )
        .with_for_update()
    )


def _apply(document: SyncDocument, change: SyncChange, seq: int) -> None:
    document.body = change.body
    document.deleted = change.deleted
    document.client_updated_at = change.updated_at
    document.seq = seq


def push_changes(db: Session, user_id: int, changes: list[SyncChange]) -> PushResult:
    result = PushResult()
    for change in changes:
        key = f"{change.collection}/{change.id}"
        existing = _locked(db, user_id, change)
        if existing is None:
            try:
                with db.begin_nested():
                    document = SyncDocument(user_id=user_id, collection=change.collection, doc_id=change.id)
                    _apply(document, change, _next_seq(db, user_id))
                    db.add(document)
                result.applied.append(key)
                continue
            except IntegrityError:
                # Another request created it first; fall through to compare.
                existing = _locked(db, user_id, change)

        stored_at = _utc(existing.client_updated_at)
        if existing.deleted:
            if change.deleted:
                result.applied.append(key)
            else:
                result.stale.append(to_read(existing))
        elif change.updated_at > stored_at:
            _apply(existing, change, _next_seq(db, user_id))
            result.applied.append(key)
        elif change.updated_at == stored_at and change.deleted == existing.deleted and change.body == existing.body:
            result.applied.append(key)  # Same change sent again (retry).
        else:
            result.stale.append(to_read(existing))
    db.flush()
    result.cursor = current_cursor(db, user_id)
    return result


def pull_changes(db: Session, user_id: int, since: int, limit: int) -> tuple[list[SyncDocumentRead], int, bool]:
    rows = db.scalars(
        select(SyncDocument)
        .where(SyncDocument.user_id == user_id, SyncDocument.seq > since)
        .order_by(SyncDocument.seq)
        .limit(limit + 1)
    ).all()
    has_more = len(rows) > limit
    page = rows[:limit]
    cursor = page[-1].seq if has_more else max(current_cursor(db, user_id), since)
    return [to_read(row) for row in page], cursor, has_more
