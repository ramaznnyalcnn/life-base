"""Household-shared notes and checklists (/api/v3/shared)."""

from sqlalchemy import select

from app.models import Household, SharedDocument, User
from app.core.config import get_settings
from app.services.auth import issue_access_token
from tests.conftest import api_request

T = "2026-10-09T12:00:00+00:00"


def user(setup_database, email, name):
    with setup_database() as session:
        row = User(email=email, display_name=name)
        session.add(row)
        session.flush()
        _, token = issue_access_token(session, row, label="test")
        session.commit()
        return row.id, {"Authorization": f"Bearer {token}"}


def doc(doc_id, body, collection="note_items", at=T, deleted=False):
    return {"collection": collection, "id": doc_id, "updated_at": at, "deleted": deleted, "body": None if deleted else body}


def push(*changes, headers=None):
    return api_request("POST", "/api/v3/shared/push", json={"changes": list(changes)}, headers=headers)


def pull(since=0, scope=None, headers=None):
    params = {"since": since, **({"scope": scope} if scope else {})}
    return api_request("GET", "/api/v3/shared/pull", params=params, headers=headers)


def household(setup_database):
    partner_id, partner = user(setup_database, "partner@example.com", "Partner")
    code = api_request("POST", "/api/v3/household/invites").json()["code"]
    assert api_request("POST", "/api/v3/household/join", json={"code": code}, headers=partner).status_code == 200
    return partner_id, partner


def test_only_household_members_share(setup_database):
    _, stranger = user(setup_database, "x@example.com", "X")
    assert push(doc("i1", {"content": "Süt"}), headers=stranger).status_code == 403
    assert pull(headers=stranger).status_code == 403


def test_members_tick_different_lines_of_one_list_at_once(setup_database):
    partner_id, partner = household(setup_database)
    list_doc = doc("market", {"title": "Market", "kind": "list"}, collection="notes")
    assert push(list_doc, doc("i1", {"note_id": "market", "content": "Süt"}), doc("i2", {"note_id": "market", "content": "Ekmek"})).status_code == 200

    first = pull(headers=partner).json()
    assert first["reset"] is True and first["scope"].startswith("h:")
    assert {c["id"] for c in first["changes"]} == {"market", "i1", "i2"}

    # Both tick a different line "at the same time" (from older copies).
    later = "2026-10-09T12:05:00+00:00"
    mine = push(doc("i1", {"note_id": "market", "content": "Süt", "done": True}, at=later))
    theirs = push(doc("i2", {"note_id": "market", "content": "Ekmek", "done": True}, at=later), headers=partner)
    assert mine.json()["applied"] == ["note_items/i1"]
    assert theirs.json()["applied"] == ["note_items/i2"]

    news = pull(first["cursor"], first["scope"], headers=partner).json()
    assert news["reset"] is False
    assert {c["id"]: c["body"]["done"] for c in news["changes"]} == {"i1": True, "i2": True}
    with setup_database() as session:
        authors = dict(session.execute(select(SharedDocument.doc_id, SharedDocument.updated_by_user_id)).all())
    assert authors["i2"] == partner_id


def test_the_household_shares_calendar_and_medications_too(setup_database):
    _, partner = household(setup_database)
    event = doc("e1", {"title": "Diş", "created_by": 1, "notify": "all"}, collection="events")
    dose = doc("m1@2026-10-09T09:00:00Z", {"medication_id": "m1", "status": "taken"}, collection="dose_logs")
    assert push(event, doc("m1", {"name": "Parol"}, collection="medications"), dose).status_code == 200

    pulled = {(c["collection"], c["id"]): c["body"] for c in pull(headers=partner).json()["changes"]}
    assert pulled[("events", "e1")]["notify"] == "all"
    assert ("medications", "m1") in pulled and ("dose_logs", "m1@2026-10-09T09:00:00Z") in pulled



def test_leaving_stops_access_and_the_last_one_out_clears_the_space(setup_database):
    _, partner = household(setup_database)
    push(doc("i1", {"note_id": "n", "content": "Süt"}))

    api_request("POST", "/api/v3/household/leave", headers=partner)
    assert pull(headers=partner).status_code == 403
    assert len(pull().json()["changes"]) == 1

    api_request("POST", "/api/v3/household/leave")
    with setup_database() as session:
        assert session.scalars(select(SharedDocument)).all() == []
        assert session.scalars(select(Household)).all() == []


def test_on_the_same_millisecond_the_member_with_tie_priority_wins(setup_database, monkeypatch):
    monkeypatch.setenv("SYNC_TIE_WINNERS", "Partner@example.com")
    get_settings.cache_clear()
    try:
        _, partner = household(setup_database)
        assert push(doc("e1", {"title": "Benim"}, collection="events")).json()["applied"] == ["events/e1"]

        # Same stamp, different text: the partner has priority and wins.
        assert push(doc("e1", {"title": "Onun"}, collection="events"), headers=partner).json()["applied"] == ["events/e1"]
        # The other way round it stays the partner's.
        late = push(doc("e1", {"title": "Benim yine"}, collection="events")).json()
        assert late["applied"] == [] and late["stale"][0]["body"] == {"title": "Onun"}
    finally:
        get_settings.cache_clear()
