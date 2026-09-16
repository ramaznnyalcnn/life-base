"""Read endpoints tailored to the Android daily-use surfaces."""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.security import get_current_user, resolve_route_user
from app.db import get_db
from app.models import Account, Category, Event, Medication, RecurringEvent, ScheduledPayment, Task, Transaction, Transfer, User
from app.services.medications import build_medication_dashboard, read_medication
from app.services.bootstrap import ensure_default_cash_account, ensure_default_categories
from app.services.wallet import build_wallet_summary


router = APIRouter(tags=["daily-v2"])


def _user(current_user: User, db: Session) -> User:
    return resolve_route_user(current_user, db)


def _row(entity) -> dict[str, object]:
    return {column.name: getattr(entity, column.name) for column in entity.__table__.columns}


@router.get("/finance/overview")
def finance_overview(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    owner = _user(current_user, db)
    summary = build_wallet_summary(db, user_id=owner.id).model_dump(mode="json")
    pending = list(db.scalars(select(ScheduledPayment).where(ScheduledPayment.user_id == owner.id, ScheduledPayment.is_completed.is_(False))).all())
    return {**summary, "pending_payments": [_row(item) for item in pending]}


@router.get("/finance/accounts")
def finance_accounts(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    owner = _user(current_user, db)
    ensure_default_cash_account(db, owner.id)
    return [_row(item) for item in db.scalars(select(Account).where(Account.user_id == owner.id).order_by(Account.name)).all()]


@router.get("/finance/categories")
def finance_categories(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    owner = _user(current_user, db)
    ensure_default_categories(db)
    return [_row(item) for item in db.scalars(select(Category).where((Category.user_id == owner.id) | (Category.user_id.is_(None))).order_by(Category.type, Category.name)).all()]


@router.get("/finance/entries")
def finance_entries(cursor: int = Query(default=0, ge=0), limit: int = Query(default=30, ge=1, le=100), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    owner = _user(current_user, db)
    transactions = [{**_row(item), "kind": "transaction"} for item in db.scalars(select(Transaction).where(Transaction.user_id == owner.id)).all()]
    transfers = [{**_row(item), "kind": "transfer"} for item in db.scalars(select(Transfer).where(Transfer.user_id == owner.id)).all()]
    entries = sorted(transactions + transfers, key=lambda item: (item["occurred_at"], item["id"]), reverse=True)
    page = entries[cursor:cursor + limit]
    return {"items": page, "next_cursor": cursor + limit if cursor + limit < len(entries) else None}


@router.get("/finance/payments")
def finance_payments(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    owner = _user(current_user, db)
    return [_row(item) for item in db.scalars(select(ScheduledPayment).where(ScheduledPayment.user_id == owner.id).order_by(ScheduledPayment.due_at)).all()]


@router.get("/planning/tasks")
def planning_tasks(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    owner = _user(current_user, db)
    return [_row(item) for item in db.scalars(select(Task).where(Task.user_id == owner.id).order_by(Task.due_on, Task.id)).all()]


@router.get("/planning/events")
def planning_events(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    owner = _user(current_user, db)
    return [_row(item) for item in db.scalars(select(Event).where(Event.user_id == owner.id).order_by(Event.starts_at, Event.id)).all()]


@router.get("/planning/routines")
def planning_routines(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    owner = _user(current_user, db)
    return [_row(item) for item in db.scalars(select(RecurringEvent).where(RecurringEvent.user_id == owner.id).order_by(RecurringEvent.title)).all()]


@router.get("/health/medications")
def health_medications(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    owner = _user(current_user, db)
    values = db.scalars(select(Medication).where(Medication.user_id == owner.id).order_by(Medication.name)).all()
    return [read_medication(item).model_dump(mode="json") | {"entity_version": item.entity_version} for item in values]


@router.get("/health/medications/{medication_id}")
def health_medication(medication_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    owner = _user(current_user, db)
    item = db.scalar(select(Medication).where(Medication.id == medication_id, Medication.user_id == owner.id))
    if item is None:
        raise HTTPException(status_code=404, detail="Ilac bulunamadi.")
    return read_medication(item).model_dump(mode="json") | {"entity_version": item.entity_version}


@router.get("/health/dashboard")
def health_dashboard(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    owner = _user(current_user, db)
    return build_medication_dashboard(db, user_id=owner.id)
