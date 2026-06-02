"""
sale_item.py — Ítem individual dentro de una venta.
"""
from ..database.db import db

class SaleItem(db.Model):
    __tablename__ = "sale_items"
    id = db.Column(db.Integer, primary_key=True)
    sale_id = db.Column(db.Integer, db.ForeignKey("sales.id"), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey("products.id"), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    price = db.Column(db.Float, nullable=False)   # Precio al momento de venta

    def to_dict(self):
        return {"id": self.id, "product_id": self.product_id,
                "product_name": self.product.name if self.product else "",
                "quantity": self.quantity, "price": self.price,
                "subtotal": self.quantity * self.price}
