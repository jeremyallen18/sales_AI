"""
app/__init__.py — Fábrica de la aplicación Flask.
Registra blueprints, base de datos y configuración inicial.
"""

import os
import logging
from flask import Flask, jsonify, send_from_directory
from werkzeug.exceptions import HTTPException
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from .database.db import db, migrate
from .config import Config

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

limiter = Limiter(key_func=get_remote_address, default_limits=[], storage_uri="memory://")



def _init_firebase(app):
    """Inicializa Firebase Admin SDK si el archivo de credenciales existe."""
    try:
        import firebase_admin
        from firebase_admin import credentials as fb_credentials
        if not firebase_admin._apps:
            cred_path = app.config.get("FIREBASE_CREDENTIALS_PATH", "firebase-service-account.json")
            if os.path.exists(cred_path):
                cred = fb_credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred)
                logger.info("Firebase Admin SDK inicializado desde %s", cred_path)
            else:
                logger.warning(
                    "Credenciales Firebase no encontradas en '%s'. "
                    "Los endpoints de Google Sign-In estarán deshabilitados.", cred_path
                )
    except ImportError:
        logger.warning("firebase-admin no está instalado. Ejecuta: pip install firebase-admin")


def create_app():
    Config.validate()
    app = Flask(__name__)
    app.config.from_object(Config)

    # Inicializar extensiones
    db.init_app(app)
    migrate.init_app(app, db)
    limiter.init_app(app)
    CORS(app, resources={r"/api/*": {"origins": "*"}})

    _init_firebase(app)

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
    from .routes.firebase_auth_routes import firebase_auth_bp
    from .routes.google_oauth_routes import google_oauth_bp
    from .routes.branch_routes import branch_bp
    from .routes.review_routes import review_bp, product_review_bp
    from .routes.combo_routes import combo_bp
    from .routes.corte_routes import corte_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(firebase_auth_bp)
    app.register_blueprint(google_oauth_bp)
    app.register_blueprint(sales_bp)
    app.register_blueprint(inventory_bp)
    app.register_blueprint(analytics_bp)
    app.register_blueprint(chatbot_bp)
    app.register_blueprint(insights_bp)
    app.register_blueprint(settings_bp)
    app.register_blueprint(store_bp)
    app.register_blueprint(health_bp)
    app.register_blueprint(bi_bp)
    app.register_blueprint(branch_bp)
    app.register_blueprint(review_bp)
    app.register_blueprint(product_review_bp)
    app.register_blueprint(combo_bp)
    app.register_blueprint(corte_bp)

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

    # Crear tablas si no existen (fallback sin Flask-Migrate) y sembrar datos iniciales
    with app.app_context():
        db.create_all()
        from .database.seed import seed_if_empty
        seed_if_empty()

    return app
