"""Alembic environment configuration."""

from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

from app.core.config import get_settings
from app.db.base import Base
import app.models.account  # noqa: F401
import app.models.auth  # noqa: F401
import app.models.event  # noqa: F401
import app.models.household  # noqa: F401
import app.models.medication  # noqa: F401
import app.models.notification  # noqa: F401
import app.models.operation_execution  # noqa: F401
import app.models.planning  # noqa: F401
import app.models.recurring_event  # noqa: F401
import app.models.scheduled_payment  # noqa: F401
import app.models.transfer  # noqa: F401
import app.models.transaction  # noqa: F401
import app.models.sync  # noqa: F401
import app.models.wallet_sync  # noqa: F401


config = context.config
settings = get_settings()

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

config.set_main_option("sqlalchemy.url", settings.database_url)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    context.configure(
        url=settings.database_url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
