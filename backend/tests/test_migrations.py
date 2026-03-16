from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]


def test_alembic_files_exist():
    base = REPO_ROOT / "backend" / "alembic"

    assert (base / "env.py").exists()
    assert (base / "script.py.mako").exists()
    assert (base / "versions" / "20260309_0001_initial_schema.py").exists()
    assert (base / "versions" / "20260309_0002_push_subscriptions.py").exists()
    assert (base / "versions" / "20260309_0003_device_scoped_events_and_push.py").exists()
    assert (base / "versions" / "20260310_0004_auth_and_user_scoping.py").exists()
    assert (base / "versions" / "20260313_0005_event_importance.py").exists()
    assert (base / "versions" / "20260314_0006_transfers.py").exists()


def test_initial_migration_contains_core_tables():
    migration = (REPO_ROOT / "backend" / "alembic" / "versions" / "20260309_0001_initial_schema.py").read_text()

    assert "accounts" in migration
    assert "categories" in migration
    assert "transactions" in migration
    assert "events" in migration
    assert "reminders" in migration


def test_push_subscription_migration_contains_subscription_table():
    migration = (REPO_ROOT / "backend" / "alembic" / "versions" / "20260309_0002_push_subscriptions.py").read_text()

    assert "push_subscriptions" in migration
    assert "endpoint" in migration
    assert "p256dh" in migration


def test_device_scoped_migration_contains_device_columns():
    migration = (
        REPO_ROOT / "backend" / "alembic" / "versions" / "20260309_0003_device_scoped_events_and_push.py"
    ).read_text()

    assert "events" in migration
    assert "push_subscriptions" in migration
    assert "device_id" in migration


def test_auth_scoping_migration_contains_user_tables_and_columns():
    migration = (REPO_ROOT / "backend" / "alembic" / "versions" / "20260310_0004_auth_and_user_scoping.py").read_text()

    assert "users" in migration
    assert "access_tokens" in migration
    assert "user_id" in migration
    assert "accounts" in migration


def test_event_importance_migration_contains_flag_column():
    migration = (REPO_ROOT / "backend" / "alembic" / "versions" / "20260313_0005_event_importance.py").read_text()

    assert "events" in migration
    assert "is_important" in migration


def test_transfers_migration_contains_transfer_table():
    migration = (REPO_ROOT / "backend" / "alembic" / "versions" / "20260314_0006_transfers.py").read_text()

    assert "transfers" in migration
    assert "source_account_id" in migration
    assert "destination_account_id" in migration
