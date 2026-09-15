"""Unified agenda endpoints for Android and calendar synchronization."""

from datetime import date, datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.db import get_db
from app.models import User
from app.schemas.agenda import AgendaRange, AgendaToday
from app.services.agenda import build_agenda_range, build_today_agenda


router = APIRouter(prefix="/agenda", tags=["agenda-v2"])


def _today(timezone_name: str) -> date:
    try:
        return datetime.now(ZoneInfo(timezone_name)).date()
    except ZoneInfoNotFoundError as exc:
        raise HTTPException(status_code=400, detail="Timezone gecersiz.") from exc


@router.get("/today", response_model=AgendaToday)
def get_today_agenda(
    value: date | None = Query(default=None, alias="date"),
    timezone_name: str = Query(default="Europe/Istanbul", alias="timezone"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    try:
        return build_today_agenda(
            db, user_id=current_user.id, value=value or _today(timezone_name), timezone_name=timezone_name
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/range", response_model=AgendaRange)
def get_agenda_range(
    from_date: date = Query(alias="from"),
    to_date: date = Query(alias="to"),
    timezone_name: str = Query(default="Europe/Istanbul", alias="timezone"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    try:
        return build_agenda_range(
            db, user_id=current_user.id, from_date=from_date, to_date=to_date, timezone_name=timezone_name
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
