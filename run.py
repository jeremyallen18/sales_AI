"""
run.py — Punto de entrada de la aplicación Flask.
Inicia ngrok automáticamente y muestra ngrok URL, LAN IPs y localhost al arrancar.
"""
import io
import os
import sys
import socket

from app import create_app

app = create_app()

PORT = 5000


# ── Helpers ────────────────────────────────────────────────────────────────────

def _get_lan_ips() -> list[str]:
    seen: set[str] = set()
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None):
            ip = info[4][0]
            if ':' not in ip and not ip.startswith('127.') and ip not in seen:
                seen.add(ip)
    except Exception:
        pass
    return sorted(seen)


def _start_ngrok(port: int) -> str | None:
    """Inicia un túnel ngrok y devuelve la URL pública HTTPS. None si falla."""
    try:
        from pyngrok import ngrok, conf

        # Permite sobreescribir el authtoken desde el entorno sin tocar código
        token = os.environ.get('NGROK_AUTHTOKEN') or os.environ.get('NGROK_AUTH_TOKEN')
        if token:
            conf.get_default().auth_token = token

        tunnel = ngrok.connect(port, 'http')
        url: str = tunnel.public_url
        # Forzar HTTPS (ngrok siempre expone ambos; la versión https es más útil)
        if url.startswith('http://'):
            url = 'https://' + url[7:]
        return url
    except Exception as exc:
        print(f'  [ngrok] No disponible: {exc}', file=sys.stderr)
        return None


def _write(text: str) -> None:
    """Escribe en stdout forzando UTF-8 (necesario en terminales Windows)."""
    try:
        sys.stdout.buffer.write(text.encode('utf-8'))
        sys.stdout.buffer.flush()
    except AttributeError:
        print(text, end='')


def _print_qr(url: str, label: str) -> None:
    try:
        import qrcode
        qr = qrcode.QRCode(border=1)
        qr.add_data(url)
        qr.make(fit=True)
        buf = io.StringIO()
        qr.print_ascii(out=buf, invert=True)
        _write(f'  QR → {label}\n')
        _write(buf.getvalue())
    except Exception:
        pass


def _print_startup(port: int, ngrok_url: str | None) -> None:
    lan_ips = _get_lan_ips()
    W = 60
    line = '═' * W

    _write(f'\n{line}\n')
    _write('  VentaIA — Servidor listo\n')
    _write(f'{line}\n')

    # localhost
    _write(f'  {"localhost":<22}  http://localhost:{port}\n')

    # LAN IPs
    for ip in lan_ips:
        _write(f'  {"LAN":<22}  http://{ip}:{port}\n')

    # ngrok
    if ngrok_url:
        _write(f'  {"ngrok (internet)":<22}  {ngrok_url}\n')
    else:
        _write(f'  {"ngrok":<22}  no disponible\n')

    _write(f'{line}\n\n')

    # QR: ngrok tiene prioridad (funciona fuera de la red local)
    if ngrok_url:
        _print_qr(ngrok_url, f'ngrok  {ngrok_url}')
        _write(f'\n  Escanea para configurar la app vendedor desde cualquier red\n')
    elif lan_ips:
        lan_url = f'http://{lan_ips[0]}:{port}'
        _print_qr(lan_url, f'LAN  {lan_url}')
        _write(f'\n  Escanea para configurar la app vendedor (misma red)\n')

    _write(f'{line}\n\n')


# ── Entrada principal ──────────────────────────────────────────────────────────

if __name__ == '__main__':
    # En modo debug, Werkzeug lanza un proceso hijo con WERKZEUG_RUN_MAIN=true.
    # Solo iniciamos ngrok y mostramos el banner en el proceso padre (primera ejecución).
    is_reloader_child = os.environ.get('WERKZEUG_RUN_MAIN') == 'true'

    if not is_reloader_child:
        ngrok_url = _start_ngrok(PORT)
        _print_startup(PORT, ngrok_url)

    app.run(host='0.0.0.0', port=PORT, debug=True)
