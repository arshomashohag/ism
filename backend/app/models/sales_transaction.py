"""SalesTransaction model — completed point-of-sale transactions."""

import uuid
from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Numeric,
    String,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class SalesTransaction(Base):
    """
    A single completed sale at the point of sale.

    :ivar id: Primary key UUID (generated client-side for offline)
    :ivar tenant_id: Owning tenant
    :ivar invoice_number: Human-readable invoice ID (INV-YYYYMMDD-seq)
    :ivar salesman_id: Staff member who made the sale
    :ivar warehouse_id: POS location / stock source
    :ivar subtotal: Sum of all line item totals before tax/discount
    :ivar tax_total: Total tax computed from line items
    :ivar discount: Transaction-level discount applied
    :ivar grand_total: Final amount charged (subtotal + tax - discount)
    :ivar status: completed | voided
    :ivar device_id: Client device identifier for sync
    :ivar created_at: Client-generated sale timestamp
    :ivar synced_at: When the record was synced to server (null=offline)
    """

    __tablename__ = "sales_transactions"

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
    invoice_number: Mapped[str] = mapped_column(
        String(30), nullable=False, unique=True
    )
    salesman_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    warehouse_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("warehouses.id", ondelete="SET NULL"),
        nullable=True,
    )
    subtotal: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    tax_total: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    discount: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False, server_default="0"
    )
    grand_total: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default="completed"
    )
    device_id: Mapped[str] = mapped_column(
        String(100), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        index=True,
    )
    synced_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    salesman: Mapped["User | None"] = relationship(
        back_populates="sales_transactions"
    )
    warehouse: Mapped["Warehouse | None"] = relationship(
        back_populates="sales_transactions"
    )
    line_items: Mapped[list["SaleLineItem"]] = relationship(
        back_populates="transaction",
        cascade="all, delete-orphan",
    )
    payment: Mapped["Payment | None"] = relationship(
        back_populates="transaction",
        cascade="all, delete-orphan",
        uselist=False,
    )
