"""Medication reminder endpoints."""

from datetime import date

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.db import get_db
from app.models import User
from app.schemas import (
    MedicationCreate,
    MedicationDashboard,
    MedicationDoseItem,
    MedicationDoseSnooze,
    MedicationDoseTaken,
    MedicationRead,
    MedicationUpdate,
)
from app.services.medications import (
    build_medication_dashboard,
    build_medication_schedule,
    build_notification_schedule,
    create_medication,
    deactivate_medication,
    list_medications,
    mark_medication_dose_taken,
    read_medication,
    snooze_medication_dose,
    update_medication,
)


router = APIRouter(prefix="/medications", tags=["medications"])


def _device_id(value: str | None) -> str | None:
    return value if isinstance(value, str) else None


@router.get("", response_model=list[MedicationRead])
def list_medications_endpoint(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    return [read_medication(medication) for medication in list_medications(db, user_id=current_user.id)]


@router.post("", response_model=MedicationRead, status_code=status.HTTP_201_CREATED)
def create_medication_endpoint(
    payload: MedicationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    payload.device_id = payload.device_id or _device_id(x_device_id)
    return read_medication(create_medication(db, payload, user_id=current_user.id))


@router.put("/{medication_id}", response_model=MedicationRead)
def update_medication_endpoint(
    medication_id: int,
    payload: MedicationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    try:
        return read_medication(
            update_medication(
                db,
                medication_id,
                payload,
                user_id=current_user.id,
            )
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete("/{medication_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_medication_endpoint(
    medication_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    try:
        deactivate_medication(db, medication_id, user_id=current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/dashboard", response_model=MedicationDashboard)
def get_medication_dashboard(
    days: int = Query(default=30, ge=0, le=90),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    return build_medication_dashboard(
        db,
        user_id=current_user.id,
        days=days,
    )


@router.get("/notification-schedule", response_model=list[MedicationDoseItem])
def get_medication_notification_schedule(
    days: int = Query(default=30, ge=0, le=90),
    limit: int = Query(default=128, ge=1, le=256),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    return build_notification_schedule(
        db,
        user_id=current_user.id,
        days=days,
        limit=limit,
    )


@router.get("/schedule", response_model=list[MedicationDoseItem])
def get_medication_schedule(
    from_date: date = Query(...),
    to_date: date = Query(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    try:
        return build_medication_schedule(
            db,
            user_id=current_user.id,
            from_date=from_date,
            to_date=to_date,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/{medication_id}/doses/taken", response_model=MedicationDoseItem)
def mark_medication_dose_taken_endpoint(
    medication_id: int,
    payload: MedicationDoseTaken,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    try:
        return mark_medication_dose_taken(
            db,
            medication_id,
            payload,
            user_id=current_user.id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/{medication_id}/doses/snooze", response_model=MedicationDoseItem)
def snooze_medication_dose_endpoint(
    medication_id: int,
    payload: MedicationDoseSnooze,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    x_device_id: str | None = Header(default=None, alias="X-Device-Id"),
):
    current_user = resolve_route_user(current_user, db)
    try:
        return snooze_medication_dose(
            db,
            medication_id,
            payload,
            user_id=current_user.id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
