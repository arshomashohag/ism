"""AuditService — records immutable create/update/delete events."""

import uuid
from typing import Any

from sqlalchemy.orm import Session

from app.models.audit_log import AuditLog


class AuditService:
    """
    Records mutations to the audit_log table.

    All methods are static and add a row to the session without
    committing — the caller is responsible for db.commit().
    """

    @staticmethod
    def log_create(
        db: Session,
        tenant_id: uuid.UUID,
        user_id: uuid.UUID,
        entity_type: str,
        entity_id: str,
        new_value: dict[str, Any],
    ) -> None:
        """
        Record a create action in the audit log.

        :param db: Database session
        :param tenant_id: Owning tenant UUID
        :param user_id: User performing the action
        :param entity_type: Table name, e.g. 'products'
        :param entity_id: Primary key of the created row
        :param new_value: JSONB snapshot of the new record
        :return: None
        """
        db.add(
            AuditLog(
                id=uuid.uuid4(),
                tenant_id=tenant_id,
                user_id=user_id,
                entity_type=entity_type,
                entity_id=entity_id,
                action="create",
                old_value=None,
                new_value=new_value,
            )
        )

    @staticmethod
    def log_update(
        db: Session,
        tenant_id: uuid.UUID,
        user_id: uuid.UUID,
        entity_type: str,
        entity_id: str,
        old_value: dict[str, Any],
        new_value: dict[str, Any],
    ) -> None:
        """
        Record an update action in the audit log.

        :param db: Database session
        :param tenant_id: Owning tenant UUID
        :param user_id: User performing the action
        :param entity_type: Table name, e.g. 'products'
        :param entity_id: Primary key of the updated row
        :param old_value: JSONB snapshot before the change
        :param new_value: JSONB snapshot after the change
        :return: None
        """
        db.add(
            AuditLog(
                id=uuid.uuid4(),
                tenant_id=tenant_id,
                user_id=user_id,
                entity_type=entity_type,
                entity_id=entity_id,
                action="update",
                old_value=old_value,
                new_value=new_value,
            )
        )

    @staticmethod
    def log_delete(
        db: Session,
        tenant_id: uuid.UUID,
        user_id: uuid.UUID,
        entity_type: str,
        entity_id: str,
        old_value: dict[str, Any],
    ) -> None:
        """
        Record a delete action in the audit log.

        :param db: Database session
        :param tenant_id: Owning tenant UUID
        :param user_id: User performing the action
        :param entity_type: Table name, e.g. 'products'
        :param entity_id: Primary key of the deleted row
        :param old_value: JSONB snapshot of the row before deletion
        :return: None
        """
        db.add(
            AuditLog(
                id=uuid.uuid4(),
                tenant_id=tenant_id,
                user_id=user_id,
                entity_type=entity_type,
                entity_id=entity_id,
                action="delete",
                old_value=old_value,
                new_value=None,
            )
        )
