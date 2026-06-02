"""
settings_routes.py — Configuración básica de la app.
"""
from flask import Blueprint, jsonify, request
from flask import current_app

settings_bp = Blueprint("settings", __name__, url_prefix="/api/settings")

@settings_bp.route("/", methods=["GET"])
def get_settings():
    """Retorna configuración pública (sin API key)."""
    return jsonify({
        "business_name": current_app.config.get("BUSINESS_NAME", "Mi Negocio"),
        "ai_enabled": bool(current_app.config.get("OPENROUTER_API_KEY"))
    })
