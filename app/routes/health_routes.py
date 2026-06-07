from flask import Blueprint, jsonify, current_app
from ..database.db import db

health_bp = Blueprint("health", __name__, url_prefix="/api")


@health_bp.route("/health", methods=["GET"])
def health():
    try:
        db.session.execute(db.text("SELECT 1"))
        db_status = "ok"
    except Exception:
        db_status = "error"

    return jsonify({"status": "ok", "db": db_status}), 200


@health_bp.route("/routes", methods=["GET"])
def list_routes():
    """Lista todas las rutas registradas en la aplicación."""
    routes = []
    for rule in sorted(current_app.url_map.iter_rules(), key=lambda r: r.rule):
        routes.append({
            "url":      rule.rule,
            "methods":  sorted(m for m in rule.methods if m not in ("HEAD", "OPTIONS")),
            "endpoint": rule.endpoint,
        })
    return jsonify({"total": len(routes), "routes": routes})
