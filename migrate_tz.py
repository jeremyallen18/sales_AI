"""
migrate_tz.py — Migración one-off: convierte los timestamps existentes
(guardados en UTC con el viejo default datetime.utcnow) a hora de
Ciudad de México, que es lo que la app guarda a partir de ahora.

Ejecutar UNA sola vez: python migrate_tz.py
"""
from datetime import timezone

from app import create_app
from app.database.db import db
from app.models.sale import Sale
from app.models.product import Product
from app.models.customer import Customer
from app.models.branch import Branch
from app.models.branch_assignment import BranchAssignment
from app.models.branch_review import BranchReview
from app.models.product_review import ProductReview
from app.models.seller_account import SellerAccount
from app.utils import MX_TZ


def utc_a_mx(dt):
    if dt is None:
        return None
    return dt.replace(tzinfo=timezone.utc).astimezone(MX_TZ).replace(tzinfo=None)


def migrar():
    modelos = [Sale, Product, Customer, Branch, BranchAssignment,
               BranchReview, ProductReview, SellerAccount]
    for modelo in modelos:
        filas = modelo.query.all()
        cambiados = 0
        for fila in filas:
            if getattr(fila, "created_at", None) is not None:
                fila.created_at = utc_a_mx(fila.created_at)
                cambiados += 1
            if getattr(fila, "updated_at", None) is not None:
                fila.updated_at = utc_a_mx(fila.updated_at)
        print(f"{modelo.__name__}: {cambiados} registros ajustados")
    db.session.commit()
    print("Migración completada.")


if __name__ == "__main__":
    app = create_app()
    with app.app_context():
        migrar()
