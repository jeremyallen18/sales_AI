"""
payment_service.py — Simulación de pasarela de pago.
"""
import time

VALID_METHODS = {"efectivo", "tarjeta", "transferencia"}

METHOD_LABELS = {
    "efectivo": "Efectivo",
    "tarjeta": "Tarjeta",
    "transferencia": "Transferencia",
}


def process_payment(method: str, amount: float) -> dict:
    """
    Simula el procesamiento de un pago.
    Para 'tarjeta' agrega un delay de 1 segundo para simular la red.
    Retorna {"status": "aprobado", "method": method} o lanza ValueError.
    """
    if method not in VALID_METHODS:
        raise ValueError(
            f"Método de pago inválido: '{method}'. "
            f"Opciones: {', '.join(sorted(VALID_METHODS))}"
        )

    if method == "tarjeta":
        time.sleep(1)

    return {"status": "aprobado", "method": method}
