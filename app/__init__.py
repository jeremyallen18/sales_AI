"""
app/__init__.py — Fábrica de la aplicación Flask.
Registra blueprints, base de datos y configuración inicial.
"""

import logging
from flask import Flask, jsonify
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

limiter = Limiter(key_func=get_remote_address, default_limits=[])


def _migrate_columns(app):
    """Add new columns to existing tables if they don't exist (SQLite)."""
    import sqlite3
    db_path = app.config["SQLALCHEMY_DATABASE_URI"].replace("sqlite:///", "")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    migrations = [
        ("products", "image_url", "TEXT DEFAULT ''"),
        ("sales", "client_name", "TEXT DEFAULT ''"),
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

    # Manejador global de errores no capturados
    @app.errorhandler(Exception)
    def handle_exception(e):
        logger.exception("Error no capturado: %s", e)
        return jsonify({"error": "Error interno del servidor"}), 500

    # Crear tablas si no existen y migrar columnas nuevas
    with app.app_context():
        db.create_all()
        _migrate_columns(app)
        from .database.seed import seed_if_empty
        seed_if_empty()

    return app
