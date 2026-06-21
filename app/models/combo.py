from ..database.db import db
from ..utils import now_mx


class Combo(db.Model):
    __tablename__ = "combos"
    id          = db.Column(db.Integer, primary_key=True)
    name        = db.Column(db.String(120), nullable=False)
    description = db.Column(db.String(300), default="")
    price       = db.Column(db.Float, nullable=False)
    image_url   = db.Column(db.String(300), default="")
    is_active   = db.Column(db.Boolean, default=True)
    branch_id   = db.Column(db.Integer, db.ForeignKey("branches.id"), nullable=True)
    created_at  = db.Column(db.DateTime, default=now_mx)

    items = db.relationship(
        "ComboItem", backref="combo", lazy=True, cascade="all, delete-orphan"
    )

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description or "",
            "price": self.price,
            "image_url": self.image_url or "",
            "is_active": self.is_active,
            "branch_id": self.branch_id,
            "created_at": self.created_at.isoformat(),
            "items": [ci.to_dict() for ci in self.items],
        }


class ComboItem(db.Model):
    __tablename__ = "combo_items"
    id         = db.Column(db.Integer, primary_key=True)
    combo_id   = db.Column(db.Integer, db.ForeignKey("combos.id"), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey("products.id"), nullable=False)
    quantity   = db.Column(db.Integer, default=1, nullable=False)

    product = db.relationship("Product", lazy=True)

    def to_dict(self):
        p = self.product
        return {
            "id": self.id,
            "product_id": self.product_id,
            "product_name": p.name if p else "",
            "product_image": p.image_url if p else "",
            "product_price": p.price if p else 0.0,
            "quantity": self.quantity,
        }
