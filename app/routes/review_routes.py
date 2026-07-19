"""
review_routes.py — Reseñas de sucursales y productos por clientes.
"""
import jwt
from sqlalchemy import func
from flask import Blueprint, jsonify, request, current_app
from ..database.db import db
from ..models.branch_review import BranchReview
from ..models.product_review import ProductReview
from ..models.product import Product

review_bp = Blueprint("reviews", __name__, url_prefix="/api/branches")
product_review_bp = Blueprint("product_reviews", __name__, url_prefix="/api/products")


def _decode_customer(request):
    """Devuelve customer_id si el Bearer JWT es válido y role==customer, o None."""
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None, ("Autenticación requerida", 401)
    try:
        payload = jwt.decode(
            auth[7:],
            current_app.config["APP_TOKEN_SECRET"],
            algorithms=["HS256"],
        )
    except jwt.ExpiredSignatureError:
        return None, ("Token expirado", 401)
    except jwt.InvalidTokenError:
        return None, ("Token inválido", 401)
    if payload.get("role") != "customer":
        return None, ("Solo clientes pueden dejar reseñas", 403)
    return int(payload.get("sub", 0)), None


@review_bp.route("/<int:bid>/reviews", methods=["GET"])
def get_reviews(bid):
    reviews = (BranchReview.query
               .filter_by(branch_id=bid)
               .order_by(BranchReview.created_at.desc())
               .all())
    avg = round(sum(r.rating for r in reviews) / len(reviews), 1) if reviews else 0.0
    return jsonify({
        "reviews": [r.to_dict() for r in reviews],
        "average_rating": avg,
        "total_reviews": len(reviews),
    })


@review_bp.route("/<int:bid>/reviews", methods=["POST"])
def post_review(bid):
    customer_id, err = _decode_customer(request)
    if err:
        return jsonify({"error": err[0]}), err[1]

    data = request.get_json(silent=True) or {}
    rating = data.get("rating")
    if not rating or not isinstance(rating, int) or not (1 <= rating <= 5):
        return jsonify({"error": "rating debe ser un entero entre 1 y 5"}), 400

    existing = BranchReview.query.filter_by(
        customer_id=customer_id, branch_id=bid).first()
    if existing:
        existing.rating = rating
        existing.comment = (data.get("comment") or "")[:1000]
        db.session.commit()
        return jsonify(existing.to_dict()), 200

    r = BranchReview(
        customer_id=customer_id,
        branch_id=bid,
        rating=rating,
        comment=(data.get("comment") or "")[:1000],
    )
    db.session.add(r)
    db.session.commit()
    return jsonify(r.to_dict()), 201


@review_bp.route("/<int:bid>/my-review", methods=["GET"])
def get_my_branch_review(bid):
    customer_id, err = _decode_customer(request)
    if err:
        return jsonify({"error": err[0]}), err[1]
    r = BranchReview.query.filter_by(
        customer_id=customer_id, branch_id=bid).first()
    return jsonify({"review": r.to_dict() if r else None})


# ── Rutas de reseñas de productos ────────────────────────────────────────────

@product_review_bp.route("/ratings", methods=["GET"])
def bulk_product_ratings():
    """Mapa {product_id: {avg_rating, total_reviews}} para todos los productos en una sola query."""
    rows = db.session.query(
        ProductReview.product_id,
        func.avg(ProductReview.rating),
        func.count(ProductReview.id),
    ).group_by(ProductReview.product_id).all()
    result = {}
    for pid, avg, count in rows:
        result[str(pid)] = {
            "avg_rating":    round(float(avg), 1) if avg else 0.0,
            "total_reviews": int(count),
        }
    return jsonify(result)


@product_review_bp.route("/<int:pid>/reviews", methods=["GET"])
def get_product_reviews(pid):
    reviews = (ProductReview.query
               .filter_by(product_id=pid)
               .order_by(ProductReview.created_at.desc())
               .all())
    avg = round(sum(r.rating for r in reviews) / len(reviews), 1) if reviews else 0.0
    return jsonify({
        "reviews":        [r.to_dict() for r in reviews],
        "average_rating": avg,
        "total_reviews":  len(reviews),
    })


@product_review_bp.route("/<int:pid>/reviews", methods=["POST"])
def post_product_review(pid):
    if not Product.query.get(pid):
        return jsonify({"error": "Producto no encontrado"}), 404

    customer_id, err = _decode_customer(request)
    if err:
        return jsonify({"error": err[0]}), err[1]

    data = request.get_json(silent=True) or {}
    rating = data.get("rating")
    if not rating or not isinstance(rating, int) or not (1 <= rating <= 5):
        return jsonify({"error": "rating debe ser un entero entre 1 y 5"}), 400

    existing = ProductReview.query.filter_by(
        customer_id=customer_id, product_id=pid).first()
    if existing:
        existing.rating = rating
        existing.comment = (data.get("comment") or "")[:1000]
        db.session.commit()
        return jsonify(existing.to_dict()), 200

    r = ProductReview(
        customer_id=customer_id,
        product_id=pid,
        rating=rating,
        comment=(data.get("comment") or "")[:1000],
    )
    db.session.add(r)
    db.session.commit()
    return jsonify(r.to_dict()), 201


@product_review_bp.route("/<int:pid>/my-review", methods=["GET"])
def get_my_product_review(pid):
    customer_id, err = _decode_customer(request)
    if err:
        return jsonify({"error": err[0]}), err[1]
    r = ProductReview.query.filter_by(
        customer_id=customer_id, product_id=pid).first()
    return jsonify({"review": r.to_dict() if r else None})
