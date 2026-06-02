"""
seed.py — Datos iniciales de demostración.
Se ejecuta solo si la BD está vacía.
"""
from .db import db
from ..models.product import Product

def seed_if_empty():
    if Product.query.count() > 0:
        return
    productos = [
        Product(name="Coca-Cola 600ml", price=18.0, stock=100, category="Bebidas"),
        Product(name="Papas Fritas", price=15.0, stock=80, category="Snacks"),
        Product(name="Agua 500ml", price=10.0, stock=150, category="Bebidas"),
        Product(name="Chocolate", price=22.0, stock=60, category="Dulces"),
        Product(name="Sandwich", price=35.0, stock=30, category="Alimentos"),
        Product(name="Jugo de Naranja", price=20.0, stock=50, category="Bebidas"),
        Product(name="Galletas", price=12.0, stock=90, category="Snacks"),
        Product(name="Cafe", price=25.0, stock=8, category="Bebidas"),
    ]
    db.session.bulk_save_objects(productos)
    db.session.commit()
    print("BD inicializada con datos de ejemplo.")
