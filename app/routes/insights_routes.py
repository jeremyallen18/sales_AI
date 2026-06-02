"""
insights_routes.py — Endpoint del Asesor IA Proactivo.

Devuelve recomendaciones accionables generadas a partir de los datos reales del
negocio. Nunca devuelve 500: ante cualquier error responde con el fallback de
reglas para que el dashboard siempre reciba recomendaciones.
"""
from flask import Blueprint, jsonify

from .. import limiter
from ..services.insights_service import get_business_insights, _rule_based_insights
from ..services.analytics_service import get_summary_for_ai

insights_bp = Blueprint("insights", __name__, url_prefix="/api/insights")


@insights_bp.route("/", methods=["GET"])
@limiter.limit("10 per minute; 60 per hour")
def insights():
    """Recomendaciones de negocio (IA con fallback determinista)."""
    try:
        return jsonify(get_business_insights())
    except Exception:
        # Último recurso: nunca dejar al dashboard sin datos.
        return jsonify({
            "insights": _rule_based_insights(get_summary_for_ai()),
            "fuente": "reglas",
        })
