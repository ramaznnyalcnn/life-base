from app.cli.run_reminder_worker import main, run_worker


def test_run_worker_stops_after_max_runs(monkeypatch):
    calls = []
    sleeps = []

    monkeypatch.setattr(
        "app.cli.run_reminder_worker.run_dispatch_reminders",
        lambda device_id=None, limit=20: calls.append((device_id, limit)) or {"sent_count": 0},
    )
    monkeypatch.setattr(
        "app.cli.run_reminder_worker.time.sleep",
        lambda seconds: sleeps.append(seconds),
    )

    result = run_worker(device_id="device-a", limit=5, interval=12, max_runs=2)

    assert result == 0
    assert calls == [("device-a", 5), ("device-a", 5)]
    assert sleeps == [12]


def test_run_worker_returns_non_zero_when_dispatch_fails(monkeypatch):
    monkeypatch.setattr(
        "app.cli.run_reminder_worker.run_dispatch_reminders",
        lambda **kwargs: (_ for _ in ()).throw(ValueError("Web push aktif degil.")),
    )

    assert run_worker(limit=5, interval=5, max_runs=1) == 2


def test_main_returns_zero(monkeypatch):
    monkeypatch.setattr(
        "app.cli.run_reminder_worker.run_worker",
        lambda **kwargs: 0,
    )

    assert main(["--max-runs", "1"]) == 0
