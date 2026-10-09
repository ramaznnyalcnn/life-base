"""add document store for local-first client sync"""

from alembic import op
import sqlalchemy as sa


revision = "20261009_0015"
down_revision = "20260915_0014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "sync_cursors",
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", name="fk_sync_cursors_user_id_users"), nullable=False),
        sa.Column("last_seq", sa.BigInteger(), nullable=False),
        sa.PrimaryKeyConstraint("user_id", name="pk_sync_cursors"),
    )
    op.create_table(
        "sync_documents",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", name="fk_sync_documents_user_id_users"), nullable=False),
        sa.Column("collection", sa.String(length=40), nullable=False),
        sa.Column("doc_id", sa.String(length=64), nullable=False),
        sa.Column("body", sa.JSON(), nullable=True),
        sa.Column("deleted", sa.Boolean(), nullable=False),
        sa.Column("client_updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("seq", sa.BigInteger(), nullable=False),
        sa.Column("server_updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_sync_documents"),
        sa.UniqueConstraint("user_id", "collection", "doc_id", name="uq_sync_documents_user_collection_doc"),
    )
    op.create_index("ix_sync_documents_user_seq", "sync_documents", ["user_id", "seq"])


def downgrade() -> None:
    op.drop_index("ix_sync_documents_user_seq", table_name="sync_documents")
    op.drop_table("sync_documents")
    op.drop_table("sync_cursors")
