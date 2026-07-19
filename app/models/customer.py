from ..database.db import db
from ..utils import now_mx


class Customer(db.Model):
    __tablename__ = "customers"
    id           = db.Column(db.Integer, primary_key=True)
    firebase_uid = db.Column(db.String(128), unique=True, nullable=False, index=True)
    email        = db.Column(db.String(255), unique=True, nullable=False)
    display_name = db.Column(db.String(150), default="")
    phone        = db.Column(db.String(30), default="")
    photo_url    = db.Column(db.String(500), default="")
    created_at   = db.Column(db.DateTime, default=now_mx)
    updated_at   = db.Column(db.DateTime, default=now_mx, onupdate=now_mx)

    sales = db.relationship("Sale", backref="customer", lazy=True)

    def to_dict(self):
        return {
            "id": self.id,
            "firebase_uid": self.firebase_uid,
            "email": self.email,
            "display_name": self.display_name,
            "phone": self.phone,
            "photo_url": self.photo_url,
            "created_at": self.created_at.isoformat(),
        }
