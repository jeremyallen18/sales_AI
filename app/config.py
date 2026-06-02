"""
config.py — Configuración central de la aplicación.
Lee variables de entorno para API keys y base de datos.
"""

import os
import sys
from dotenv import load_dotenv

load_dotenv()  # Cargar variables desde .env

# Directorio base del proyecto (un nivel arriba de /app/)
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

_DEMO_KEY = 'CONFIGURA_TU_OPENROUTER_API_KEY_EN_EL_ARCHIVO_.env'


def _require_env(name, demo_value=None):
    value = os.environ.get(name, '')
    if not value or value == demo_value:
        print(f"[CONFIG ERROR] La variable de entorno '{name}' no está configurada o usa el valor demo.", file=sys.stderr)
        print(f"[CONFIG ERROR] Define '{name}' en tu archivo .env o en las variables de Railway.", file=sys.stderr)
        sys.exit(1)
    return value


class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY', 'dev-secret-key-cambiar-en-produccion')

    SQLALCHEMY_DATABASE_URI = os.environ.get(
        'DATABASE_URL',
        'sqlite:///' + os.path.join(BASE_DIR, 'instance', 'app.db')
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # API key de OpenRouter — SOLO se usa en backend, nunca en frontend
    OPENROUTER_API_KEY = os.environ.get('OPENROUTER_API_KEY', _DEMO_KEY)

    BUSINESS_NAME = os.environ.get('BUSINESS_NAME', 'Mi Negocio')

    # Unidades mínimas antes de marcar producto como bajo stock
    LOW_STOCK_THRESHOLD = int(os.environ.get('LOW_STOCK_THRESHOLD', '10'))

    @classmethod
    def validate(cls):
        """Valida que las variables críticas estén definidas antes de arrancar."""
        errors = []
        if cls.OPENROUTER_API_KEY == _DEMO_KEY:
            errors.append("OPENROUTER_API_KEY usa el valor demo — cámbiala por una clave real.")
        if cls.SECRET_KEY == 'dev-secret-key-cambiar-en-produccion':
            errors.append("SECRET_KEY usa el valor por defecto — define una clave aleatoria segura.")
        if errors:
            print("[CONFIG] Advertencia — variables de entorno sin configurar:", file=sys.stderr)
            for e in errors:
                print(f"  ✗ {e}", file=sys.stderr)
