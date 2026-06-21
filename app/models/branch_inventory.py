from ..database.db import db


class BranchInventory(db.Model):
    __tablename__ = "branch_inventory"
    id           = db.Column(db.Integer, primary_key=True)
    branch_id    = db.Column(db.Integer, db.ForeignKey("branches.id"), nullable=False)
    product_id   = db.Column(db.Integer, db.ForeignKey("products.id"), nullable=False)
    stock        = db.Column(db.Integer, default=0)
    price        = db.Column(db.Float, nullable=True)        # None = usa precio global
    discount_pct = db.Column(db.Float, nullable=True)        # None = usa descuento global
    offer_badge  = db.Column(db.String(40), nullable=True)   # "2x1", "Flash", etc.

    product = db.relationship("Product", lazy=True)

    __table_args__ = (
        db.UniqueConstraint("branch_id", "product_id", name="uq_branch_product"),
        db.Index("ix_branch_inventory_branch", "branch_id"),
    )

    def effective_price(self):
        return self.price if self.price is not None else self.product.price

    def effective_discount(self):
        if self.discount_pct is not None:
            return self.discount_pct
        return self.product.discount_pct or 0.0

    def to_dict(self):
        p = self.product
        return {
            "id": self.id,
            "branch_id": self.branch_id,
            "product_id": self.product_id,
            "stock": self.stock,
            "price": self.effective_price(),
            "discount_pct": self.effective_discount(),
            "offer_badge": self.offer_badge or None,
            "name": p.name,
            "category": p.category,
            "image_url": p.image_url,
        }
