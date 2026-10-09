"""operation core tables and planning templates"""

from alembic import op
import sqlalchemy as sa


revision = "20260915_0012"
down_revision = "20260526_0011"
branch_labels = None
depends_on = None


template_kind = sa.Enum("task", "event", "routine", name="activitytemplatekind")


def _timestamps() -> tuple[sa.Column, sa.Column]:
    return (
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )


def upgrade() -> None:
    op.create_table(
        "activity_templates",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=True),
        sa.Column("kind", template_kind, nullable=False),
        sa.Column("label", sa.String(length=160), nullable=False),
        sa.Column("is_system", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        *_timestamps(),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_activity_templates_user_id_users"),
        sa.UniqueConstraint("user_id", "kind", "label", name="uq_activity_templates_user_kind_label"),
    )
    op.create_index("ix_activity_templates_user_id", "activity_templates", ["user_id"])
    op.create_index("ix_activity_templates_kind", "activity_templates", ["kind"])
    op.create_index("ix_activity_templates_label", "activity_templates", ["label"])
    op.create_index("ix_activity_templates_is_system", "activity_templates", ["is_system"])
    op.create_index("ix_activity_templates_is_active", "activity_templates", ["is_active"])

    op.add_column("events", sa.Column("template_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_events_template_id_activity_templates",
        "events",
        "activity_templates",
        ["template_id"],
        ["id"],
    )
    op.create_index("ix_events_template_id", "events", ["template_id"])
    op.add_column("recurring_events", sa.Column("template_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_recurring_events_template_id_activity_templates",
        "recurring_events",
        "activity_templates",
        ["template_id"],
        ["id"],
    )
    op.create_index("ix_recurring_events_template_id", "recurring_events", ["template_id"])

    op.create_table(
        "tasks",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("device_id", sa.String(length=120), nullable=True),
        sa.Column("template_id", sa.Integer(), nullable=True),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("due_on", sa.Date(), nullable=False),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_important", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("is_completed", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        *_timestamps(),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_tasks_user_id_users"),
        sa.ForeignKeyConstraint(
            ["template_id"], ["activity_templates.id"], name="fk_tasks_template_id_activity_templates"
        ),
    )
    for column in ("user_id", "device_id", "template_id", "title", "due_on", "scheduled_at", "is_important", "is_completed"):
        op.create_index(f"ix_tasks_{column}", "tasks", [column])

    op.create_table(
        "scheduled_payments",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("device_id", sa.String(length=120), nullable=True),
        sa.Column("source_account_id", sa.Integer(), nullable=False),
        sa.Column("destination_account_id", sa.Integer(), nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("due_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("is_completed", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("completed_transfer_id", sa.Integer(), nullable=True),
        *_timestamps(),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_scheduled_payments_user_id_users"),
        sa.ForeignKeyConstraint(["source_account_id"], ["accounts.id"], name="fk_scheduled_payments_source_account_id_accounts"),
        sa.ForeignKeyConstraint(["destination_account_id"], ["accounts.id"], name="fk_scheduled_payments_destination_account_id_accounts"),
        sa.ForeignKeyConstraint(["completed_transfer_id"], ["transfers.id"], name="fk_scheduled_payments_completed_transfer_id_transfers"),
        sa.CheckConstraint(
            "source_account_id <> destination_account_id",
            name="ck_scheduled_payments_distinct_accounts",
        ),
        sa.CheckConstraint("amount > 0", name="ck_scheduled_payments_positive_amount"),
        sa.UniqueConstraint("completed_transfer_id", name="uq_scheduled_payments_completed_transfer_id"),
    )
    for column in ("user_id", "device_id", "source_account_id", "destination_account_id", "due_at", "is_completed"):
        op.create_index(f"ix_scheduled_payments_{column}", "scheduled_payments", [column])

    op.create_table(
        "operation_executions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("request_id", sa.String(length=36), nullable=False),
        sa.Column("operation_key", sa.String(length=120), nullable=False),
        sa.Column("request_hash", sa.String(length=64), nullable=False),
        sa.Column("response_payload", sa.JSON(), nullable=False),
        *_timestamps(),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_operation_executions_user_id_users"),
        sa.UniqueConstraint("user_id", "request_id", name="uq_operation_executions_user_request_id"),
    )
    for column in ("user_id", "request_id", "operation_key"):
        op.create_index(f"ix_operation_executions_{column}", "operation_executions", [column])

    op.create_table(
        "agenda_revisions",
        sa.Column("user_id", sa.Integer(), primary_key=True),
        sa.Column("version", sa.BigInteger(), nullable=False, server_default="0"),
        *_timestamps(),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_agenda_revisions_user_id_users"),
    )

    op.alter_column("activity_templates", "is_active", server_default=None)
    op.alter_column("activity_templates", "is_system", server_default=None)
    op.alter_column("tasks", "is_important", server_default=None)
    op.alter_column("tasks", "is_completed", server_default=None)
    op.alter_column("scheduled_payments", "is_completed", server_default=None)
    op.alter_column("agenda_revisions", "version", server_default=None)


def downgrade() -> None:
    op.drop_table("agenda_revisions")
    op.drop_table("operation_executions")
    op.drop_table("scheduled_payments")
    op.drop_table("tasks")
    op.drop_index("ix_recurring_events_template_id", table_name="recurring_events")
    op.drop_constraint("fk_recurring_events_template_id_activity_templates", "recurring_events", type_="foreignkey")
    op.drop_column("recurring_events", "template_id")
    op.drop_index("ix_events_template_id", table_name="events")
    op.drop_constraint("fk_events_template_id_activity_templates", "events", type_="foreignkey")
    op.drop_column("events", "template_id")
    op.drop_table("activity_templates")
    template_kind.drop(op.get_bind(), checkfirst=True)
