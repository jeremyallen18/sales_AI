"""
sales_service.py — Registro de ventas y descuento de stock.
"""
from ..database.db import db
from ..models.sale import Sale
from ..models.sale_item import SaleItem
from ..models.product import Product

def register_sale(items_data, client_name=""):
    """
    items_data: lista de {product_id, quantity}
    client_name: nombre del cliente para el ticket
    Crea la venta, descuenta stock y retorna Sale.
    """
    total = 0.0
    sale = Sale(total_amount=0, client_name=client_name)
    db.session.add(sale)
    db.session.flush()

    for item in items_data:
        product = Product.query.get(item["product_id"])
        if not product or product.stock < item["quantity"]:
            db.session.rollback()
            name = product.name if product else str(item["product_id"])
            raise ValueError(f"Stock insuficiente para {name}")
        subtotal = product.price * item["quantity"]
        total += subtotal
        product.stock -= item["quantity"]
        si = SaleItem(sale_id=sale.id, product_id=product.id,
                      quantity=item["quantity"], price=product.price)
        db.session.add(si)

    sale.total_amount = total
    db.session.commit()
    return sale

def get_recent_sales(limit=20):
    return Sale.query.order_by(Sale.created_at.desc()).limit(limit).all()

def get_sale_by_id(sid):
    return Sale.query.get_or_404(sid)
