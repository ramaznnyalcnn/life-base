from app.cli.issue_token import issue_token_for_user, main


class DummySession:
    def __init__(self):
        self.closed = False

    def close(self):
        self.closed = True


class DummyUser:
    id = 7
    email = "owner@example.com"
    display_name = "Owner"


class DummyToken:
    id = 9
    label = "CLI token"


def test_issue_token_for_user_uses_session_factory(monkeypatch):
    dummy_session = DummySession()

    monkeypatch.setattr("app.cli.issue_token.SessionLocal", lambda: dummy_session)
    monkeypatch.setattr(
        "app.cli.issue_token.get_or_create_user",
        lambda session, email, display_name: DummyUser(),
    )
    monkeypatch.setattr(
        "app.cli.issue_token.issue_access_token",
        lambda session, user, label, note=None: (DummyToken(), "plain-token"),
    )

    payload = issue_token_for_user(
        email="owner@example.com",
        display_name="Owner",
        label="CLI token",
    )

    assert payload["token"] == "plain-token"
    assert dummy_session.closed is True


def test_main_returns_zero(monkeypatch):
    monkeypatch.setattr(
        "app.cli.issue_token.issue_token_for_user",
        lambda **kwargs: {"token": "plain-token", "email": "owner@example.com"},
    )

    assert main([]) == 0
