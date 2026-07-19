"""
sales_routes.py — Registro y consulta de ventas + recibo HTML.
"""
from flask import Blueprint, jsonify, request, send_file, render_template, current_app
from ..services.sales_service import register_sale, get_recent_sales, get_sale_by_id
from ..services.pdf_service import generate_receipt, generate_qr_b64
import io

sales_bp = Blueprint("sales", __name__, url_prefix="/api/sales")


def _get_customer_from_token():
    """Extrae (customer_id, display_name) del Bearer token si está presente."""
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None, ""
    try:
        import jwt
        payload = jwt.decode(
            auth[7:],
            current_app.config["APP_TOKEN_SECRET"],
            algorithms=["HS256"],
        )
        if payload.get("role") == "customer":
            from ..models.customer import Customer
            cust = Customer.query.get(int(payload["sub"]))
            if cust:
                return cust.id, cust.display_name
    except Exception:
        pass
    return None, ""


@sales_bp.route("/", methods=["POST"])
def new_sale():
    """Registra venta y descuenta stock."""
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "Cuerpo JSON inválido o Content-Type incorrecto"}), 400
    try:
        client_name    = (data.get("client_name") or "").strip()
        payment_method = (data.get("payment_method") or "efectivo").strip().lower()
        items          = data.get("items")
        if not items:
            return jsonify({"error": "Se requiere al menos un ítem"}), 400

        customer_id, auto_name = _get_customer_from_token()
        if not client_name and auto_name:
            client_name = auto_name

        branch_id = data.get("branch_id") or None
        if branch_id is not None:
            branch_id = int(branch_id)

        sale = register_sale(
            items,
            client_name=client_name,
            payment_method=payment_method,
            customer_id=customer_id,
            branch_id=branch_id,
        )
        return jsonify(sale.to_dict()), 201
    except ValueError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:
        return jsonify({"error": f"Error interno: {str(e)}"}), 500

@sales_bp.route("/", methods=["GET"])
def list_sales():
    branch_id = request.args.get("branch_id", type=int)
    from ..models.sale import Sale
    q = Sale.query
    if branch_id is not None:
        q = q.filter(Sale.branch_id == branch_id)
    sales = q.order_by(Sale.created_at.desc()).limit(20).all()
    return jsonify([s.to_dict() for s in sales])

_MESES = ["Enero","Febrero","Marzo","Abril","Mayo","Junio",
          "Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"]

@sales_bp.route("/<int:sid>/receipt", methods=["GET"])
def download_receipt(sid):
    """Muestra recibo HTML con diseño OXXO Go."""
    sale = get_sale_by_id(sid)
    qr_b64 = generate_qr_b64(sale)
    dt = sale.created_at
    date = f"{dt.day:02d} {_MESES[dt.month - 1]} {dt.year}"
    time = dt.strftime("%I:%M %p")
    return render_template("receipt.html", sale=sale, date=date, time=time, qr_b64=qr_b64)

@sales_bp.route("/<int:sid>/receipt/pdf", methods=["GET"])
def download_receipt_pdf(sid):
    """Descarga recibo PDF (formato legacy)."""
    sale = get_sale_by_id(sid)
    pdf_bytes = generate_receipt(sale)
    return send_file(
        io.BytesIO(pdf_bytes),
        mimetype="application/pdf",
        as_attachment=True,
        download_name=f"recibo_{sid:04d}.pdf"
    )
