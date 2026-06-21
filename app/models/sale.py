"""
sale.py — Modelo de Venta completa.
"""
from ..database.db import db
from ..utils import now_mx

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
    created_at = db.Column(db.DateTime, default=now_mx)
    customer_id = db.Column(db.Integer, db.ForeignKey("customers.id"), nullable=True)
    branch_id   = db.Column(db.Integer, db.ForeignKey("branches.id"), nullable=True)
    items = db.relationship("SaleItem", backref="sale", lazy=True, cascade="all, delete-orphan")

    def to_dict(self):
        return {"id": self.id, "client_name": self.client_name or "", "customer_id": self.customer_id,
                "subtotal_amount": self.subtotal_amount or 0.0,
                "discount_amount": self.discount_amount or 0.0,
                "tax_amount": self.tax_amount or 0.0,
                "total_amount": self.total_amount,
                "payment_method": self.payment_method or "efectivo",
                "payment_status": self.payment_status or "aprobado",
                "branch_id": self.branch_id,
                "branch_name": self.branch.name if self.branch else None,
                "created_at": self.created_at.isoformat(),
                "items": [i.to_dict() for i in self.items]}
