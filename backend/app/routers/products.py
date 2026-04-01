"""Products router — CRUD with search and audit logging."""

import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.dependencies import get_current_user, get_db, require_role
from app.models.category import Category
from app.models.inventory import Inventory
from app.models.product import Product
from app.models.warehouse import Warehouse
from app.schemas.auth import CurrentUser
from app.schemas.inventory import InventorySummaryItem
from app.schemas.products import (
    ProductCreate,
    ProductListResponse,
    ProductResponse,
    ProductUpdate,
)
from app.services.audit import AuditService

router = APIRouter(prefix="/products", tags=["products"])


def _stock_status(
    qty_on_hand: int, reorder_point: int
) -> str:
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

_UPDATABLE_FIELDS = (
    "sku",
    "name",
    "barcode",
    "category_id",
    "unit_price",
    "cost_price",
    "tax_rate",
)


def _product_to_response(
    product: Product, db: Session
) -> ProductResponse:
    """
    Build a ProductResponse from a Product ORM instance.

    :param product: SQLAlchemy Product instance
    :param db: Database session
    :return: ProductResponse with category_name resolved
    """
    category_name: str | None = None
    if product.category_id is not None:
        cat = db.get(Category, product.category_id)
        if cat is not None:
            category_name = cat.name

    inv_entries = (
        db.query(Inventory)
        .join(Warehouse, Inventory.warehouse_id == Warehouse.id)
        .filter(
            Inventory.product_id == product.id,
            Warehouse.is_active.is_(True),
        )
        .all()
    )
    inventory_summary = [
        InventorySummaryItem(
            warehouse_id=inv.warehouse_id,
            warehouse_name=inv.warehouse.name,
            qty_on_hand=inv.qty_on_hand,
            qty_reserved=inv.qty_reserved,
            qty_available=inv.qty_on_hand - inv.qty_reserved,
            reorder_point=inv.reorder_point,
            stock_status=_stock_status(
                inv.qty_on_hand, inv.reorder_point
            ),
        )
        for inv in inv_entries
    ]

    return ProductResponse(
        id=product.id,
        tenant_id=product.tenant_id,
        sku=product.sku,
        name=product.name,
        barcode=product.barcode,
        category_id=product.category_id,
        category_name=category_name,
        unit_price=float(product.unit_price),
        cost_price=(
            float(product.cost_price)
            if product.cost_price is not None
            else None
        ),
        tax_rate=float(product.tax_rate),
        metadata_=product.metadata_,
        is_active=product.is_active,
        created_at=product.created_at,
        updated_at=product.updated_at,
        inventory_summary=inventory_summary,
    )


def _product_snapshot(product: Product) -> dict[str, Any]:
    """
    Capture a serialisable snapshot of mutable product fields.

    :param product: SQLAlchemy Product instance
    :return: Dict suitable for audit log JSON storage
    """
    return {
        "sku": product.sku,
        "name": product.name,
        "barcode": product.barcode,
        "category_id": str(product.category_id)
        if product.category_id
        else None,
        "unit_price": float(product.unit_price),
        "cost_price": (
            float(product.cost_price)
            if product.cost_price is not None
            else None
        ),
        "tax_rate": float(product.tax_rate),
    }


