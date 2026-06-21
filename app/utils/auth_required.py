"""
auth_required.py — Decoradores para proteger endpoints de la API con JWT de app.
Los decoradores aceptan Bearer JWT (apps móviles) O sesión Flask (panel web).
"""
import jwt
from functools import wraps
from flask import request, jsonify, current_app, session


def _session_is_admin():
    """Devuelve True si hay sesión web activa (usuario admin del panel)."""
    return "user" in session


def seller_required(f):
    """Exige Bearer JWT (role seller/admin/owner) o sesión Flask activa."""
    @wraps(f)
    def decorated(*args, **kwargs):
        if _session_is_admin():
            return f(*args, **kwargs)
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return jsonify({"error": "Autenticación requerida"}), 401
        try:
            payload = jwt.decode(
                auth[7:],
                current_app.config["APP_TOKEN_SECRET"],
                algorithms=["HS256"],
            )
            if payload.get("role") not in ("seller", "admin", "owner"):
                return jsonify({"error": "Acceso denegado"}), 403
            request.seller_payload = payload
        except jwt.ExpiredSignatureError:
            return jsonify({"error": "Token expirado"}), 401
        except jwt.InvalidTokenError:
            return jsonify({"error": "Token inválido"}), 401
        return f(*args, **kwargs)
    return decorated


def owner_required(f):
    """Exige Bearer JWT (role owner) o sesión Flask activa (panel web = owner)."""
    @wraps(f)
    def decorated(*args, **kwargs):
        if _session_is_admin():
            return f(*args, **kwargs)
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return jsonify({"error": "Autenticación requerida"}), 401
        try:
            payload = jwt.decode(
                auth[7:],
                current_app.config["APP_TOKEN_SECRET"],
                algorithms=["HS256"],
            )
            if payload.get("role") != "owner":
                return jsonify({"error": "Acceso solo para el dueño"}), 403
            request.seller_payload = payload
        except jwt.ExpiredSignatureError:
            return jsonify({"error": "Token expirado"}), 401
        except jwt.InvalidTokenError:
            return jsonify({"error": "Token inválido"}), 401
        return f(*args, **kwargs)
    return decorated


def seller_or_admin_required(f):
    """
    Exige Bearer JWT (role seller/admin/owner) o sesión Flask activa.
    Para sellers con JWT, verifica acceso a la sucursal del request.
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        if _session_is_admin():
            return f(*args, **kwargs)
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return jsonify({"error": "Autenticación requerida"}), 401
        try:
            payload = jwt.decode(
                auth[7:],
                current_app.config["APP_TOKEN_SECRET"],
                algorithms=["HS256"],
            )
            role = payload.get("role")
            if role not in ("seller", "admin", "owner"):
                return jsonify({"error": "Acceso denegado"}), 403

            if role == "seller":
                bid = kwargs.get("bid") or kwargs.get("branch_id")
                if bid is not None:
                    from ..models.branch_assignment import BranchAssignment
                    seller_id = int(payload.get("sub", 0))
                    ok = BranchAssignment.query.filter_by(
                        seller_id=seller_id, branch_id=int(bid)).first()
                    if not ok:
                        return jsonify({"error": "Sin acceso a esta sucursal"}), 403

            request.seller_payload = payload
        except jwt.ExpiredSignatureError:
            return jsonify({"error": "Token expirado"}), 401
        except jwt.InvalidTokenError:
            return jsonify({"error": "Token inválido"}), 401
        return f(*args, **kwargs)
    return decorated
