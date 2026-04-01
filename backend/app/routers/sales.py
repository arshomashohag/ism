"""Sales router — POS transactions, void, and summary."""

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.dependencies import get_current_user, get_db, require_role
from app.models.inventory import Inventory
from app.models.payment import Payment
from app.models.product import Product
from app.models.sale_line_item import SaleLineItem
from app.models.sales_transaction import SalesTransaction
from app.models.user import User
from app.models.warehouse import Warehouse
from app.schemas.auth import CurrentUser
from app.schemas.sales import (
    SaleCreate,
    SaleListItem,
    SaleListResponse,
    SaleResponse,
    SalesSummary,
    SaleLineItemResponse,
    PaymentResponse,
    TopProduct,
)
from app.services.audit import AuditService

router = APIRouter(prefix="/sales", tags=["sales"])


def _next_invoice_number(
    db: Session, tenant_id: uuid.UUID
) -> str:
    """
    Generate the next INV-YYYYMMDD-NNNN invoice number.

    Counts all transactions for this tenant on today's date to
    derive the sequence number.

    :param db: Database session
    :param tenant_id: Owning tenant UUID
    :return: Invoice number string e.g. INV-20260401-0001
    """
    today = datetime.now(timezone.utc)
    date_prefix = today.strftime("%Y%m%d")
    like_pattern = f"INV-{date_prefix}-%"

    count = (
        db.query(func.count(SalesTransaction.id))
        .filter(
            SalesTransaction.tenant_id == tenant_id,
            SalesTransaction.invoice_number.like(like_pattern),
        )
        .scalar()
        or 0
    )
    seq = count + 1
    return f"INV-{date_prefix}-{seq:04d}"


def _sale_to_response(
    sale: SalesTransaction,
    db: Session,
) -> SaleResponse:
    """
    Build a SaleResponse from a SalesTransaction ORM instance.

    :param sale: SalesTransaction ORM instance
    :param db: Database session
    :return: SaleResponse
    """
    salesman_name: str | None = None
    if sale.salesman_id is not None:
        user = db.get(User, sale.salesman_id)
        if user is not None:
            salesman_name = user.name

    warehouse_name: str | None = None
    if sale.warehouse_id is not None:
        wh = db.get(Warehouse, sale.warehouse_id)
        if wh is not None:
            warehouse_name = wh.name

    line_items = [
        SaleLineItemResponse(
            id=li.id,
            product_id=li.product_id,
            product_name=li.product_name,
            qty=li.qty,
            unit_price=float(li.unit_price),
            tax_rate=float(li.tax_rate),
            line_total=float(li.line_total),
            line_tax=float(li.line_tax),
        )
        for li in sale.line_items
    ]

    payment_resp: PaymentResponse | None = None
    if sale.payment is not None:
        p = sale.payment
        payment_resp = PaymentResponse(
            id=p.id,
            method=p.method,
            amount_tendered=float(p.amount_tendered),
            change_given=float(p.change_given),
            reference=p.reference,
            paid_at=p.paid_at,
        )

    return SaleResponse(
        id=sale.id,
        invoice_number=sale.invoice_number,
        salesman_id=sale.salesman_id,
        salesman_name=salesman_name,
        warehouse_id=sale.warehouse_id,
        warehouse_name=warehouse_name,
        subtotal=float(sale.subtotal),
        tax_total=float(sale.tax_total),
        discount=float(sale.discount),
        grand_total=float(sale.grand_total),
        status=sale.status,
        line_items=line_items,
        payment=payment_resp,
        created_at=sale.created_at,
    )


