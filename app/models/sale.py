"""
sale.py — Modelo de Venta completa.
"""
from ..database.db import db
from datetime import datetime

class Sale(db.Model):
    __tablename__ = "sales"
    id = db.Column(db.Integer, primary_key=True)
    client_name = db.Column(db.String(150), default="")
    subtotal_amount = db.Column(db.Float, default=0.0)
    discount_amount = db.Column(db.Float, default=0.0)
    tax_amount = db.Column(db.Float, default=0.0)
    total_amount = db.Column(db.Float, nullable=False)
    payment_method = db.Column(db.String(50), default="efectivo")
    payment_status = db.Column(db.String(20), default="aprobado")
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    items = db.relationship("SaleItem", backref="sale", lazy=True, cascade="all, delete-orphan")

    def to_dict(self):
        return {"id": self.id, "client_name": self.client_name or "",
                "subtotal_amount": self.subtotal_amount or 0.0,
                "discount_amount": self.discount_amount or 0.0,
                "tax_amount": self.tax_amount or 0.0,
                "total_amount": self.total_amount,
                "payment_method": self.payment_method or "efectivo",
                "payment_status": self.payment_status or "aprobado",
                "created_at": self.created_at.isoformat(),
                "items": [i.to_dict() for i in self.items]}
