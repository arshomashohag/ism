"""SaleLineItem model — individual product lines within a sale."""

import uuid

from sqlalchemy import ForeignKey, Integer, Numeric, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class SaleLineItem(Base):
    """
    One product line within a sales transaction.

    :ivar id: Primary key UUID
    :ivar transaction_id: Parent sales transaction
    :ivar product_id: Product sold
    :ivar product_name: Snapshot of product name at time of sale
    :ivar qty: Units sold
    :ivar unit_price: Price per unit at time of sale
    :ivar tax_rate: Tax rate applied at time of sale
    :ivar line_total: qty * unit_price (pre-tax)
    :ivar line_tax: Tax amount for this line
    """

    __tablename__ = "sale_line_items"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    transaction_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("sales_transactions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    product_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("products.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    product_name: Mapped[str] = mapped_column(
        String(255), nullable=False
    )
    qty: Mapped[int] = mapped_column(Integer, nullable=False)
    unit_price: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    tax_rate: Mapped[float] = mapped_column(
        Numeric(5, 4), nullable=False, server_default="0"
    )
    line_total: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    line_tax: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False, server_default="0"
    )

    transaction: Mapped["SalesTransaction"] = relationship(
        back_populates="line_items"
    )
    product: Mapped["Product | None"] = relationship(
        back_populates="sale_line_items"
    )
