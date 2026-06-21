"""
branch_service.py — CRUD de sucursales, inventario por sucursal y asignaciones.
"""
import math
import json
from ..database.db import db
from ..models.branch import Branch
from ..models.branch_inventory import BranchInventory
from ..models.branch_assignment import BranchAssignment


# ── Sucursales ────────────────────────────────────────────────────────────────

def get_all_branches(active_only=True):
    q = Branch.query
    if active_only:
        q = q.filter_by(is_active=True)
    return q.order_by(Branch.name).all()


def get_branch_by_id(bid):
    return Branch.query.get_or_404(bid)


def create_branch(data):
    b = Branch(
        name=data["name"],
        description=data.get("description", ""),
        address=data.get("address", ""),
        city=data.get("city", ""),
        state=data.get("state", ""),
        zip_code=data.get("zip_code", ""),
        latitude=data.get("latitude"),
        longitude=data.get("longitude"),
        phone=data.get("phone", ""),
        email=data.get("email", ""),
        opening_time=data.get("opening_time", "08:00"),
        closing_time=data.get("closing_time", "22:00"),
        is_active=data.get("is_active", True),
        images=json.dumps(data.get("images", [])),
    )
    db.session.add(b)
    db.session.commit()
    return b


def update_branch(bid, data):
    b = Branch.query.get_or_404(bid)
    for field in ["name", "description", "address", "city", "state", "zip_code",
                  "latitude", "longitude", "phone", "email", "opening_time",
                  "closing_time", "is_active"]:
        if field in data:
            setattr(b, field, data[field])
    if "images" in data:
        b.images = json.dumps(data["images"])
    db.session.commit()
    return b


def delete_branch(bid):
    b = Branch.query.get_or_404(bid)
    db.session.delete(b)
    db.session.commit()


def get_nearby_branches(lat, lng, radius_km=20):
    """Devuelve sucursales activas ordenadas por distancia al punto dado."""
    branches = get_all_branches(active_only=True)
    result = []
    for b in branches:
        if b.latitude is None or b.longitude is None:
            continue
        dist = _haversine(lat, lng, b.latitude, b.longitude)
        if dist <= radius_km:
            result.append(b.to_dict(distance_km=round(dist, 2)))
    result.sort(key=lambda x: x["distance_km"])
    return result


def _haversine(lat1, lon1, lat2, lon2):
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2))
         * math.sin(dlon / 2) ** 2)
    return R * 2 * math.asin(math.sqrt(a))


# ── Inventario por sucursal ───────────────────────────────────────────────────

def get_branch_inventory(branch_id):
    return (BranchInventory.query
            .filter_by(branch_id=branch_id)
            .join(BranchInventory.product)
            .all())


def upsert_branch_inventory(branch_id, product_id, data):
    bi = BranchInventory.query.filter_by(
        branch_id=branch_id, product_id=product_id).first()
    if bi is None:
        bi = BranchInventory(branch_id=branch_id, product_id=product_id)
        db.session.add(bi)
    if "stock" in data:
        bi.stock = int(data["stock"])
    if "price" in data:
        bi.price = float(data["price"]) if data["price"] is not None else None
    if "discount_pct" in data:
        bi.discount_pct = float(data["discount_pct"]) if data["discount_pct"] is not None else None
    if "offer_badge" in data:
        raw = (data["offer_badge"] or "").strip()
        bi.offer_badge = raw[:40] if raw else None
    db.session.commit()
    return bi


# ── Asignaciones seller → sucursal ───────────────────────────────────────────

def get_seller_branches(seller_id):
    assignments = BranchAssignment.query.filter_by(seller_id=seller_id).all()
    return [a.branch_id for a in assignments]


def assign_seller_to_branch(seller_id, branch_id):
    existing = BranchAssignment.query.filter_by(
        seller_id=seller_id, branch_id=branch_id).first()
    if existing:
        return existing
    a = BranchAssignment(seller_id=seller_id, branch_id=branch_id)
    db.session.add(a)
    db.session.commit()
    return a


def unassign_seller_from_branch(seller_id, branch_id):
    a = BranchAssignment.query.filter_by(
        seller_id=seller_id, branch_id=branch_id).first()
    if a:
        db.session.delete(a)
        db.session.commit()
