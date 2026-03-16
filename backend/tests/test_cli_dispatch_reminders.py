from app.cli.dispatch_reminders import main, run_dispatch_reminders


class DummyResult:
    def model_dump(self):
        return {
            "sent_count": 1,
            "failed_count": 0,
            "deactivated_count": 0,
            "reminder_count": 1,
        }


class DummySession:
    def __init__(self):
        self.closed = False

    def close(self):
        self.closed = True


def test_run_dispatch_reminders_uses_session_factory(monkeypatch):
    dummy_session = DummySession()

    monkeypatch.setattr(
        "app.cli.dispatch_reminders.SessionLocal",
        lambda: dummy_session,
    )
    monkeypatch.setattr(
        "app.cli.dispatch_reminders.dispatch_due_reminders",
        lambda session, device_id=None, limit=20: DummyResult(),
    )

    payload = run_dispatch_reminders(device_id="device-a", limit=5)

    assert payload["sent_count"] == 1
    assert dummy_session.closed is True


def test_main_returns_non_zero_when_push_is_not_ready(monkeypatch):
    monkeypatch.setattr(
        "app.cli.dispatch_reminders.run_dispatch_reminders",
        lambda **kwargs: (_ for _ in ()).throw(ValueError("Web push aktif degil.")),
    )

    assert main([]) == 2
