"""medication reminders"""

from alembic import op
import sqlalchemy as sa


revision = "20260517_0010"
down_revision = "20260316_0009"
branch_labels = None
depends_on = None


status_enum = sa.Enum("taken", "snoozed", name="medicationdosestatus")


def upgrade() -> None:
    op.create_table(
        "medications",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=True),
        sa.Column("device_id", sa.String(length=120), nullable=True),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("dosage", sa.String(length=120), nullable=False),
        sa.Column("instructions", sa.Text(), nullable=True),
        sa.Column("weekdays", sa.String(length=32), nullable=False),
        sa.Column("dose_times", sa.String(length=255), nullable=False),
        sa.Column("starts_on", sa.Date(), nullable=False),
        sa.Column("ends_on", sa.Date(), nullable=True),
        sa.Column("timezone", sa.String(length=64), nullable=False, server_default="Europe/Istanbul"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_medications_user_id_users"),
    )
    op.create_index("ix_medications_user_id", "medications", ["user_id"])
    op.create_index("ix_medications_device_id", "medications", ["device_id"])
    op.create_index("ix_medications_name", "medications", ["name"])
    op.create_index("ix_medications_starts_on", "medications", ["starts_on"])
    op.create_index("ix_medications_ends_on", "medications", ["ends_on"])
    op.create_index("ix_medications_is_active", "medications", ["is_active"])

    op.create_table(
        "medication_dose_logs",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("medication_id", sa.Integer(), nullable=False),
        sa.Column("scheduled_for", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", status_enum, nullable=False),
        sa.Column("taken_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("snoozed_until", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["medication_id"], ["medications.id"], name="fk_medication_dose_logs_medication_id_medications"),
        sa.UniqueConstraint(
            "medication_id",
            "scheduled_for",
            name="uq_medication_dose_logs_medication_id_scheduled_for",
        ),
    )
    op.create_index("ix_medication_dose_logs_medication_id", "medication_dose_logs", ["medication_id"])
    op.create_index("ix_medication_dose_logs_scheduled_for", "medication_dose_logs", ["scheduled_for"])
    op.create_index("ix_medication_dose_logs_status", "medication_dose_logs", ["status"])
    op.create_index("ix_medication_dose_logs_snoozed_until", "medication_dose_logs", ["snoozed_until"])

    op.alter_column("medications", "timezone", server_default=None)
    op.alter_column("medications", "is_active", server_default=None)


def downgrade() -> None:
    op.drop_index("ix_medication_dose_logs_snoozed_until", table_name="medication_dose_logs")
    op.drop_index("ix_medication_dose_logs_status", table_name="medication_dose_logs")
    op.drop_index("ix_medication_dose_logs_scheduled_for", table_name="medication_dose_logs")
    op.drop_index("ix_medication_dose_logs_medication_id", table_name="medication_dose_logs")
    op.drop_table("medication_dose_logs")
    op.drop_index("ix_medications_is_active", table_name="medications")
    op.drop_index("ix_medications_ends_on", table_name="medications")
    op.drop_index("ix_medications_starts_on", table_name="medications")
    op.drop_index("ix_medications_name", table_name="medications")
    op.drop_index("ix_medications_device_id", table_name="medications")
    op.drop_index("ix_medications_user_id", table_name="medications")
    op.drop_table("medications")
    status_enum.drop(op.get_bind(), checkfirst=True)
