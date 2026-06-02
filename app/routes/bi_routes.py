"""
bi_routes.py — Endpoints de datos para Power BI (conector Web/JSON).

Exponen los datos del negocio en esquema estrella, listos para ser
consumidos desde Power BI Desktop → Obtener datos → Web. Son públicos
(sin sesión) igual que /api/analytics/summary, para que el conector
pueda leerlos sin autenticación. Todos devuelven {"data": [ ... ]}.
"""
from flask import Blueprint, jsonify
from ..models.sale import Sale
from ..models.product import Product
from ..services.analytics_service import get_detalle_ventas

bi_bp = Blueprint("bi", __name__, url_prefix="/api/bi")


@bi_bp.route("/productos")
def bi_productos():
    """Dimensión de productos."""
    data = [{
        "id": p.id,
        "name": p.name,
        "price": float(p.price),
        "stock": int(p.stock or 0),
        "category": p.category or "General",
        "created_at": p.created_at.isoformat() if p.created_at else None,
    } for p in Product.query.order_by(Product.id).all()]
    return jsonify({"data": data})


@bi_bp.route("/ventas")
def bi_ventas():
    """Cabecera de ventas (nivel venta)."""
    data = [{
        "id": s.id,
        "client_name": s.client_name or "",
        "total_amount": float(s.total_amount),
        "created_at": s.created_at.isoformat() if s.created_at else None,
    } for s in Sale.query.order_by(Sale.created_at).all()]
    return jsonify({"data": data})


@bi_bp.route("/detalle")
def bi_detalle():
    """Tabla de hechos a nivel ítem (la principal para el dashboard)."""
    return jsonify({"data": get_detalle_ventas()})
