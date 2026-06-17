from app.cli.create_user import create_user_from_cli, main


class DummySession:
    def __init__(self):
        self.closed = False

    def close(self):
        self.closed = True


class DummyUser:
    id = 12
    email = "abi@example.com"
    display_name = "Abi"
    is_admin = False
    is_active = True


def test_create_user_from_cli_uses_session_factory(monkeypatch):
    dummy_session = DummySession()

    monkeypatch.setattr("app.cli.create_user.SessionLocal", lambda: dummy_session)
    monkeypatch.setattr(
        "app.cli.create_user.get_or_create_user",
        lambda session, email, display_name, password, is_admin=False: DummyUser(),
    )

    payload = create_user_from_cli(
        email="abi@example.com",
        display_name="Abi",
        password="cok-guclu-sifre-123",
    )

    assert payload["email"] == "abi@example.com"
    assert dummy_session.closed is True


def test_main_returns_zero(monkeypatch):
    monkeypatch.setattr(
        "app.cli.create_user.create_user_from_cli",
        lambda **kwargs: {"email": "abi@example.com"},
    )

    assert main(["--email", "abi@example.com", "--name", "Abi", "--password", "secret-secret-123"]) == 0
