"""Event and reminder endpoints."""

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.db import get_db
from app.models import User
from app.schemas import CalendarDashboard, EventCreate, EventRead, EventUpdate, ReminderCreate, ReminderRead
from app.services.events import (
    add_reminder,
    build_calendar_dashboard,
    create_event,
    delete_event,
    delete_reminder,
    get_event_or_raise,
    list_events,
    list_reminders,
    update_event,
)


router = APIRouter(prefix="/events", tags=["events"])


def _device_id(value: str | None) -> str | None:
    return value if isinstance(value, str) else None


@router.get("/dashboard", response_model=CalendarDashboard)
def get_calendar_dashboard(
    include_past: bool = Query(default=False),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    return build_calendar_dashboard(
        db,
        user_id=current_user.id,
        include_past=include_past,
    )


@router.get("", response_model=list[EventRead])
def list_events_endpoint(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    return list_events(db, user_id=current_user.id)


@router.get("/{event_id}", response_model=EventRead)
def get_event(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    try:
        return get_event_or_raise(db, event_id, current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("", response_model=EventRead, status_code=status.HTTP_201_CREATED)
def create_event_endpoint(
    payload: EventCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    payload.device_id = payload.device_id or _device_id(x_device_id)
    return create_event(db, payload, user_id=current_user.id)


@router.put("/{event_id}", response_model=EventRead)
def update_event_endpoint(
    event_id: int,
    payload: EventUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    try:
        return update_event(db, event_id, payload, current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete("/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_event_endpoint(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    try:
        delete_event(db, event_id, current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/{event_id}/reminders", response_model=list[ReminderRead])
def list_event_reminders(
    event_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    try:
        return list_reminders(db, event_id, current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post(
    "/{event_id}/reminders",
    response_model=ReminderRead,
    status_code=status.HTTP_201_CREATED,
)
def create_event_reminder(
    event_id: int,
    payload: ReminderCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    try:
        return add_reminder(db, event_id, payload, current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete(
    "/{event_id}/reminders/{reminder_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_event_reminder(
    event_id: int,
    reminder_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    try:
        delete_reminder(db, event_id, reminder_id, current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
