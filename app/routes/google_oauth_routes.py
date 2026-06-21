"""
google_oauth_routes.py — Google Sign-In con flujo server-side (Authorization Code).

Ventaja sobre GIS/Firebase client-side: el redirect_uri siempre es
http://localhost:5000/auth/google/callback — URL que NO cambia nunca, se
registra UNA sola vez en Google Cloud Console, y funciona sin importar desde
qué IP/red se acceda al servidor (siempre que el navegador esté en la misma
máquina que el servidor, lo que aplica en demos).
"""
import time
import secrets
import requests as req_lib
from flask import Blueprint, redirect, request, session, current_app, render_template_string

google_oauth_bp = Blueprint('google_oauth', __name__, url_prefix='/auth/google')

_GOOGLE_AUTH  = 'https://accounts.google.com/o/oauth2/v2/auth'
_GOOGLE_TOKEN = 'https://oauth2.googleapis.com/token'
_REDIRECT_URI = 'http://localhost:5000/auth/google/callback'

# Códigos de activación de un solo uso: {code: {email, token, expires}}
# El popup genera el código; la ventana principal lo consume para establecer la sesión.
_activation_codes: dict[str, dict] = {}


# ── Inicio del flujo ────────────────────────────────────────────────────────────

@google_oauth_bp.route('/start')
def start():
    client_id     = current_app.config.get('GOOGLE_CLIENT_ID', '')
    client_secret = current_app.config.get('GOOGLE_CLIENT_SECRET', '')

    if not client_id:
        return _popup_error('GOOGLE_CLIENT_ID no configurado en el servidor.')
    if not client_secret:
        return _popup_error(
            'GOOGLE_CLIENT_SECRET no configurado. '
            'Agrégalo en .env y registra http://localhost:5000/auth/google/callback '
            'en Google Cloud Console → Credenciales → tu OAuth Client ID.'
        )

    mode  = request.args.get('mode', 'seller')   # 'seller' | 'customer'
    state = secrets.token_urlsafe(16)
    session['oauth_state'] = state
    session['oauth_mode']  = mode

    params = '&'.join([
        f'client_id={client_id}',
        f'redirect_uri={_REDIRECT_URI}',
        'response_type=code',
        'scope=openid+email+profile',
        f'state={state}',
        'access_type=online',
        'prompt=select_account',
    ])
    return redirect(f'{_GOOGLE_AUTH}?{params}')


# ── Callback de Google ──────────────────────────────────────────────────────────

@google_oauth_bp.route('/callback')
def callback():
    # Verificar state para prevenir CSRF
    expected = session.pop('oauth_state', None)
    if not expected or request.args.get('state') != expected:
        return _popup_error('Estado OAuth inválido — intenta de nuevo.')

    error = request.args.get('error')
    if error:
        return _popup_error(f'Google denegó el acceso: {error}')

    code = request.args.get('code')
    if not code:
        return _popup_error('No se recibió código de autorización.')

    # Intercambiar código por tokens
    try:
        resp = req_lib.post(_GOOGLE_TOKEN, data={
            'code':          code,
            'client_id':     current_app.config['GOOGLE_CLIENT_ID'],
            'client_secret': current_app.config['GOOGLE_CLIENT_SECRET'],
            'redirect_uri':  _REDIRECT_URI,
            'grant_type':    'authorization_code',
        }, timeout=10)
        token_data = resp.json()
    except Exception as exc:
        return _popup_error(f'Error de red al contactar Google: {exc}')

    if 'error' in token_data:
        return _popup_error(token_data.get('error_description', token_data['error']))

    id_token = token_data.get('id_token')
    if not id_token:
        return _popup_error('Google no devolvió id_token.')

    mode = session.pop('oauth_mode', 'seller')
    try:
        if mode == 'customer':
            return _complete_customer_login(id_token)
        return _complete_seller_login(id_token)
    except Exception as exc:
        return _popup_error(str(exc))


# ── Lógica de login del vendedor ────────────────────────────────────────────────

def _complete_seller_login(id_token: str) -> str:
    from .firebase_auth_routes import _verify_any_token, _make_app_token
    from ..database.db import db
    from ..models.seller_account import SellerAccount
    from ..models.branch import Branch
    from ..services.branch_service import get_seller_branches

    claims = _verify_any_token(id_token)

    uid          = claims['uid']
    email        = claims.get('email', '')
    display_name = claims.get('name', '')
    photo_url    = claims.get('picture', '')

    seller = SellerAccount.query.filter_by(firebase_uid=uid).first()

    if seller is None:
        seller_by_email = SellerAccount.query.filter_by(email=email).first()
        total           = SellerAccount.query.count()

        if seller_by_email:
            seller_by_email.firebase_uid = uid
            seller_by_email.display_name = display_name
            db.session.commit()
            seller = seller_by_email
        elif total == 0:
            seller = SellerAccount(
                firebase_uid=uid, email=email, display_name=display_name,
                photo_url=photo_url, role='owner', is_active=True,
            )
            db.session.add(seller)
            db.session.commit()
        else:
            raise ValueError('No tienes acceso como vendedor.')

    if not seller.is_active:
        raise ValueError('Cuenta desactivada.')

    seller.display_name = display_name
    seller.photo_url    = photo_url
    db.session.commit()

    session['user'] = seller.email

    branch_ids  = get_seller_branches(seller.id)
    branches    = [Branch.query.get(bid).to_dict() for bid in branch_ids
                   if Branch.query.get(bid)]

    secret = current_app.config['APP_TOKEN_SECRET']
    ttl    = current_app.config['APP_TOKEN_TTL_HOURS']
    token  = _make_app_token(
        {'sub': str(seller.id), 'uid': uid, 'role': seller.role,
         'branch_ids': branch_ids},
        ttl, secret,
    )
    seller_data            = seller.to_dict()
    seller_data['branches'] = branches

    return _popup_success(token, seller_data)


