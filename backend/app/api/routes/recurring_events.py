"""Recurring event (routine) endpoints."""

from fastapi import APIRouter, Depends, Header, status
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.db import get_db
from app.models import User
from app.schemas import RecurringEventCreate, RecurringEventRead
from app.services.recurring_events import create_recurring_event, list_recurring_events, read_recurring_rule


router = APIRouter(prefix="/recurring-events", tags=["recurring-events"])


def _device_id(value: str | None) -> str | None:
    return value if isinstance(value, str) else None


@router.post("", response_model=RecurringEventRead, status_code=status.HTTP_201_CREATED)
def create_recurring_event_endpoint(
    payload: RecurringEventCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    payload.device_id = payload.device_id or _device_id(x_device_id)
    # The model stores weekdays as text; serialize through the read schema.
    return read_recurring_rule(create_recurring_event(db, payload, user_id=current_user.id))


@router.get("", response_model=list[RecurringEventRead])
def list_recurring_events_endpoint(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Active routines; the app reads them once to move them on-device."""

    current_user = resolve_route_user(current_user, db)
    return [read_recurring_rule(rule) for rule in list_recurring_events(db, user_id=current_user.id)]
