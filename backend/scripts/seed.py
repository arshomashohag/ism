"""Seed script — populates the database with initial sample data.

Run from backend/ directory:
    python -m scripts.seed
"""

import os
import sys
import uuid
from decimal import Decimal

from passlib.context import CryptContext
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from app.models import (  # noqa: E402
    AuditLog,
    Base,
    Category,
    Inventory,
    Product,
    SyncChangelog,
    SyncConflict,
    Tenant,
    User,
    Warehouse,
)

_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

CATEGORIES = [
    "Electronics",
    "Clothing",
    "Food & Beverages",
    "Home & Kitchen",
    "Sports & Outdoors",
]

PRODUCTS = [
    ("Wireless Earbuds Pro", "SKU-ELEC-001", "8801234567890",
     "Electronics", Decimal("79.99"), Decimal("42.00"),
     Decimal("0.075")),
    ("USB-C Hub 7-in-1", "SKU-ELEC-002", "8801234567891",
     "Electronics", Decimal("34.99"), Decimal("18.50"),
     Decimal("0.075")),
    ("Bluetooth Speaker", "SKU-ELEC-003", "8801234567892",
     "Electronics", Decimal("49.99"), Decimal("26.00"),
     Decimal("0.075")),
    ("Phone Case (Universal)", "SKU-ELEC-004", "8801234567893",
     "Electronics", Decimal("9.99"), Decimal("3.00"),
     Decimal("0.075")),
    ("Cotton T-Shirt (M)", "SKU-CLTH-001", "8802234567890",
     "Clothing", Decimal("14.99"), Decimal("6.00"),
     Decimal("0.00")),
    ("Slim Fit Jeans (32)", "SKU-CLTH-002", "8802234567891",
     "Clothing", Decimal("39.99"), Decimal("18.00"),
     Decimal("0.00")),
    ("Hoodie - Navy Blue", "SKU-CLTH-003", "8802234567892",
     "Clothing", Decimal("29.99"), Decimal("13.00"),
     Decimal("0.00")),
    ("Running Socks (3-pack)", "SKU-CLTH-004", "8802234567893",
     "Clothing", Decimal("7.99"), Decimal("2.50"),
     Decimal("0.00")),
    ("Mineral Water 1L", "SKU-FOOD-001", "8803234567890",
     "Food & Beverages", Decimal("1.29"), Decimal("0.40"),
     Decimal("0.00")),
    ("Premium Coffee Beans 250g", "SKU-FOOD-002", "8803234567891",
     "Food & Beverages", Decimal("12.99"), Decimal("6.50"),
     Decimal("0.00")),
    ("Protein Bar (Box of 12)", "SKU-FOOD-003", "8803234567892",
     "Food & Beverages", Decimal("18.99"), Decimal("10.00"),
     Decimal("0.00")),
    ("Energy Drink 250ml", "SKU-FOOD-004", "8803234567893",
     "Food & Beverages", Decimal("2.49"), Decimal("0.80"),
     Decimal("0.00")),
    ("Non-stick Frying Pan", "SKU-HOME-001", "8804234567890",
     "Home & Kitchen", Decimal("24.99"), Decimal("12.00"),
     Decimal("0.075")),
    ("Bamboo Cutting Board", "SKU-HOME-002", "8804234567891",
     "Home & Kitchen", Decimal("16.99"), Decimal("7.00"),
     Decimal("0.075")),
    ("Stainless Steel Water Bottle", "SKU-HOME-003",
     "8804234567892",
     "Home & Kitchen", Decimal("19.99"), Decimal("9.00"),
     Decimal("0.075")),
    ("Microfibre Cleaning Cloths (5)", "SKU-HOME-004",
     "8804234567893",
     "Home & Kitchen", Decimal("6.99"), Decimal("2.00"),
     Decimal("0.075")),
    ("Yoga Mat 6mm", "SKU-SPRT-001", "8805234567890",
     "Sports & Outdoors", Decimal("29.99"), Decimal("14.00"),
     Decimal("0.075")),
    ("Resistance Bands Set", "SKU-SPRT-002", "8805234567891",
     "Sports & Outdoors", Decimal("19.99"), Decimal("8.00"),
     Decimal("0.075")),
    ("Jump Rope", "SKU-SPRT-003", "8805234567892",
     "Sports & Outdoors", Decimal("11.99"), Decimal("4.50"),
     Decimal("0.075")),
    ("Water-proof Backpack 20L", "SKU-SPRT-004", "8805234567893",
     "Sports & Outdoors", Decimal("44.99"), Decimal("22.00"),
     Decimal("0.075")),
]

