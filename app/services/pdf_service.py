"""
pdf_service.py — Generacion de recibos PDF con ReportLab.
"""
from reportlab.lib.pagesizes import A6
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm
import io

def generate_receipt(sale) -> bytes:
    """Genera PDF del recibo con nombre de cliente y todos los productos."""
    buffer = io.BytesIO()
    c = canvas.Canvas(buffer, pagesize=A6)
    w, h = A6

    # Encabezado
    c.setFont("Helvetica-Bold", 14)
    c.drawCentredString(w / 2, h - 18 * mm, "RECIBO DE VENTA")

    c.setFont("Helvetica", 9)
    c.drawCentredString(w / 2, h - 24 * mm,
                        f"Fecha: {sale.created_at.strftime('%d/%m/%Y %H:%M')}")
    c.drawCentredString(w / 2, h - 29 * mm, f"Folio: #{sale.id:04d}")

    # Nombre de cliente
    y = h - 35 * mm
    client = sale.client_name.strip() if sale.client_name else ""
    if client:
        c.setFont("Helvetica-Bold", 9)
        c.drawString(10 * mm, y, "Cliente:")
        c.setFont("Helvetica", 9)
        c.drawString(30 * mm, y, client)
        y -= 6 * mm

    c.line(10 * mm, y, w - 10 * mm, y)
    y -= 6 * mm

    # Encabezado de tabla
    c.setFont("Helvetica-Bold", 8)
    c.drawString(10 * mm, y, "Producto")
    c.drawString(70 * mm, y, "Cant.")
    c.drawString(80 * mm, y, "P.Unit")
    c.drawRightString(w - 10 * mm, y, "Subtotal")
    y -= 4 * mm
    c.line(10 * mm, y, w - 10 * mm, y)
    y -= 5 * mm

    # Items
    c.setFont("Helvetica", 8)
    for item in sale.items:
        if y < 18 * mm:
            c.showPage()
            c.setFont("Helvetica", 8)
            y = h - 15 * mm
        name = item.product.name if item.product else "Producto"
        if len(name) > 20:
            name = name[:20] + "..."
        c.drawString(10 * mm, y, name)
        c.drawString(72 * mm, y, str(item.quantity))
        c.drawString(80 * mm, y, f"${item.price:.2f}")
        c.drawRightString(w - 10 * mm, y, f"${item.quantity * item.price:.2f}")
        y -= 5 * mm

    # Total
    y -= 2 * mm
    c.line(10 * mm, y, w - 10 * mm, y)
    y -= 7 * mm
    c.setFont("Helvetica-Bold", 11)
    c.drawString(10 * mm, y, "TOTAL:")
    c.drawRightString(w - 10 * mm, y, f"${sale.total_amount:.2f}")

    y -= 8 * mm
    c.setFont("Helvetica", 7)
    c.drawCentredString(w / 2, y, "Gracias por su compra")

    c.save()
    return buffer.getvalue()
