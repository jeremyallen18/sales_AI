from ..database.db import db
from ..utils import now_mx


class BranchAssignment(db.Model):
    __tablename__ = "branch_assignments"
    id         = db.Column(db.Integer, primary_key=True)
    seller_id  = db.Column(db.Integer, db.ForeignKey("seller_accounts.id"), nullable=False)
    branch_id  = db.Column(db.Integer, db.ForeignKey("branches.id"), nullable=False)
    is_primary = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=now_mx)

    __table_args__ = (
        db.UniqueConstraint("seller_id", "branch_id", name="uq_seller_branch"),
        db.Index("ix_branch_assignment_seller", "seller_id"),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "seller_id": self.seller_id,
            "branch_id": self.branch_id,
            "is_primary": self.is_primary,
        }