def _deduct_inventory(
    db: Session,
    product_id: uuid.UUID,
    warehouse_id: uuid.UUID,
    tenant_id: uuid.UUID,
    qty: int,
) -> None:
    """
    Deduct qty from inventory, raising 422 if stock insufficient.

    :param db: Database session
    :param product_id: Product UUID
    :param warehouse_id: Warehouse UUID
    :param tenant_id: Tenant UUID for ownership check
    :param qty: Units to deduct
    :raises HTTPException: 422 if insufficient stock
    :raises HTTPException: 404 if inventory record not found
    """
    inv = (
        db.query(Inventory)
        .join(Product, Inventory.product_id == Product.id)
        .filter(
            Inventory.product_id == product_id,
            Inventory.warehouse_id == warehouse_id,
            Product.tenant_id == tenant_id,
        )
        .first()
    )
    if inv is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=(
                f"No inventory for product {product_id} "
                f"in warehouse {warehouse_id}"
            ),
        )
    if inv.qty_on_hand < qty:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                f"Insufficient stock for product "
                f"'{inv.product.name}': "
                f"available={inv.qty_on_hand}, requested={qty}"
            ),
        )
    inv.qty_on_hand -= qty


@router.post(
    "/",
    response_model=SaleResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_sale(
    body: SaleCreate,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SaleResponse:
    """
    Create a new completed sale atomically.

    Creates the transaction, all line items, payment record, and
    deducts inventory in a single database transaction.

    :param body: Sale creation payload
    :param current_user: Injected JWT context
    :param db: Database session
    :return: Created SaleResponse
    :raises HTTPException: 404 if product or inventory not found
    :raises HTTPException: 422 if stock insufficient or
        amount_tendered < grand_total
    """
    warehouse = (
        db.query(Warehouse)
        .filter(
            Warehouse.id == body.warehouse_id,
            Warehouse.tenant_id == current_user.tenant_id,
            Warehouse.is_active.is_(True),
        )
        .first()
    )
    if warehouse is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Warehouse not found",
        )

    subtotal = 0.0
    tax_total = 0.0
    sale_id = uuid.uuid4()
    line_item_objs: list[SaleLineItem] = []

    for item in body.line_items:
        product = (
            db.query(Product)
            .filter(
                Product.id == item.product_id,
                Product.tenant_id == current_user.tenant_id,
                Product.is_active.is_(True),
            )
            .first()
        )
        if product is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Product {item.product_id} not found",
            )

        price = (
            item.unit_price
            if item.unit_price is not None
            else float(product.unit_price)
        )
        tax_rate = float(product.tax_rate)
        line_total = round(price * item.qty, 2)
        line_tax = round(line_total * tax_rate, 2)

        subtotal += line_total
        tax_total += line_tax

        line_item_objs.append(
            SaleLineItem(
                id=uuid.uuid4(),
                transaction_id=sale_id,
                product_id=product.id,
                product_name=product.name,
                qty=item.qty,
                unit_price=price,
                tax_rate=tax_rate,
                line_total=line_total,
                line_tax=line_tax,
            )
        )

    subtotal = round(subtotal, 2)
    tax_total = round(tax_total, 2)
    discount = round(body.discount, 2)
    grand_total = round(subtotal + tax_total - discount, 2)

    if body.amount_tendered < grand_total:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                f"Amount tendered ({body.amount_tendered}) is "
                f"less than grand total ({grand_total})"
            ),
        )

    change_given = round(body.amount_tendered - grand_total, 2)

    for item in body.line_items:
        _deduct_inventory(
            db,
            item.product_id,
            body.warehouse_id,
            current_user.tenant_id,
            item.qty,
        )

    invoice_number = _next_invoice_number(
        db, current_user.tenant_id
    )

    sale = SalesTransaction(
        id=sale_id,
        tenant_id=current_user.tenant_id,
        invoice_number=invoice_number,
        salesman_id=current_user.user_id,
        warehouse_id=body.warehouse_id,
        subtotal=subtotal,
        tax_total=tax_total,
        discount=discount,
        grand_total=grand_total,
        status="completed",
        device_id=body.device_id,
        synced_at=datetime.now(timezone.utc),
    )
    db.add(sale)

    for li in line_item_objs:
        db.add(li)

    payment = Payment(
        id=uuid.uuid4(),
        transaction_id=sale_id,
        method=body.payment_method,
        amount_tendered=body.amount_tendered,
        change_given=change_given,
        reference=body.reference,
        paid_at=datetime.now(timezone.utc),
    )
    db.add(payment)

    AuditService.log_create(
        db=db,
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        entity_type="sales",
        entity_id=str(sale_id),
        new_value={
            "invoice_number": invoice_number,
            "grand_total": grand_total,
            "item_count": len(line_item_objs),
        },
    )

    db.commit()
    db.refresh(sale)
    return _sale_to_response(sale, db)


