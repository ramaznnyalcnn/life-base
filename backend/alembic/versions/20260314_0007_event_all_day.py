"""event all day support"""

from alembic import op
import sqlalchemy as sa


revision = "20260314_0007"
down_revision = "20260314_0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "events",
        sa.Column("is_all_day", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.create_index("ix_events_is_all_day", "events", ["is_all_day"])
    op.alter_column("events", "is_all_day", server_default=None)


def downgrade() -> None:
    op.drop_index("ix_events_is_all_day", table_name="events")
    op.drop_column("events", "is_all_day")
