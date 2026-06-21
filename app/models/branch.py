from ..database.db import db
from ..utils import now_mx
import json


class Branch(db.Model):
    __tablename__ = "branches"
    id           = db.Column(db.Integer, primary_key=True)
    name         = db.Column(db.String(120), nullable=False)
    description  = db.Column(db.Text, default="")
    address      = db.Column(db.String(255), default="")
    city         = db.Column(db.String(100), default="")
    state        = db.Column(db.String(100), default="")
    zip_code     = db.Column(db.String(20), default="")
    latitude     = db.Column(db.Float, nullable=True)
    longitude    = db.Column(db.Float, nullable=True)
    phone        = db.Column(db.String(30), default="")
    email        = db.Column(db.String(255), default="")
    opening_time = db.Column(db.String(10), default="08:00")
    closing_time = db.Column(db.String(10), default="22:00")
    is_active    = db.Column(db.Boolean, default=True)
    images       = db.Column(db.Text, default="[]")  # JSON array
    created_at   = db.Column(db.DateTime, default=now_mx)

    inventory   = db.relationship("BranchInventory", backref="branch", lazy=True, cascade="all, delete-orphan")
    reviews     = db.relationship("BranchReview", backref="branch", lazy=True, cascade="all, delete-orphan")
    assignments = db.relationship("BranchAssignment", backref="branch", lazy=True, cascade="all, delete-orphan")
    sales       = db.relationship("Sale", backref="branch", lazy=True)

    def to_dict(self, distance_km=None):
        try:
            images = json.loads(self.images) if self.images else []
        except Exception:
            images = []
        d = {
            "id": self.id,
            "name": self.name,
            "description": self.description or "",
            "address": self.address or "",
            "city": self.city or "",
            "state": self.state or "",
            "zip_code": self.zip_code or "",
            "latitude": self.latitude,
            "longitude": self.longitude,
            "phone": self.phone or "",
            "email": self.email or "",
            "opening_time": self.opening_time or "08:00",
            "closing_time": self.closing_time or "22:00",
            "is_active": self.is_active,
            "images": images,
            "created_at": self.created_at.isoformat(),
        }
        if distance_km is not None:
            d["distance_km"] = distance_km
        return d
