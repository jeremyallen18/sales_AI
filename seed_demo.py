"""
seed_demo.py — Poblar la BD con ventas históricas realistas para el dashboard Power BI.

Genera ~60 ventas distribuidas en los últimos 30 días con variación diaria
para que el gráfico de tendencia se vea con datos reales.

USO:
    python seed_demo.py            # Agrega ventas (no borra las existentes)
    python seed_demo.py --reset    # Borra TODAS las ventas y recrea desde cero
"""
import sys
import random
from datetime import datetime, timedelta
from app import create_app
from app.database.db import db
from app.models.product import Product
from app.models.sale import Sale
from app.models.sale_item import SaleItem

# ── Configuración ────────────────────────────────────────────────────────────

DIAS = 30          # Ventana histórica
VENTAS_POR_DIA = (1, 5)    # Rango de ventas por día (min, max)
ITEMS_POR_VENTA = (1, 4)   # Ítems por venta
CLIENTES = [
    "Juan Pérez", "María García", "Carlos López", "Ana Torres",
    "Luis Martínez", "Sofia Rodríguez", "Pedro Sánchez", "Laura Jiménez",
    "Cliente General", "Miguel Hernández", "Isabella Díaz", "Diego Morales",
]

# Pesos de probabilidad por producto (simula productos más populares)
POPULARIDAD = {
    "Coca-Cola 600ml": 0.22,
    "Agua 500ml": 0.18,
    "Papas Fritas": 0.15,
    "Cafe": 0.13,
    "Jugo de Naranja": 0.10,
    "Galletas": 0.09,
    "Chocolate": 0.08,
    "Sandwich": 0.05,
}

# ── Lógica ───────────────────────────────────────────────────────────────────

def run_seed(reset: bool = False):
    app = create_app()
    with app.app_context():
        productos = Product.query.all()
        if not productos:
            print("ERROR: No hay productos en la BD. Ejecuta primero `python run.py` para inicializar.")
            sys.exit(1)

        if reset:
            print("[RESET] Borrando ventas existentes...")
            SaleItem.query.delete()
            Sale.query.delete()
            db.session.commit()
            print("[RESET] Listo.")

        # Construir lista de productos con sus pesos
        nombres = [p.name for p in productos]
        pesos = [POPULARIDAD.get(p.name, 0.05) for p in productos]
        total_peso = sum(pesos)
        pesos = [w / total_peso for w in pesos]   # normalizar

        hoy = datetime.utcnow().replace(hour=23, minute=59, second=59)
        total_ventas = 0

        for dias_atras in range(DIAS, 0, -1):
            fecha_base = hoy - timedelta(days=dias_atras)

            # Fin de semana → más ventas
            es_finde = fecha_base.weekday() >= 5
            min_v, max_v = VENTAS_POR_DIA
            if es_finde:
                max_v += 2

            n_ventas = random.randint(min_v, max_v)

            for _ in range(n_ventas):
                hora = random.randint(8, 21)
                minuto = random.randint(0, 59)
                fecha_venta = fecha_base.replace(hour=hora, minute=minuto, second=0)

                cliente = random.choice(CLIENTES)
                n_items = random.randint(*ITEMS_POR_VENTA)

                # Elegir productos sin repetir en la misma venta
                prods_elegidos = random.choices(productos, weights=pesos, k=n_items * 3)
                vistos = set()
                items_venta = []
                for prod in prods_elegidos:
                    if prod.id not in vistos:
                        vistos.add(prod.id)
                        items_venta.append(prod)
                    if len(items_venta) == n_items:
                        break

                total = 0.0
                sale = Sale(
                    client_name=cliente,
                    total_amount=0.0,
                    created_at=fecha_venta,
                )
                db.session.add(sale)
                db.session.flush()   # obtener sale.id

                for prod in items_venta:
                    qty = random.randint(1, 4)
                    subtotal = prod.price * qty
                    total += subtotal
                    db.session.add(SaleItem(
                        sale_id=sale.id,
                        product_id=prod.id,
                        quantity=qty,
                        price=prod.price,
                    ))

                sale.total_amount = round(total, 2)

            total_ventas += n_ventas

        db.session.commit()

        # Actualizar stock del Café a bajo (≤10) para que el KPI se vea
        cafe = Product.query.filter_by(name="Cafe").first()
        if cafe and cafe.stock > 10:
            cafe.stock = 7
        sandwich = Product.query.filter_by(name="Sandwich").first()
        if sandwich and sandwich.stock > 10:
            sandwich.stock = 9
        db.session.commit()

        print(f"OK: {total_ventas} ventas generadas en los ultimos {DIAS} dias.")
        print(f"   Productos con stock bajo: Cafe ({cafe.stock if cafe else '?'}) - Sandwich ({sandwich.stock if sandwich else '?'})")
        print("   Actualiza Power BI -> boton 'Actualizar' para ver los nuevos datos.")


if __name__ == "__main__":
    reset = "--reset" in sys.argv
    run_seed(reset=reset)
