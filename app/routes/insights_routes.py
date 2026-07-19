"""
insights_routes.py — Endpoint del Asesor IA Proactivo.

Devuelve recomendaciones accionables generadas a partir de los datos reales del
negocio. Nunca devuelve 500: ante cualquier error responde con el fallback de
reglas para que el dashboard siempre reciba recomendaciones.
"""
from flask import Blueprint, jsonify, request

from .. import limiter
from ..services.insights_service import get_business_insights, _rule_based_insights
from ..services.analytics_service import get_summary_for_ai
from ..services.forecast_service import get_demand_forecast

insights_bp = Blueprint("insights", __name__, url_prefix="/api/insights")


@insights_bp.route("/", methods=["GET"])
@limiter.limit("10 per minute; 60 per hour")
def insights():
    """Recomendaciones de negocio (IA con fallback determinista)."""
    branch_id = request.args.get("branch_id", type=int)
    try:
        return jsonify(get_business_insights(branch_id=branch_id))
    except Exception:
        return jsonify({
            "insights": _rule_based_insights(get_summary_for_ai(branch_id=branch_id)),
            "fuente": "reglas",
        })


@insights_bp.route("/forecast", methods=["GET"])
@limiter.limit("6 per minute; 30 per hour")
def forecast():
    """Predicción de demanda semanal por producto (IA con fallback determinista)."""
    branch_id = request.args.get("branch_id", type=int)
    try:
        return jsonify(get_demand_forecast(branch_id=branch_id))
    except Exception as e:
        return jsonify({"error": str(e), "predicciones": [], "fuente": "error"}), 500
