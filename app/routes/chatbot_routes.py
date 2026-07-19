"""
chatbot_routes.py — Endpoint del chatbot de IA con streaming SSE + JSON.
"""
from flask import Blueprint, request, Response, stream_with_context, jsonify
from .. import limiter
from ..services.chatbot_service import get_ai_response

chatbot_bp = Blueprint("chatbot", __name__, url_prefix="/api/chat")

@chatbot_bp.route("/", methods=["POST"])
@limiter.limit("20 per minute; 100 per hour")
def chat():
    """Recibe pregunta del usuario y retorna respuesta de IA con streaming."""
    data = request.get_json(silent=True)
    if not data:
        return Response("data: {\"error\": \"JSON inválido\"}\n\n", mimetype="text/event-stream", status=400)
    user_message = data.get("message", "")

    branch_id = data.get("branch_id") or None

    def generate():
        for chunk in get_ai_response(user_message, stream=True, branch_id=branch_id):
            yield chunk

    return Response(
        stream_with_context(generate()),
        mimetype="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no"
        }
    )

@chatbot_bp.route("/json", methods=["POST"])
@limiter.limit("20 per minute; 100 per hour")
def chat_json():
    """Respuesta JSON sin streaming — para apps móviles."""
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "JSON inválido o Content-Type incorrecto"}), 400
    user_message = data.get("message", "")
    branch_id = data.get("branch_id") or None
    try:
        response_text = get_ai_response(user_message, stream=False, branch_id=branch_id)
        return jsonify({"response": response_text})
    except Exception as e:
        return jsonify({"error": str(e)}), 500
