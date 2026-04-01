"""SyncConflict model — records where two clients diverged."""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class SyncConflict(Base):
    """
    Conflict record created when two devices edit the same entity.

    :ivar id: Primary key UUID
    :ivar tenant_id: Owning tenant
    :ivar entity_type: Table name of the conflicting entity
    :ivar entity_id: Primary key of the conflicting row
    :ivar version_a: Server-side version at conflict time
    :ivar version_b: Client-side version that caused conflict
    :ivar status: pending | resolved_a | resolved_b
    :ivar resolved_by_device: Device that resolved the conflict
    :ivar created_at: When the conflict was detected
    :ivar resolved_at: When the conflict was resolved
    """

    __tablename__ = "sync_conflicts"

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
    entity_type: Mapped[str] = mapped_column(
        String(50), nullable=False
    )
    entity_id: Mapped[str] = mapped_column(
        String(100), nullable=False
    )
    version_a: Mapped[dict] = mapped_column(JSONB, nullable=False)
    version_b: Mapped[dict] = mapped_column(JSONB, nullable=False)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default="pending"
    )
    resolved_by_device: Mapped[str | None] = mapped_column(
        String(100), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        index=True,
    )
    resolved_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
