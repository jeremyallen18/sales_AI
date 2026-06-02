"""
product.py — Modelo de Producto en inventario.
"""
from flask import request as flask_request
from ..database.db import db
from datetime import datetime

class Product(db.Model):
    __tablename__ = "products"
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(120), nullable=False)
    price = db.Column(db.Float, nullable=False)
    stock = db.Column(db.Integer, default=0)
    category = db.Column(db.String(60), default="General")
    image_url = db.Column(db.String(300), default="")
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    sale_items = db.relationship("SaleItem", backref="product", lazy=True)

    def to_dict(self):
        image_url = self.image_url or ""
        if image_url and image_url.startswith("/"):
            try:
                image_url = flask_request.host_url.rstrip("/") + image_url
            except RuntimeError:
                pass  # fuera de contexto de request, dejar relativa
        return {"id": self.id, "name": self.name, "price": self.price,
                "stock": self.stock, "category": self.category,
                "image_url": image_url,
                "created_at": self.created_at.isoformat()}
