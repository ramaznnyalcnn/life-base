"""Household-shared documents (shared notes and checklists).

Same push/pull contract as /sync, but the documents belong to the caller's
household. Only members may use it; a client whose household changed gets a
full snapshot (`reset`).
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.db import get_db
from app.models import User
from app.schemas.sync import SyncPushRequest
from app.services.ledger import household_id_of
from app.services.sync import household_space, pull_changes, push_changes


router = APIRouter(prefix="/shared", tags=["shared-v3"])

SHARED_COLLECTIONS = frozenset({"notes", "note_items"})


def _space(db: Session, user: User):
    household_id = household_id_of(db, user.id)
    if household_id is None:
        raise HTTPException(status_code=403, detail="Bir haneye uye degilsin.")
    return household_space(household_id, user.id)


@router.post("/push")
def push(payload: SyncPushRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    current_user = resolve_route_user(current_user, db)
    space = _space(db, current_user)
    if any(change.collection not in SHARED_COLLECTIONS for change in payload.changes):
        raise HTTPException(status_code=400, detail="Bu koleksiyon paylasilamaz.")
    result = push_changes(db, space, payload.changes)
    db.commit()
    return {"applied": result.applied, "stale": result.stale, "cursor": result.cursor, "scope": f"h:{space.owner_id}"}


@router.get("/pull")
def pull(
    since: int = Query(default=0, ge=0),
    scope: str | None = Query(default=None, max_length=24),
    limit: int = Query(default=500, ge=1, le=1000),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    space = _space(db, current_user)
    current = f"h:{space.owner_id}"
    reset = scope != current
    changes, cursor, has_more = pull_changes(db, space, 0 if reset else since, limit)
    return {"changes": changes, "cursor": cursor, "has_more": has_more, "scope": current, "reset": reset}
