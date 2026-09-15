"""allow reminders to belong to tasks or scheduled payments"""

from alembic import op
import sqlalchemy as sa


revision = "20260915_0013"
down_revision = "20260915_0012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column("reminders", "event_id", existing_type=sa.Integer(), nullable=True)
    op.add_column("reminders", sa.Column("task_id", sa.Integer(), nullable=True))
    op.add_column("reminders", sa.Column("scheduled_payment_id", sa.Integer(), nullable=True))
    op.create_foreign_key("fk_reminders_task_id_tasks", "reminders", "tasks", ["task_id"], ["id"])
    op.create_foreign_key(
        "fk_reminders_scheduled_payment_id_scheduled_payments",
        "reminders",
        "scheduled_payments",
        ["scheduled_payment_id"],
        ["id"],
    )
    op.create_index("ix_reminders_task_id", "reminders", ["task_id"])
    op.create_index("ix_reminders_scheduled_payment_id", "reminders", ["scheduled_payment_id"])
    op.create_check_constraint(
        "ck_reminders_exactly_one_source",
        "reminders",
        "(CASE WHEN event_id IS NOT NULL THEN 1 ELSE 0 END) + "
        "(CASE WHEN task_id IS NOT NULL THEN 1 ELSE 0 END) + "
        "(CASE WHEN scheduled_payment_id IS NOT NULL THEN 1 ELSE 0 END) = 1",
    )


def downgrade() -> None:
    op.drop_constraint("ck_reminders_exactly_one_source", "reminders", type_="check")
    op.drop_index("ix_reminders_scheduled_payment_id", table_name="reminders")
    op.drop_index("ix_reminders_task_id", table_name="reminders")
    op.drop_constraint(
        "fk_reminders_scheduled_payment_id_scheduled_payments", "reminders", type_="foreignkey"
    )
    op.drop_constraint("fk_reminders_task_id_tasks", "reminders", type_="foreignkey")
    op.drop_column("reminders", "scheduled_payment_id")
    op.drop_column("reminders", "task_id")
    op.alter_column("reminders", "event_id", existing_type=sa.Integer(), nullable=False)
