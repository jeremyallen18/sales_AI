"""
inventory_routes.py — CRUD de productos via API REST + subida de imagenes.
"""
import os
import uuid
from flask import Blueprint, jsonify, request, current_app, send_from_directory
from werkzeug.utils import secure_filename
from ..services.inventory_service import (get_all_products, create_product,
    update_product, delete_product, get_low_stock)

inventory_bp = Blueprint("inventory", __name__, url_prefix="/api/inventory")

ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "gif", "webp"}

def allowed_file(filename):
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS

def get_upload_folder():
    folder = os.path.join(current_app.root_path, "static", "uploads")
    os.makedirs(folder, exist_ok=True)
    return folder

@inventory_bp.route("/products", methods=["GET"])
def list_products():
    return jsonify([p.to_dict() for p in get_all_products()])

@inventory_bp.route("/products", methods=["POST"])
def add_product():
    data = request.get_json()
    p = create_product(data)
    return jsonify(p.to_dict()), 201

@inventory_bp.route("/products/<int:pid>", methods=["PUT"])
def edit_product(pid):
    data = request.get_json()
    p = update_product(pid, data)
    return jsonify(p.to_dict())

@inventory_bp.route("/products/<int:pid>", methods=["DELETE"])
def remove_product(pid):
    delete_product(pid)
    return jsonify({"ok": True})

@inventory_bp.route("/low-stock", methods=["GET"])
def low_stock():
    return jsonify([p.to_dict() for p in get_low_stock()])

@inventory_bp.route("/products/<int:pid>/image", methods=["POST"])
def upload_product_image(pid):
    """Sube una imagen para un producto y guarda la URL."""
    if "image" not in request.files:
        return jsonify({"error": "No se envio imagen"}), 400
    file = request.files["image"]
    if file.filename == "":
        return jsonify({"error": "Archivo vacio"}), 400
    if not allowed_file(file.filename):
        return jsonify({"error": "Formato no permitido"}), 400

    ext = file.filename.rsplit(".", 1)[1].lower()
    filename = f"{uuid.uuid4().hex}.{ext}"
    filepath = os.path.join(get_upload_folder(), filename)
    file.save(filepath)

    image_url = f"/static/uploads/{filename}"
    from ..services.inventory_service import update_product
    update_product(pid, {"image_url": image_url})
    return jsonify({"image_url": image_url}), 200
