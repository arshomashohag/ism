"""Admin router — tenant provisioning and management endpoints."""

import logging
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.dependencies import get_admin_db, require_admin_key
from app.models.tenant import Tenant
from app.schemas.admin import (
    TenantListResponse,
    TenantProvisionRequest,
    TenantResponse,
    TenantUpdateRequest,
)
from app.services.tenant_provisioner import TenantProvisioner

logger = logging.getLogger("ims.admin")

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/tenants/public", response_model=list[str])
def list_tenant_slugs(
    db: Session = Depends(get_admin_db),
) -> Any:
    """
    Return a list of active tenant slugs (public, no auth required).

    Used by the Flutter login screen to populate the tenant selector.

    :param db: Admin database session
    :return: List of active tenant slug strings
    """
    rows = (
        db.query(Tenant.slug)
        .filter(Tenant.is_active.is_(True))
        .order_by(Tenant.name)
        .all()
    )
    return [r.slug for r in rows]


@router.post(
    "/tenants",
    response_model=TenantResponse,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_admin_key)],
)
def provision_tenant(
    body: TenantProvisionRequest,
    db: Session = Depends(get_admin_db),
) -> Any:
    """
    Provision a new tenant with an isolated PostgreSQL schema.

    Creates the schema, runs migrations, and seeds an admin user
    and default warehouse. Requires a valid X-Admin-Key header.

    :param body: Tenant provisioning request
    :param db: Admin database session
    :return: Newly created tenant record
    :raises HTTPException: 409 if slug is already taken
    :raises HTTPException: 422 if slug format is invalid
    """
    provisioner = TenantProvisioner(db)
    try:
        provisioner.provision(
            name=body.name,
            slug=body.slug,
            plan=body.plan,
            admin_email=body.admin_email,
            admin_password=body.admin_password,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc

    tenant = (
        db.query(Tenant).filter(Tenant.slug == body.slug).first()
    )
    return tenant


@router.get(
    "/tenants",
    response_model=TenantListResponse,
    dependencies=[Depends(require_admin_key)],
)
def list_tenants(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_admin_db),
) -> Any:
    """
    Return a paginated list of all tenants.

    :param page: Page number (1-based)
    :param page_size: Number of items per page
    :param db: Admin database session
    :return: Paginated tenant list
    """
    total = db.query(func.count(Tenant.id)).scalar() or 0
    items = (
        db.query(Tenant)
        .order_by(Tenant.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return TenantListResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get(
    "/tenants/{slug}",
    response_model=TenantResponse,
    dependencies=[Depends(require_admin_key)],
)
def get_tenant(
    slug: str,
    db: Session = Depends(get_admin_db),
) -> Any:
    """
    Return a single tenant by slug.

    :param slug: Tenant URL-safe identifier
    :param db: Admin database session
    :return: Tenant record
    :raises HTTPException: 404 if tenant not found
    """
    tenant = db.query(Tenant).filter(Tenant.slug == slug).first()
    if tenant is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Tenant '{slug}' not found",
        )
    return tenant


@router.patch(
    "/tenants/{slug}",
    response_model=TenantResponse,
    dependencies=[Depends(require_admin_key)],
)
def update_tenant(
    slug: str,
    body: TenantUpdateRequest,
    db: Session = Depends(get_admin_db),
) -> Any:
    """
    Update a tenant's plan or active/suspended status.

    :param slug: Tenant URL-safe identifier
    :param body: Fields to update (plan, is_active)
    :param db: Admin database session
    :return: Updated tenant record
    :raises HTTPException: 404 if tenant not found
    """
    tenant = db.query(Tenant).filter(Tenant.slug == slug).first()
    if tenant is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Tenant '{slug}' not found",
        )
    if body.plan is not None:
        tenant.plan = body.plan
    if body.is_active is not None:
        tenant.is_active = body.is_active
    db.commit()
    db.refresh(tenant)

    logger.info(
        "Tenant updated",
        extra={
            "slug": slug,
            "plan": body.plan,
            "is_active": body.is_active,
        },
    )
    return tenant


@router.post(
    "/tenants/{slug}/migrate",
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_admin_key)],
)
def migrate_tenant(
    slug: str,
    db: Session = Depends(get_admin_db),
) -> dict:
    """
    Run Alembic upgrade head on a specific tenant schema.

    :param slug: Tenant URL-safe identifier
    :param db: Admin database session
    :return: Success message dict
    :raises HTTPException: 404 if tenant not found
    """
    tenant = db.query(Tenant).filter(Tenant.slug == slug).first()
    if tenant is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Tenant '{slug}' not found",
        )

    provisioner = TenantProvisioner(db)
    provisioner._run_migrations(slug)

    logger.info("Tenant migration run", extra={"slug": slug})
    return {"detail": f"Migration completed for tenant '{slug}'"}
