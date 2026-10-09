"""household-shared documents (shared notes and checklists)"""

from alembic import op
import sqlalchemy as sa


revision = "20261010_0017"
down_revision = "20261010_0016"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "shared_cursors",
        sa.Column("household_id", sa.Integer(), sa.ForeignKey("households.id", name="fk_shared_cursors_household_id_households"), nullable=False),
        sa.Column("last_seq", sa.BigInteger(), nullable=False),
        sa.PrimaryKeyConstraint("household_id", name="pk_shared_cursors"),
    )
    op.create_table(
        "shared_documents",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("household_id", sa.Integer(), sa.ForeignKey("households.id", name="fk_shared_documents_household_id_households"), nullable=False),
        sa.Column("collection", sa.String(length=40), nullable=False),
        sa.Column("doc_id", sa.String(length=64), nullable=False),
        sa.Column("body", sa.JSON(), nullable=True),
        sa.Column("deleted", sa.Boolean(), nullable=False),
        sa.Column("client_updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("seq", sa.BigInteger(), nullable=False),
        sa.Column("updated_by_user_id", sa.Integer(), sa.ForeignKey("users.id", name="fk_shared_documents_updated_by_user_id_users"), nullable=True),
        sa.Column("server_updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_shared_documents"),
        sa.UniqueConstraint("household_id", "collection", "doc_id", name="uq_shared_documents_household_collection_doc"),
    )
    op.create_index("ix_shared_documents_household_seq", "shared_documents", ["household_id", "seq"])


def downgrade() -> None:
    op.drop_index("ix_shared_documents_household_seq", table_name="shared_documents")
    op.drop_table("shared_documents")
    op.drop_table("shared_cursors")
