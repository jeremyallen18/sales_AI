"""
insights_service.py — Asesor IA Proactivo.

Analiza los datos reales del negocio y genera recomendaciones accionables en
JSON estructurado (reabastecer / tendencia / promocion / alerta). Si la IA falla
o no devuelve JSON válido, cae a un generador determinista basado en reglas para
que el dashboard siempre reciba recomendaciones útiles.
"""
import json
import logging

from .analytics_service import get_summary_for_ai
from .ai_service import ask_ai
from .prompt_safety import wrap_business_data, sanitize_text, DATA_GUARD, MAX_FIELD_LEN

logger = logging.getLogger(__name__)

TIPOS_VALIDOS = {"reabastecer", "tendencia", "promocion", "alerta"}
PRIORIDADES_VALIDAS = {"alta", "media", "baja"}

SYSTEM_TEMPLATE = """Eres un asesor de negocios para una tienda al por menor.
Analiza los datos reales del negocio y genera recomendaciones accionables.

Respondes SIEMPRE en español. Basas tus recomendaciones SOLO en los datos dados.

Responde ÚNICAMENTE con un objeto JSON válido (sin texto extra, sin markdown,
sin ```), con esta forma EXACTA:
{{
  "insights": [
    {{
      "tipo": "reabastecer|tendencia|promocion|alerta",
      "titulo": "string corto (max 6 palabras)",
      "descripcion": "1-2 frases accionables y concretas",
      "prioridad": "alta|media|baja",
      "producto": "nombre del producto relevante o null"
    }}
  ]
}}

Genera entre 3 y 5 insights, ordenados de mayor a menor prioridad.

{guard}

DATOS ACTUALES DEL NEGOCIO:
{data}
"""

USER_MESSAGE = (
    "Genera las recomendaciones de negocio en el formato JSON indicado, "
    "basándote en los datos proporcionados."
)


def get_business_insights(branch_id=None) -> dict:
    """Devuelve {'insights': [...], 'fuente': 'ia'|'reglas'}.

    Intenta generar con IA; ante cualquier fallo cae al generador por reglas.
    """
    summary = get_summary_for_ai(branch_id=branch_id)
    try:
        data_str = wrap_business_data(json.dumps(summary, ensure_ascii=False, indent=2))
        system_prompt = SYSTEM_TEMPLATE.format(guard=DATA_GUARD, data=data_str)
        raw = ask_ai(system_prompt, USER_MESSAGE, stream=False)
        parsed = _extract_json(raw)
        insights = _normalize(parsed.get("insights", []))
        if insights:
            return {"insights": insights, "fuente": "ia"}
        logger.warning("La IA no devolvió insights válidos; usando reglas.")
    except Exception as e:  # red, parseo, API key inválida, etc.
        logger.warning("Fallo al generar insights con IA (%s); usando reglas.", e)

    return {"insights": _rule_based_insights(summary), "fuente": "reglas"}


def _extract_json(text: str) -> dict:
    """Parseo defensivo: quita fences markdown y recorta al objeto JSON."""
    if not text:
        raise ValueError("respuesta vacía")
    cleaned = text.strip()
    if cleaned.startswith("```"):
        # quita ```json ... ``` o ``` ... ```
        cleaned = cleaned.split("```", 2)[1] if "```" in cleaned[3:] else cleaned
        if cleaned.lower().startswith("json"):
            cleaned = cleaned[4:]
    start = cleaned.find("{")
    end = cleaned.rfind("}")
    if start == -1 or end == -1 or end < start:
        raise ValueError("no se encontró objeto JSON en la respuesta")
    return json.loads(cleaned[start:end + 1])


def _normalize(items) -> list:
    """Valida y normaliza cada insight; descarta los que no cumplen el esquema."""
    result = []
    if not isinstance(items, list):
        return result
    for item in items:
        if not isinstance(item, dict):
            continue
        tipo = str(item.get("tipo", "")).strip().lower()
        prioridad = str(item.get("prioridad", "")).strip().lower()
        # Recorta longitud y limpia el texto generado: aunque una inyección
        # lograra colar contenido, no puede inflar ni ofuscar la salida.
        titulo = sanitize_text(item.get("titulo", ""), 80)
        descripcion = sanitize_text(item.get("descripcion", ""), MAX_FIELD_LEN)
        if not titulo or not descripcion:
            continue
        if tipo not in TIPOS_VALIDOS:
            tipo = "tendencia"
        if prioridad not in PRIORIDADES_VALIDAS:
            prioridad = "media"
        producto = item.get("producto")
        producto = sanitize_text(producto, 80) if producto else None
        result.append({
            "tipo": tipo,
            "titulo": titulo,
            "descripcion": descripcion,
            "prioridad": prioridad,
            "producto": producto or None,
        })
    return result


def _rule_based_insights(summary: dict) -> list:
    """Genera recomendaciones deterministas a partir de los datos reales."""
    insights = []

    # Alerta: sin ventas aún
    if not summary.get("total_ventas"):
        insights.append({
            "tipo": "alerta",
            "titulo": "Aún no hay ventas registradas",
            "descripcion": "Registra tus primeras ventas para empezar a recibir "
                           "análisis y recomendaciones basadas en datos reales.",
            "prioridad": "alta",
            "producto": None,
        })

    # Reabastecer: productos bajo stock (prioridad por nivel)
    for p in summary.get("productos_bajo_stock", []):
        stock = p.get("stock", 0)
        prioridad = "alta" if stock <= 3 else "media" if stock <= 7 else "baja"
        insights.append({
            "tipo": "reabastecer",
            "titulo": f"Reabastecer {p.get('name', 'producto')}",
            "descripcion": f"Quedan {stock} unidades de {p.get('name', 'este producto')}. "
                           "Considera reordenar antes de que se agote.",
            "prioridad": prioridad,
            "producto": p.get("name"),
        })

    # Tendencia: producto más vendido
    top = summary.get("productos_top") or []
    if top:
        best = top[0]
        insights.append({
            "tipo": "tendencia",
            "titulo": f"{best.get('name', 'Producto')} lidera ventas",
            "descripcion": f"{best.get('name', 'Este producto')} es el más vendido "
                           f"({best.get('total_qty', 0)} unidades). Asegura su "
                           "disponibilidad y destácalo en el catálogo.",
            "prioridad": "media",
            "producto": best.get("name"),
        })

    # Promoción: segundo producto top, para impulsar rotación
    if len(top) > 1:
        second = top[1]
        insights.append({
            "tipo": "promocion",
            "titulo": f"Impulsar {second.get('name', 'producto')}",
            "descripcion": f"{second.get('name', 'Este producto')} vende bien; una "
                           "promoción o paquete podría aumentar aún más su rotación.",
            "prioridad": "baja",
            "producto": second.get("name"),
        })

    # Garantiza al menos un insight
    if not insights:
        insights.append({
            "tipo": "tendencia",
            "titulo": "Negocio en marcha",
            "descripcion": "No hay alertas de stock ni de ventas. Mantén el inventario "
                           "surtido y revisa el dashboard regularmente.",
            "prioridad": "baja",
            "producto": None,
        })

    # Ordena por prioridad (alta primero)
    orden = {"alta": 0, "media": 1, "baja": 2}
    insights.sort(key=lambda i: orden.get(i["prioridad"], 3))
    return insights
