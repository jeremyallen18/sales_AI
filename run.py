"""
run.py — Punto de entrada de la aplicación Flask.
Inicializa y lanza el servidor en modo desarrollo.
"""

from app import create_app

app = create_app()

if __name__ == '__main__':
    # Modo debug activo para desarrollo local
    app.run(host='0.0.0.0', port=5000, debug=True)
