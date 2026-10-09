"""households, client ids and a change feed for the shared wallet"""

from uuid import uuid4

from alembic import op
import sqlalchemy as sa


revision = "20261010_0016"
down_revision = "20261009_0015"
branch_labels = None
depends_on = None


def _fk(table: str, column: str, target: str) -> sa.ForeignKey:
    return sa.ForeignKey(f"{target}.id", name=f"fk_{table}_{column}_{target}")


def _backfill_client_ids(table: str) -> None:
    bind = op.get_bind()
    rows = bind.execute(sa.text(f"SELECT id FROM {table} WHERE client_id IS NULL")).fetchall()
    for (row_id,) in rows:
        bind.execute(sa.text(f"UPDATE {table} SET client_id = :cid WHERE id = :id"), {"cid": str(uuid4()), "id": row_id})


def upgrade() -> None:
    op.create_table(
        "households",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_households"),
    )
    op.create_table(
        "household_members",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("household_id", sa.Integer(), _fk("household_members", "household_id", "households"), nullable=False),
        sa.Column("user_id", sa.Integer(), _fk("household_members", "user_id", "users"), nullable=False),
        sa.Column("role", sa.String(length=10), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_household_members"),
        sa.UniqueConstraint("user_id", name="uq_household_members_user_id"),
    )
    op.create_index("ix_household_members_household_id", "household_members", ["household_id"])
    op.create_table(
        "household_invites",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("household_id", sa.Integer(), _fk("household_invites", "household_id", "households"), nullable=False),
        sa.Column("code", sa.String(length=12), nullable=False),
        sa.Column("created_by_user_id", sa.Integer(), _fk("household_invites", "created_by_user_id", "users"), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_by_user_id", sa.Integer(), _fk("household_invites", "used_by_user_id", "users"), nullable=True),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_household_invites"),
        sa.UniqueConstraint("code", name="uq_household_invites_code"),
    )
    op.create_index("ix_household_invites_household_id", "household_invites", ["household_id"])

    with op.batch_alter_table("accounts") as batch:
        batch.add_column(sa.Column("client_id", sa.String(length=64), nullable=True))
        batch.add_column(sa.Column("household_id", sa.Integer(), _fk("accounts", "household_id", "households"), nullable=True))
        batch.add_column(sa.Column("visibility", sa.String(length=10), nullable=False, server_default="personal"))
        batch.add_column(sa.Column("opening_balance", sa.Numeric(12, 2), nullable=False, server_default="0"))
        batch.add_column(sa.Column("last4", sa.String(length=4), nullable=True))
        batch.add_column(sa.Column("network", sa.String(length=12), nullable=True))
        batch.add_column(sa.Column("color", sa.String(length=20), nullable=True))
        batch.add_column(sa.Column("iban", sa.String(length=34), nullable=True))
        batch.create_unique_constraint("uq_accounts_client_id", ["client_id"])
        batch.create_index("ix_accounts_household_id", ["household_id"])
    with op.batch_alter_table("transactions") as batch:
        batch.add_column(sa.Column("client_id", sa.String(length=64), nullable=True))
        batch.add_column(sa.Column("created_by_user_id", sa.Integer(), _fk("transactions", "created_by_user_id", "users"), nullable=True))
        batch.add_column(sa.Column("installment_group", sa.String(length=64), nullable=True))
        batch.add_column(sa.Column("installment_index", sa.Integer(), nullable=True))
        batch.add_column(sa.Column("installment_count", sa.Integer(), nullable=True))
        batch.create_unique_constraint("uq_transactions_client_id", ["client_id"])
        batch.create_index("ix_transactions_installment_group", ["installment_group"])
    with op.batch_alter_table("transfers") as batch:
        batch.add_column(sa.Column("client_id", sa.String(length=64), nullable=True))
        batch.add_column(sa.Column("created_by_user_id", sa.Integer(), _fk("transfers", "created_by_user_id", "users"), nullable=True))
        batch.create_unique_constraint("uq_transfers_client_id", ["client_id"])

    op.create_table(
        "statement_marks",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("account_id", sa.Integer(), _fk("statement_marks", "account_id", "accounts"), nullable=False),
        sa.Column("statement_month", sa.Date(), nullable=False),
        sa.Column("paid", sa.Boolean(), nullable=False),
        sa.Column("updated_by_user_id", sa.Integer(), _fk("statement_marks", "updated_by_user_id", "users"), nullable=True),
        sa.Column("entity_version", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_statement_marks"),
        sa.UniqueConstraint("account_id", "statement_month", name="uq_statement_marks_account_month"),
    )
    op.create_index("ix_statement_marks_account_id", "statement_marks", ["account_id"])
    op.create_table(
        "wallet_cursors",
        sa.Column("scope", sa.String(length=24), nullable=False),
        sa.Column("last_seq", sa.BigInteger(), nullable=False),
        sa.PrimaryKeyConstraint("scope", name="pk_wallet_cursors"),
    )
    op.create_table(
        "wallet_changes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("scope", sa.String(length=24), nullable=False),
        sa.Column("seq", sa.BigInteger(), nullable=False),
        sa.Column("kind", sa.String(length=20), nullable=False),
        sa.Column("client_id", sa.String(length=64), nullable=False),
        sa.Column("deleted", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_wallet_changes"),
    )
    op.create_index("ix_wallet_changes_scope_seq", "wallet_changes", ["scope", "seq"])

    for table in ("accounts", "transactions", "transfers"):
        _backfill_client_ids(table)
    op.execute("UPDATE transactions SET created_by_user_id = user_id WHERE created_by_user_id IS NULL")
    op.execute("UPDATE transfers SET created_by_user_id = user_id WHERE created_by_user_id IS NULL")
    # Card balances used to mean "available credit"; they now mean minus the debt.
    op.execute(
        "UPDATE accounts SET balance = balance - credit_limit "
        "WHERE type = 'credit_card' AND credit_limit IS NOT NULL"
    )
    # balance = opening_balance + every recorded effect.
    op.execute(
        """
        UPDATE accounts SET opening_balance = balance
          - COALESCE((SELECT SUM(CASE WHEN t.type IN ('income', 'payment') THEN t.amount ELSE -t.amount END)
                      FROM transactions t WHERE t.account_id = accounts.id), 0)
          - COALESCE((SELECT SUM(tr.amount) FROM transfers tr WHERE tr.destination_account_id = accounts.id), 0)
          + COALESCE((SELECT SUM(tr.amount) FROM transfers tr WHERE tr.source_account_id = accounts.id), 0)
        """
    )


def downgrade() -> None:
    op.execute(
        "UPDATE accounts SET balance = balance + credit_limit "
        "WHERE type = 'credit_card' AND credit_limit IS NOT NULL"
    )
    op.drop_index("ix_wallet_changes_scope_seq", table_name="wallet_changes")
    op.drop_table("wallet_changes")
    op.drop_table("wallet_cursors")
    op.drop_index("ix_statement_marks_account_id", table_name="statement_marks")
    op.drop_table("statement_marks")
    with op.batch_alter_table("transfers") as batch:
        batch.drop_constraint("uq_transfers_client_id", type_="unique")
        batch.drop_constraint("fk_transfers_created_by_user_id_users", type_="foreignkey")
        batch.drop_column("created_by_user_id")
        batch.drop_column("client_id")
    with op.batch_alter_table("transactions") as batch:
        batch.drop_index("ix_transactions_installment_group")
        batch.drop_constraint("uq_transactions_client_id", type_="unique")
        batch.drop_constraint("fk_transactions_created_by_user_id_users", type_="foreignkey")
        for column in ("installment_count", "installment_index", "installment_group", "created_by_user_id", "client_id"):
            batch.drop_column(column)
    with op.batch_alter_table("accounts") as batch:
        batch.drop_index("ix_accounts_household_id")
        batch.drop_constraint("uq_accounts_client_id", type_="unique")
        batch.drop_constraint("fk_accounts_household_id_households", type_="foreignkey")
        for column in ("iban", "color", "network", "last4", "opening_balance", "visibility", "household_id", "client_id"):
            batch.drop_column(column)
    op.drop_index("ix_household_invites_household_id", table_name="household_invites")
    op.drop_table("household_invites")
    op.drop_index("ix_household_members_household_id", table_name="household_members")
    op.drop_table("household_members")
    op.drop_table("households")
