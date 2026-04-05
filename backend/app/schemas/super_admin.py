"""Super admin schemas — request/response models for /sadmin."""

import uuid
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


class WebAuthnRegisterKeyRequest(BaseModel):
    """
    Request body for initiating WebAuthn key registration.

    :ivar email: Super admin email address
    """

    email: str = Field(max_length=255)


class WebAuthnRegisterKeyChallenge(BaseModel):
    """
    Registration options returned to the client.

    :ivar options: WebAuthn PublicKeyCredentialCreationOptions dict
    :ivar challenge: Server-side challenge (opaque to client)
    """

    options: dict[str, Any]
    challenge: str


class WebAuthnRegisterKeyVerify(BaseModel):
    """
    Request body for verifying a registration response.

    :ivar email: Super admin email address
    :ivar credential: Raw WebAuthn credential from the authenticator
    :ivar challenge: Challenge returned from the initiation step
    :ivar origin: Expected request origin (must match the browser)
    """

    email: str = Field(max_length=255)
    credential: dict[str, Any]
    challenge: str
    origin: str


class WebAuthnAuthRequest(BaseModel):
    """
    Request body for initiating WebAuthn authentication.

    :ivar email: Super admin email address
    """

    email: str = Field(max_length=255)


class WebAuthnAuthChallenge(BaseModel):
    """
    Authentication options returned to the client.

    :ivar options: WebAuthn PublicKeyCredentialRequestOptions dict
    :ivar challenge: Server-side challenge (opaque to client)
    """

    options: dict[str, Any]
    challenge: str


class WebAuthnAuthVerify(BaseModel):
    """
    Request body for verifying an authentication assertion.

    :ivar email: Super admin email address
    :ivar credential: Raw WebAuthn credential from the authenticator
    :ivar challenge: Challenge returned from the initiation step
    :ivar origin: Expected request origin (must match the browser)
    """

    email: str = Field(max_length=255)
    credential: dict[str, Any]
    challenge: str
    origin: str


class SuperAdminTokenResponse(BaseModel):
    """
    Short-lived super admin JWT returned after successful auth.

    :ivar access_token: Signed JWT with role=super_admin
    :ivar token_type: Always "bearer"
    :ivar expires_in: Token lifetime in seconds
    """

    access_token: str
    token_type: str = "bearer"
    expires_in: int


class EcsTaskInfo(BaseModel):
    """
    Summary of a single ECS task.

    :ivar task_arn: Full ARN of the ECS task
    :ivar status: Last known task status string
    :ivar cpu: CPU units allocated
    :ivar memory: Memory (MiB) allocated
    """

    task_arn: str
    status: str
    cpu: str
    memory: str


class HealthResponse(BaseModel):
    """
    Platform health snapshot from ECS and RDS metrics.

    :ivar ecs_running_tasks: Count of running ECS tasks
    :ivar ecs_tasks: Per-task details
    :ivar rds_connections: Current active RDS connection count
    :ivar rds_connections_limit: Configured max_connections limit
    """

    ecs_running_tasks: int
    ecs_tasks: list[EcsTaskInfo]
    rds_connections: int
    rds_connections_limit: int


class SuperAdminTenantResponse(BaseModel):
    """
    Tenant record returned by super admin endpoints.

    :ivar id: Tenant UUID
    :ivar name: Display name
    :ivar slug: URL-safe identifier
    :ivar plan: Subscription plan
    :ivar is_active: Active / suspended flag
    :ivar schema_name: PostgreSQL schema name
    :ivar created_at: Provisioning timestamp
    """

    id: uuid.UUID
    name: str
    slug: str
    plan: str
    is_active: bool
    schema_name: str
    created_at: datetime

    model_config = {"from_attributes": True}


class SuperAdminTenantListResponse(BaseModel):
    """
    Paginated tenant list for the super admin panel.

    :ivar items: Tenant records on this page
    :ivar total: Total tenant count
    :ivar page: Current page (1-based)
    :ivar page_size: Items per page
    """

    items: list[SuperAdminTenantResponse]
    total: int
    page: int
    page_size: int


class SuperAdminTenantProvisionRequest(BaseModel):
    """
    Request body for provisioning a new tenant from the super admin panel.

    :ivar name: Human-readable shop name
    :ivar slug: URL-safe identifier
    :ivar plan: Subscription plan tier
    :ivar admin_email: Seeded admin user email
    :ivar admin_password: Seeded admin user password
    """

    name: str = Field(min_length=2, max_length=255)
    slug: str = Field(min_length=2, max_length=100)
    plan: str = Field(default="starter", max_length=50)
    admin_email: str = Field(max_length=255)
    admin_password: str = Field(min_length=8)


class SuperAdminTenantUpdateRequest(BaseModel):
    """
    Request body for updating a tenant's plan or status.

    :ivar plan: New subscription plan (optional)
    :ivar is_active: Active flag (optional)
    """

    plan: Optional[str] = Field(default=None, max_length=50)
    is_active: Optional[bool] = None


class AuditLogEntryResponse(BaseModel):
    """
    Single audit-log entry returned to the super admin panel.

    :ivar id: Entry UUID
    :ivar tenant_id: Owning tenant UUID
    :ivar user_id: Acting user UUID (may be null)
    :ivar entity_type: Affected table name
    :ivar entity_id: Affected row identifier
    :ivar action: create | update | delete | void
    :ivar created_at: When the action occurred
    """

    id: uuid.UUID
    tenant_id: Optional[uuid.UUID]
    user_id: Optional[uuid.UUID]
    entity_type: str
    entity_id: str
    action: str
    created_at: datetime

    model_config = {"from_attributes": True}


class AuditLogListResponse(BaseModel):
    """
    Paginated audit-log response.

    :ivar items: Log entries on this page
    :ivar total: Total matching entries
    :ivar page: Current page (1-based)
    :ivar page_size: Items per page
    """

    items: list[AuditLogEntryResponse]
    total: int
    page: int
    page_size: int
