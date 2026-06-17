from sqlalchemy import create_engine, inspect

from app.db.base import Base
from app.models import (
    AccessToken,
    Account,
    Category,
    Event,
    Medication,
    MedicationDoseLog,
    MedicationPushDelivery,
    PushSubscription,
    Reminder,
    Transaction,
    Transfer,
    User,
)


def test_all_core_tables_are_registered():
    tables = set(Base.metadata.tables.keys())

    assert {
        "users",
        "access_tokens",
        "accounts",
        "categories",
        "transactions",
        "events",
        "reminders",
        "recurring_events",
        "transfers",
        "push_subscriptions",
        "medications",
        "medication_dose_logs",
        "medication_push_deliveries",
    } <= tables


def test_metadata_can_create_schema():
    engine = create_engine("sqlite:///:memory:")

    Base.metadata.create_all(engine)

    inspector = inspect(engine)
    assert set(inspector.get_table_names()) == {
        "access_tokens",
        "accounts",
        "categories",
        "events",
        "medication_dose_logs",
        "medication_push_deliveries",
        "medications",
        "push_subscriptions",
        "recurring_events",
        "reminders",
        "transfers",
        "transactions",
        "users",
    }


def test_transaction_and_reminder_relationship_columns_exist():
    account_fk = next(
        fk for fk in Transaction.__table__.foreign_keys if fk.parent.name == "account_id"
    )
    category_fk = next(
        fk for fk in Transaction.__table__.foreign_keys if fk.parent.name == "category_id"
    )
    reminder_fk = next(
        fk for fk in Reminder.__table__.foreign_keys if fk.parent.name == "event_id"
    )
    transfer_source_fk = next(
        fk for fk in Transfer.__table__.foreign_keys if fk.parent.name == "source_account_id"
    )
    transfer_destination_fk = next(
        fk for fk in Transfer.__table__.foreign_keys if fk.parent.name == "destination_account_id"
    )

    assert account_fk.target_fullname == "accounts.id"
    assert category_fk.target_fullname == "categories.id"
    assert reminder_fk.target_fullname == "events.id"
    assert transfer_source_fk.target_fullname == "accounts.id"
    assert transfer_destination_fk.target_fullname == "accounts.id"


def test_medication_model_supports_schedule_and_dose_logs():
    medication_columns = Medication.__table__.columns
    log_columns = MedicationDoseLog.__table__.columns
    medication_fk = next(
        fk for fk in MedicationDoseLog.__table__.foreign_keys if fk.parent.name == "medication_id"
    )

    assert "weekdays" in medication_columns
    assert "dose_times" in medication_columns
    assert "timezone" in medication_columns
    assert "schedule_mode" in medication_columns
    assert "interval_days" in medication_columns
    assert "scheduled_for" in log_columns
    assert "snoozed_until" in log_columns
    assert medication_fk.target_fullname == "medications.id"
    assert "notify_at" in MedicationPushDelivery.__table__.columns


def test_credit_card_cycle_fields_are_available():
    columns = Account.__table__.columns

    assert "statement_day" in columns
    assert "due_day" in columns


def test_event_model_supports_reminders_and_completion():
    columns = Event.__table__.columns
    category_columns = Category.__table__.columns

    assert "starts_at" in columns
    assert "is_important" in columns
    assert "is_completed" in columns
    assert "type" in category_columns
    assert "user_id" in columns
    assert "user_id" in category_columns


def test_push_subscription_model_supports_device_keys():
    columns = PushSubscription.__table__.columns

    assert "endpoint" in columns
    assert "p256dh" in columns
    assert "auth" in columns
    assert "user_id" in columns


def test_user_and_access_token_models_exist():
    user_columns = User.__table__.columns
    token_columns = AccessToken.__table__.columns

    assert "email" in user_columns
    assert "user_id" in token_columns
    assert "token_hash" in token_columns
