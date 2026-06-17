"""device scoped events and push"""

from alembic import op
import sqlalchemy as sa


revision = "20260309_0003"
down_revision = "20260309_0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("events", sa.Column("device_id", sa.String(length=120), nullable=True))
    op.create_index("ix_events_device_id", "events", ["device_id"])

    op.add_column("push_subscriptions", sa.Column("device_id", sa.String(length=120), nullable=True))
    op.create_index("ix_push_subscriptions_device_id", "push_subscriptions", ["device_id"])


def downgrade() -> None:
    op.drop_index("ix_push_subscriptions_device_id", table_name="push_subscriptions")
    op.drop_column("push_subscriptions", "device_id")

    op.drop_index("ix_events_device_id", table_name="events")
    op.drop_column("events", "device_id")
