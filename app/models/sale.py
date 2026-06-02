"""
sale.py — Modelo de Venta completa.
"""
from ..database.db import db
from datetime import datetime

class Sale(db.Model):
    __tablename__ = "sales"
    id = db.Column(db.Integer, primary_key=True)
    client_name = db.Column(db.String(150), default="")
    total_amount = db.Column(db.Float, nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    items = db.relationship("SaleItem", backref="sale", lazy=True, cascade="all, delete-orphan")

    def to_dict(self):
        return {"id": self.id, "client_name": self.client_name or "",
                "total_amount": self.total_amount,
                "created_at": self.created_at.isoformat(),
                "items": [i.to_dict() for i in self.items]}
