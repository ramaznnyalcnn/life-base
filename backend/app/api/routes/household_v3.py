"""Household membership for the shared wallet (online-only actions)."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.db import get_db
from app.models import User
from app.services import households


router = APIRouter(prefix="/household", tags=["household-v3"])


class JoinRequest(BaseModel):
    code: str = Field(min_length=4, max_length=12)


@router.get("")
def get_household(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    current_user = resolve_route_user(current_user, db)
    return households.describe(db, current_user.id)


@router.post("/invites")
def create_invite(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    current_user = resolve_route_user(current_user, db)
    invite = households.create_invite(db, current_user.id)
    db.commit()
    return {"code": invite.code, "expires_at": invite.expires_at}


@router.post("/join")
def join(payload: JoinRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    current_user = resolve_route_user(current_user, db)
    try:
        households.join(db, current_user.id, payload.code)
    except households.HouseholdError as exc:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    db.commit()
    return households.describe(db, current_user.id)


@router.post("/leave")
def leave(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    current_user = resolve_route_user(current_user, db)
    households.leave(db, current_user.id)
    db.commit()
    return households.describe(db, current_user.id)