_MAIN_STORE_QTY = [
    45, 30, 0, 8, 60, 25, 15, 100, 5, 40,
    22, 80, 12, 35, 18, 90, 0, 55, 7, 20,
]

_WAREHOUSE_B_QTY = [
    10, 0, 25, 50, 5, 0, 30, 20, 3, 0,
    8, 15, 40, 10, 0, 25, 60, 0, 12, 35,
]


def _hash_password(plain: str) -> str:
    """
    Hash a plain-text password with bcrypt.

    :param plain: Plain-text password
    :return: bcrypt hash string
    """
    return _pwd_context.hash(plain)


def seed(db: Session) -> None:
    """
    Insert all seed data within the provided session.

    Skips seeding entirely if the demo-shop tenant already exists.

    :param db: Active SQLAlchemy session
    :return: None
    """
    existing = (
        db.query(Tenant)
        .filter(Tenant.slug == "demo-shop")
        .first()
    )
    if existing:
        print("Seed data already exists — skipping.")
        return

    tenant = Tenant(
        id=uuid.uuid4(),
        name="Demo Shop",
        slug="demo-shop",
        plan="starter",
        is_active=True,
    )
    db.add(tenant)
    db.flush()
    print(f"  Created tenant: {tenant.name} ({tenant.id})")

    admin = User(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        name="Admin User",
        email="admin@demo.shop",
        password_hash=_hash_password("admin123"),
        role="admin",
        is_active=True,
    )
    db.add(admin)
    db.flush()
    print(f"  Created admin user: {admin.email}")

    warehouse_main = Warehouse(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        name="Main Store",
        address="123 Main Street",
        is_active=True,
    )
    warehouse_b = Warehouse(
        id=uuid.uuid4(),
        tenant_id=tenant.id,
        name="Warehouse B",
        address="456 Commerce Ave",
        is_active=True,
    )
    db.add(warehouse_main)
    db.add(warehouse_b)
    db.flush()
    print(
        f"  Created warehouses: "
        f"{warehouse_main.name}, {warehouse_b.name}"
    )

    category_map: dict[str, Category] = {}
    for cat_name in CATEGORIES:
        category = Category(
            id=uuid.uuid4(),
            tenant_id=tenant.id,
            name=cat_name,
        )
        db.add(category)
        category_map[cat_name] = category
    db.flush()
    print(f"  Created {len(CATEGORIES)} categories")

    reorder_points = [
        10, 10, 5, 20, 15, 10, 8, 30, 10, 12,
        10, 25, 8, 12, 10, 20, 5, 15, 10, 8,
    ]

    for idx, (
        name, sku, barcode, cat_name,
        unit_price, cost_price, tax_rate
    ) in enumerate(PRODUCTS):
        product = Product(
            id=uuid.uuid4(),
            tenant_id=tenant.id,
            category_id=category_map[cat_name].id,
            sku=sku,
            name=name,
            barcode=barcode,
            unit_price=unit_price,
            cost_price=cost_price,
            tax_rate=tax_rate,
            metadata_={},
            is_hub_shared=False,
            is_active=True,
            hlc_timestamp=0,
        )
        db.add(product)
        db.flush()

        rp = reorder_points[idx]

        db.add(Inventory(
            id=uuid.uuid4(),
            product_id=product.id,
            warehouse_id=warehouse_main.id,
            qty_on_hand=_MAIN_STORE_QTY[idx],
            qty_reserved=0,
            reorder_point=rp,
            hlc_timestamp=0,
        ))
        db.add(Inventory(
            id=uuid.uuid4(),
            product_id=product.id,
            warehouse_id=warehouse_b.id,
            qty_on_hand=_WAREHOUSE_B_QTY[idx],
            qty_reserved=0,
            reorder_point=rp,
            hlc_timestamp=0,
        ))

    db.flush()
    print(
        f"  Created {len(PRODUCTS)} products with inventory "
        f"across 2 warehouses"
    )

    db.commit()
    print("Seed complete.")


def main() -> None:
    """
    Entry point: connect to DB, run seed, close connection.

    :return: None
    """
    database_url = os.environ.get(
        "DATABASE_URL",
        "postgresql://ims:ims@localhost:5432/ims",
    )
    engine = create_engine(database_url)

    print(f"Seeding database: {database_url}")
    with Session(engine) as db:
        seed(db)

    engine.dispose()


if __name__ == "__main__":
    main()
