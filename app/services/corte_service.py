"""
corte_service.py — Lógica de corte de caja semanal y mensual.
"""
from datetime import datetime, timedelta
from sqlalchemy import func
from ..database.db import db
from ..models.sale import Sale
from ..models.sale_item import SaleItem
from ..models.product import Product
from ..models.branch import Branch
from ..utils import now_mx


def _periodo_semanal(semanas_atras: int = 0):
    """Retorna (inicio, fin) del lunes al domingo de la semana indicada."""
    hoy = now_mx().date()
    lunes_esta = hoy - timedelta(days=hoy.weekday())
    lunes = lunes_esta - timedelta(weeks=semanas_atras)
    domingo = lunes + timedelta(days=6)
    inicio = datetime.combine(lunes, datetime.min.time())
    fin    = datetime.combine(domingo, datetime.max.time().replace(microsecond=0))
    return inicio, fin


def _periodo_mensual(meses_atras: int = 0):
    """Retorna (inicio, fin) del mes indicado."""
    hoy = now_mx().date()
    anio  = hoy.year
    mes   = hoy.month - meses_atras
    while mes <= 0:
        mes  += 12
        anio -= 1
    primer_dia = datetime(anio, mes, 1)
    if mes == 12:
        ultimo_dia = datetime(anio + 1, 1, 1) - timedelta(seconds=1)
    else:
        ultimo_dia = datetime(anio, mes + 1, 1) - timedelta(seconds=1)
    return primer_dia, ultimo_dia


def _build_corte(inicio: datetime, fin: datetime, tipo: str, branch_id: int | None = None) -> dict:
    """Calcula el corte de caja para el período indicado."""
    q = Sale.query.filter(Sale.created_at >= inicio, Sale.created_at <= fin,
                          Sale.payment_status == "aprobado")
    if branch_id is not None:
        q = q.filter(Sale.branch_id == branch_id)

    ventas = q.all()
    total_transacciones = len(ventas)

    subtotal     = sum(v.subtotal_amount or 0 for v in ventas)
    descuentos   = sum(v.discount_amount or 0 for v in ventas)
    iva          = sum(v.tax_amount or 0 for v in ventas)
    ingresos_netos = sum(v.total_amount for v in ventas)

    # Desglose por método de pago
    metodos: dict[str, dict] = {}
    for v in ventas:
        m = (v.payment_method or "efectivo").lower()
        if m not in metodos:
            metodos[m] = {"transacciones": 0, "total": 0.0}
        metodos[m]["transacciones"] += 1
        metodos[m]["total"] = round(metodos[m]["total"] + v.total_amount, 2)

    # Ventas por día
    por_dia: dict[str, dict] = {}
    for v in ventas:
        dia = v.created_at.strftime("%Y-%m-%d")
        if dia not in por_dia:
            por_dia[dia] = {"ventas": 0, "total": 0.0}
        por_dia[dia]["ventas"]  += 1
        por_dia[dia]["total"]    = round(por_dia[dia]["total"] + v.total_amount, 2)
    ventas_por_dia = [{"fecha": k, **v} for k, v in sorted(por_dia.items())]

    # Ticket promedio
    ticket_promedio = round(ingresos_netos / total_transacciones, 2) if total_transacciones else 0.0

    # Top productos del período
    sale_ids = [v.id for v in ventas]
    top_productos = []
    if sale_ids:
        filas = (
            db.session.query(
                Product.id,
                Product.name,
                Product.category,
                func.sum(SaleItem.quantity).label("qty"),
                func.sum(SaleItem.quantity * SaleItem.price).label("revenue"),
            )
            .join(SaleItem, SaleItem.product_id == Product.id)
            .filter(SaleItem.sale_id.in_(sale_ids))
            .group_by(Product.id, Product.name, Product.category)
            .order_by(func.sum(SaleItem.quantity).desc())
            .limit(10)
            .all()
        )
        top_productos = [
            {"product_id": r.id, "name": r.name, "category": r.category,
             "cantidad": int(r.qty), "ingresos": round(float(r.revenue), 2)}
            for r in filas
        ]

    # Info de sucursal
    branch_info = None
    if branch_id is not None:
        b = Branch.query.get(branch_id)
        if b:
            branch_info = {"id": b.id, "name": b.name, "address": b.address, "city": b.city}

    return {
        "tipo": tipo,
        "periodo": {
            "inicio": inicio.strftime("%Y-%m-%d %H:%M:%S"),
            "fin":    fin.strftime("%Y-%m-%d %H:%M:%S"),
            "label":  _label_periodo(tipo, inicio),
        },
        "branch": branch_info,
        "resumen": {
            "total_transacciones": total_transacciones,
            "subtotal":            round(subtotal, 2),
            "descuentos":          round(descuentos, 2),
            "iva":                 round(iva, 2),
            "ingresos_netos":      round(ingresos_netos, 2),
            "ticket_promedio":     ticket_promedio,
        },
        "por_metodo_pago": metodos,
        "ventas_por_dia":  ventas_por_dia,
        "top_productos":   top_productos,
        "generado_en":     now_mx().strftime("%Y-%m-%d %H:%M:%S"),
    }


def _label_periodo(tipo: str, inicio: datetime) -> str:
    MESES = ["Enero","Febrero","Marzo","Abril","Mayo","Junio",
             "Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"]
    if tipo == "semanal":
        fin = inicio + timedelta(days=6)
        return f"Semana {inicio.strftime('%d/%m')} – {fin.strftime('%d/%m/%Y')}"
    return f"{MESES[inicio.month - 1]} {inicio.year}"


def corte_semanal(branch_id: int | None = None, semanas_atras: int = 0) -> dict:
    inicio, fin = _periodo_semanal(semanas_atras)
    return _build_corte(inicio, fin, "semanal", branch_id)


def corte_mensual(branch_id: int | None = None, meses_atras: int = 0) -> dict:
    inicio, fin = _periodo_mensual(meses_atras)
    return _build_corte(inicio, fin, "mensual", branch_id)
