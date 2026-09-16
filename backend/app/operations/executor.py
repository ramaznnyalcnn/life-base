"""Transactional, idempotent execution for structured operations."""

from __future__ import annotations

from datetime import datetime, timezone
from hashlib import sha256
import json
from uuid import UUID

from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session
from sqlalchemy.orm.exc import StaleDataError

from app.models import AgendaRevision, OperationExecution
from app.operations.base import OperationContext
from app.operations.registry import OperationRegistry
from app.schemas import OperationResult


class OperationConflictError(ValueError):
    """Raised when a request id is reused for different operation content."""


class EntityVersionConflictError(OperationConflictError):
    """Raised when an offline edit targets an older entity revision."""

    def __init__(self, current: dict[str, object]):
        super().__init__("Kayit baska bir cihazda degistirildi.")
        self.current = current


class OperationExecutor:
    def __init__(self, registry: OperationRegistry):
        self.registry = registry

    @staticmethod
    def _request_hash(payload: BaseModel) -> str:
        canonical = json.dumps(
            payload.model_dump(mode="json"),
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        )
        return sha256(canonical.encode("utf-8")).hexdigest()

    def execute(
        self,
        session: Session,
        payload: BaseModel,
        *,
        user_id: int,
        device_id: str | None = None,
        now: datetime | None = None,
    ) -> OperationResult:
        operation_key = str(payload.operation_key)
        request_id = UUID(str(payload.request_id))
        request_hash = self._request_hash(payload)
        existing = session.scalar(
            select(OperationExecution).where(
                OperationExecution.user_id == user_id,
                OperationExecution.request_id == str(request_id),
            )
        )
        if existing is not None:
            if existing.operation_key != operation_key or existing.request_hash != request_hash:
                raise OperationConflictError("request_id farkli bir istek icin daha once kullanildi.")
            result = OperationResult.model_validate(existing.response_payload)
            return result.model_copy(update={"replayed": True})

        handler = self.registry.get(operation_key)
        typed_payload = handler.input_model.model_validate(payload.model_dump())
        current_time = now or datetime.now(timezone.utc)

        try:
            handler_result = handler.execute(
                OperationContext(
                    session=session,
                    user_id=user_id,
                    device_id=device_id,
                    now=current_time,
                ),
                typed_payload,
            )
            revision = session.get(AgendaRevision, user_id)
            if revision is None:
                revision = AgendaRevision(user_id=user_id, version=0)
                session.add(revision)
                session.flush()
            if handler_result.affects_agenda:
                revision.version += 1

            result = OperationResult(
                request_id=request_id,
                operation_key=operation_key,
                entities=handler_result.entities,
                agenda_version=revision.version,
            )
            session.add(
                OperationExecution(
                    user_id=user_id,
                    request_id=str(request_id),
                    operation_key=operation_key,
                    request_hash=request_hash,
                    response_payload=result.model_dump(mode="json"),
                )
            )
            session.commit()
            return result
        except StaleDataError as exc:
            session.rollback()
            snapshot = handler.current_snapshot(
                OperationContext(
                    session=session,
                    user_id=user_id,
                    device_id=device_id,
                    now=current_time,
                ),
                typed_payload,
            )
            raise EntityVersionConflictError(snapshot) from exc
        except Exception:
            session.rollback()
            raise
