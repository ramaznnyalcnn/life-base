from datetime import datetime, timedelta, timezone

from app.services.auth import get_or_create_user, issue_access_token
from tests.conftest import api_request

T0 = datetime(2026, 10, 9, 12, 0, tzinfo=timezone.utc)


def change(doc_id="e1", *, at=T0, body=None, deleted=False, collection="events"):
    return {
        "collection": collection,
        "id": doc_id,
        "updated_at": at.isoformat(),
        "deleted": deleted,
        "body": None if deleted else (body or {"title": "Diş hekimi"}),
    }


def push(*changes, headers=None):
    response = api_request("POST", "/api/v3/sync/push", json={"changes": list(changes)}, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def pull(since=0, limit=500, headers=None):
    response = api_request("GET", "/api/v3/sync/pull", params={"since": since, "limit": limit}, headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def test_pushed_document_comes_back_on_pull_with_a_cursor():
    result = push(change(body={"title": "Diş hekimi", "notes": "Kontrol"}))

    assert result == {"applied": ["events/e1"], "stale": [], "cursor": 1}
    body = pull()
    assert body["cursor"] == 1
    assert body["has_more"] is False
    assert body["changes"][0]["body"] == {"title": "Diş hekimi", "notes": "Kontrol"}
    assert pull(since=1)["changes"] == []


def test_newer_change_wins_and_older_one_gets_the_server_copy_back():
    push(change(at=T0, body={"title": "v1"}))
    newer = push(change(at=T0 + timedelta(minutes=5), body={"title": "v2"}))
    older = push(change(at=T0 + timedelta(minutes=1), body={"title": "stale edit"}))

    assert newer["applied"] == ["events/e1"]
    assert older["applied"] == []
    assert older["stale"][0]["body"] == {"title": "v2"}
    assert [c["body"]["title"] for c in pull()["changes"]] == ["v2"]


def test_deletion_is_final_even_against_a_later_edit():
    push(change(at=T0))
    push(change(at=T0 + timedelta(minutes=1), deleted=True))

    revived = push(change(at=T0 + timedelta(hours=1), body={"title": "edited offline"}))

    assert revived["applied"] == []
    assert revived["stale"][0]["deleted"] is True
    assert pull()["changes"][0]["deleted"] is True


def test_retrying_the_same_change_does_not_create_a_new_revision():
    first = push(change())
    retry = push(change())

    assert retry["applied"] == ["events/e1"]
    assert retry["cursor"] == first["cursor"] == 1


def test_sequence_is_shared_across_collections_and_pull_pages():
    push(
        change("e1"),
        change("m1", collection="medications", body={"name": "D vitamini"}),
        change("m1@2026-10-09T09:00", collection="dose_logs", body={"status": "taken"}),
    )

    first = pull(limit=2)
    assert [c["seq"] for c in first["changes"]] == [1, 2]
    assert first["has_more"] is True and first["cursor"] == 2
    rest = pull(since=first["cursor"], limit=2)
    assert [c["collection"] for c in rest["changes"]] == ["dose_logs"]
    assert rest["has_more"] is False and rest["cursor"] == 3


def test_same_id_in_different_collections_are_different_documents():
    push(change("x"), change("x", collection="medications", body={"name": "x"}))

    assert len(pull()["changes"]) == 2


def test_users_only_see_their_own_documents(setup_database):
    with setup_database() as session:
        other = get_or_create_user(session, email="partner@lifeos.local", display_name="Partner")
        _, token = issue_access_token(session, other, label="test")
    partner = {"Authorization": f"Bearer {token}"}

    push(change("mine"))
    push(change("theirs"), headers=partner)

    assert [c["id"] for c in pull()["changes"]] == ["mine"]
    assert [c["id"] for c in pull(headers=partner)["changes"]] == ["theirs"]
    assert pull(headers=partner)["cursor"] == 1


def test_invalid_changes_are_rejected():
    def status(payload):
        return api_request("POST", "/api/v3/sync/push", json={"changes": [payload]}).status_code

    assert status({**change(), "collection": "wallet"}) == 422
    assert status({**change(), "body": None}) == 422
    assert status({**change(), "updated_at": "2026-10-09T12:00:00"}) == 422
    assert status({**change(), "body": {"blob": "x" * 70_000}}) == 422
