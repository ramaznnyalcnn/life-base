"""Last-writer-wins document sync for local-first client data.

Rules:
- A change replaces the stored copy only if its ``updated_at`` is newer.
- Deletion is final: once a document is a tombstone, later edits from a stale
  device are refused instead of resurrecting it.
- Every stored change gets the space's next ``seq``; clients pull "since seq".

A space is one user's own documents or a household's shared ones; the rules
are the same, only the table and the counter differ.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone

from sqlalchemy import select, update
from sqlalchemy.dialects import postgresql, sqlite
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.sync import SharedCursor, SharedDocument, SyncCursor, SyncDocument
from app.schemas.sync import SyncChange, SyncDocumentRead


@dataclass(frozen=True, slots=True)
class Space:
    document: type
    cursor: type
    owner: str
    owner_id: int
    author_id: int | None = None

    def doc_owner(self):
        return getattr(self.document, self.owner)

    def cursor_owner(self):
        return getattr(self.cursor, self.owner)


def personal(user_id: int) -> Space:
    return Space(SyncDocument, SyncCursor, "user_id", user_id)


def household_space(household_id: int, author_id: int) -> Space:
    return Space(SharedDocument, SharedCursor, "household_id", household_id, author_id)


@dataclass
class PushResult:
    applied: list[str] = field(default_factory=list)
    stale: list[SyncDocumentRead] = field(default_factory=list)
    cursor: int = 0


def _utc(value: datetime) -> datetime:
    # SQLite drops tzinfo on the way back; everything is stored as UTC.
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def to_read(document) -> SyncDocumentRead:
    return SyncDocumentRead(
        collection=document.collection,
        id=document.doc_id,
        updated_at=_utc(document.client_updated_at),
        deleted=document.deleted,
        body=document.body,
        seq=document.seq,
    )


def _space(owner: int | Space) -> Space:
    return owner if isinstance(owner, Space) else personal(owner)


def current_cursor(db: Session, owner: int | Space) -> int:
    space = _space(owner)
    return db.scalar(select(space.cursor.last_seq).where(space.cursor_owner() == space.owner_id)) or 0


def _next_seq(db: Session, space: Space) -> int:
    """Atomically take the space's next sequence number (row-locked in Postgres)."""

    bump = (
        update(space.cursor)
        .where(space.cursor_owner() == space.owner_id)
        .values(last_seq=space.cursor.last_seq + 1)
        .returning(space.cursor.last_seq)
    )
    value = db.execute(bump, execution_options={"synchronize_session": False}).scalar_one_or_none()
    if value is not None:
        return value
    dialect = postgresql if db.get_bind().dialect.name == "postgresql" else sqlite
    db.execute(dialect.insert(space.cursor).values({space.owner: space.owner_id, "last_seq": 0}).on_conflict_do_nothing())
    return db.execute(bump, execution_options={"synchronize_session": False}).scalar_one()


def _locked(db: Session, space: Space, change: SyncChange):
    model = space.document
    return db.scalar(
        select(model)
        .where(space.doc_owner() == space.owner_id, model.collection == change.collection, model.doc_id == change.id)
        .with_for_update()
    )


def _apply(space: Space, document, change: SyncChange, seq: int) -> None:
    document.body = change.body
    document.deleted = change.deleted
    document.client_updated_at = change.updated_at
    document.seq = seq
    if space.author_id is not None:
        document.updated_by_user_id = space.author_id


def push_changes(db: Session, owner: int | Space, changes: list[SyncChange]) -> PushResult:
    space = _space(owner)
    result = PushResult()
    for change in changes:
        key = f"{change.collection}/{change.id}"
        existing = _locked(db, space, change)
        if existing is None:
            try:
                with db.begin_nested():
                    document = space.document(**{space.owner: space.owner_id}, collection=change.collection, doc_id=change.id)
                    _apply(space, document, change, _next_seq(db, space))
                    db.add(document)
                result.applied.append(key)
                continue
            except IntegrityError:
                # Another request created it first; fall through to compare.
                existing = _locked(db, space, change)

        stored_at = _utc(existing.client_updated_at)
        if existing.deleted:
            if change.deleted:
                result.applied.append(key)
            else:
                result.stale.append(to_read(existing))
        elif change.updated_at > stored_at:
            _apply(space, existing, change, _next_seq(db, space))
            result.applied.append(key)
        elif change.updated_at == stored_at and change.deleted == existing.deleted and change.body == existing.body:
            result.applied.append(key)  # Same change sent again (retry).
        else:
            result.stale.append(to_read(existing))
    db.flush()
    result.cursor = current_cursor(db, space)
    return result


def pull_changes(db: Session, owner: int | Space, since: int, limit: int) -> tuple[list[SyncDocumentRead], int, bool]:
    space = _space(owner)
    model = space.document
    rows = db.scalars(
        select(model)
        .where(space.doc_owner() == space.owner_id, model.seq > since)
        .order_by(model.seq)
        .limit(limit + 1)
    ).all()
    has_more = len(rows) > limit
    page = rows[:limit]
    cursor = page[-1].seq if has_more else max(current_cursor(db, space), since)
    return [to_read(row) for row in page], cursor, has_more
