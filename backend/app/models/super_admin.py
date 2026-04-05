"""SuperAdmin model — platform-level administrators."""

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class SuperAdmin(Base):
    """
    Platform-level super administrator account.

    Super admins authenticate via WebAuthn hardware key plus TOTP
    and receive a short-lived JWT with role=super_admin.

    :ivar id: Primary key UUID
    :ivar email: Unique admin email address
    :ivar webauthn_credential: Stored WebAuthn credential (JSONB)
    :ivar totp_secret: Base-32 TOTP secret (optional)
    :ivar last_login: Timestamp of most recent successful login
    :ivar is_active: Whether the account is enabled
    :ivar created_at: Record creation timestamp
    :ivar updated_at: Last update timestamp
    """

    __tablename__ = "super_admins"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    email: Mapped[str] = mapped_column(
        String(255), nullable=False, unique=True
    )
    webauthn_credential: Mapped[dict] = mapped_column(
        JSONB, nullable=True
    )
    totp_secret: Mapped[str] = mapped_column(
        String(64), nullable=True
    )
    last_login: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="true"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
