"""
combo_routes.py — CRUD de combos de productos.
"""
from flask import Blueprint, jsonify, request
from ..database.db import db
from ..models.combo import Combo, ComboItem
from ..utils.auth_required import owner_required

combo_bp = Blueprint("combos", __name__, url_prefix="/api/combos")


# ── Pública: combos activos ───────────────────────────────────────────────────

@combo_bp.route("/", methods=["GET"])
def list_combos():
    """Combos activos; filtra por branch_id si se provee (incluye globales)."""
    branch_id = request.args.get("branch_id", type=int)
    q = Combo.query.filter_by(is_active=True)
    if branch_id:
        q = q.filter(
            (Combo.branch_id == branch_id) | (Combo.branch_id.is_(None))
        )
    return jsonify([c.to_dict() for c in q.order_by(Combo.created_at.desc()).all()])


# ── Owner: admin ──────────────────────────────────────────────────────────────

@combo_bp.route("/all", methods=["GET"])
@owner_required
def list_all():
    """Admin: todos los combos (incluyendo inactivos)."""
    combos = Combo.query.order_by(Combo.created_at.desc()).all()
    return jsonify([c.to_dict() for c in combos])


@combo_bp.route("/<int:cid>", methods=["GET"])
@owner_required
def get_combo(cid):
    return jsonify(Combo.query.get_or_404(cid).to_dict())


@combo_bp.route("/", methods=["POST"])
@owner_required
def create_combo():
    data = request.get_json(silent=True) or {}
    if not data.get("name"):
        return jsonify({"error": "El nombre es requerido"}), 400
    if not data.get("price"):
        return jsonify({"error": "El precio es requerido"}), 400

    combo = Combo(
        name=data["name"].strip(),
        description=(data.get("description") or "").strip(),
        price=float(data["price"]),
        image_url=(data.get("image_url") or "").strip(),
        is_active=bool(data.get("is_active", True)),
        branch_id=data.get("branch_id") or None,
    )
    db.session.add(combo)
    db.session.flush()

    for item in data.get("items", []):
        pid = item.get("product_id")
        qty = int(item.get("quantity") or 1)
        if pid and qty > 0:
            db.session.add(ComboItem(combo_id=combo.id, product_id=int(pid), quantity=qty))

    db.session.commit()
    return jsonify(combo.to_dict()), 201


@combo_bp.route("/<int:cid>", methods=["PUT"])
@owner_required
def update_combo(cid):
    combo = Combo.query.get_or_404(cid)
    data  = request.get_json(silent=True) or {}

    if "name"        in data: combo.name        = data["name"].strip()
    if "description" in data: combo.description = (data["description"] or "").strip()
    if "price"       in data: combo.price        = float(data["price"])
    if "image_url"   in data: combo.image_url    = (data["image_url"] or "").strip()
    if "is_active"   in data: combo.is_active    = bool(data["is_active"])
    if "branch_id"   in data: combo.branch_id    = data["branch_id"] or None

    if "items" in data:
        ComboItem.query.filter_by(combo_id=cid).delete()
        for item in data["items"]:
            pid = item.get("product_id")
            qty = int(item.get("quantity") or 1)
            if pid and qty > 0:
                db.session.add(ComboItem(combo_id=cid, product_id=int(pid), quantity=qty))

    db.session.commit()
    return jsonify(combo.to_dict())


@combo_bp.route("/<int:cid>", methods=["DELETE"])
@owner_required
def delete_combo(cid):
    combo = Combo.query.get_or_404(cid)
    db.session.delete(combo)
    db.session.commit()
    return jsonify({"message": "Combo eliminado"})
