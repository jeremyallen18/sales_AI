from datetime import datetime
from zoneinfo import ZoneInfo

MX_TZ = ZoneInfo("America/Mexico_City")


def now_mx():
    """Hora actual de Ciudad de México (naive, para columnas DateTime)."""
    return datetime.now(MX_TZ).replace(tzinfo=None)
