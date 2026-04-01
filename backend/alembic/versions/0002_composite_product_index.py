"""Add composite index on products(tenant_id, is_active).

Revision ID: 0002
Revises: 0001
Create Date: 2026-03-31
"""

from alembic import op


revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """Create composite index for tenant-scoped active product queries."""
    op.create_index(
        "ix_products_tenant_active",
        "products",
        ["tenant_id", "is_active"],
    )


def downgrade() -> None:
    """Drop composite index."""
    op.drop_index("ix_products_tenant_active", table_name="products")
