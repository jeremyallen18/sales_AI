"""
firebase_auth_routes.py — Autenticación con Firebase ID Token (Google Sign-In).

Endpoints:
  POST /api/auth/google/customer  — para la app cliente Flutter
  POST /api/auth/google/seller    — para la app vendedor Flutter y web admin
  GET  /api/auth/me               — perfil del portador del Bearer token
"""
import jwt
import datetime
import os
import firebase_admin
from flask import Blueprint, request, jsonify, current_app, session

firebase_auth_bp = Blueprint("firebase_auth", __name__, url_prefix="/api/auth")


def _firebase_available():
    return bool(firebase_admin._apps)


def _verify_firebase_token(id_token: str) -> dict:
    from firebase_admin import auth as fb_auth
    return fb_auth.verify_id_token(id_token)


def _verify_google_token_via_api(id_token: str) -> dict:
    """Verifica un Google ID token usando la API pública de Google.
    No requiere Firebase en el cliente ni registro de dominios/IPs."""
    import requests as req_lib
    r = req_lib.get(
        'https://oauth2.googleapis.com/tokeninfo',
        params={'id_token': id_token},
        timeout=5,
    )
    if r.status_code != 200:
        raise ValueError('Token de Google inválido o expirado')
    info = r.json()
    if 'error' in info:
        raise ValueError(info.get('error_description', 'Token rechazado por Google'))
    uid = info.get('sub', '')
    if not uid:
        raise ValueError('Token sin identificador de usuario')
    return {
        'uid': uid,
        'email': info.get('email', ''),
        'name': info.get('name', info.get('email', '').split('@')[0]),
        'picture': info.get('picture', ''),
    }


def _token_issuer(id_token: str) -> str:
    """Decodifica el payload del JWT sin verificar firma y retorna el campo iss."""
    try:
        import base64
        import json as _json
        part = id_token.split('.')[1]
        part += '=' * (4 - len(part) % 4)   # padding
        return _json.loads(base64.b64decode(part)).get('iss', '')
    except Exception:
        return ''


def _verify_any_token(id_token: str) -> dict:
    """Enruta la verificación según el emisor (iss) del JWT.

    - Firebase ID token  (iss = securetoken.google.com/…) → Firebase Admin SDK
    - Google ID token    (iss = accounts.google.com)       → API tokeninfo de Google

    Esto permite usar la app desde cualquier IP/red sin registrar dominios en Firebase.
    """
    iss = _token_issuer(id_token)

    if 'securetoken.google.com' in iss:
        # Token emitido por Firebase → solo Firebase Admin puede verificarlo
        if not _firebase_available():
            raise ValueError('Firebase Admin no está configurado en el servidor')
        claims = _verify_firebase_token(id_token)
        return {
            'uid': claims['uid'],
            'email': claims.get('email', ''),
            'name': claims.get('name', ''),
            'picture': claims.get('picture', ''),
        }

    # Token emitido directamente por Google (google_sign_in sin firebase_auth,
    # o Google Identity Services en el navegador) → API tokeninfo de Google.
    # Esta ruta no requiere que ningún dominio/IP esté registrado en Firebase.
    return _verify_google_token_via_api(id_token)


def _make_app_token(payload: dict, ttl_hours: int, secret: str) -> str:
    data = payload.copy()
    data["exp"] = datetime.datetime.utcnow() + datetime.timedelta(hours=ttl_hours)
    data["iat"] = datetime.datetime.utcnow()
    return jwt.encode(data, secret, algorithm="HS256")


def _decode_app_token(token: str, secret: str) -> dict:
    return jwt.decode(token, secret, algorithms=["HS256"])


@firebase_auth_bp.route("/google/customer", methods=["POST"])
def google_customer_login():
    """
    Body: { "id_token": "<Firebase ID token o Google ID token>" }
    Returns: { "ok": true, "token": "<app JWT>", "customer": {...} }
    """
    from ..database.db import db
    from ..models.customer import Customer

    data = request.get_json(silent=True) or {}
    id_token = (data.get("id_token") or "").strip()
    if not id_token:
        return jsonify({"error": "id_token requerido"}), 400

    try:
        claims = _verify_any_token(id_token)
    except Exception as e:
        return jsonify({"error": f"Token inválido: {str(e)}"}), 401

    uid          = claims["uid"]
    email        = claims.get("email", "")
    display_name = claims.get("name", "")
    photo_url    = claims.get("picture", "")

    customer = Customer.query.filter_by(firebase_uid=uid).first()
    if customer is None:
        # Puede existir un registro previo con el mismo email pero sin UID vinculado
        customer = Customer.query.filter_by(email=email).first()
        if customer is not None:
            customer.firebase_uid = uid
            customer.display_name = display_name
            customer.photo_url    = photo_url
        else:
            customer = Customer(
                firebase_uid=uid,
                email=email,
                display_name=display_name,
                photo_url=photo_url,
            )
            db.session.add(customer)
    else:
        customer.display_name = display_name
        customer.photo_url    = photo_url
    db.session.commit()

    secret = current_app.config["APP_TOKEN_SECRET"]
    ttl    = current_app.config["APP_TOKEN_TTL_HOURS"]
    token  = _make_app_token(
        {"sub": str(customer.id), "uid": uid, "role": "customer"},
        ttl, secret,
    )
    return jsonify({"ok": True, "token": token, "customer": customer.to_dict()}), 200


