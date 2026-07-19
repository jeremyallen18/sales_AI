"""
db.py — Instancia compartida de SQLAlchemy y Flask-Migrate.
Se importa en modelos y factory de la app.
"""
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate

db = SQLAlchemy()
migrate = Migrate()
