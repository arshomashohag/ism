"""Schema-per-tenant bootstrap migration.

Revision ID: 0004
Revises: 0003
Create Date: 2026-04-04

Adds schema_name column to public.tenants, then for each existing
tenant creates an isolated PostgreSQL schema and migrates all
per-tenant rows into it. tenant_id FK columns are retained in this
migration and will be dropped in 0005 after isolation is validated.
"""

import uuid

import sqlalchemy as sa
from alembic import op
from sqlalchemy import text

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None

_PER_TENANT_TABLES = [
    "users",
    "categories",
    "warehouses",
    "sales_transactions",
    "audit_log",
    "sync_changelog",
    "sync_conflicts",
]


def upgrade() -> None:
    """
    Add schema_name to tenants and migrate existing tenant data.

    :return: None
    """
    conn = op.get_bind()

    conn.execute(
        text(
            "ALTER TABLE tenants "
            "ADD COLUMN IF NOT EXISTS schema_name "
            "VARCHAR(100) NOT NULL DEFAULT ''"
        )
    )

    conn.execute(
        text(
            "UPDATE tenants SET schema_name = slug "
            "WHERE schema_name = ''"
        )
    )

    tenants = conn.execute(
        text("SELECT id, slug FROM tenants")
    ).fetchall()

    for tenant in tenants:
        slug = tenant.slug
        tenant_id = str(tenant.id)

        conn.execute(
            text(f'CREATE SCHEMA IF NOT EXISTS "{slug}"')
        )

        conn.execute(
            text(f'SET search_path TO "{slug}", public')
        )

        for table in _PER_TENANT_TABLES:
            _copy_table(conn, table, tenant_id, slug)

        conn.execute(
            text("SET search_path TO public")
        )

    conn.execute(text("SET search_path TO public"))


def _copy_table(
    conn: sa.engine.Connection,
    table: str,
    tenant_id: str,
    slug: str,
) -> None:
    """
    Copy rows for one tenant from public schema into tenant schema.

    Uses INSERT INTO {slug}.{table} SELECT to move data while keeping
    the original public rows (they are removed in migration 0005).

    :param conn: Active SQLAlchemy connection
    :param table: Table name to copy
    :param tenant_id: Tenant UUID string to filter rows
    :param slug: Target schema name
    :return: None
    """
    col_row = conn.execute(
        text(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_schema = 'public' AND table_name = :tbl "
            "ORDER BY ordinal_position"
        ),
        {"tbl": table},
    ).fetchall()
    if not col_row:
        return

    columns = ", ".join(r.column_name for r in col_row)

    if table in ("sale_line_items", "payments", "inventory"):
        return

    conn.execute(
        text(
            f'INSERT INTO "{slug}".{table} ({columns}) '
            f"SELECT {columns} FROM public.{table} "
            f"WHERE tenant_id = :tid "
            f"ON CONFLICT DO NOTHING"
        ),
        {"tid": tenant_id},
    )


def downgrade() -> None:
    """
    Remove schema_name column from public.tenants.

    Tenant schemas created during upgrade are not dropped here to
    prevent accidental data loss. Remove them manually if needed.

    :return: None
    """
    op.drop_column("tenants", "schema_name")
