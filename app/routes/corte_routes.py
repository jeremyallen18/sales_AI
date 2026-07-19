"""
corte_routes.py — Endpoints de corte de caja semanal y mensual.

GET /api/cortes/semanal          → JSON del corte de la semana actual
GET /api/cortes/semanal?semanas_atras=1   → semana anterior
GET /api/cortes/mensual          → JSON del corte del mes actual
GET /api/cortes/mensual?meses_atras=1     → mes anterior

Parámetros comunes:
    branch_id    (int, opcional) — filtra por sucursal
    semanas_atras / meses_atras  (int, default 0) — períodos anteriores

Sufijo /pdf en cualquier ruta descarga el PDF correspondiente.
"""
import io
from flask import Blueprint, jsonify, request, send_file
from ..services.corte_service import corte_semanal, corte_mensual
from ..services.pdf_service import generate_corte_pdf
from ..utils.auth_required import seller_required

corte_bp = Blueprint("cortes", __name__, url_prefix="/api/cortes")


def _parse_params():
    branch_id = request.args.get("branch_id", type=int)
    return branch_id


@corte_bp.route("/semanal", methods=["GET"])
@seller_required
def get_corte_semanal():
    semanas_atras = request.args.get("semanas_atras", 0, type=int)
    branch_id     = _parse_params()
    return jsonify(corte_semanal(branch_id=branch_id, semanas_atras=semanas_atras))


@corte_bp.route("/semanal/pdf", methods=["GET"])
@seller_required
def get_corte_semanal_pdf():
    semanas_atras = request.args.get("semanas_atras", 0, type=int)
    branch_id     = _parse_params()
    corte         = corte_semanal(branch_id=branch_id, semanas_atras=semanas_atras)
    pdf           = generate_corte_pdf(corte)
    nombre        = f"corte_semanal_{corte['periodo']['inicio'][:10]}.pdf"
    return send_file(io.BytesIO(pdf), mimetype="application/pdf",
                     as_attachment=True, download_name=nombre)


@corte_bp.route("/mensual", methods=["GET"])
@seller_required
def get_corte_mensual():
    meses_atras = request.args.get("meses_atras", 0, type=int)
    branch_id   = _parse_params()
    return jsonify(corte_mensual(branch_id=branch_id, meses_atras=meses_atras))


@corte_bp.route("/mensual/pdf", methods=["GET"])
@seller_required
def get_corte_mensual_pdf():
    meses_atras = request.args.get("meses_atras", 0, type=int)
    branch_id   = _parse_params()
    corte       = corte_mensual(branch_id=branch_id, meses_atras=meses_atras)
    pdf         = generate_corte_pdf(corte)
    nombre      = f"corte_mensual_{corte['periodo']['inicio'][:7]}.pdf"
    return send_file(io.BytesIO(pdf), mimetype="application/pdf",
                     as_attachment=True, download_name=nombre)
