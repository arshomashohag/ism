"""Super admin router — /sadmin endpoints for platform management."""

import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

import boto3
from botocore.exceptions import ClientError
from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy import func, text
from sqlalchemy.orm import Session

from app.config import settings
from app.dependencies import get_admin_db
from app.models.audit_log import AuditLog
from app.models.super_admin import SuperAdmin
from app.models.tenant import Tenant
from app.schemas.super_admin import (
    AuditLogListResponse,
    EcsTaskInfo,
    HealthResponse,
    SuperAdminTenantListResponse,
    SuperAdminTenantProvisionRequest,
    SuperAdminTenantResponse,
    SuperAdminTenantUpdateRequest,
    SuperAdminTokenResponse,
    WebAuthnAuthChallenge,
    WebAuthnAuthRequest,
    WebAuthnAuthVerify,
    WebAuthnRegisterKeyChallenge,
    WebAuthnRegisterKeyRequest,
    WebAuthnRegisterKeyVerify,
)
from app.services.tenant_provisioner import TenantProvisioner
from app.services.webauthn import WebAuthnService

logger = logging.getLogger("ims.super_admin")

router = APIRouter(prefix="/sadmin", tags=["super-admin"])

_bearer_scheme = HTTPBearer()

_SUPER_ADMIN_TOKEN_EXPIRE_MINUTES = 15
_SUPER_ADMIN_ROLE = "super_admin"

_webauthn = WebAuthnService()


def _issue_super_admin_token(email: str) -> str:
    """
    Issue a short-lived JWT with role=super_admin.

    :param email: Super admin email to embed as subject
    :return: Signed JWT string
    """
    now = datetime.now(tz=timezone.utc)
    expire = now + timedelta(
        minutes=_SUPER_ADMIN_TOKEN_EXPIRE_MINUTES
    )
    payload = {
        "sub": email,
        "role": _SUPER_ADMIN_ROLE,
        "iat": now,
        "exp": expire,
    }
    return jwt.encode(
        payload,
        settings.jwt_private_key,
        algorithm="RS256",
    )


def _require_super_admin(
    credentials: HTTPAuthorizationCredentials = Depends(
        _bearer_scheme
    ),
) -> str:
    """
    Validate the super admin JWT and return the email subject.

    :param credentials: Bearer credentials from the Authorization header
    :return: Super admin email extracted from token subject
    :raises HTTPException: 401 if token is invalid or has wrong role
    """
    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.jwt_public_key,
            algorithms=["RS256"],
        )
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired super admin token",
        ) from exc

    if payload.get("role") != _SUPER_ADMIN_ROLE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient privileges",
        )
    return payload["sub"]


def _get_super_admin_or_404(
    email: str, db: Session
) -> SuperAdmin:
    """
    Fetch a SuperAdmin record by email or raise 404.

    :param email: Super admin email
    :param db: Database session
    :return: SuperAdmin model instance
    :raises HTTPException: 404 if not found or inactive
    """
    admin = (
        db.query(SuperAdmin)
        .filter(
            SuperAdmin.email == email,
            SuperAdmin.is_active.is_(True),
        )
        .first()
    )
    if admin is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Super admin not found",
        )
    return admin


@router.post(
    "/auth/register-key",
    response_model=WebAuthnRegisterKeyChallenge,
    status_code=status.HTTP_200_OK,
)
def register_key_initiate(
    body: WebAuthnRegisterKeyRequest,
    db: Session = Depends(get_admin_db),
) -> Any:
    """
    Initiate WebAuthn key registration for a super admin.

    Creates the super admin record if it doesn't exist and returns
    WebAuthn registration options to the client.

    :param body: Registration initiation request with email
    :param db: Admin database session
    :return: WebAuthn registration options and challenge
    """
    existing = (
        db.query(SuperAdmin)
        .filter(SuperAdmin.email == body.email)
        .first()
    )
    if existing is None:
        admin = SuperAdmin(email=body.email)
        db.add(admin)
        db.commit()
        db.refresh(admin)
        logger.info(
            "Super admin created",
            extra={"email": body.email},
        )

    options, challenge = _webauthn.generate_registration_options(
        email=body.email
    )
    return WebAuthnRegisterKeyChallenge(
        options=options, challenge=challenge
    )


