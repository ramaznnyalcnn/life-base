"""medication intervals and push delivery tracking"""

from alembic import op
import sqlalchemy as sa


revision = "20260526_0011"
down_revision = "20260517_0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "medications",
        sa.Column("schedule_mode", sa.String(length=16), nullable=False, server_default="weekdays"),
    )
    op.add_column("medications", sa.Column("interval_days", sa.Integer(), nullable=True))
    op.alter_column("medications", "schedule_mode", server_default=None)

    op.create_table(
        "medication_push_deliveries",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("push_subscription_id", sa.Integer(), nullable=False),
        sa.Column("medication_id", sa.Integer(), nullable=False),
        sa.Column("scheduled_for", sa.DateTime(timezone=True), nullable=False),
        sa.Column("notify_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("sent_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["push_subscription_id"], ["push_subscriptions.id"], name="fk_medication_push_deliveries_push_subscription_id_push_subscriptions"),
        sa.ForeignKeyConstraint(["medication_id"], ["medications.id"], name="fk_medication_push_deliveries_medication_id_medications"),
        sa.UniqueConstraint(
            "push_subscription_id",
            "medication_id",
            "scheduled_for",
            "notify_at",
            name="uq_medication_push_delivery_target_dose_time",
        ),
    )
    op.create_index("ix_medication_push_deliveries_push_subscription_id", "medication_push_deliveries", ["push_subscription_id"])
    op.create_index("ix_medication_push_deliveries_medication_id", "medication_push_deliveries", ["medication_id"])
    op.create_index("ix_medication_push_deliveries_scheduled_for", "medication_push_deliveries", ["scheduled_for"])
    op.create_index("ix_medication_push_deliveries_notify_at", "medication_push_deliveries", ["notify_at"])
    op.create_index("ix_medication_push_deliveries_sent_at", "medication_push_deliveries", ["sent_at"])


def downgrade() -> None:
    op.drop_index("ix_medication_push_deliveries_sent_at", table_name="medication_push_deliveries")
    op.drop_index("ix_medication_push_deliveries_notify_at", table_name="medication_push_deliveries")
    op.drop_index("ix_medication_push_deliveries_scheduled_for", table_name="medication_push_deliveries")
    op.drop_index("ix_medication_push_deliveries_medication_id", table_name="medication_push_deliveries")
    op.drop_index("ix_medication_push_deliveries_push_subscription_id", table_name="medication_push_deliveries")
    op.drop_table("medication_push_deliveries")
    op.drop_column("medications", "interval_days")
    op.drop_column("medications", "schedule_mode")
