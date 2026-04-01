"""User model — shop staff accounts with RBAC roles."""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class User(Base):
    """
    Shop staff account belonging to a tenant.

    :ivar id: Primary key UUID
    :ivar tenant_id: Owning tenant
    :ivar name: Full display name
    :ivar email: Login email, unique per tenant
    :ivar password_hash: bcrypt-hashed password
    :ivar role: admin | manager | salesman
    :ivar is_active: Soft-disable flag
    :ivar created_at: Record creation timestamp
    :ivar updated_at: Last update timestamp
    """

    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint(
            "tenant_id", "email", name="uq_users_tenant_email"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tenants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name: Mapped[str] = mapped_column(
        String(255), nullable=False
    )
    email: Mapped[str] = mapped_column(
        String(255), nullable=False
    )
    password_hash: Mapped[str] = mapped_column(
        String(255), nullable=False
    )
    role: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default="salesman"
    )
    is_active: Mapped[bool] = mapped_column(
        nullable=False, server_default="true"
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

    tenant: Mapped["Tenant"] = relationship(
        back_populates="users"
    )
    sales_transactions: Mapped[list["SalesTransaction"]] = (
        relationship(back_populates="salesman")
    )
    audit_logs: Mapped[list["AuditLog"]] = relationship(
        back_populates="user"
    )
