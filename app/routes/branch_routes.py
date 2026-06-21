"""
branch_routes.py — CRUD de sucursales, inventario por sucursal y asignaciones.
"""
from flask import Blueprint, jsonify, request
from ..services.branch_service import (
    get_all_branches, get_branch_by_id, create_branch, update_branch,
    delete_branch, get_nearby_branches, get_branch_inventory,
    upsert_branch_inventory, assign_seller_to_branch, unassign_seller_from_branch,
    get_seller_branches,
)
from ..utils.auth_required import owner_required, seller_or_admin_required

branch_bp = Blueprint("branches", __name__, url_prefix="/api/branches")


# ── Pública: sucursales cercanas ──────────────────────────────────────────────

@branch_bp.route("/nearby", methods=["GET"])
def nearby():
    lat = request.args.get("lat", type=float)
    lng = request.args.get("lng", type=float)
    radius = request.args.get("radius", 20, type=float)
    if lat is None or lng is None:
        return jsonify({"error": "lat y lng son requeridos"}), 400
    return jsonify(get_nearby_branches(lat, lng, radius))


# ── Pública: lista/detalle de sucursales ─────────────────────────────────────

@branch_bp.route("/", methods=["GET"])
def list_branches():
    active_only = request.args.get("active_only", "true").lower() != "false"
    return jsonify([b.to_dict() for b in get_all_branches(active_only=active_only)])


@branch_bp.route("/<int:bid>", methods=["GET"])
def get_branch(bid):
    return jsonify(get_branch_by_id(bid).to_dict())


# ── Pública: inventario de una sucursal (catálogo cliente) ────────────────────

@branch_bp.route("/<int:bid>/inventory", methods=["GET"])
def branch_inventory(bid):
    items = get_branch_inventory(bid)
    return jsonify([bi.to_dict() for bi in items])


# ── Pública: ofertas activas (con descuento o badge) ─────────────────────────

@branch_bp.route("/offers", methods=["GET"])
def list_offers():
    """Devuelve todos los items de inventario con oferta activa.
    Filtra por branch_id si se provee. Ordena por discount_pct desc."""
    from ..models.branch_inventory import BranchInventory
    from ..models.branch import Branch
    branch_id = request.args.get("branch_id", type=int)
    q = (BranchInventory.query
         .join(BranchInventory.product)
         .filter(
             (BranchInventory.discount_pct > 0) |
             (BranchInventory.offer_badge.isnot(None))
         ))
    if branch_id:
        q = q.filter(BranchInventory.branch_id == branch_id)
    items = q.all()
    # Enriquece con nombre de sucursal
    branch_names = {}
    result = []
    for bi in items:
        if bi.branch_id not in branch_names:
            b = Branch.query.get(bi.branch_id)
            branch_names[bi.branch_id] = b.name if b else f"Sucursal {bi.branch_id}"
        d = bi.to_dict()
        d["branch_name"] = branch_names[bi.branch_id]
        result.append(d)
    result.sort(key=lambda x: x.get("discount_pct") or 0, reverse=True)
    return jsonify(result)


# ── Owner: CRUD de sucursales ─────────────────────────────────────────────────

@branch_bp.route("/", methods=["POST"])
@owner_required
def create():
    data = request.get_json(silent=True) or {}
    if not data.get("name"):
        return jsonify({"error": "El campo 'name' es requerido"}), 400
    return jsonify(create_branch(data).to_dict()), 201


@branch_bp.route("/<int:bid>", methods=["PUT"])
@owner_required
def update(bid):
    data = request.get_json(silent=True) or {}
    return jsonify(update_branch(bid, data).to_dict())


@branch_bp.route("/<int:bid>", methods=["DELETE"])
@owner_required
def delete(bid):
    delete_branch(bid)
    return jsonify({"ok": True})


# ── Admin/Owner: gestión de inventario por sucursal ───────────────────────────

@branch_bp.route("/<int:bid>/inventory/<int:pid>", methods=["PUT"])
@seller_or_admin_required
def update_inventory(bid, pid):
    data = request.get_json(silent=True) or {}
    bi = upsert_branch_inventory(bid, pid, data)
    return jsonify(bi.to_dict())


# ── Owner: asignación de vendedores a sucursal ────────────────────────────────

@branch_bp.route("/<int:bid>/assign", methods=["POST"])
@owner_required
def assign(bid):
    data = request.get_json(silent=True) or {}
    seller_id = data.get("seller_id")
    if not seller_id:
        return jsonify({"error": "seller_id requerido"}), 400
    a = assign_seller_to_branch(int(seller_id), bid)
    return jsonify(a.to_dict()), 201


@branch_bp.route("/<int:bid>/assign/<int:sid>", methods=["DELETE"])
@owner_required
def unassign(bid, sid):
    unassign_seller_from_branch(sid, bid)
    return jsonify({"ok": True})


# ── Sellers de una sucursal ───────────────────────────────────────────────────

@branch_bp.route("/<int:bid>/sellers", methods=["GET"])
@owner_required
def list_branch_sellers(bid):
    from ..models.branch_assignment import BranchAssignment
    from ..models.seller_account import SellerAccount
    assignments = BranchAssignment.query.filter_by(branch_id=bid).all()
    result = []
    for a in assignments:
        seller = SellerAccount.query.get(a.seller_id)
        if seller:
            d = seller.to_dict()
            d["assignment_id"] = a.id
            result.append(d)
    return jsonify(result)