@router.get("/summary", response_model=SalesSummary)
def get_summary(
    date_from: datetime = Query(
        default=None,
        description="Start of range (ISO 8601). Defaults to 30 days ago.",
    ),
    date_to: datetime = Query(
        default=None,
        description="End of range (ISO 8601). Defaults to now.",
    ),
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SalesSummary:
    """
    Return aggregated sales summary for a date range.

    :param date_from: Optional range start (defaults to -30 days)
    :param date_to: Optional range end (defaults to now)
    :param current_user: Injected JWT context
    :param db: Database session
    :return: SalesSummary with totals and top products
    """
    now = datetime.now(timezone.utc)
    if date_to is None:
        date_to = now
    if date_from is None:
        from datetime import timedelta
        date_from = now - timedelta(days=30)

    base_q = db.query(SalesTransaction).filter(
        SalesTransaction.tenant_id == current_user.tenant_id,
        SalesTransaction.created_at >= date_from,
        SalesTransaction.created_at <= date_to,
    )

    completed = base_q.filter(
        SalesTransaction.status == "completed"
    ).all()
    voided_count = base_q.filter(
        SalesTransaction.status == "voided"
    ).count()

    total_revenue = sum(
        float(s.grand_total) for s in completed
    )
    total_tax = sum(float(s.tax_total) for s in completed)
    total_discount = sum(float(s.discount) for s in completed)

    product_qty: dict[uuid.UUID | None, int] = {}
    product_revenue: dict[uuid.UUID | None, float] = {}
    product_names: dict[uuid.UUID | None, str] = {}

    for sale in completed:
        for li in sale.line_items:
            pid = li.product_id
            product_qty[pid] = (
                product_qty.get(pid, 0) + li.qty
            )
            product_revenue[pid] = round(
                product_revenue.get(pid, 0.0)
                + float(li.line_total),
                2,
            )
            product_names[pid] = li.product_name

    top = sorted(
        product_qty.keys(),
        key=lambda k: product_qty[k],
        reverse=True,
    )[:5]

    top_products = [
        TopProduct(
            product_id=pid,
            product_name=product_names[pid],
            qty_sold=product_qty[pid],
            revenue=product_revenue[pid],
        )
        for pid in top
    ]

    return SalesSummary(
        date_from=date_from,
        date_to=date_to,
        total_sales=len(completed),
        total_revenue=round(total_revenue, 2),
        total_tax=round(total_tax, 2),
        total_discount=round(total_discount, 2),
        voided_count=voided_count,
        top_products=top_products,
    )


@router.get("/", response_model=SaleListResponse)
def list_sales(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    status_filter: str | None = Query(
        default=None, alias="status"
    ),
    date_from: datetime | None = Query(default=None),
    date_to: datetime | None = Query(default=None),
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SaleListResponse:
    """
    Return a paginated list of sales for the tenant.

    Salesmen see only their own sales; admins and managers see all.

    :param page: Page number (1-based)
    :param page_size: Items per page (max 100)
    :param status_filter: Optional status filter (completed/voided)
    :param date_from: Optional start of date range filter
    :param date_to: Optional end of date range filter
    :param current_user: Injected JWT context
    :param db: Database session
    :return: Paginated SaleListResponse
    """
    query = db.query(SalesTransaction).filter(
        SalesTransaction.tenant_id == current_user.tenant_id,
    )

    if current_user.role == "salesman":
        query = query.filter(
            SalesTransaction.salesman_id
            == current_user.user_id
        )

    if status_filter is not None:
        query = query.filter(
            SalesTransaction.status == status_filter
        )

    if date_from is not None:
        query = query.filter(
            SalesTransaction.created_at >= date_from
        )
    if date_to is not None:
        query = query.filter(
            SalesTransaction.created_at <= date_to
        )

    total = query.count()
    sales = (
        query.order_by(SalesTransaction.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    items: list[SaleListItem] = []
    for sale in sales:
        salesman_name: str | None = None
        if sale.salesman_id is not None:
            user = db.get(User, sale.salesman_id)
            if user is not None:
                salesman_name = user.name

        warehouse_name: str | None = None
        if sale.warehouse_id is not None:
            wh = db.get(Warehouse, sale.warehouse_id)
            if wh is not None:
                warehouse_name = wh.name

        items.append(
            SaleListItem(
                id=sale.id,
                invoice_number=sale.invoice_number,
                salesman_name=salesman_name,
                warehouse_name=warehouse_name,
                grand_total=float(sale.grand_total),
                status=sale.status,
                item_count=len(sale.line_items),
                created_at=sale.created_at,
            )
        )

    return SaleListResponse(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
    )


@router.get("/{sale_id}", response_model=SaleResponse)
def get_sale(
    sale_id: uuid.UUID,
    current_user: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SaleResponse:
    """
    Return a single sale by ID.

    Salesmen may only access their own sales.

    :param sale_id: Sale UUID from path
    :param current_user: Injected JWT context
    :param db: Database session
    :return: SaleResponse
    :raises HTTPException: 404 if not found or wrong tenant/salesman
    """
    sale = (
        db.query(SalesTransaction)
        .filter(
            SalesTransaction.id == sale_id,
            SalesTransaction.tenant_id
            == current_user.tenant_id,
        )
        .first()
    )
    if sale is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sale not found",
        )
    if (
        current_user.role == "salesman"
        and sale.salesman_id != current_user.user_id
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorised to view this sale",
        )
    return _sale_to_response(sale, db)


@router.post(
    "/{sale_id}/void",
    response_model=SaleResponse,
)
def void_sale(
    sale_id: uuid.UUID,
    current_user: CurrentUser = Depends(
        require_role("admin", "manager")
    ),
    db: Session = Depends(get_db),
) -> SaleResponse:
    """
    Void a completed sale and restore inventory.

    Sets status to 'voided' and reverses all inventory deductions.

    :param sale_id: Sale UUID from path
    :param current_user: Injected JWT context (admin/manager only)
    :param db: Database session
    :return: Updated SaleResponse with status 'voided'
    :raises HTTPException: 404 if not found or wrong tenant
    :raises HTTPException: 409 if sale is already voided
    """
    sale = (
        db.query(SalesTransaction)
        .filter(
            SalesTransaction.id == sale_id,
            SalesTransaction.tenant_id
            == current_user.tenant_id,
        )
        .first()
    )
    if sale is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Sale not found",
        )
    if sale.status == "voided":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Sale is already voided",
        )

    for li in sale.line_items:
        if li.product_id is None or sale.warehouse_id is None:
            continue
        inv = (
            db.query(Inventory)
            .join(Product, Inventory.product_id == Product.id)
            .filter(
                Inventory.product_id == li.product_id,
                Inventory.warehouse_id == sale.warehouse_id,
                Product.tenant_id == current_user.tenant_id,
            )
            .first()
        )
        if inv is not None:
            inv.qty_on_hand += li.qty

    sale.status = "voided"

    AuditService.log_update(
        db=db,
        tenant_id=current_user.tenant_id,
        user_id=current_user.user_id,
        entity_type="sales",
        entity_id=str(sale.id),
        old_value={"status": "completed"},
        new_value={"status": "voided"},
    )

    db.commit()
    db.refresh(sale)
    return _sale_to_response(sale, db)
