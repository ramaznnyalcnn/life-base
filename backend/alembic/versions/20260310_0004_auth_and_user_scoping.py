"""auth and user scoping"""

from alembic import op
import sqlalchemy as sa


revision = "20260310_0004"
down_revision = "20260309_0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("display_name", sa.String(length=160), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("email", name="uq_users_email"),
    )
    op.create_index("ix_users_email", "users", ["email"])
    op.create_index("ix_users_is_active", "users", ["is_active"])

    op.create_table(
        "access_tokens",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("label", sa.String(length=120), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("last_used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name="fk_access_tokens_user_id_users"),
        sa.UniqueConstraint("token_hash", name="uq_access_tokens_token_hash"),
    )
    op.create_index("ix_access_tokens_user_id", "access_tokens", ["user_id"])
    op.create_index("ix_access_tokens_token_hash", "access_tokens", ["token_hash"])
    op.create_index("ix_access_tokens_is_active", "access_tokens", ["is_active"])

    bind = op.get_bind()
    owner_id = bind.execute(
        sa.text(
            """
            INSERT INTO users (email, display_name, is_active, created_at, updated_at)
            VALUES ('owner@lifeos.local', 'Life OS Owner', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING id
            """
        )
    ).scalar_one()

    op.add_column("accounts", sa.Column("user_id", sa.Integer(), nullable=True))
    op.add_column("categories", sa.Column("user_id", sa.Integer(), nullable=True))
    op.add_column("transactions", sa.Column("user_id", sa.Integer(), nullable=True))
    op.add_column("events", sa.Column("user_id", sa.Integer(), nullable=True))
    op.add_column("push_subscriptions", sa.Column("user_id", sa.Integer(), nullable=True))

    bind.execute(sa.text("UPDATE accounts SET user_id = :owner_id"), {"owner_id": owner_id})
    bind.execute(sa.text("UPDATE transactions SET user_id = :owner_id"), {"owner_id": owner_id})
    bind.execute(sa.text("UPDATE events SET user_id = :owner_id"), {"owner_id": owner_id})
    bind.execute(sa.text("UPDATE push_subscriptions SET user_id = :owner_id"), {"owner_id": owner_id})
    bind.execute(
        sa.text("UPDATE categories SET user_id = :owner_id WHERE is_system = false"),
        {"owner_id": owner_id},
    )

    op.create_foreign_key("fk_accounts_user_id_users", "accounts", "users", ["user_id"], ["id"])
    op.create_foreign_key("fk_categories_user_id_users", "categories", "users", ["user_id"], ["id"])
    op.create_foreign_key("fk_transactions_user_id_users", "transactions", "users", ["user_id"], ["id"])
    op.create_foreign_key("fk_events_user_id_users", "events", "users", ["user_id"], ["id"])
    op.create_foreign_key(
        "fk_push_subscriptions_user_id_users",
        "push_subscriptions",
        "users",
        ["user_id"],
        ["id"],
    )

    op.create_index("ix_accounts_user_id", "accounts", ["user_id"])
    op.create_index("ix_categories_user_id", "categories", ["user_id"])
    op.create_index("ix_transactions_user_id", "transactions", ["user_id"])
    op.create_index("ix_events_user_id", "events", ["user_id"])
    op.create_index("ix_push_subscriptions_user_id", "push_subscriptions", ["user_id"])

    op.drop_constraint("uq_accounts_name", "accounts", type_="unique")
    op.drop_constraint("uq_categories_name", "categories", type_="unique")
    op.create_unique_constraint("uq_accounts_user_id_name", "accounts", ["user_id", "name"])
    op.create_unique_constraint("uq_categories_user_id_name", "categories", ["user_id", "name"])


def downgrade() -> None:
    op.drop_constraint("uq_categories_user_id_name", "categories", type_="unique")
    op.drop_constraint("uq_accounts_user_id_name", "accounts", type_="unique")
    op.create_unique_constraint("uq_categories_name", "categories", ["name"])
    op.create_unique_constraint("uq_accounts_name", "accounts", ["name"])

    op.drop_index("ix_push_subscriptions_user_id", table_name="push_subscriptions")
    op.drop_index("ix_events_user_id", table_name="events")
    op.drop_index("ix_transactions_user_id", table_name="transactions")
    op.drop_index("ix_categories_user_id", table_name="categories")
    op.drop_index("ix_accounts_user_id", table_name="accounts")

    op.drop_constraint("fk_push_subscriptions_user_id_users", "push_subscriptions", type_="foreignkey")
    op.drop_constraint("fk_events_user_id_users", "events", type_="foreignkey")
    op.drop_constraint("fk_transactions_user_id_users", "transactions", type_="foreignkey")
    op.drop_constraint("fk_categories_user_id_users", "categories", type_="foreignkey")
    op.drop_constraint("fk_accounts_user_id_users", "accounts", type_="foreignkey")

    op.drop_column("push_subscriptions", "user_id")
    op.drop_column("events", "user_id")
    op.drop_column("transactions", "user_id")
    op.drop_column("categories", "user_id")
    op.drop_column("accounts", "user_id")

    op.drop_index("ix_access_tokens_is_active", table_name="access_tokens")
    op.drop_index("ix_access_tokens_token_hash", table_name="access_tokens")
    op.drop_index("ix_access_tokens_user_id", table_name="access_tokens")
    op.drop_table("access_tokens")

    op.drop_index("ix_users_is_active", table_name="users")
    op.drop_index("ix_users_email", table_name="users")
    op.drop_table("users")
