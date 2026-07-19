"""
analytics_service.py — Consultas de métricas para dashboard e IA.
"""
from ..database.db import db
from ..models.sale import Sale
from ..models.sale_item import SaleItem
from ..models.product import Product
from ..models.branch import Branch
from sqlalchemy import func
from datetime import timedelta
from ..utils import now_mx


def _branch_filter(query, branch_id=None):
    """Aplica filtro por sucursal si se provee."""
    if branch_id is not None:
        query = query.filter(Sale.branch_id == branch_id)
    return query


def get_total_revenue(branch_id=None):
    q = db.session.query(func.sum(Sale.total_amount))
    q = _branch_filter(q, branch_id)
    result = q.scalar()
    return result or 0.0


def get_revenue_last_days(days=30, branch_id=None):
    """Ingresos agrupados por día para el gráfico de tendencia."""
    since = now_mx() - timedelta(days=days)
    q = db.session.query(
        func.date(Sale.created_at).label("day"),
        func.sum(Sale.total_amount).label("total")
    ).filter(Sale.created_at >= since)
    q = _branch_filter(q, branch_id)
    rows = q.group_by(func.date(Sale.created_at)).all()
    return [{"day": str(r.day), "total": float(r.total)} for r in rows]


def get_top_products(limit=5, branch_id=None):
    """Productos más vendidos por cantidad."""
    q = db.session.query(
        Product.name,
        func.sum(SaleItem.quantity).label("total_qty"),
        func.sum(SaleItem.quantity * SaleItem.price).label("revenue")
    ).join(SaleItem).join(Sale, SaleItem.sale_id == Sale.id)
    if branch_id is not None:
        q = q.filter(Sale.branch_id == branch_id)
    rows = q.group_by(Product.id).order_by(
        func.sum(SaleItem.quantity).desc()
    ).limit(limit).all()
    return [{"name": r.name, "total_qty": int(r.total_qty), "revenue": float(r.revenue)} for r in rows]


def get_detalle_ventas(branch_id=None):
    """Tabla de hechos a nivel ítem para Power BI (una fila por SaleItem)."""
    q = db.session.query(
        SaleItem.sale_id,
        Sale.created_at,
        Sale.client_name,
        Sale.branch_id,
        SaleItem.product_id,
        Product.name.label("product_name"),
        Product.category,
        SaleItem.quantity,
        SaleItem.price,
    ).join(Sale, SaleItem.sale_id == Sale.id).join(
        Product, SaleItem.product_id == Product.id
    )
    if branch_id is not None:
        q = q.filter(Sale.branch_id == branch_id)
    rows = q.order_by(Sale.created_at).all()
    return [{
        "sale_id": r.sale_id,
        "fecha": r.created_at.isoformat() if r.created_at else None,
        "client_name": r.client_name or "",
        "branch_id": r.branch_id,
        "product_id": r.product_id,
        "product_name": r.product_name,
        "category": r.category or "General",
        "quantity": int(r.quantity),
        "price": float(r.price),
        "subtotal": float(r.quantity * r.price),
    } for r in rows]


def get_summary_for_ai(branch_id=None):
    """Resumen estructurado del negocio para inyectar en el prompt de IA."""
    q = Sale.query
    if branch_id is not None:
        q = q.filter(Sale.branch_id == branch_id)
    return {
        "ingresos_totales": get_total_revenue(branch_id=branch_id),
        "total_ventas": q.count(),
        "productos_top": get_top_products(branch_id=branch_id),
        "ingresos_ultimos_7_dias": get_revenue_last_days(7, branch_id=branch_id),
        "productos_bajo_stock": [p.to_dict() for p in Product.query.filter(Product.stock <= 10).all()]
    }


def get_branch_comparison():
    """Ingresos totales agrupados por sucursal para el panel del dueño."""
    rows = db.session.query(
        Sale.branch_id,
        func.sum(Sale.total_amount).label("total"),
        func.count(Sale.id).label("num_sales"),
    ).filter(Sale.branch_id.isnot(None)).group_by(Sale.branch_id).all()

    result = []
    for r in rows:
        branch = Branch.query.get(r.branch_id)
        result.append({
            "branch_id": r.branch_id,
            "branch_name": branch.name if branch else f"Sucursal {r.branch_id}",
            "total_revenue": float(r.total),
            "num_sales": int(r.num_sales),
        })
    result.sort(key=lambda x: x["total_revenue"], reverse=True)
    return result