# ── Login cliente ──────────────────────────────────────────────────────────────

def _complete_customer_login(id_token: str) -> str:
    from .firebase_auth_routes import _verify_any_token, _make_app_token
    from ..database.db import db
    from ..models.customer import Customer

    claims = _verify_any_token(id_token)

    uid          = claims['uid']
    email        = claims.get('email', '')
    display_name = claims.get('name', '')
    photo_url    = claims.get('picture', '')

    customer = Customer.query.filter_by(firebase_uid=uid).first()
    if customer is None:
        customer = Customer.query.filter_by(email=email).first()
        if customer is not None:
            customer.firebase_uid = uid
            customer.display_name = display_name
            customer.photo_url    = photo_url
        else:
            customer = Customer(
                firebase_uid=uid, email=email,
                display_name=display_name, photo_url=photo_url,
            )
            db.session.add(customer)
    else:
        customer.display_name = display_name
        customer.photo_url    = photo_url
    db.session.commit()

    secret = current_app.config['APP_TOKEN_SECRET']
    ttl    = current_app.config['APP_TOKEN_TTL_HOURS']
    token  = _make_app_token(
        {'sub': str(customer.id), 'uid': uid, 'role': 'customer'},
        ttl, secret,
    )
    import json
    payload  = json.dumps({
        'type': 'google-auth-ok',
        'token': token,
        'customer': customer.to_dict(),
    })
    fallback = (
        "localStorage.setItem('customer_token'," + json.dumps(token) + ");"
        "localStorage.setItem('customer_display_name'," + json.dumps(display_name) + ");"
        "window.location.reload();"
    )
    return _POPUP_BASE.replace('{payload}', payload).replace('{fallback}', fallback).replace('{body}', '')


# ── Activación de sesión (ventana principal) ───────────────────────────────────

@google_oauth_bp.route('/activate')
def activate():
    """
    La ventana principal navega aquí con el código que le pasó el popup.
    Establece session['user'] en el dominio correcto y redirige al dashboard.
    """
    # Limpiar códigos expirados de paso
    now = time.time()
    expired = [k for k, v in _activation_codes.items() if v['expires'] < now]
    for k in expired:
        _activation_codes.pop(k, None)

    code  = request.args.get('code', '')
    entry = _activation_codes.pop(code, None)

    if not entry or entry['expires'] < now:
        return redirect('/login')

    session['user'] = entry['email']
    # Redirigir al dashboard; el JS del dashboard leerá seller_token desde sessionStorage
    # (ya fue guardado por la ventana principal al recibir el postMessage)
    return redirect('/dashboard')


# ── Respuestas del popup ────────────────────────────────────────────────────────

_POPUP_BASE = '''<!doctype html><html><head><meta charset="utf-8"></head><body>
<script>
(function(){
  var payload = {payload};
  if(window.opener){
    window.opener.postMessage(payload,'*');
    window.close();
  } else {
    {fallback}
  }
})();
</script>
{body}
</body></html>'''


def _popup_success(token: str, seller: dict) -> str:
    import json
    # Genera un código de un solo uso (120 s) para que la ventana principal
    # establezca la sesión Flask en su propio dominio.
    code = secrets.token_urlsafe(32)
    _activation_codes[code] = {
        'email': seller.get('email', ''),
        'token': token,
        'expires': time.time() + 120,
    }
    payload  = json.dumps({'type': 'google-auth-ok', 'token': token,
                           'seller': seller, 'activate_code': code})
    fallback = (
        "window.location.href='/auth/google/activate?code='+" + json.dumps(code) + ";"
    )
    return _POPUP_BASE.replace('{payload}', payload).replace('{fallback}', fallback).replace('{body}', '')


def _popup_error(msg: str) -> str:
    import json
    payload  = json.dumps({'type': 'google-auth-error', 'error': msg})
    fallback = "document.body.innerHTML='<p style=\"color:red;font-family:sans-serif;padding:1rem\">'+" + json.dumps(msg) + "+'</p>';"
    return _POPUP_BASE.replace('{payload}', payload).replace('{fallback}', fallback).replace('{body}', '')
