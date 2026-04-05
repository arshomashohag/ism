"""Create super_admins table in public schema.

Revision ID: 0006
Revises: 0005
Create Date: 2026-04-05

Creates the platform-level super_admins table used for WebAuthn-
authenticated administrator access to the /sadmin panel.
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    """
    Create the super_admins table in the public schema.

    :return: None
    """
    op.create_table(
        "super_admins",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "email",
            sa.String(255),
            nullable=False,
        ),
        sa.Column(
            "webauthn_credential",
            JSONB,
            nullable=True,
        ),
        sa.Column(
            "totp_secret",
            sa.String(64),
            nullable=True,
        ),
        sa.Column(
            "last_login",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "is_active",
            sa.Boolean,
            nullable=False,
            server_default="true",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        schema="public",
    )
    op.create_index(
        "ix_super_admins_email",
        "super_admins",
        ["email"],
        unique=True,
        schema="public",
    )


def downgrade() -> None:
    """
    Drop the super_admins table from the public schema.

    :return: None
    """
    op.drop_index(
        "ix_super_admins_email",
        table_name="super_admins",
        schema="public",
    )
    op.drop_table("super_admins", schema="public")
