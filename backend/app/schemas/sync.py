"""Schemas for the local-first document sync API."""

from __future__ import annotations

import json
from datetime import datetime, timezone

from pydantic import BaseModel, Field, field_validator, model_validator

SYNC_COLLECTIONS = frozenset({"events", "medications", "dose_logs", "notes", "note_items"})
MAX_BODY_BYTES = 64 * 1024
MAX_PUSH_CHANGES = 500


class SyncChange(BaseModel):
    collection: str
    id: str = Field(min_length=1, max_length=64)
    updated_at: datetime
    deleted: bool = False
    body: dict | None = None

    @field_validator("collection")
    @classmethod
    def known_collection(cls, value: str) -> str:
        if value not in SYNC_COLLECTIONS:
            raise ValueError(f"Bilinmeyen koleksiyon: {value}")
        return value

    @field_validator("updated_at")
    @classmethod
    def aware_utc(cls, value: datetime) -> datetime:
        if value.tzinfo is None:
            raise ValueError("updated_at saat dilimi icermeli.")
        return value.astimezone(timezone.utc)

    @model_validator(mode="after")
    def body_matches_state(self) -> "SyncChange":
        if self.deleted:
            self.body = None
        elif self.body is None:
            raise ValueError("Silinmemis kayit icin body zorunlu.")
        elif len(json.dumps(self.body, ensure_ascii=False).encode()) > MAX_BODY_BYTES:
            raise ValueError("Kayit cok buyuk.")
        return self


class SyncPushRequest(BaseModel):
    changes: list[SyncChange] = Field(max_length=MAX_PUSH_CHANGES)


class SyncDocumentRead(BaseModel):
    collection: str
    id: str
    updated_at: datetime
    deleted: bool
    body: dict | None
    seq: int


class SyncPushResponse(BaseModel):
    applied: list[str]
    """``collection/id`` of changes the server now holds."""
    stale: list[SyncDocumentRead]
    """Server copies that won over the pushed change; the client adopts them."""
    cursor: int


class SyncPullResponse(BaseModel):
    changes: list[SyncDocumentRead]
    cursor: int
    has_more: bool
