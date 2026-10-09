"""Households: create on first invite, join with a code, leave."""

from __future__ import annotations

import secrets
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Account, Household, HouseholdInvite, HouseholdMember, User
from app.services.ledger import PERSONAL, SHARED, record_change, scope_for


INVITE_TTL = timedelta(hours=48)
# No 0/O, 1/I/L: codes are read aloud and typed on a phone.
_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"


class HouseholdError(ValueError):
    pass


def _utc(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def membership(session: Session, user_id: int) -> HouseholdMember | None:
    return session.scalar(select(HouseholdMember).where(HouseholdMember.user_id == user_id))


def describe(session: Session, user_id: int) -> dict[str, object]:
    member = membership(session, user_id)
    if member is None:
        return {"household": None}
    rows = session.execute(
        select(HouseholdMember, User)
        .join(User, User.id == HouseholdMember.user_id)
        .where(HouseholdMember.household_id == member.household_id)
        .order_by(HouseholdMember.created_at, HouseholdMember.id)
    ).all()
    return {
        "household": {
            "id": member.household_id,
            "name": member.household.name,
            "members": [
                {"user_id": user.id, "name": user.display_name, "email": user.email, "role": row.role, "is_me": user.id == user_id}
                for row, user in rows
            ],
        }
    }


def create_invite(session: Session, user_id: int, *, now: datetime | None = None) -> HouseholdInvite:
    """A single-use code for someone else to join; creates the household on first use."""

    now = now or datetime.now(timezone.utc)
    member = membership(session, user_id)
    if member is None:
        household = Household(name="Hane")
        session.add(household)
        session.flush()
        member = HouseholdMember(household_id=household.id, user_id=user_id, role="owner")
        session.add(member)
        session.flush()
    for _ in range(10):
        code = "".join(secrets.choice(_ALPHABET) for _ in range(6))
        if session.scalar(select(HouseholdInvite.id).where(HouseholdInvite.code == code)) is None:
            break
    invite = HouseholdInvite(household_id=member.household_id, code=code, created_by_user_id=user_id, expires_at=now + INVITE_TTL)
    session.add(invite)
    session.flush()
    return invite


def join(session: Session, user_id: int, code: str, *, now: datetime | None = None) -> HouseholdMember:
    now = now or datetime.now(timezone.utc)
    if membership(session, user_id) is not None:
        raise HouseholdError("Zaten bir hanedesin; once ondan ayril.")
    invite = session.scalar(
        select(HouseholdInvite).where(HouseholdInvite.code == code.strip().upper()).with_for_update()
    )
    if invite is None or invite.used_at is not None or _utc(invite.expires_at) < now:
        raise HouseholdError("Davet kodu gecersiz veya suresi dolmus.")
    member = HouseholdMember(household_id=invite.household_id, user_id=user_id, role="member")
    invite.used_by_user_id = user_id
    invite.used_at = now
    session.add(member)
    session.flush()
    return member


def leave(session: Session, user_id: int) -> None:
    """The leaver keeps their shared accounts as personal ones; the others stop seeing them."""

    member = membership(session, user_id)
    if member is None:
        return
    household_id = member.household_id
    old_scope = scope_for(household_id, user_id)
    for account in session.scalars(
        select(Account).where(Account.user_id == user_id, Account.visibility == SHARED).with_for_update()
    ):
        account.visibility = PERSONAL
        account.household_id = None
        record_change(session, old_scope, "account", account.client_id)
    session.delete(member)
    session.flush()
    if session.scalar(select(HouseholdMember.id).where(HouseholdMember.household_id == household_id)) is None:
        for invite in session.scalars(select(HouseholdInvite).where(HouseholdInvite.household_id == household_id)):
            session.delete(invite)
        session.flush()
        session.delete(session.get(Household, household_id))
