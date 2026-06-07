"""
inventory_service.py — CRUD de productos e inventario.
"""
from flask import current_app
from ..database.db import db
from ..models.product import Product
from .prompt_safety import sanitize_text, MAX_NAME_LEN, MAX_CATEGORY_LEN

def get_all_products():
    return Product.query.order_by(Product.name).all()

def get_product_by_id(pid):
    return Product.query.get_or_404(pid)

def create_product(data):
    # Saneamiento en el punto de entrada: estos campos terminan inyectados en
    # los prompts de IA, así que se limpian antes de persistirlos.
    name = sanitize_text(data["name"], MAX_NAME_LEN)
    category = sanitize_text(data.get("category", "General"), MAX_CATEGORY_LEN) or "General"
    p = Product(name=name, price=float(data["price"]),
                stock=int(data.get("stock", 0)), category=category,
                image_url=data.get("image_url", ""),
                discount_pct=float(data.get("discount_pct", 0.0)))
    db.session.add(p)
    db.session.commit()
    return p

def update_product(pid, data):
    p = Product.query.get_or_404(pid)
    if "name" in data:
        p.name = sanitize_text(data["name"], MAX_NAME_LEN) or p.name
    p.price = float(data.get("price", p.price))
    p.stock = int(data.get("stock", p.stock))
    if "category" in data:
        p.category = sanitize_text(data["category"], MAX_CATEGORY_LEN) or p.category
    if "image_url" in data:
        p.image_url = data["image_url"]
    if "discount_pct" in data:
        p.discount_pct = float(data["discount_pct"])
    db.session.commit()
    return p

def delete_product(pid):
    p = Product.query.get_or_404(pid)
    db.session.delete(p)
    db.session.commit()

def get_low_stock():
    threshold = current_app.config.get("LOW_STOCK_THRESHOLD", 10)
    return Product.query.filter(Product.stock <= threshold).all()
