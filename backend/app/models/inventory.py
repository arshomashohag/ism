"""Inventory model — stock levels per product per warehouse."""

import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    DateTime,
    ForeignKey,
    Integer,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class Inventory(Base):
    """
    Current stock level for one product at one warehouse.

    :ivar id: Primary key UUID
    :ivar product_id: Product being tracked
    :ivar warehouse_id: Storage location
    :ivar qty_on_hand: Current available units
    :ivar qty_reserved: Units held for pending orders
    :ivar reorder_point: Alert threshold (qty below triggers alert)
    :ivar hlc_timestamp: Hybrid Logical Clock for sync ordering
    :ivar last_counted_at: Timestamp of most recent physical count
    """

    __tablename__ = "inventory"
    __table_args__ = (
        UniqueConstraint(
            "product_id",
            "warehouse_id",
            name="uq_inventory_product_warehouse",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    product_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("products.id", ondelete="CASCADE"),
        nullable=False,
    )
    warehouse_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("warehouses.id", ondelete="CASCADE"),
        nullable=False,
    )
    qty_on_hand: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default="0"
    )
    qty_reserved: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default="0"
    )
    reorder_point: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default="0"
    )
    hlc_timestamp: Mapped[int] = mapped_column(
        BigInteger, nullable=False, server_default="0"
    )
    last_counted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    product: Mapped["Product"] = relationship(
        back_populates="inventory_entries"
    )
    warehouse: Mapped["Warehouse"] = relationship(
        back_populates="inventory_entries"
    )
