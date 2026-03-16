"""event importance flag"""

from alembic import op
import sqlalchemy as sa


revision = "20260313_0005"
down_revision = "20260310_0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "events",
        sa.Column("is_important", sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.create_index("ix_events_is_important", "events", ["is_important"])


def downgrade() -> None:
    op.drop_index("ix_events_is_important", table_name="events")
    op.drop_column("events", "is_important")
