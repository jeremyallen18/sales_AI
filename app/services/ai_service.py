"""
ai_service.py — Wrapper del API de OpenRouter.
Mantiene la API key solo en el backend.
"""
import requests
import json
from flask import current_app

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
DEFAULT_MODEL = "openai/gpt-4o-mini"  # modelo fijo y rápido (auto agrega latencia de routing)

# (timeout de conexión, timeout de lectura) en segundos.
# Conexión holgada porque esta red tarda ~12s en el handshake TLS.
CONNECT_TIMEOUT = 30
READ_TIMEOUT = 120

def ask_ai(system_prompt: str, user_message: str, stream: bool = False):
    """Envía mensajes a OpenRouter y retorna respuesta o generador SSE."""
    api_key = current_app.config["OPENROUTER_API_KEY"]
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "http://localhost:5000",
        "X-Title": "Sales AI App"
    }
    payload = {
        "model": DEFAULT_MODEL,
        "stream": stream,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message}
        ]
    }
    if stream:
        return _stream_response(headers, payload)
    resp = requests.post(OPENROUTER_URL, headers=headers, json=payload,
                         timeout=(CONNECT_TIMEOUT, READ_TIMEOUT))
    resp.raise_for_status()
    data = resp.json()
    return data["choices"][0]["message"]["content"]

def _stream_response(headers, payload):
    """Generador SSE que transmite tokens del modelo en tiempo real.

    Captura errores de red para que un timeout no tumbe el servidor:
    en su lugar emite un evento de error que el frontend puede mostrar.
    """
    try:
        with requests.post(OPENROUTER_URL, headers=headers, json=payload,
                           stream=True,
                           timeout=(CONNECT_TIMEOUT, READ_TIMEOUT)) as resp:
            resp.raise_for_status()
            for line in resp.iter_lines():
                if line:
                    line = line.decode("utf-8")
                    if line.startswith("data: "):
                        data_str = line[6:]
                        if data_str == "[DONE]":
                            yield "data: [DONE]\n\n"
                            break
                        try:
                            data = json.loads(data_str)
                            delta = data["choices"][0]["delta"].get("content", "")
                            if delta:
                                yield f"data: {json.dumps({'token': delta})}\n\n"
                        except Exception:
                            pass
    except requests.exceptions.Timeout:
        yield f"data: {json.dumps({'error': 'La IA tardó demasiado en responder. Revisa tu conexión e inténtalo de nuevo.'})}\n\n"
        yield "data: [DONE]\n\n"
    except requests.exceptions.RequestException as e:
        yield f"data: {json.dumps({'error': f'Error de conexión con la IA: {e}'})}\n\n"
        yield "data: [DONE]\n\n"
