"""
chatbot_service.py — Inyecta contexto real del negocio en el prompt de IA.
"""
from .analytics_service import get_summary_for_ai
from .ai_service import ask_ai
from .prompt_safety import wrap_business_data, DATA_GUARD
import json

SYSTEM_TEMPLATE = """Eres un analista de negocios especializado en ventas al por menor.
Respondes SIEMPRE en español, no debes usar ingles, de forma clara y profesional.
Basas tus análisis SOLO en los datos reales del negocio que se te proporcionan.

{guard}

DATOS ACTUALES DEL NEGOCIO:
{data}
"""

def get_ai_response(user_message: str, stream: bool = False):
    """Construye prompt con datos reales y llama al servicio de IA."""
    summary = get_summary_for_ai()
    data_str = wrap_business_data(json.dumps(summary, ensure_ascii=False, indent=2))
    system_prompt = SYSTEM_TEMPLATE.format(guard=DATA_GUARD, data=data_str)
    return ask_ai(system_prompt, user_message, stream=stream)
