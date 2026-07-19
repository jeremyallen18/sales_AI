"""
seed_branches.py — Pobla BranchInventory con stock/precios diferenciados por sucursal
y distribuye las ventas existentes entre las tiendas para mostrar métricas distintas.

USO:
    python seed_branches.py            # Migra datos (no borra lo existente)
    python seed_branches.py --reset    # Limpia BranchInventory y ventas, luego recrea
"""
import sys
import random
from datetime import datetime, timedelta
from app import create_app
from app.database.db import db
from app.models.product import Product
from app.models.branch import Branch
from app.models.branch_inventory import BranchInventory
from app.models.sale import Sale
from app.models.sale_item import SaleItem

# ── Configuración por tienda ─────────────────────────────────────────────────

# Cada tienda tiene: (factor_precio, min_stock, max_stock, ventas_min, ventas_max)
BRANCH_PROFILES = [
    (1.00, 20, 50, 50, 70),   # Tienda principal  — precios base, stock alto, alto volumen
    (1.05, 10, 30, 25, 40),   # Segunda tienda    — +5% precio, volumen medio
    (1.08, 8,  25, 15, 25),   # Tercera tienda    — +8% precio, volumen bajo
    (1.12, 5,  20, 8,  18),   # Tienda extra      — +12% precio, volumen mínimo
]

POPULARIDAD = {
    "Coca-Cola 600ml": 0.22,
    "Agua 500ml":      0.18,
    "Papas Fritas":    0.15,
    "Cafe":            0.13,
    "Jugo de Naranja": 0.10,
    "Galletas":        0.09,
    "Chocolate":       0.08,
    "Sandwich":        0.05,
}

CLIENTES = [
    "Juan Pérez", "María García", "Carlos López", "Ana Torres",
    "Luis Martínez", "Sofia Rodríguez", "Pedro Sánchez", "Laura Jiménez",
    "Cliente General", "Miguel Hernández", "Isabella Díaz", "Diego Morales",
]

DIAS = 30
ITEMS_POR_VENTA = (1, 4)

# ── Lógica ───────────────────────────────────────────────────────────────────

def run_seed(reset: bool = False):
    app = create_app()
    with app.app_context():
        branches = Branch.query.order_by(Branch.id).all()
        productos = Product.query.order_by(Product.id).all()

        if not branches:
            print("ERROR: No hay sucursales registradas. Crea al menos una sucursal en el panel.")
            sys.exit(1)
        if not productos:
            print("ERROR: No hay productos en la BD. Ejecuta primero `python run.py`.")
            sys.exit(1)

        if reset:
            print("[RESET] Eliminando BranchInventory y ventas existentes...")
            SaleItem.query.delete()
            Sale.query.delete()
            BranchInventory.query.delete()
            db.session.commit()
            print("[RESET] Listo.")

        num_branches = len(branches)
        print(f"Sucursales encontradas: {num_branches} → {[b.name for b in branches]}")
        print(f"Productos encontrados: {len(productos)}")

        # ── 1. Crear BranchInventory por (sucursal × producto) ────────────────
        inv_creados = 0
        for i, branch in enumerate(branches):
            profile = BRANCH_PROFILES[min(i, len(BRANCH_PROFILES) - 1)]
            price_factor, stock_min, stock_max, *_ = profile

            for prod in productos:
                existing = BranchInventory.query.filter_by(
                    branch_id=branch.id, product_id=prod.id).first()
                if existing:
                    continue

                stock = random.randint(stock_min, stock_max)
                # 15% de probabilidad de stock bajo (≤5) para demo de alertas
                if random.random() < 0.15:
                    stock = random.randint(0, 5)

                price = round(prod.price * price_factor, 2) if price_factor != 1.0 else None
                discount = random.choice([0, 0, 5, 10, 15])  # sesgo hacia sin descuento

                bi = BranchInventory(
                    branch_id=branch.id,
                    product_id=prod.id,
                    stock=stock,
                    price=price,
                    discount_pct=float(discount) if discount > 0 else None,
                )
                db.session.add(bi)
                inv_creados += 1

        db.session.commit()
        print(f"BranchInventory creados: {inv_creados}")

        # ── 2. Distribuir ventas existentes con branch_id=NULL ────────────────
        ventas_sin_branch = Sale.query.filter(Sale.branch_id.is_(None)).all()
        distribuidas = 0
        for sale in ventas_sin_branch:
            sale.branch_id = branches[sale.id % num_branches].id
            distribuidas += 1
        db.session.commit()
        print(f"Ventas existentes redistribuidas: {distribuidas}")

        # ── 3. Crear ventas demo por sucursal ─────────────────────────────────
        nombres_prod = [p.name for p in productos]
        pesos = [POPULARIDAD.get(p.name, 0.05) for p in productos]
        total_peso = sum(pesos)
        pesos = [w / total_peso for w in pesos]

        hoy = datetime.utcnow().replace(hour=23, minute=59, second=59)
        total_nuevas = 0

        for i, branch in enumerate(branches):
            profile = BRANCH_PROFILES[min(i, len(BRANCH_PROFILES) - 1)]
            _, _, _, ventas_min, ventas_max = profile

            # Obtener inventario de esta sucursal para usar precios efectivos
            branch_inv = {
                bi.product_id: bi
                for bi in BranchInventory.query.filter_by(branch_id=branch.id).all()
            }

            ventas_branch = 0
            for dias_atras in range(DIAS, 0, -1):
                fecha_base = hoy - timedelta(days=dias_atras)
                es_finde = fecha_base.weekday() >= 5
                n_ventas = random.randint(
                    max(1, ventas_min // DIAS),
                    max(2, ventas_max // DIAS + (2 if es_finde else 0))
                )

                for _ in range(n_ventas):
                    hora = random.randint(8, 21)
                    minuto = random.randint(0, 59)
                    fecha_venta = fecha_base.replace(hour=hora, minute=minuto, second=0)

                    cliente = random.choice(CLIENTES)
                    n_items = random.randint(*ITEMS_POR_VENTA)

                    prods_elegidos = random.choices(productos, weights=pesos, k=n_items * 3)
                    vistos = set()
                    items_venta = []
                    for prod in prods_elegidos:
                        if prod.id not in vistos:
                            vistos.add(prod.id)
                            items_venta.append(prod)
                        if len(items_venta) == n_items:
                            break

                    sale = Sale(
                        client_name=cliente,
                        total_amount=0.0,
                        branch_id=branch.id,
                        payment_method=random.choice(["efectivo", "efectivo", "tarjeta", "transferencia"]),
                        created_at=fecha_venta,
                    )
                    db.session.add(sale)
                    db.session.flush()

                    total = 0.0
                    for prod in items_venta:
                        qty = random.randint(1, 3)
                        bi = branch_inv.get(prod.id)
                        price = bi.effective_price() if bi else prod.price
                        subtotal = price * qty
                        total += subtotal
                        db.session.add(SaleItem(
                            sale_id=sale.id,
                            product_id=prod.id,
                            quantity=qty,
                            price=price,
                        ))

                    sale.total_amount = round(total, 2)
                    ventas_branch += 1

            total_nuevas += ventas_branch
            print(f"  {branch.name}: {ventas_branch} ventas nuevas generadas")

        db.session.commit()
        print(f"\nTotal ventas nuevas creadas: {total_nuevas}")
        print("Migración completada. Recarga el dashboard para ver las métricas por sucursal.")


if __name__ == "__main__":
    reset = "--reset" in sys.argv
    run_seed(reset=reset)
