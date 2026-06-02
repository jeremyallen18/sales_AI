"""
db.py — Instancia compartida de SQLAlchemy.
Se importa en modelos y factory de la app.
"""
from flask_sqlalchemy import SQLAlchemy
db = SQLAlchemy()
