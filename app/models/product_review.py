from ..database.db import db
from ..utils import now_mx


class ProductReview(db.Model):
    __tablename__ = "product_reviews"
    id          = db.Column(db.Integer, primary_key=True)
    customer_id = db.Column(db.Integer, db.ForeignKey("customers.id"), nullable=False)
    product_id  = db.Column(db.Integer, db.ForeignKey("products.id"), nullable=False)
    rating      = db.Column(db.Integer, nullable=False)  # 1-5
    comment     = db.Column(db.Text, default="")
    created_at  = db.Column(db.DateTime, default=now_mx)

    customer = db.relationship("Customer", foreign_keys=[customer_id])

    __table_args__ = (
        db.Index("ix_product_review_product", "product_id"),
    )

    def to_dict(self):
        return {
            "id":            self.id,
            "customer_id":   self.customer_id,
            "customer_name": self.customer.display_name if self.customer else "Cliente",
            "product_id":    self.product_id,
            "rating":        self.rating,
            "comment":       self.comment or "",
            "created_at":    self.created_at.isoformat(),
        }
