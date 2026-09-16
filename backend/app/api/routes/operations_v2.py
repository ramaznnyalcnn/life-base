"""Selection-first operation endpoints for mobile clients."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.db import get_db
from app.models import User
from app.operations.catalog import build_operation_registry
from app.operations.executor import EntityVersionConflictError, OperationConflictError, OperationExecutor
from app.schemas import OperationContextResponse, OperationDefinition, OperationExecuteInput, OperationResult
from app.services.activity_templates import ensure_system_activity_templates
from app.services.operation_context import build_operation_context


router = APIRouter(prefix="/operations", tags=["operations-v2"])
registry = build_operation_registry()
executor = OperationExecutor(registry)


@router.get("/catalog", response_model=list[OperationDefinition])
def get_catalog() -> list[OperationDefinition]:
    return registry.definitions()


@router.get("/context", response_model=OperationContextResponse)
def get_context(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    return build_operation_context(db, user_id=current_user.id)


@router.post("/execute", response_model=OperationResult)
def execute_operation(
    payload: OperationExecuteInput,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    ensure_system_activity_templates(db)
    try:
        return executor.execute(
            db,
            payload,
            user_id=current_user.id,
            device_id=x_device_id,
            now=datetime.now(timezone.utc),
        )
    except EntityVersionConflictError as exc:
        raise HTTPException(status_code=409, detail={"message": str(exc), "current": exc.current}) from exc
    except OperationConflictError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    except (KeyError, ValueError) as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
