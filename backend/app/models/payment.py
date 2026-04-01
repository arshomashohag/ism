"""Payment model — payment record for a sales transaction."""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Numeric, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class Payment(Base):
    """
    Payment record attached to a single sales transaction.

    :ivar id: Primary key UUID
    :ivar transaction_id: Parent sales transaction (one-to-one)
    :ivar method: cash | card | mobile
    :ivar amount_tendered: Amount given by the customer
    :ivar change_given: Change returned (cash payments only)
    :ivar reference: Card terminal / mobile reference number
    :ivar paid_at: Timestamp payment was received
    """

    __tablename__ = "payments"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    transaction_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("sales_transactions.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    method: Mapped[str] = mapped_column(
        String(20), nullable=False
    )
    amount_tendered: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False
    )
    change_given: Mapped[float] = mapped_column(
        Numeric(12, 2), nullable=False, server_default="0"
    )
    reference: Mapped[str | None] = mapped_column(
        String(100), nullable=True
    )
    paid_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    transaction: Mapped["SalesTransaction"] = relationship(
        back_populates="payment"
    )
