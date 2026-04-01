"""Product model — sellable items in the catalogue."""

import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Numeric,
    String,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class Product(Base):
    """
    A sellable item belonging to a tenant's catalogue.

    :ivar id: Primary key UUID (generated client-side for offline)
    :ivar tenant_id: Owning tenant
    :ivar category_id: Optional product category
    :ivar sku: Stock-keeping unit, unique within tenant
    :ivar name: Product name, full-text indexed
    :ivar barcode: EAN-13 or custom barcode
    :ivar unit_price: Selling price (must be > 0)
    :ivar cost_price: Purchase / landed cost
    :ivar tax_rate: VAT/GST rate, e.g. 0.075 for 7.5%
    :ivar metadata: Flexible JSONB attributes (colour, size, etc.)
    :ivar is_hub_shared: Opt-in flag for Product Hub
    :ivar is_active: Soft-delete flag
    :ivar hlc_timestamp: Hybrid Logical Clock for sync ordering
    :ivar created_at: Record creation timestamp
    :ivar updated_at: Last update timestamp
    """

    __tablename__ = "products"
    __table_args__ = (
        CheckConstraint(
            "unit_price > 0",
            name="ck_products_unit_price_positive",
        ),
        CheckConstraint(
            "cost_price >= 0 OR cost_price IS NULL",
            name="ck_products_cost_price_nonneg",
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
    category_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("categories.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    sku: Mapped[str] = mapped_column(
        String(50), nullable=False
    )
    name: Mapped[str] = mapped_column(
        String(255), nullable=False
    )
    barcode: Mapped[str | None] = mapped_column(
        String(100), nullable=True, index=True
    )
    unit_price: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    cost_price: Mapped[float | None] = mapped_column(
        Numeric(12, 2), nullable=True
    )
    tax_rate: Mapped[float] = mapped_column(
        Numeric(5, 4), nullable=False, server_default="0"
    )
    metadata_: Mapped[dict] = mapped_column(
        "metadata",
        JSONB,
        nullable=False,
        server_default=text("'{}'"),
    )
    is_hub_shared: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="false"
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default="true"
    )
    hlc_timestamp: Mapped[int] = mapped_column(
        BigInteger, nullable=False, server_default="0"
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
        back_populates="products"
    )
    category: Mapped["Category | None"] = relationship(
        back_populates="products"
    )
    inventory_entries: Mapped[list["Inventory"]] = relationship(
        back_populates="product"
    )
    sale_line_items: Mapped[list["SaleLineItem"]] = relationship(
        back_populates="product"
    )
    sync_changelogs: Mapped[list["SyncChangelog"]] = relationship(
        back_populates="product"
    )
