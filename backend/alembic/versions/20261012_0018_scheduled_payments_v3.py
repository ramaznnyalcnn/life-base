"""scheduled payments for the mobile wallet: client ids, expenses, monthly repeat"""

from uuid import uuid4

from alembic import op
import sqlalchemy as sa


revision = "20261012_0018"
down_revision = "20261010_0017"
branch_labels = None
depends_on = None


def _fk(table: str, column: str, target: str) -> sa.ForeignKey:
    return sa.ForeignKey(f"{target}.id", name=f"fk_{table}_{column}_{target}")


def upgrade() -> None:
    with op.batch_alter_table("scheduled_payments") as batch:
        batch.add_column(sa.Column("client_id", sa.String(length=64), nullable=True))
        batch.add_column(sa.Column("created_by_user_id", sa.Integer(), _fk("scheduled_payments", "created_by_user_id", "users"), nullable=True))
        batch.add_column(sa.Column("title", sa.String(length=120), nullable=True))
        batch.add_column(sa.Column("kind", sa.String(length=10), nullable=False, server_default="transfer"))
        batch.add_column(sa.Column("category_id", sa.Integer(), _fk("scheduled_payments", "category_id", "categories"), nullable=True))
        batch.add_column(sa.Column("repeat_monthly", sa.Boolean(), nullable=False, server_default=sa.false()))
        batch.add_column(sa.Column("last_paid_at", sa.DateTime(timezone=True), nullable=True))
        # An expense has no destination; the distinct-accounts check passes on NULL.
        batch.alter_column("destination_account_id", existing_type=sa.Integer(), nullable=True)
        batch.create_unique_constraint("uq_scheduled_payments_client_id", ["client_id"])

    bind = op.get_bind()
    for (row_id,) in bind.execute(sa.text("SELECT id FROM scheduled_payments WHERE client_id IS NULL")).fetchall():
        bind.execute(sa.text("UPDATE scheduled_payments SET client_id = :cid WHERE id = :id"), {"cid": str(uuid4()), "id": row_id})
    op.execute("UPDATE scheduled_payments SET created_by_user_id = user_id WHERE created_by_user_id IS NULL")


def downgrade() -> None:
    # Expenses cannot exist without a destination in the old schema.
    op.execute("DELETE FROM reminders WHERE scheduled_payment_id IN (SELECT id FROM scheduled_payments WHERE destination_account_id IS NULL)")
    op.execute("DELETE FROM scheduled_payments WHERE destination_account_id IS NULL")
    with op.batch_alter_table("scheduled_payments") as batch:
        batch.drop_constraint("uq_scheduled_payments_client_id", type_="unique")
        batch.alter_column("destination_account_id", existing_type=sa.Integer(), nullable=False)
        batch.drop_constraint("fk_scheduled_payments_category_id_categories", type_="foreignkey")
        batch.drop_constraint("fk_scheduled_payments_created_by_user_id_users", type_="foreignkey")
        for column in ("last_paid_at", "repeat_monthly", "category_id", "kind", "title", "created_by_user_id", "client_id"):
            batch.drop_column(column)