@router.post(
    "/auth/verify-registration",
    response_model=SuperAdminTokenResponse,
    status_code=status.HTTP_200_OK,
)
def register_key_verify(
    body: WebAuthnRegisterKeyVerify,
    db: Session = Depends(get_admin_db),
) -> Any:
    """
    Complete WebAuthn registration and store the credential.

    :param body: Verification payload with credential and challenge
    :param db: Admin database session
    :return: Short-lived super admin JWT
    :raises HTTPException: 400 if WebAuthn verification fails
    :raises HTTPException: 404 if super admin record not found
    """
    admin = (
        db.query(SuperAdmin)
        .filter(SuperAdmin.email == body.email)
        .first()
    )
    if admin is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Super admin not found",
        )

    try:
        stored = _webauthn.verify_registration(
            credential_json=body.credential,
            expected_challenge_b64=body.challenge,
            expected_origin=body.origin,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    admin.webauthn_credential = stored
    admin.last_login = datetime.now(tz=timezone.utc)
    db.commit()

    token = _issue_super_admin_token(body.email)
    return SuperAdminTokenResponse(
        access_token=token,
        expires_in=_SUPER_ADMIN_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.post(
    "/auth/authenticate",
    response_model=WebAuthnAuthChallenge,
    status_code=status.HTTP_200_OK,
)
def auth_initiate(
    body: WebAuthnAuthRequest,
    db: Session = Depends(get_admin_db),
) -> Any:
    """
    Initiate WebAuthn authentication for a super admin.

    :param body: Authentication initiation request with email
    :param db: Admin database session
    :return: WebAuthn authentication options and challenge
    :raises HTTPException: 404 if admin not found or has no key
    """
    admin = _get_super_admin_or_404(body.email, db)
    if not admin.webauthn_credential:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No registered hardware key found",
        )

    credential_id = admin.webauthn_credential["credential_id"]
    options, challenge = (
        _webauthn.generate_authentication_options(
            credential_id_b64=credential_id
        )
    )
    return WebAuthnAuthChallenge(
        options=options, challenge=challenge
    )


@router.post(
    "/auth/verify-authentication",
    response_model=SuperAdminTokenResponse,
    status_code=status.HTTP_200_OK,
)
def auth_verify(
    body: WebAuthnAuthVerify,
    db: Session = Depends(get_admin_db),
) -> Any:
    """
    Verify WebAuthn authentication assertion and issue a JWT.

    :param body: Verification payload with credential and challenge
    :param db: Admin database session
    :return: Short-lived super admin JWT
    :raises HTTPException: 400 if verification fails
    :raises HTTPException: 404 if admin not found or has no key
    """
    admin = _get_super_admin_or_404(body.email, db)
    if not admin.webauthn_credential:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No registered hardware key found",
        )

    try:
        new_sign_count = _webauthn.verify_authentication(
            credential_json=body.credential,
            expected_challenge_b64=body.challenge,
            expected_origin=body.origin,
            stored_credential=admin.webauthn_credential,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc

    updated_credential = dict(admin.webauthn_credential)
    updated_credential["sign_count"] = new_sign_count
    admin.webauthn_credential = updated_credential
    admin.last_login = datetime.now(tz=timezone.utc)
    db.commit()

    logger.info(
        "Super admin authenticated",
        extra={"email": body.email},
    )
    token = _issue_super_admin_token(body.email)
    return SuperAdminTokenResponse(
        access_token=token,
        expires_in=_SUPER_ADMIN_TOKEN_EXPIRE_MINUTES * 60,
    )


@router.get(
    "/health",
    response_model=HealthResponse,
)
def health(
    _email: str = Depends(_require_super_admin),
) -> Any:
    """
    Return platform health metrics from ECS and RDS.

    Queries AWS ECS for running task count and CloudWatch for the
    active RDS connection count. Falls back to zeros on any AWS
    error to keep the endpoint operational in local development.

    :param _email: Authenticated super admin email (from token)
    :return: Health snapshot including ECS tasks and RDS connections
    """
    ecs_tasks: list[EcsTaskInfo] = []
    rds_connections = 0
    rds_limit = 0

    try:
        ecs = boto3.client(
            "ecs", region_name=settings.aws_region
        )
        cluster = settings.ecs_cluster_name
        task_arns = ecs.list_tasks(
            cluster=cluster, desiredStatus="RUNNING"
        ).get("taskArns", [])

        if task_arns:
            described = ecs.describe_tasks(
                cluster=cluster, tasks=task_arns
            ).get("tasks", [])
            for task in described:
                container = (
                    task.get("containers", [{}])[0]
                )
                ecs_tasks.append(
                    EcsTaskInfo(
                        task_arn=task.get("taskArn", ""),
                        status=task.get("lastStatus", ""),
                        cpu=task.get("cpu", ""),
                        memory=task.get("memory", ""),
                    )
                )
    except (ClientError, Exception) as exc:
        logger.warning(
            "ECS health query failed",
            extra={"error": str(exc)},
        )

    try:
        cw = boto3.client(
            "cloudwatch", region_name=settings.aws_region
        )
        metric = cw.get_metric_statistics(
            Namespace="AWS/RDS",
            MetricName="DatabaseConnections",
            Dimensions=[
                {
                    "Name": "DBInstanceIdentifier",
                    "Value": settings.rds_instance_id,
                }
            ],
            StartTime=datetime.now(tz=timezone.utc)
            - timedelta(minutes=5),
            EndTime=datetime.now(tz=timezone.utc),
            Period=300,
            Statistics=["Average"],
        )
        datapoints = metric.get("Datapoints", [])
        if datapoints:
            rds_connections = int(
                datapoints[-1].get("Average", 0)
            )
    except (ClientError, Exception) as exc:
        logger.warning(
            "RDS connection metric query failed",
            extra={"error": str(exc)},
        )

    return HealthResponse(
        ecs_running_tasks=len(ecs_tasks),
        ecs_tasks=ecs_tasks,
        rds_connections=rds_connections,
        rds_connections_limit=rds_limit,
    )


@router.get(
    "/tenants",
    response_model=SuperAdminTenantListResponse,
)
def list_tenants(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    _email: str = Depends(_require_super_admin),
    db: Session = Depends(get_admin_db),
) -> Any:
    """
    Return a paginated list of all tenants.

    :param page: Page number (1-based)
    :param page_size: Items per page
    :param _email: Authenticated super admin email (from token)
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
    return SuperAdminTenantListResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
    )


@router.post(
    "/tenants",
    response_model=SuperAdminTenantResponse,
    status_code=status.HTTP_201_CREATED,
)
def provision_tenant(
    body: SuperAdminTenantProvisionRequest,
    _email: str = Depends(_require_super_admin),
    db: Session = Depends(get_admin_db),
) -> Any:
    """
    Provision a new tenant from the super admin panel.

    :param body: Tenant provisioning details
    :param _email: Authenticated super admin email (from token)
    :param db: Admin database session
    :return: Newly created tenant record
    :raises HTTPException: 409 if slug already taken
    :raises HTTPException: 422 if provisioning parameters invalid
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
    logger.info(
        "Tenant provisioned via super admin",
        extra={"slug": body.slug, "by": _email},
    )
    return tenant


@router.patch(
    "/tenants/{slug}",
    response_model=SuperAdminTenantResponse,
)
def update_tenant(
    slug: str,
    body: SuperAdminTenantUpdateRequest,
    _email: str = Depends(_require_super_admin),
    db: Session = Depends(get_admin_db),
) -> Any:
    """
    Update a tenant's plan or active/suspended status.

    :param slug: Tenant URL-safe identifier
    :param body: Fields to update
    :param _email: Authenticated super admin email (from token)
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
        "Tenant updated via super admin",
        extra={
            "slug": slug,
            "plan": body.plan,
            "is_active": body.is_active,
            "by": _email,
        },
    )
    return tenant


@router.post(
    "/tenants/{slug}/migrate",
    status_code=status.HTTP_200_OK,
)
def migrate_tenant(
    slug: str,
    _email: str = Depends(_require_super_admin),
    db: Session = Depends(get_admin_db),
) -> dict:
    """
    Run Alembic upgrade head on a specific tenant schema.

    :param slug: Tenant URL-safe identifier
    :param _email: Authenticated super admin email (from token)
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
    logger.info(
        "Tenant migrated via super admin",
        extra={"slug": slug, "by": _email},
    )
    return {"detail": f"Migration completed for tenant '{slug}'"}


@router.get(
    "/audit-log",
    response_model=AuditLogListResponse,
)
def get_audit_log(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    entity_type: Optional[str] = Query(default=None),
    action: Optional[str] = Query(default=None),
    tenant_id: Optional[str] = Query(default=None),
    _email: str = Depends(_require_super_admin),
    db: Session = Depends(get_admin_db),
) -> Any:
    """
    Return a paginated, filterable audit log across all tenants.

    Queries the public-schema audit_log if it exists; otherwise
    returns an empty result set (per-tenant schemas have their own
    audit_log tables, queried separately here via search_path).

    :param page: Page number (1-based)
    :param page_size: Items per page
    :param entity_type: Filter by entity table name (optional)
    :param action: Filter by action type (optional)
    :param tenant_id: Filter by tenant UUID string (optional)
    :param _email: Authenticated super admin email (from token)
    :param db: Admin database session
    :return: Paginated audit log entries
    """
    query = db.query(AuditLog)

    if entity_type:
        query = query.filter(
            AuditLog.entity_type == entity_type
        )
    if action:
        query = query.filter(AuditLog.action == action)

    total = query.with_entities(
        func.count(AuditLog.id)
    ).scalar() or 0

    items = (
        query.order_by(AuditLog.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return AuditLogListResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
    )
