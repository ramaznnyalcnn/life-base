"""Notification and push subscription endpoints."""

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.core.config import get_settings
from app.db import get_db
from app.models import User
from app.schemas import (
    PushDispatchResult,
    PushMessageRequest,
    PushPublicConfig,
    PushSubscriptionCreate,
    PushSubscriptionDelete,
    PushSubscriptionRead,
)
from app.services.notifications import (
    dispatch_due_reminders,
    deactivate_push_subscription,
    list_push_subscriptions,
    send_push_message,
    upsert_push_subscription,
)


router = APIRouter(prefix="/notifications", tags=["notifications"])


def _device_id(value: str | None) -> str | None:
    return value if isinstance(value, str) else None


@router.get("/config", response_model=PushPublicConfig)
def get_push_public_config():
    settings = get_settings()
    return PushPublicConfig(
        enabled=settings.enable_web_push and bool(settings.vapid_public_key),
        vapid_public_key=settings.vapid_public_key,
    )


@router.get("/subscriptions", response_model=list[PushSubscriptionRead])
def list_subscriptions(
    db: Session = Depends(get_db),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    return list_push_subscriptions(db, current_user.id, device_id=_device_id(x_device_id))


@router.post(
    "/subscriptions",
    response_model=PushSubscriptionRead,
    status_code=status.HTTP_201_CREATED,
)
def create_or_update_subscription(
    payload: PushSubscriptionCreate,
    db: Session = Depends(get_db),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    return upsert_push_subscription(
        db,
        payload,
        current_user.id,
        device_id=_device_id(x_device_id),
    )


@router.delete("/subscriptions", status_code=status.HTTP_204_NO_CONTENT)
def delete_subscription(
    payload: PushSubscriptionDelete,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    deactivate_push_subscription(db, payload.endpoint, user_id=current_user.id)


@router.post("/test", response_model=PushDispatchResult)
def send_test_push(
    payload: PushMessageRequest,
    db: Session = Depends(get_db),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    try:
        return send_push_message(
            db,
            payload,
            user_id=current_user.id,
            device_id=_device_id(x_device_id),
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/dispatch-reminders", response_model=PushDispatchResult)
def dispatch_reminders(
    db: Session = Depends(get_db),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    try:
        return dispatch_due_reminders(
            db,
            user_id=current_user.id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
