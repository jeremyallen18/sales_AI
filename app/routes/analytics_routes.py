"""
analytics_routes.py — Dashboard principal y endpoints de métricas.
"""
from flask import Blueprint, render_template, jsonify, session, redirect, url_for
from ..services.analytics_service import (get_total_revenue, get_revenue_last_days,
    get_top_products, get_summary_for_ai)

analytics_bp = Blueprint("analytics", __name__)

def login_required(f):
    """Decorador simple para proteger rutas."""
    from functools import wraps
    @wraps(f)
    def decorated(*args, **kwargs):
        if "user" not in session:
            return redirect(url_for("auth.login"))
        return f(*args, **kwargs)
    return decorated

@analytics_bp.route("/dashboard")
@login_required
def dashboard():
    return render_template("dashboard.html")

@analytics_bp.route("/api/analytics/summary")
def api_summary():
    return jsonify({
        "ingresos_totales": get_total_revenue(),
        "ventas_recientes": get_revenue_last_days(30),
        "top_productos": get_top_products()
    })
