"""account transfers"""

from alembic import op
import sqlalchemy as sa


revision = "20260314_0006"
down_revision = "20260313_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "transfers",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=True),
        sa.Column("source_account_id", sa.Integer(), nullable=False),
        sa.Column("destination_account_id", sa.Integer(), nullable=False),
        sa.Column("amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("description", sa.String(length=160), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("occurred_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("source_account_id <> destination_account_id", name="ck_transfers_distinct_accounts"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_transfers_user_id_users"),
        sa.ForeignKeyConstraint(
            ["source_account_id"],
            ["accounts.id"],
            name="fk_transfers_source_account_id_accounts",
        ),
        sa.ForeignKeyConstraint(
            ["destination_account_id"],
            ["accounts.id"],
            name="fk_transfers_destination_account_id_accounts",
        ),
    )
    op.create_index("ix_transfers_user_id", "transfers", ["user_id"])
    op.create_index("ix_transfers_source_account_id", "transfers", ["source_account_id"])
    op.create_index("ix_transfers_destination_account_id", "transfers", ["destination_account_id"])
    op.create_index("ix_transfers_occurred_at", "transfers", ["occurred_at"])


def downgrade() -> None:
    op.drop_index("ix_transfers_occurred_at", table_name="transfers")
    op.drop_index("ix_transfers_destination_account_id", table_name="transfers")
    op.drop_index("ix_transfers_source_account_id", table_name="transfers")
    op.drop_index("ix_transfers_user_id", table_name="transfers")
    op.drop_table("transfers")
