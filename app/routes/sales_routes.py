"""
sales_routes.py — Registro y consulta de ventas + descarga de recibo.
"""
from flask import Blueprint, jsonify, request, send_file
from ..services.sales_service import register_sale, get_recent_sales, get_sale_by_id
from ..services.pdf_service import generate_receipt
import io

sales_bp = Blueprint("sales", __name__, url_prefix="/api/sales")

@sales_bp.route("/", methods=["POST"])
def new_sale():
    """Registra venta y descuenta stock."""
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "Cuerpo JSON inválido o Content-Type incorrecto"}), 400
    try:
        client_name = (data.get("client_name") or "").strip()
        payment_method = (data.get("payment_method") or "efectivo").strip().lower()
        items = data.get("items")
        if not items:
            return jsonify({"error": "Se requiere al menos un ítem"}), 400
        sale = register_sale(items, client_name=client_name, payment_method=payment_method)
        return jsonify(sale.to_dict()), 201
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": f"Error interno: {str(e)}"}), 500

@sales_bp.route("/", methods=["GET"])
def list_sales():
    return jsonify([s.to_dict() for s in get_recent_sales()])

@sales_bp.route("/<int:sid>/receipt", methods=["GET"])
def download_receipt(sid):
    """Descarga recibo PDF de una venta especifica."""
    sale = get_sale_by_id(sid)
    pdf_bytes = generate_receipt(sale)
    return send_file(
        io.BytesIO(pdf_bytes),
        mimetype="application/pdf",
        as_attachment=True,
        download_name=f"recibo_{sid:04d}.pdf"
    )