@router.get("/", response_model=ProductListResponse)
def list_products(
    search: str | None = Query(default=None),
    category_id: uuid.UUID | None = Query(default=None),
    barcode: str | None = Query(default=None),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProductListResponse:
    """
    Return a paginated list of active products for the tenant.

    Supports trigram search on name, exact barcode lookup,
    and category filtering.

    :param search: Optional fuzzy name search term
    :param category_id: Optional category UUID filter
    :param barcode: Optional exact barcode filter
    :param page: Page number, 1-based
    :param page_size: Items per page (max 100)
    :param current_user: Injected JWT context
    :param db: Database session
    :return: Paginated ProductListResponse
    """
    query = db.query(Product).filter(
        Product.tenant_id == current_user.tenant_id,
        Product.is_active.is_(True),
    )

    if barcode:
        query = query.filter(Product.barcode == barcode)
    elif search:
        query = query.filter(
            func.similarity(Product.name, search) > 0.1
        ).order_by(
            func.similarity(Product.name, search).desc()
        )

    if category_id is not None:
        query = query.filter(Product.category_id == category_id)

    total = query.count()
    products = (
        query.offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    return ProductListResponse(
        items=[_product_to_response(p, db) for p in products],
        total=total,
        page=page,
        page_size=page_size,
    )


@router.post(
    "/",
    response_model=ProductResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_product(
    body: ProductCreate,
    current_user: CurrentUser = Depends(
        require_role("admin", "manager")
    ),
    db: Session = Depends(get_db),
) -> ProductResponse:
    """
    Create a new product for the tenant.

    :param body: Product creation payload
    :param current_user: Injected JWT context (admin/manager only)
    :param db: Database session
    :return: Created ProductResponse
    :raises HTTPException: 409 if SKU already exists for tenant
    """
    existing = (
        db.query(Product)
        .filter(
            Product.tenant_id == current_user.tenant_id,
            Product.sku == body.sku,
        )
        .first()
    )
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"SKU '{body.sku}' already exists",
        )

    product = Product(
        id=uuid.uuid4(),
        tenant_id=current_user.tenant_id,
        sku=body.sku,
        name=body.name,
        barcode=body.barcode,
        category_id=body.category_id,
        unit_price=body.unit_price,
        cost_price=body.cost_price,
        tax_rate=body.tax_rate,
        metadata_=body.metadata,
        is_active=True,
    )
    db.add(product)
    db.flush()

    AuditService.log_create(
        db=db,
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        entity_type="products",
        entity_id=str(product.id),
        new_value=_product_snapshot(product),
    )

    db.commit()
    db.refresh(product)
    return _product_to_response(product, db)


@router.get("/{product_id}", response_model=ProductResponse)
def get_product(
    product_id: uuid.UUID,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> ProductResponse:
    """
    Return a single product by ID.

    :param product_id: Product UUID from path
    :param current_user: Injected JWT context
    :param db: Database session
    :return: ProductResponse
    :raises HTTPException: 404 if not found or wrong tenant
    """
    product = (
        db.query(Product)
        .filter(
            Product.id == product_id,
            Product.tenant_id == current_user.tenant_id,
            Product.is_active.is_(True),
        )
        .first()
    )
    if product is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Product not found",
        )
    return _product_to_response(product, db)


@router.patch("/{product_id}", response_model=ProductResponse)
def update_product(
    product_id: uuid.UUID,
    body: ProductUpdate,
    current_user: CurrentUser = Depends(
        require_role("admin", "manager")
    ),
    db: Session = Depends(get_db),
) -> ProductResponse:
    """
    Partially update a product.

    :param product_id: Product UUID from path
    :param body: Partial update payload
    :param current_user: Injected JWT context (admin/manager only)
    :param db: Database session
    :return: Updated ProductResponse
    :raises HTTPException: 404 if not found or wrong tenant
    """
    product = (
        db.query(Product)
        .filter(
            Product.id == product_id,
            Product.tenant_id == current_user.tenant_id,
            Product.is_active.is_(True),
        )
        .first()
    )
    if product is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Product not found",
        )

    updates = body.model_dump(exclude_unset=True)
    if not updates:
        return _product_to_response(product, db)

    changed_fields = [
        f for f in _UPDATABLE_FIELDS if f in updates
    ]
    old_snapshot = {
        f: _product_snapshot(product).get(f)
        for f in changed_fields
    }

    for field, value in updates.items():
        if field == "metadata":
            setattr(product, "metadata_", value)
        else:
            setattr(product, field, value)

    new_snapshot = {
        f: _product_snapshot(product).get(f)
        for f in changed_fields
    }

    AuditService.log_update(
        db=db,
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        entity_type="products",
        entity_id=str(product.id),
        old_value=old_snapshot,
        new_value=new_snapshot,
    )

    db.commit()
    db.refresh(product)
    return _product_to_response(product, db)


@router.delete(
    "/{product_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_product(
    product_id: uuid.UUID,
    current_user: CurrentUser = Depends(
        require_role("admin", "manager")
    ),
    db: Session = Depends(get_db),
) -> None:
    """
    Soft-delete a product by setting is_active=False.

    :param product_id: Product UUID from path
    :param current_user: Injected JWT context (admin/manager only)
    :param db: Database session
    :return: None (204 No Content)
    :raises HTTPException: 404 if not found or wrong tenant
    """
    product = (
        db.query(Product)
        .filter(
            Product.id == product_id,
            Product.tenant_id == current_user.tenant_id,
            Product.is_active.is_(True),
        )
        .first()
    )
    if product is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Product not found",
        )

    snapshot = _product_snapshot(product)
    product.is_active = False

    AuditService.log_delete(
        db=db,
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        entity_type="products",
        entity_id=str(product.id),
        old_value=snapshot,
    )

    db.commit()
