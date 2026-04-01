"""Inventory router — stock levels, adjustments, transfers, counts."""

import uuid
from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.dependencies import get_current_user, get_db, require_role
from app.models.inventory import Inventory
from app.models.product import Product
from app.models.warehouse import Warehouse
from app.schemas.auth import CurrentUser
from app.schemas.inventory import (
    AdjustRequest,
    AlertResponse,
    CountRequest,
    InventoryListResponse,
    InventoryResponse,
    TransferRequest,
    WarehouseResponse,
)
from app.services.audit import AuditService

router = APIRouter(prefix="/inventory", tags=["inventory"])


def _stock_status(
    qty_on_hand: int, reorder_point: int
) -> Literal["ok", "low", "out"]:
    """
    Derive stock health label from quantity and reorder point.

    :param qty_on_hand: Current on-hand quantity
    :param reorder_point: Low-stock threshold
    :return: 'out', 'low', or 'ok'
    """
    if qty_on_hand <= 0:
        return "out"
    if qty_on_hand <= reorder_point:
        return "low"
    return "ok"


def _to_response(
    inv: Inventory,
    product: Product,
    warehouse: Warehouse,
) -> InventoryResponse:
    """
    Build an InventoryResponse from ORM instances.

    :param inv: Inventory ORM instance
    :param product: Related Product ORM instance
    :param warehouse: Related Warehouse ORM instance
    :return: InventoryResponse
    """
    available = inv.qty_on_hand - inv.qty_reserved
    return InventoryResponse(
        id=inv.id,
        product_id=inv.product_id,
        product_name=product.name,
        product_sku=product.sku,
        warehouse_id=inv.warehouse_id,
        warehouse_name=warehouse.name,
        qty_on_hand=inv.qty_on_hand,
        qty_reserved=inv.qty_reserved,
        qty_available=available,
        reorder_point=inv.reorder_point,
        stock_status=_stock_status(
            inv.qty_on_hand, inv.reorder_point
        ),
        last_counted_at=inv.last_counted_at,
    )


def _get_inventory_entry(
    db: Session,
    product_id: uuid.UUID,
    warehouse_id: uuid.UUID,
    tenant_id: uuid.UUID,
) -> Inventory:
    """
    Fetch an inventory entry, verifying tenant ownership.

    :param db: Database session
    :param product_id: Product UUID
    :param warehouse_id: Warehouse UUID
    :param tenant_id: Tenant UUID for ownership check
    :return: Inventory ORM instance
    :raises HTTPException: 404 if not found or wrong tenant
    """
    inv = (
        db.query(Inventory)
        .join(Product, Inventory.product_id == Product.id)
        .join(Warehouse, Inventory.warehouse_id == Warehouse.id)
        .filter(
            Inventory.product_id == product_id,
            Inventory.warehouse_id == warehouse_id,
            Product.tenant_id == tenant_id,
            Product.is_active.is_(True),
        )
        .first()
    )
    if inv is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Inventory entry not found",
        )
    return inv


@router.get("/warehouses", response_model=list[WarehouseResponse])
def list_warehouses(
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[WarehouseResponse]:
    """
    Return all active warehouses for the tenant.

    :param current_user: Injected JWT context
    :param db: Database session
    :return: List of WarehouseResponse objects
    """
    warehouses = (
        db.query(Warehouse)
        .filter(
            Warehouse.tenant_id == current_user.tenant_id,
            Warehouse.is_active.is_(True),
        )
        .order_by(Warehouse.name)
        .all()
    )
    return [
        WarehouseResponse(
            id=w.id,
            name=w.name,
            is_active=w.is_active,
        )
        for w in warehouses
    ]


@router.get("/", response_model=InventoryListResponse)
def list_inventory(
    warehouse_id: uuid.UUID | None = Query(default=None),
    low_stock: bool = Query(default=False),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=50, ge=1, le=200),
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> InventoryListResponse:
    """
    Return paginated inventory entries for the tenant.

    Optionally filter by warehouse or to show only low/out-of-stock
    items.

    :param warehouse_id: Optional warehouse UUID filter
    :param low_stock: If True, return only low or out-of-stock entries
    :param page: Page number (1-based)
    :param page_size: Items per page (max 200)
    :param current_user: Injected JWT context
    :param db: Database session
    :return: Paginated InventoryListResponse
    """
    query = (
        db.query(Inventory)
        .join(Product, Inventory.product_id == Product.id)
        .join(Warehouse, Inventory.warehouse_id == Warehouse.id)
        .filter(
            Product.tenant_id == current_user.tenant_id,
            Product.is_active.is_(True),
            Warehouse.is_active.is_(True),
        )
    )

    if warehouse_id is not None:
        query = query.filter(
            Inventory.warehouse_id == warehouse_id
        )

    if low_stock:
        query = query.filter(
            Inventory.qty_on_hand <= Inventory.reorder_point
        )

    total = query.count()
    entries = (
        query.order_by(Product.name)
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    items = [
        _to_response(inv, inv.product, inv.warehouse)
        for inv in entries
    ]

    return InventoryListResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
    )


@router.post("/adjust", response_model=InventoryResponse)
def adjust_stock(
    body: AdjustRequest,
    current_user: CurrentUser = Depends(
        require_role("admin", "manager")
    ),
    db: Session = Depends(get_db),
) -> InventoryResponse:
    """
    Apply a signed delta adjustment to stock on hand.

    Uses delta (not absolute) to avoid race conditions.

    :param body: Adjustment payload with warehouse, product, delta,
        reason
    :param current_user: Injected JWT context (admin/manager only)
    :param db: Database session
    :return: Updated InventoryResponse
    :raises HTTPException: 404 if inventory entry not found
    :raises HTTPException: 422 if resulting qty would be negative
    """
    inv = _get_inventory_entry(
        db,
        body.product_id,
        body.warehouse_id,
        current_user.tenant_id,
    )

    new_qty = inv.qty_on_hand + body.delta
    if new_qty < 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                f"Insufficient stock: on_hand={inv.qty_on_hand}, "
                f"delta={body.delta}"
            ),
        )

    old_qty = inv.qty_on_hand
    inv.qty_on_hand = new_qty

    AuditService.log_update(
        db=db,
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        entity_type="inventory",
        entity_id=str(inv.id),
        old_value={
            "qty_on_hand": old_qty,
            "reason": body.reason,
        },
        new_value={
            "qty_on_hand": new_qty,
            "delta": body.delta,
            "reason": body.reason,
        },
    )

    db.commit()
    db.refresh(inv)
    return _to_response(inv, inv.product, inv.warehouse)


