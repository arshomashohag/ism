"""AuditLog model — immutable record of all data mutations."""

import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class AuditLog(Base):
    """
    Immutable audit trail of every create/update/delete action.

    :ivar id: Primary key UUID
    :ivar tenant_id: Owning tenant
    :ivar user_id: Staff member who performed the action
    :ivar entity_type: Table name, e.g. 'products'
    :ivar entity_id: Primary key of the affected row
    :ivar action: create | update | delete | void
    :ivar old_value: JSONB snapshot before the change
    :ivar new_value: JSONB snapshot after the change
    :ivar created_at: When the action occurred
    """

    __tablename__ = "audit_log"

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
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    entity_type: Mapped[str] = mapped_column(
        String(50), nullable=False, index=True
    )
    entity_id: Mapped[str] = mapped_column(
        Text, nullable=False
    )
    action: Mapped[str] = mapped_column(
        String(20), nullable=False
    )
    old_value: Mapped[dict | None] = mapped_column(
        JSONB, nullable=True
    )
    new_value: Mapped[dict | None] = mapped_column(
        JSONB, nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        index=True,
    )

    user: Mapped["User | None"] = relationship(
        back_populates="audit_logs"
    )
