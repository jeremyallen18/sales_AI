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
{branch_context}
{guard}

DATOS ACTUALES DEL NEGOCIO{branch_label}:
{data}
"""

def get_ai_response(user_message: str, stream: bool = False, branch_id: int = None):
    """Construye prompt con datos reales y llama al servicio de IA."""
    branch_context = ""
    branch_label = ""
    if branch_id:
        from ..models.branch import Branch
        b = Branch.query.get(branch_id)
        if b:
            branch_label = f" — Sucursal: {b.name}"
            branch_context = f"\nSucursal activa: {b.name}, {b.city}\n"
    summary = get_summary_for_ai(branch_id=branch_id)
    data_str = wrap_business_data(json.dumps(summary, ensure_ascii=False, indent=2))
    system_prompt = SYSTEM_TEMPLATE.format(
        guard=DATA_GUARD, data=data_str,
        branch_context=branch_context, branch_label=branch_label)
    return ask_ai(system_prompt, user_message, stream=stream)
