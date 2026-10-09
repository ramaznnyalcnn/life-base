"""add optimistic entity versions for offline edits"""

from alembic import op
import sqlalchemy as sa


revision = "20260915_0014"
down_revision = "20260915_0013"
branch_labels = None
depends_on = None


TABLES = (
    "accounts", "categories", "transactions", "transfers", "events",
    "recurring_events", "activity_templates", "tasks", "medications",
    "scheduled_payments",
)


def upgrade() -> None:
    for table in TABLES:
        op.add_column(table, sa.Column("entity_version", sa.Integer(), nullable=False, server_default="1"))
        op.alter_column(table, "entity_version", server_default=None)
    op.add_column("categories", sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()))
    op.create_index("ix_categories_is_active", "categories", ["is_active"])
    op.alter_column("categories", "is_active", server_default=None)


def downgrade() -> None:
    op.drop_index("ix_categories_is_active", table_name="categories")
    op.drop_column("categories", "is_active")
    for table in reversed(TABLES):
        op.drop_column(table, "entity_version")