@router.post("/transfer", response_model=list[InventoryResponse])
def transfer_stock(
    body: TransferRequest,
    current_user: CurrentUser = Depends(
        require_role("admin", "manager")
    ),
    db: Session = Depends(get_db),
) -> list[InventoryResponse]:
    """
    Move stock atomically from one warehouse to another.

    Decrements source and increments destination in a single
    transaction.

    :param body: Transfer payload with product, warehouses, qty, reason
    :param current_user: Injected JWT context (admin/manager only)
    :param db: Database session
    :return: List of two updated InventoryResponse objects
        [source, destination]
    :raises HTTPException: 404 if either inventory entry not found
    :raises HTTPException: 422 if source has insufficient stock
    """
    src = _get_inventory_entry(
        db,
        body.product_id,
        body.from_warehouse_id,
        current_user.tenant_id,
    )
    dst = _get_inventory_entry(
        db,
        body.product_id,
        body.to_warehouse_id,
        current_user.tenant_id,
    )

    if src.qty_on_hand < body.qty:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                f"Insufficient stock in source warehouse: "
                f"on_hand={src.qty_on_hand}, requested={body.qty}"
            ),
        )

    src.qty_on_hand -= body.qty
    dst.qty_on_hand += body.qty

    AuditService.log_update(
        db=db,
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        entity_type="inventory_transfer",
        entity_id=str(body.product_id),
        old_value={
            "from_warehouse": str(body.from_warehouse_id),
            "to_warehouse": str(body.to_warehouse_id),
            "qty": body.qty,
        },
        new_value={
            "reason": body.reason,
            "src_qty_after": src.qty_on_hand,
            "dst_qty_after": dst.qty_on_hand,
        },
    )

    db.commit()
    db.refresh(src)
    db.refresh(dst)
    return [
        _to_response(src, src.product, src.warehouse),
        _to_response(dst, dst.product, dst.warehouse),
    ]


@router.post("/count", response_model=InventoryResponse)
def record_count(
    body: CountRequest,
    current_user: CurrentUser = Depends(
        require_role("admin", "manager")
    ),
    db: Session = Depends(get_db),
) -> InventoryResponse:
    """
    Record the result of a physical stock count (absolute quantity).

    Sets qty_on_hand to the counted value and records the timestamp.

    :param body: Count payload with warehouse, product, counted_qty
    :param current_user: Injected JWT context (admin/manager only)
    :param db: Database session
    :return: Updated InventoryResponse
    :raises HTTPException: 404 if inventory entry not found
    """
    inv = _get_inventory_entry(
        db,
        body.product_id,
        body.warehouse_id,
        current_user.tenant_id,
    )

    old_qty = inv.qty_on_hand
    inv.qty_on_hand = body.counted_qty
    inv.last_counted_at = datetime.now(timezone.utc)

    AuditService.log_update(
        db=db,
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        entity_type="inventory_count",
        entity_id=str(inv.id),
        old_value={"qty_on_hand": old_qty},
        new_value={
            "qty_on_hand": body.counted_qty,
            "notes": body.notes,
        },
    )

    db.commit()
    db.refresh(inv)
    return _to_response(inv, inv.product, inv.warehouse)


@router.get("/alerts", response_model=list[AlertResponse])
def get_alerts(
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[AlertResponse]:
    """
    Return all low-stock and out-of-stock alerts for the tenant.

    An entry is included when qty_on_hand <= reorder_point.

    :param current_user: Injected JWT context
    :param db: Database session
    :return: List of AlertResponse objects
    """
    entries = (
        db.query(Inventory)
        .join(Product, Inventory.product_id == Product.id)
        .join(Warehouse, Inventory.warehouse_id == Warehouse.id)
        .filter(
            Product.tenant_id == current_user.tenant_id,
            Product.is_active.is_(True),
            Warehouse.is_active.is_(True),
            Inventory.qty_on_hand <= Inventory.reorder_point,
        )
        .order_by(Inventory.qty_on_hand)
        .all()
    )

    return [
        AlertResponse(
            product_id=inv.product_id,
            product_name=inv.product.name,
            product_sku=inv.product.sku,
            warehouse_id=inv.warehouse_id,
            warehouse_name=inv.warehouse.name,
            qty_on_hand=inv.qty_on_hand,
            reorder_point=inv.reorder_point,
            stock_status=_stock_status(
                inv.qty_on_hand, inv.reorder_point
            ),
        )
        for inv in entries
    ]
