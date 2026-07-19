"""
forecast_service.py — Predicción de demanda semanal con IA.

Analiza ventas de los últimos 30 días por producto y sugiere
cuánto reabastecer la próxima semana para cada sucursal.
Fallback determinista si la IA no responde.
"""
import json
import logging
from datetime import timedelta

from sqlalchemy import func

from ..database.db import db
from ..models.sale import Sale
from ..models.sale_item import SaleItem
from ..models.product import Product
from ..models.branch_inventory import BranchInventory
from ..utils import now_mx
from .ai_service import ask_ai
from .prompt_safety import wrap_business_data, sanitize_text, DATA_GUARD

logger = logging.getLogger(__name__)

SYSTEM_TEMPLATE = """Eres un analista de demanda para una tienda de conveniencia.
Con base en las ventas de los últimos 30 días y el stock actual, predice la
demanda para los próximos 7 días y recomienda cuánto reabastecer.

Responde ÚNICAMENTE con un JSON válido sin texto extra ni markdown:
{{
  "resumen": "1-2 frases sobre el periodo y tendencia general",
  "predicciones": [
    {{
      "producto": "nombre exacto",
      "ventas_30d": número,
      "demanda_7d": número entero estimado,
      "stock_actual": número,
      "reabastecer": número entero recomendado (0 si el stock es suficiente),
      "confianza": "alta|media|baja",
      "nota": "frase corta explicando el por qué (opcional, puede ser null)"
    }}
  ]
}}

Incluye solo los productos con al menos 1 venta en los 30 días.
Ordena de mayor a menor urgencia (stock/demanda más crítico primero).

{guard}

DATOS:
{data}
"""

USER_MESSAGE = (
    "Genera la predicción de demanda semanal en el formato JSON indicado."
)


def get_demand_forecast(branch_id=None) -> dict:
    """Retorna {'resumen': str, 'predicciones': [...], 'fuente': 'ia'|'reglas'}."""
    data = _gather_data(branch_id)
    if not data["productos"]:
        return {
            "resumen": "No hay ventas registradas en los últimos 30 días.",
            "predicciones": [],
            "fuente": "reglas",
        }
    try:
        data_str = wrap_business_data(
            json.dumps(data, ensure_ascii=False, indent=2)
        )
        system = SYSTEM_TEMPLATE.format(guard=DATA_GUARD, data=data_str)
        raw = ask_ai(system, USER_MESSAGE, stream=False)
        parsed = _extract_json(raw)
        preds = _normalize(parsed.get("predicciones", []), data)
        if preds:
            return {
                "resumen": sanitize_text(parsed.get("resumen", ""), 300),
                "predicciones": preds,
                "fuente": "ia",
            }
        logger.warning("IA no devolvió predicciones válidas; usando reglas.")
    except Exception as e:
        logger.warning("Fallo forecast IA (%s); usando reglas.", e)

    return _rule_based_forecast(data)


# ── Recolección de datos ──────────────────────────────────────────────────────

def _gather_data(branch_id):
    since = now_mx() - timedelta(days=30)

    q = (db.session.query(
            Product.id,
            Product.name,
            func.sum(SaleItem.quantity).label("qty30d"),
            func.count(func.distinct(func.date(Sale.created_at))).label("days_sold"),
         )
         .join(SaleItem, SaleItem.product_id == Product.id)
         .join(Sale, Sale.id == SaleItem.sale_id)
         .filter(Sale.created_at >= since))
    if branch_id:
        q = q.filter(Sale.branch_id == branch_id)
    rows = q.group_by(Product.id).order_by(
        func.sum(SaleItem.quantity).desc()
    ).all()

    # Stock actual por sucursal o global
    stock_map = {}
    if branch_id:
        inv = BranchInventory.query.filter_by(branch_id=branch_id).all()
        stock_map = {i.product_id: i.stock for i in inv}
    else:
        for p in Product.query.all():
            stock_map[p.id] = p.stock

    productos = []
    for r in rows:
        productos.append({
            "nombre": r.name,
            "ventas_30d": int(r.qty30d),
            "dias_con_venta": int(r.days_sold),
            "stock_actual": stock_map.get(r.id, 0),
        })

    return {
        "periodo_dias": 30,
        "sucursal_id": branch_id,
        "productos": productos,
    }


# ── Helpers ───────────────────────────────────────────────────────────────────

def _extract_json(text: str) -> dict:
    if not text:
        raise ValueError("respuesta vacía")
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.split("```", 2)[1] if "```" in cleaned[3:] else cleaned
        if cleaned.lower().startswith("json"):
            cleaned = cleaned[4:]
    start = cleaned.find("{")
    end = cleaned.rfind("}")
    if start == -1 or end == -1 or end < start:
        raise ValueError("JSON no encontrado")
    return json.loads(cleaned[start : end + 1])


def _normalize(items, raw_data) -> list:
    stock_lookup = {p["nombre"]: p["stock_actual"] for p in raw_data["productos"]}
    result = []
    for item in items:
        if not isinstance(item, dict):
            continue
        nombre = sanitize_text(item.get("producto", ""), 120)
        if not nombre:
            continue
        try:
            demanda = max(0, int(item.get("demanda_7d", 0)))
            reabastecer = max(0, int(item.get("reabastecer", 0)))
            ventas = max(0, int(item.get("ventas_30d", 0)))
            stock = max(0, int(item.get("stock_actual", stock_lookup.get(nombre, 0))))
        except (ValueError, TypeError):
            continue
        confianza = str(item.get("confianza", "media")).lower()
        if confianza not in {"alta", "media", "baja"}:
            confianza = "media"
        nota = sanitize_text(item.get("nota") or "", 200) or None
        result.append({
            "producto": nombre,
            "ventas_30d": ventas,
            "demanda_7d": demanda,
            "stock_actual": stock,
            "reabastecer": reabastecer,
            "confianza": confianza,
            "nota": nota,
        })
    return result


def _rule_based_forecast(data) -> dict:
    """Estimación determinista: demanda_7d ≈ ventas_30d / 4.3."""
    preds = []
    for p in data["productos"]:
        demanda_7d = max(1, round(p["ventas_30d"] / 4.3))
        stock = p["stock_actual"]
        reabastecer = max(0, demanda_7d * 2 - stock)
        confianza = "alta" if p["dias_con_venta"] >= 20 else (
            "media" if p["dias_con_venta"] >= 10 else "baja"
        )
        preds.append({
            "producto": p["nombre"],
            "ventas_30d": p["ventas_30d"],
            "demanda_7d": demanda_7d,
            "stock_actual": stock,
            "reabastecer": reabastecer,
            "confianza": confianza,
            "nota": None,
        })
    preds.sort(key=lambda x: (
        -(x["reabastecer"]),
        -(x["ventas_30d"])
    ))
    return {
        "resumen": (
            f"Estimación basada en {len(preds)} productos con ventas "
            "en los últimos 30 días."
        ),
        "predicciones": preds,
        "fuente": "reglas",
    }