@firebase_auth_bp.route("/google/seller", methods=["POST"])
def google_seller_login():
    """
    Body: { "id_token": "<Firebase ID token o Google ID token directo>" }
    Returns: { "ok": true, "token": "<app JWT>", "seller": {...} }

    Política de acceso:
    - Si la tabla está vacía el primer usuario queda como owner.
    - Si el email ya existe en seller_accounts se vincula el UID.
    - De lo contrario se devuelve 403.
    """
    from ..database.db import db
    from ..models.seller_account import SellerAccount

    data = request.get_json(silent=True) or {}
    id_token = (data.get("id_token") or "").strip()
    if not id_token:
        return jsonify({"error": "id_token requerido"}), 400

    try:
        claims = _verify_any_token(id_token)
    except Exception as e:
        return jsonify({"error": f"Token inválido: {str(e)}"}), 401

    uid          = claims["uid"]
    email        = claims.get("email", "")
    display_name = claims.get("name", "")
    photo_url    = claims.get("picture", "")

    seller = SellerAccount.query.filter_by(firebase_uid=uid).first()
    if seller is None:
        seller_by_email = SellerAccount.query.filter_by(email=email).first()
        total           = SellerAccount.query.count()
        if seller_by_email:
            seller_by_email.firebase_uid = uid
            seller_by_email.display_name = display_name
            db.session.commit()
            seller = seller_by_email
        elif total == 0:
            # Primera cuenta — se convierte en owner (dueño global)
            seller = SellerAccount(
                firebase_uid=uid,
                email=email,
                display_name=display_name,
                photo_url=photo_url,
                role="owner",
                is_active=True,
            )
            db.session.add(seller)
            db.session.commit()
        else:
            return jsonify({"error": "No tienes acceso como vendedor"}), 403

    if not seller.is_active:
        return jsonify({"error": "Cuenta desactivada"}), 403

    seller.display_name = display_name
    seller.photo_url    = photo_url
    db.session.commit()

    # Establecer sesión web para flujos desde el navegador
    session["user"] = seller.email

    from ..services.branch_service import get_seller_branches
    from ..models.branch import Branch
    branch_ids = get_seller_branches(seller.id)
    branches = [Branch.query.get(bid).to_dict() for bid in branch_ids
                if Branch.query.get(bid)]

    secret = current_app.config["APP_TOKEN_SECRET"]
    ttl    = current_app.config["APP_TOKEN_TTL_HOURS"]
    token  = _make_app_token(
        {"sub": str(seller.id), "uid": uid, "role": seller.role,
         "branch_ids": branch_ids},
        ttl, secret,
    )
    seller_data = seller.to_dict()
    seller_data["branches"] = branches
    return jsonify({"ok": True, "token": token, "seller": seller_data}), 200


@firebase_auth_bp.route("/me", methods=["GET"])
def get_me():
    """
    Header: Authorization: Bearer <app JWT>
    Devuelve el perfil del portador.
    """
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return jsonify({"error": "Token requerido"}), 401
    token = auth_header[7:]
    try:
        secret  = current_app.config["APP_TOKEN_SECRET"]
        payload = _decode_app_token(token, secret)
    except jwt.ExpiredSignatureError:
        return jsonify({"error": "Token expirado"}), 401
    except jwt.InvalidTokenError:
        return jsonify({"error": "Token inválido"}), 401

    from ..models.customer import Customer
    from ..models.seller_account import SellerAccount

    role = payload.get("role")
    sub  = int(payload.get("sub", 0))
    if role == "customer":
        obj = Customer.query.get(sub)
        return (jsonify(obj.to_dict()), 200) if obj else (jsonify({"error": "No encontrado"}), 404)
    if role in ("seller", "admin", "owner"):
        obj = SellerAccount.query.get(sub)
        if not obj:
            return jsonify({"error": "No encontrado"}), 404
        from ..services.branch_service import get_seller_branches
        from ..models.branch import Branch
        branch_ids = get_seller_branches(obj.id)
        data = obj.to_dict()
        data["branch_ids"] = branch_ids
        data["branches"] = [Branch.query.get(bid).to_dict() for bid in branch_ids
                            if Branch.query.get(bid)]
        return jsonify(data), 200
    return jsonify({"error": "Rol inválido"}), 400


@firebase_auth_bp.route("/sellers", methods=["GET"])
def list_sellers():
    """Lista todos los vendedores/admins — solo para owner."""
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        return jsonify({"error": "Token requerido"}), 401
    try:
        secret  = current_app.config["APP_TOKEN_SECRET"]
        payload = _decode_app_token(auth_header[7:], secret)
    except Exception:
        return jsonify({"error": "Token inválido"}), 401
    if payload.get("role") not in ("owner", "admin"):
        return jsonify({"error": "Acceso denegado"}), 403

    from ..models.seller_account import SellerAccount
    sellers = SellerAccount.query.filter_by(is_active=True).all()
    return jsonify([s.to_dict() for s in sellers])
