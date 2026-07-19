from ..database.db import db
from ..utils import now_mx


class SellerAccount(db.Model):
    __tablename__ = "seller_accounts"
    id           = db.Column(db.Integer, primary_key=True)
    firebase_uid = db.Column(db.String(128), unique=True, nullable=False, index=True)
    email        = db.Column(db.String(255), unique=True, nullable=False)
    display_name = db.Column(db.String(150), default="")
    photo_url    = db.Column(db.String(500), default="")
    role         = db.Column(db.String(20), default="seller")  # "seller" | "admin" | "owner"
    is_active    = db.Column(db.Boolean, default=True)
    created_at   = db.Column(db.DateTime, default=now_mx)

    def to_dict(self):
        return {
            "id": self.id,
            "email": self.email,
            "display_name": self.display_name,
            "photo_url": self.photo_url,
            "role": self.role,
        }
