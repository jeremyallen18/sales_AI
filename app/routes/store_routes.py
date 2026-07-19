"""
store_routes.py — Tienda móvil para clientes.
Permite consultar productos, realizar compras y usar el chatbot de recomendaciones.
"""
from flask import Blueprint, render_template, request, jsonify
from .. import limiter
from ..services.inventory_service import get_all_products
from ..services.ai_service import ask_ai
from ..services.prompt_safety import sanitize_text, wrap_business_data, DATA_GUARD

store_bp = Blueprint("store", __name__, url_prefix="/tienda")

STORE_SYSTEM_PROMPT = """Eres un asistente amigable de tienda especializado en dulces, botanas y abarrotes.
Tu misión es ayudar a los clientes a encontrar productos y dar recomendaciones personalizadas.
Responde SIEMPRE en español, de forma cálida, breve y entusiasta.
Cuando recomiendes un producto, menciona su nombre exacto y precio.
Si el cliente pide algo que no existe en la tienda, sugiere la alternativa más parecida disponible.

{guard}

CATÁLOGO ACTUAL (solo productos con stock disponible):
{product_block}
"""


@store_bp.route("/")
def storefront():
    return render_template("cliente.html")


@store_bp.route("/chat", methods=["POST"])
@limiter.limit("15 per minute; 60 per hour")
def store_chat():
    """
    Chatbot público de recomendaciones para clientes móviles.
    No requiere autenticación. Devuelve JSON con la respuesta completa.
    """
    data = request.get_json(silent=True) or {}
    message = data.get("message", "").strip()

    if not message:
        return jsonify({"error": "El mensaje no puede estar vacío"}), 400

    try:
        branch_id = data.get("branch_id") or None
        if branch_id:
            from ..services.branch_service import get_branch_inventory
            items = get_branch_inventory(int(branch_id))
            product_lines = "\n".join(
                f"• {sanitize_text(bi.product.name)} | Categoría: {sanitize_text(bi.product.category)}"
                f" | Precio: ${bi.effective_price():.2f}"
                for bi in items if bi.stock > 0
            )
        else:
            products = get_all_products()
            product_lines = "\n".join(
                f"• {sanitize_text(p.name)} | Categoría: {sanitize_text(p.category)} | Precio: ${p.price:.2f}"
                for p in products if p.stock > 0
            )
        product_block = wrap_business_data(product_lines or "Sin productos disponibles")
        system_prompt = STORE_SYSTEM_PROMPT.format(guard=DATA_GUARD, product_block=product_block)

        response_text = ask_ai(system_prompt, message, stream=False)
        return jsonify({"response": response_text})

    except Exception as exc:
        return jsonify({"error": f"Error del asistente: {str(exc)}"}), 500
