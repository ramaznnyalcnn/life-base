"""recurring event rules"""

from alembic import op
import sqlalchemy as sa


revision = "20260314_0008"
down_revision = "20260314_0007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "recurring_events",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=True),
        sa.Column("device_id", sa.String(length=120), nullable=True),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("weekdays", sa.String(length=32), nullable=False),
        sa.Column("starts_on", sa.Date(), nullable=False),
        sa.Column("ends_on", sa.Date(), nullable=True),
        sa.Column("start_time", sa.Time(), nullable=True),
        sa.Column("end_time", sa.Time(), nullable=True),
        sa.Column("is_all_day", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("is_important", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("interval_weeks", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_recurring_events_user_id_users"),
    )
    op.create_index("ix_recurring_events_user_id", "recurring_events", ["user_id"])
    op.create_index("ix_recurring_events_device_id", "recurring_events", ["device_id"])
    op.create_index("ix_recurring_events_title", "recurring_events", ["title"])
    op.create_index("ix_recurring_events_starts_on", "recurring_events", ["starts_on"])
    op.create_index("ix_recurring_events_ends_on", "recurring_events", ["ends_on"])
    op.create_index("ix_recurring_events_is_all_day", "recurring_events", ["is_all_day"])
    op.create_index("ix_recurring_events_is_important", "recurring_events", ["is_important"])
    op.create_index("ix_recurring_events_is_active", "recurring_events", ["is_active"])

    op.alter_column("recurring_events", "is_all_day", server_default=None)
    op.alter_column("recurring_events", "is_important", server_default=None)
    op.alter_column("recurring_events", "is_active", server_default=None)
    op.alter_column("recurring_events", "interval_weeks", server_default=None)


def downgrade() -> None:
    op.drop_index("ix_recurring_events_is_active", table_name="recurring_events")
    op.drop_index("ix_recurring_events_is_important", table_name="recurring_events")
    op.drop_index("ix_recurring_events_is_all_day", table_name="recurring_events")
    op.drop_index("ix_recurring_events_ends_on", table_name="recurring_events")
    op.drop_index("ix_recurring_events_starts_on", table_name="recurring_events")
    op.drop_index("ix_recurring_events_title", table_name="recurring_events")
    op.drop_index("ix_recurring_events_device_id", table_name="recurring_events")
    op.drop_index("ix_recurring_events_user_id", table_name="recurring_events")
    op.drop_table("recurring_events")
