"""
sales_service.py — Registro de ventas y descuento de stock.
"""
from ..database.db import db
from ..models.sale import Sale
from ..models.sale_item import SaleItem
from ..models.product import Product
from .payment_service import process_payment

_TAX_FACTOR = 0.16 / 1.16  # extrae el IVA incluido en el precio

def register_sale(items_data, client_name="", payment_method="efectivo",
                  customer_id=None, branch_id=None):
    """
    items_data: lista de {product_id, quantity}
    client_name: nombre del cliente para el ticket
    payment_method: "efectivo" | "tarjeta" | "transferencia"
    branch_id: si se proporciona, usa stock e inventario de esa sucursal
    Crea la venta, descuenta stock y retorna Sale.
    Los precios ya incluyen IVA; el descuento se aplica por producto.
    """
    from ..models.branch_inventory import BranchInventory

    sale = Sale(total_amount=0, client_name=client_name,
                customer_id=customer_id, branch_id=branch_id)
    db.session.add(sale)
    db.session.flush()

    subtotal_bruto = 0.0
    subtotal_neto = 0.0

    for item in items_data:
        product = Product.query.get(item["product_id"])
        qty = item["quantity"]

        price_override = item.get("price_override")

        if branch_id:
            bi = BranchInventory.query.filter_by(
                branch_id=branch_id, product_id=item["product_id"]).first()
            if not bi or bi.stock < qty:
                db.session.rollback()
                name = product.name if product else str(item["product_id"])
                raise ValueError(f"Stock insuficiente en la sucursal para {name}")
            unit_price  = float(price_override) if price_override is not None else bi.effective_price()
            disc_factor = 1.0 if price_override is not None else 1.0 - bi.effective_discount() / 100.0
            bi.stock -= qty
        else:
            if not product or product.stock < qty:
                db.session.rollback()
                name = product.name if product else str(item["product_id"])
                raise ValueError(f"Stock insuficiente para {name}")
            unit_price  = float(price_override) if price_override is not None else product.price
            disc_factor = 1.0 if price_override is not None else 1.0 - (product.discount_pct or 0.0) / 100.0
            product.stock -= qty

        disc_price = unit_price * disc_factor
        subtotal_bruto += unit_price * qty
        subtotal_neto += disc_price * qty
        si = SaleItem(sale_id=sale.id, product_id=product.id,
                      quantity=qty, price=disc_price)
        db.session.add(si)

    discount_amount = subtotal_bruto - subtotal_neto
    tax_amount = subtotal_neto * _TAX_FACTOR  # IVA extraído (informativo)
    total = subtotal_neto

    sale.subtotal_amount = subtotal_bruto
    sale.discount_amount = discount_amount
    sale.tax_amount = tax_amount
    sale.total_amount = total

    payment_result = process_payment(payment_method, total)
    sale.payment_method = payment_result["method"]
    sale.payment_status = payment_result["status"]

    db.session.commit()
    return sale

def get_recent_sales(limit=20):
    return Sale.query.order_by(Sale.created_at.desc()).limit(limit).all()

def get_sale_by_id(sid):
    return Sale.query.get_or_404(sid)
