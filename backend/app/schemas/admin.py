"""Admin schemas — tenant provisioning request and response models."""

import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator


class TenantProvisionRequest(BaseModel):
    """
    Request body for provisioning a new tenant.

    :ivar name: Human-readable shop or business name
    :ivar slug: URL-safe lowercase identifier for the schema name
    :ivar plan: Subscription plan tier
    :ivar admin_email: Email address for the seeded admin user
    :ivar admin_password: Plain-text password for the seeded admin user
    """

    name: str = Field(min_length=2, max_length=255)
    slug: str = Field(min_length=2, max_length=100)
    plan: str = Field(default="starter", max_length=50)
    admin_email: str = Field(max_length=255)
    admin_password: str = Field(min_length=8)

    @field_validator("slug")
    @classmethod
    def slug_lowercase(cls, v: str) -> str:
        """
        Coerce the slug to lowercase.

        :param v: Raw slug value
        :return: Lowercased slug
        """
        return v.lower()

    @field_validator("admin_email")
    @classmethod
    def email_must_contain_at(cls, v: str) -> str:
        """
        Validate that the email contains an @ symbol.

        :param v: Raw email value
        :return: Validated email string
        :raises ValueError: If @ is not present
        """
        if "@" not in v:
            raise ValueError("admin_email must be a valid email address")
        return v.lower()


class TenantUpdateRequest(BaseModel):
    """
    Request body for updating a tenant's plan or status.

    All fields are optional — only provided fields are updated.

    :ivar plan: New subscription plan tier
    :ivar is_active: Whether the tenant should be active or suspended
    """

    plan: Optional[str] = Field(default=None, max_length=50)
    is_active: Optional[bool] = None


class TenantResponse(BaseModel):
    """
    Serialised tenant record returned by admin endpoints.

    :ivar id: Tenant primary key UUID
    :ivar name: Human-readable tenant name
    :ivar slug: URL-safe tenant identifier
    :ivar plan: Subscription plan tier
    :ivar is_active: Whether the tenant account is active
    :ivar schema_name: PostgreSQL schema name for the tenant
    :ivar created_at: Timestamp when the tenant was created
    """

    id: uuid.UUID
    name: str
    slug: str
    plan: str
    is_active: bool
    schema_name: str
    created_at: datetime

    model_config = {"from_attributes": True}


class TenantListResponse(BaseModel):
    """
    Paginated list of tenants.

    :ivar items: Tenant records for the current page
    :ivar total: Total number of tenants
    :ivar page: Current page number (1-based)
    :ivar page_size: Number of items per page
    """

    items: list[TenantResponse]
    total: int
    page: int
    page_size: int
