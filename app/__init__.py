"""
app/__init__.py — Fábrica de la aplicación Flask.
Registra blueprints, base de datos y configuración inicial.
"""

import logging
from flask import Flask, jsonify, send_from_directory
from werkzeug.exceptions import HTTPException
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from .database.db import db
from .config import Config

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

limiter = Limiter(key_func=get_remote_address, default_limits=[], storage_uri="memory://")


def _migrate_columns(app):
    """Add new columns to existing tables if they don't exist (SQLite)."""
    import sqlite3
    db_path = app.config["SQLALCHEMY_DATABASE_URI"].replace("sqlite:///", "")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    migrations = [
        ("products", "image_url",       "TEXT DEFAULT ''"),
        ("products", "discount_pct",    "REAL DEFAULT 0.0"),
        ("sales",    "client_name",     "TEXT DEFAULT ''"),
        ("sales",    "payment_method",  "TEXT DEFAULT 'efectivo'"),
        ("sales",    "payment_status",  "TEXT DEFAULT 'aprobado'"),
        ("sales",    "subtotal_amount", "REAL DEFAULT 0.0"),
        ("sales",    "discount_amount", "REAL DEFAULT 0.0"),
        ("sales",    "tax_amount",      "REAL DEFAULT 0.0"),
    ]
    for table, column, col_type in migrations:
        cursor.execute(f"PRAGMA table_info({table})")
        columns = [row[1] for row in cursor.fetchall()]
        if column not in columns:
            cursor.execute(f"ALTER TABLE {table} ADD COLUMN {column} {col_type}")
    conn.commit()
    conn.close()


def create_app():
    Config.validate()
    app = Flask(__name__)
    app.config.from_object(Config)

    # Inicializar extensiones
    db.init_app(app)
    limiter.init_app(app)
    CORS(app, resources={r"/api/*": {"origins": "*"}})

    # Registrar blueprints (módulos de rutas)
    from .routes.auth_routes import auth_bp
    from .routes.sales_routes import sales_bp
    from .routes.inventory_routes import inventory_bp
    from .routes.analytics_routes import analytics_bp
    from .routes.chatbot_routes import chatbot_bp
    from .routes.insights_routes import insights_bp
    from .routes.settings_routes import settings_bp
    from .routes.store_routes import store_bp
    from .routes.health_routes import health_bp
    from .routes.bi_routes import bi_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(sales_bp)
    app.register_blueprint(inventory_bp)
    app.register_blueprint(analytics_bp)
    app.register_blueprint(chatbot_bp)
    app.register_blueprint(insights_bp)
    app.register_blueprint(settings_bp)
    app.register_blueprint(store_bp)
    app.register_blueprint(health_bp)
    app.register_blueprint(bi_bp)

    # Favicon — evita 404 constante en browsers
    @app.route("/favicon.ico")
    def favicon():
        return send_from_directory(app.static_folder, "favicon.ico",
                                   mimetype="image/vnd.microsoft.icon") \
               if (app.static_folder and
                   __import__("os").path.exists(
                       __import__("os").path.join(app.static_folder, "favicon.ico"))) \
               else ("", 204)

    # Manejador de errores HTTP (404, 405, etc.) — responde con el código correcto
    @app.errorhandler(HTTPException)
    def handle_http_exception(e):
        return jsonify({"error": e.description}), e.code

    # Manejador global de errores inesperados
    @app.errorhandler(Exception)
    def handle_exception(e):
        if isinstance(e, HTTPException):
            return jsonify({"error": e.description}), e.code
        logger.exception("Error no capturado: %s", e)
        return jsonify({"error": "Error interno del servidor"}), 500

    # Crear tablas si no existen y migrar columnas nuevas
    with app.app_context():
        db.create_all()
        _migrate_columns(app)
        from .database.seed import seed_if_empty
        seed_if_empty()

    return app
