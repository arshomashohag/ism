"""Warehouse model — physical stock locations."""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class Warehouse(Base):
    """
    Physical location where inventory is stored.

    :ivar id: Primary key UUID
    :ivar tenant_id: Owning tenant
    :ivar name: Warehouse display name
    :ivar address: Physical address (optional)
    :ivar is_active: Soft-disable flag
    :ivar created_at: Record creation timestamp
    """

    __tablename__ = "warehouses"

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
        String(100), nullable=False
    )
    address: Mapped[str | None] = mapped_column(
        String(500), nullable=True
    )
    is_active: Mapped[bool] = mapped_column(
        nullable=False, server_default="true"
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    tenant: Mapped["Tenant"] = relationship(
        back_populates="warehouses"
    )
    inventory_entries: Mapped[list["Inventory"]] = relationship(
        back_populates="warehouse"
    )
    sales_transactions: Mapped[list["SalesTransaction"]] = (
        relationship(back_populates="warehouse")
    )
