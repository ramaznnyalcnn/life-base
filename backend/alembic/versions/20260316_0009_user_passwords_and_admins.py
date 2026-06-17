"""user passwords and admins"""

from alembic import op
import sqlalchemy as sa


revision = "20260316_0009"
down_revision = "20260314_0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("password_hash", sa.String(length=512), nullable=False, server_default=""))
    op.add_column("users", sa.Column("is_admin", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.create_index("ix_users_is_admin", "users", ["is_admin"])

    bind = op.get_bind()
    bind.execute(sa.text("UPDATE users SET is_admin = true WHERE email = 'owner@lifeos.local'"))


def downgrade() -> None:
    op.drop_index("ix_users_is_admin", table_name="users")
    op.drop_column("users", "is_admin")
    op.drop_column("users", "password_hash")
