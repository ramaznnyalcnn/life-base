from datetime import date, datetime, time, timedelta, timezone
from types import SimpleNamespace

from pywebpush import WebPushException

from app.api.routes import notifications as notifications_routes
from app.api.routes.medications import create_medication_endpoint
from app.api.routes.notifications import (
    create_or_update_subscription,
    dispatch_reminders,
    delete_subscription,
    get_push_public_config,
    list_subscriptions,
    send_test_push,
)
from app.main import app
from app.models import Event, Reminder, ReminderChannel
from app.schemas import (
    PushMessageRequest,
    MedicationCreate,
    PushSubscriptionCreate,
    PushSubscriptionDelete,
)
from app.services.notifications import dispatch_due_reminders, send_push_message


def sample_payload():
    return PushSubscriptionCreate(
        endpoint="https://push.example.test/subscriptions/123",
        keys={
            "p256dh": "BOrnekAnahtarDegeri1234567890",
            "auth": "authvalue123",
        },
        device_label="iPhone Safari",
        user_agent="Mozilla/5.0",
    )


class FakeGateway:
    def __init__(self, failing_endpoints=None):
        self.calls = []
        self.failing_endpoints = set(failing_endpoints or [])

    def send(self, subscription, payload, settings):
        self.calls.append((subscription.endpoint, payload, settings.vapid_subject))
        if subscription.endpoint in self.failing_endpoints:
            response = SimpleNamespace(status_code=410)
            raise WebPushException("expired", response=response)


def push_settings():
    return SimpleNamespace(
        enable_web_push=True,
        vapid_public_key="public-key",
        vapid_private_key="private-key",
        vapid_subject="mailto:test@example.com",
    )


def test_notifications_api_creates_lists_and_deactivates_subscription(db_session):
    created = create_or_update_subscription(sample_payload(), db_session, "device-a")

    assert created.id is not None
    assert created.device_label == "iPhone Safari"

    rows = list_subscriptions(db_session, "device-a")
    assert len(rows) == 1

    updated = create_or_update_subscription(
        PushSubscriptionCreate(
            endpoint="https://push.example.test/subscriptions/123",
            keys={
                "p256dh": "BYeniAnahtarDegeri1234567890",
                "auth": "authvalue456",
            },
            device_label="Ana Telefon",
            user_agent="Mozilla/5.0",
        ),
        db_session,
        "device-a",
    )
    assert updated.device_label == "Ana Telefon"

    delete_subscription(
        PushSubscriptionDelete(endpoint="https://push.example.test/subscriptions/123"),
        db_session,
    )

    rows_after_delete = list_subscriptions(db_session, "device-a")
    assert rows_after_delete == []


def test_notifications_public_config_is_exposed():
    payload = get_push_public_config()

    assert isinstance(payload.enabled, bool)
    assert isinstance(payload.vapid_public_key, str)


def test_send_push_message_dispatches_to_active_subscriptions(db_session):
    create_or_update_subscription(sample_payload(), db_session, "device-a")
    gateway = FakeGateway()

    result = send_push_message(
        db_session,
        PushMessageRequest(title="Test Bildirimi", body="Merhaba", url="/"),
        device_id="device-a",
        gateway=gateway,
        settings=push_settings(),
    )

    assert result.sent_count == 1
    assert result.failed_count == 0
    assert gateway.calls[0][1]["title"] == "Test Bildirimi"


def test_send_push_message_deactivates_expired_subscription(db_session):
    create_or_update_subscription(sample_payload(), db_session, "device-a")
    gateway = FakeGateway({"https://push.example.test/subscriptions/123"})

    result = send_push_message(
        db_session,
        PushMessageRequest(title="Test Bildirimi", body="Merhaba", url="/"),
        device_id="device-a",
        gateway=gateway,
        settings=push_settings(),
    )

    assert result.sent_count == 0
    assert result.failed_count == 1
    assert result.deactivated_count == 1
    assert list_subscriptions(db_session, "device-a") == []


