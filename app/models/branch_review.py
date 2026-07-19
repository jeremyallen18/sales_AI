from ..database.db import db
from ..utils import now_mx


class BranchReview(db.Model):
    __tablename__ = "branch_reviews"
    id          = db.Column(db.Integer, primary_key=True)
    customer_id = db.Column(db.Integer, db.ForeignKey("customers.id"), nullable=False)
    branch_id   = db.Column(db.Integer, db.ForeignKey("branches.id"), nullable=False)
    rating      = db.Column(db.Integer, nullable=False)  # 1-5
    comment     = db.Column(db.Text, default="")
    created_at  = db.Column(db.DateTime, default=now_mx)

    customer = db.relationship("Customer", foreign_keys=[customer_id])

    __table_args__ = (
        db.Index("ix_branch_review_branch", "branch_id"),
    )

    def to_dict(self):
        return {
            "id":            self.id,
            "customer_id":   self.customer_id,
            "customer_name": self.customer.display_name if self.customer else "Cliente",
            "branch_id":     self.branch_id,
            "rating":        self.rating,
            "comment":       self.comment or "",
            "created_at":    self.created_at.isoformat(),
        }
