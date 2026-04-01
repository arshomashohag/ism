"""Tenant model — global registry of all shop accounts."""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class Tenant(Base):
    """
    Central registry of all tenant (shop) accounts.

    :ivar id: Primary key UUID
    :ivar name: Shop / business name
    :ivar slug: URL-safe unique identifier
    :ivar plan: Subscription plan tier
    :ivar is_active: Whether the tenant account is active
    :ivar created_at: Record creation timestamp
    :ivar updated_at: Last update timestamp
    """

    __tablename__ = "tenants"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    name: Mapped[str] = mapped_column(
        String(255), nullable=False
    )
    slug: Mapped[str] = mapped_column(
        String(100), nullable=False, unique=True
    )
    plan: Mapped[str] = mapped_column(
        String(50), nullable=False, server_default="starter"
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

    users: Mapped[list["User"]] = relationship(
        back_populates="tenant"
    )
    categories: Mapped[list["Category"]] = relationship(
        back_populates="tenant"
    )
    warehouses: Mapped[list["Warehouse"]] = relationship(
        back_populates="tenant"
    )
    products: Mapped[list["Product"]] = relationship(
        back_populates="tenant"
    )
