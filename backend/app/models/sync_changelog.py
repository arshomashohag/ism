"""SyncChangelog model — outbox for offline-first delta sync."""

import uuid
from datetime import datetime

from sqlalchemy import BigInteger, DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class SyncChangelog(Base):
    """
    Delta record queued for sync between client and server.

    :ivar id: Primary key UUID
    :ivar tenant_id: Owning tenant
    :ivar product_id: Product this change relates to
    :ivar entity_type: Table name of the changed entity
    :ivar operation: insert | update | delete
    :ivar delta: JSONB diff payload to apply
    :ivar hlc_timestamp: HLC at time of change (sync ordering key)
    :ivar device_id: Originating client device
    :ivar applied_at: When the server applied this change (null=pending)
    :ivar created_at: When the changelog entry was created
    """

    __tablename__ = "sync_changelog"

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
    product_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("products.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    entity_type: Mapped[str] = mapped_column(
        String(50), nullable=False
    )
    operation: Mapped[str] = mapped_column(
        String(10), nullable=False
    )
    delta: Mapped[dict] = mapped_column(JSONB, nullable=False)
    hlc_timestamp: Mapped[int] = mapped_column(
        BigInteger, nullable=False, index=True
    )
    device_id: Mapped[str] = mapped_column(
        String(100), nullable=False
    )
    applied_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    product: Mapped["Product | None"] = relationship(
        back_populates="sync_changelogs"
    )
