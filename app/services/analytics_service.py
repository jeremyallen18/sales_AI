"""
analytics_service.py — Consultas de métricas para dashboard e IA.
"""
from ..database.db import db
from ..models.sale import Sale
from ..models.sale_item import SaleItem
from ..models.product import Product
from sqlalchemy import func
from datetime import datetime, timedelta

def get_total_revenue():
    result = db.session.query(func.sum(Sale.total_amount)).scalar()
    return result or 0.0

def get_revenue_last_days(days=30):
    """Ingresos agrupados por día para el gráfico de tendencia."""
    since = datetime.utcnow() - timedelta(days=days)
    rows = db.session.query(
        func.date(Sale.created_at).label("day"),
        func.sum(Sale.total_amount).label("total")
    ).filter(Sale.created_at >= since).group_by(func.date(Sale.created_at)).all()
    return [{"day": str(r.day), "total": float(r.total)} for r in rows]

def get_top_products(limit=5):
    """Productos más vendidos por cantidad."""
    rows = db.session.query(
        Product.name,
        func.sum(SaleItem.quantity).label("total_qty"),
        func.sum(SaleItem.quantity * SaleItem.price).label("revenue")
    ).join(SaleItem).group_by(Product.id).order_by(
        func.sum(SaleItem.quantity).desc()
    ).limit(limit).all()
    return [{"name": r.name, "total_qty": int(r.total_qty), "revenue": float(r.revenue)} for r in rows]

def get_detalle_ventas():
    """Tabla de hechos a nivel ítem para Power BI (una fila por SaleItem)."""
    rows = db.session.query(
        SaleItem.sale_id,
        Sale.created_at,
        Sale.client_name,
        SaleItem.product_id,
        Product.name.label("product_name"),
        Product.category,
        SaleItem.quantity,
        SaleItem.price,
    ).join(Sale, SaleItem.sale_id == Sale.id).join(
        Product, SaleItem.product_id == Product.id
    ).order_by(Sale.created_at).all()
    return [{
        "sale_id": r.sale_id,
        "fecha": r.created_at.isoformat() if r.created_at else None,
        "client_name": r.client_name or "",
        "product_id": r.product_id,
        "product_name": r.product_name,
        "category": r.category or "General",
        "quantity": int(r.quantity),
        "price": float(r.price),
        "subtotal": float(r.quantity * r.price),
    } for r in rows]


def get_summary_for_ai():
    """Resumen estructurado del negocio para inyectar en el prompt de IA."""
    return {
        "ingresos_totales": get_total_revenue(),
        "total_ventas": Sale.query.count(),
        "productos_top": get_top_products(),
        "ingresos_ultimos_7_dias": get_revenue_last_days(7),
        "productos_bajo_stock": [p.to_dict() for p in Product.query.filter(Product.stock <= 10).all()]
    }
