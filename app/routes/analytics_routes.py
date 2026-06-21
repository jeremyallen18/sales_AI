"""
analytics_routes.py — Dashboard principal y endpoints de métricas.
"""
from functools import wraps
from flask import Blueprint, render_template, jsonify, session, redirect, url_for, request
from ..services.analytics_service import (
    get_total_revenue, get_revenue_last_days,
    get_top_products, get_summary_for_ai, get_branch_comparison,
)

analytics_bp = Blueprint("analytics", __name__)


def login_required(f):
    """Decorador simple para proteger rutas de sesión Flask."""
    @wraps(f)
    def decorated(*args, **kwargs):
        if "user" not in session:
            return redirect(url_for("auth.login"))
        return f(*args, **kwargs)
    return decorated


def owner_session_required(f):
    """Exige sesión activa con role == 'owner'."""
    @wraps(f)
    def decorated(*args, **kwargs):
        if "user" not in session:
            return redirect(url_for("auth.login"))
        from ..models.seller_account import SellerAccount
        seller = SellerAccount.query.filter_by(email=session["user"]).first()
        if not seller or seller.role != "owner":
            return jsonify({"error": "Acceso solo para el dueño global"}), 403
        return f(*args, **kwargs)
    return decorated


@analytics_bp.route("/dashboard")
@login_required
def dashboard():
    return render_template("dashboard.html")


@analytics_bp.route("/api/analytics/summary")
def api_summary():
    branch_id = request.args.get("branch_id", type=int)
    return jsonify({
        "ingresos_totales": get_total_revenue(branch_id=branch_id),
        "ventas_recientes": get_revenue_last_days(30, branch_id=branch_id),
        "top_productos": get_top_products(branch_id=branch_id),
    })


@analytics_bp.route("/api/analytics/branch-comparison")
@login_required
def branch_comparison():
    return jsonify(get_branch_comparison())


@analytics_bp.route("/api/analytics/reviews")
@login_required
def reviews_analytics():
    from sqlalchemy import func
    from ..database.db import db
    from ..models.branch import Branch
    from ..models.product import Product
    from ..models.branch_review import BranchReview
    from ..models.product_review import ProductReview

    branch_rows = db.session.query(
        Branch.id, Branch.name,
        func.avg(BranchReview.rating),
        func.count(BranchReview.id),
    ).outerjoin(BranchReview, Branch.id == BranchReview.branch_id).group_by(Branch.id).all()

    product_rows = db.session.query(
        Product.id, Product.name,
        func.avg(ProductReview.rating),
        func.count(ProductReview.id),
    ).outerjoin(ProductReview, Product.id == ProductReview.product_id).group_by(Product.id).all()

    recent_branch = [
        {**r.to_dict(), "type": "branch", "target_name": r.branch_id}
        for r in BranchReview.query.order_by(BranchReview.created_at.desc()).limit(10).all()
    ]
    recent_product = [
        {**r.to_dict(), "type": "product", "target_name": r.product_id}
        for r in ProductReview.query.order_by(ProductReview.created_at.desc()).limit(10).all()
    ]

    # Enrich target names
    branch_names = {b.id: b.name for b in Branch.query.all()}
    product_names = {p.id: p.name for p in Product.query.all()}
    for r in recent_branch:
        r["target_name"] = branch_names.get(r["branch_id"], f"Sucursal #{r['branch_id']}")
    for r in recent_product:
        r["target_name"] = product_names.get(r["product_id"], f"Producto #{r['product_id']}")

    recent = sorted(recent_branch + recent_product, key=lambda x: x["created_at"], reverse=True)[:20]

    return jsonify({
        "branches": [
            {"id": bid, "name": name,
             "avg_rating": round(float(avg), 1) if avg else 0.0,
             "total_reviews": int(count)}
            for bid, name, avg, count in branch_rows
        ],
        "products": [
            {"id": pid, "name": name,
             "avg_rating": round(float(avg), 1) if avg else 0.0,
             "total_reviews": int(count)}
            for pid, name, avg, count in product_rows
        ],
        "recent": recent,
    })