def test_dispatch_due_reminders_marks_sent_when_push_succeeds(db_session):
    create_or_update_subscription(sample_payload(), db_session, "device-a")
    event = Event(
        title="Fatura Hatirlatma",
        description="Bugun odenecek",
        starts_at=datetime(2026, 3, 9, 18, 0, tzinfo=timezone.utc),
        device_id="device-a",
    )
    db_session.add(event)
    db_session.flush()
    reminder = Reminder(
        event_id=event.id,
        remind_at=datetime.now(timezone.utc) - timedelta(minutes=5),
        channel=ReminderChannel.WEB_PUSH,
        is_sent=False,
    )
    db_session.add(reminder)
    db_session.commit()

    result = dispatch_due_reminders(
        db_session,
        now=datetime.now(timezone.utc),
        gateway=FakeGateway(),
        settings=push_settings(),
    )

    assert result.sent_count == 1
    assert result.reminder_count == 1
    assert db_session.get(Reminder, reminder.id).is_sent is True


def test_dispatch_due_medication_dose_sends_once_to_web_subscription(db_session):
    create_or_update_subscription(sample_payload(), db_session, "web-device")
    create_medication_endpoint(
        MedicationCreate(
            name="Tansiyon ilaci",
            dosage="5 mg",
            weekdays=[6],
            dose_times=[time(9, 0)],
            starts_on=date(2026, 5, 17),
            timezone="Europe/Istanbul",
        ),
        db_session,
        x_device_id="mobile-device",
    )
    gateway = FakeGateway()
    now = datetime(2026, 5, 17, 6, 0, tzinfo=timezone.utc)

    first = dispatch_due_reminders(db_session, now=now, gateway=gateway, settings=push_settings())
    second = dispatch_due_reminders(db_session, now=now, gateway=gateway, settings=push_settings())

    assert first.sent_count == 1
    assert first.medication_dose_count == 1
    assert second.sent_count == 0
    assert second.medication_dose_count == 0


def test_send_test_push_targets_only_same_device_subscription(db_session):
    create_or_update_subscription(sample_payload(), db_session, "device-a")
    create_or_update_subscription(
        PushSubscriptionCreate(
            endpoint="https://push.example.test/subscriptions/999",
            keys={
                "p256dh": "BOrnekAnahtarDegeri9999999999999",
                "auth": "authvalue999",
            },
            device_label="Diger Telefon",
            user_agent="Mozilla/5.0",
        ),
        db_session,
        "device-b",
    )
    gateway = FakeGateway()

    result = send_push_message(
        db_session,
        PushMessageRequest(title="Test Bildirimi", body="Merhaba", url="/"),
        device_id="device-a",
        gateway=gateway,
        settings=push_settings(),
    )

    assert result.sent_count == 1
    assert gateway.calls[0][0] == "https://push.example.test/subscriptions/123"


def test_notification_endpoints_expose_test_and_dispatch_routes(db_session, monkeypatch):
    monkeypatch.setattr(
        notifications_routes,
        "send_push_message",
        lambda db, payload, device_id=None, user_id=None: SimpleNamespace(
            sent_count=1,
            failed_count=0,
            deactivated_count=0,
            reminder_count=0,
        ),
    )
    monkeypatch.setattr(
        notifications_routes,
        "dispatch_due_reminders",
        lambda db, device_id=None, user_id=None: SimpleNamespace(
            sent_count=0,
            failed_count=0,
            deactivated_count=0,
            reminder_count=2,
        ),
    )

    test_result = send_test_push(
        PushMessageRequest(title="Deneme", body="Bildirim", url="/"),
        db=db_session,
    )
    dispatch_result = dispatch_reminders(db_session)

    assert test_result.sent_count == 1
    assert dispatch_result.reminder_count == 2


def test_notification_routes_are_registered_on_app():
    paths = {route.path for route in app.routes}

    assert "/api/v1/notifications/config" in paths
    assert "/api/v1/notifications/subscriptions" in paths
    assert "/api/v1/notifications/test" in paths
    assert "/api/v1/notifications/dispatch-reminders" in paths
