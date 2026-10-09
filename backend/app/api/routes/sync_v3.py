"""Local-first document sync: clients push their changes and pull everyone else's."""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.db import get_db
from app.models import User
from app.schemas.sync import SyncPullResponse, SyncPushRequest, SyncPushResponse
from app.services.sync import pull_changes, push_changes


router = APIRouter(prefix="/sync", tags=["sync-v3"])


@router.post("/push", response_model=SyncPushResponse)
def push(
    payload: SyncPushRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    result = push_changes(db, current_user.id, payload.changes)
    db.commit()
    return SyncPushResponse(applied=result.applied, stale=result.stale, cursor=result.cursor)


@router.get("/pull", response_model=SyncPullResponse)
def pull(
    since: int = Query(default=0, ge=0),
    limit: int = Query(default=500, ge=1, le=1000),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    changes, cursor, has_more = pull_changes(db, current_user.id, since, limit)
    return SyncPullResponse(changes=changes, cursor=cursor, has_more=has_more)
