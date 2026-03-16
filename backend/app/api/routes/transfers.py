"""Transfer endpoints."""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.db import get_db
from app.models import User
from app.schemas import TransferCreate, TransferRead, TransferUpdate
from app.services.transfers import create_transfer, delete_transfer, list_transfers, update_transfer


router = APIRouter(prefix="/transfers", tags=["transfers"])


@router.get("", response_model=list[TransferRead])
def list_transfers_endpoint(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    source_account_id: Annotated[int | None, Query()] = None,
    destination_account_id: Annotated[int | None, Query()] = None,
):
    current_user = resolve_route_user(current_user, db)
    return list_transfers(
        db,
        user_id=current_user.id,
        source_account_id=source_account_id,
        destination_account_id=destination_account_id,
    )


@router.post("", response_model=TransferRead, status_code=status.HTTP_201_CREATED)
def create_transfer_endpoint(
    payload: TransferCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    try:
        return create_transfer(db, payload, user_id=current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.put("/{transfer_id}", response_model=TransferRead)
def update_transfer_endpoint(
    transfer_id: int,
    payload: TransferUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    try:
        return update_transfer(db, transfer_id, payload, user_id=current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.delete("/{transfer_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_transfer_endpoint(
    transfer_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    current_user = resolve_route_user(current_user, db)
    try:
        delete_transfer(db, transfer_id, user_id=current_user.id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
