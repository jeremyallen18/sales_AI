"""
pdf_service.py — Generacion de recibos PDF y cortes de caja con ReportLab.
"""
from reportlab.lib.pagesizes import A6, A4
from reportlab.lib import colors
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm
import io
import base64
import qrcode


def generate_qr_b64(sale) -> str:
    """Genera imagen QR del folio/total como PNG base64."""
    data = f"VENTA-{sale.id:04d} | Total: ${sale.total_amount:.2f}"
    img = qrcode.make(data)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode()

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


# ─── Corte de caja ────────────────────────────────────────────────────────────

def generate_corte_pdf(corte: dict) -> bytes:
    """Genera PDF del corte de caja semanal o mensual (formato A4)."""
    buffer = io.BytesIO()
    c = canvas.Canvas(buffer, pagesize=A4)
    W, H = A4
    MARGEN = 18 * mm
    COL2 = W / 2 + 5 * mm

    def linea_h(y, grosor=0.5, color=colors.lightgrey):
        c.setStrokeColor(color)
        c.setLineWidth(grosor)
        c.line(MARGEN, y, W - MARGEN, y)
        c.setStrokeColor(colors.black)
        c.setLineWidth(0.5)

    def encabezado_seccion(titulo: str, y: float) -> float:
        c.setFillColor(colors.HexColor("#C8102E"))
        c.rect(MARGEN, y - 5 * mm, W - 2 * MARGEN, 7 * mm, fill=1, stroke=0)
        c.setFillColor(colors.white)
        c.setFont("Helvetica-Bold", 10)
        c.drawString(MARGEN + 3 * mm, y - 2 * mm, titulo.upper())
        c.setFillColor(colors.black)
        return y - 12 * mm

    def check_page(y, needed=12):
        """Nueva página si no hay espacio suficiente."""
        if y < MARGEN + needed * mm:
            c.showPage()
            return H - MARGEN
        return y

    resumen  = corte["resumen"]
    periodo  = corte["periodo"]
    branch   = corte.get("branch")
    metodos  = corte.get("por_metodo_pago", {})
    por_dia  = corte.get("ventas_por_dia", [])
    top_prod = corte.get("top_productos", [])
    tipo     = corte["tipo"].capitalize()

    y = H - MARGEN

    # ── Encabezado principal ──────────────────────────────────────────────────
    c.setFillColor(colors.HexColor("#C8102E"))
    c.rect(0, H - 28 * mm, W, 28 * mm, fill=1, stroke=0)
    c.setFillColor(colors.white)
    c.setFont("Helvetica-Bold", 18)
    c.drawCentredString(W / 2, H - 12 * mm, f"CORTE DE CAJA {tipo.upper()}")
    c.setFont("Helvetica", 10)
    c.drawCentredString(W / 2, H - 20 * mm, periodo["label"])
    c.setFillColor(colors.black)

    y = H - 35 * mm

    # Sucursal y fecha de generación
    c.setFont("Helvetica", 8)
    branch_txt = f"Sucursal: {branch['name']}" if branch else "Todas las sucursales"
    c.drawString(MARGEN, y, branch_txt)
    c.drawRightString(W - MARGEN, y, f"Generado: {corte['generado_en']}")
    y -= 4 * mm
    linea_h(y, grosor=1, color=colors.HexColor("#C8102E"))
    y -= 8 * mm

    # ── Resumen financiero ────────────────────────────────────────────────────
    y = encabezado_seccion("Resumen Financiero", y)

    datos_resumen = [
        ("Total de transacciones", str(resumen["total_transacciones"])),
        ("Subtotal (antes de IVA)", f"${resumen['subtotal']:,.2f}"),
        ("Descuentos aplicados",    f"-${resumen['descuentos']:,.2f}"),
        ("IVA recaudado (16%)",     f"${resumen['iva']:,.2f}"),
        ("Ticket promedio",         f"${resumen['ticket_promedio']:,.2f}"),
    ]
    c.setFont("Helvetica", 10)
    for label, valor in datos_resumen:
        y = check_page(y)
        c.drawString(MARGEN, y, label)
        c.drawRightString(W - MARGEN, y, valor)
        y -= 6 * mm

    # Total neto — destacado
    y = check_page(y, 16)
    linea_h(y + 2 * mm, grosor=0.5)
    y -= 5 * mm
    c.setFillColor(colors.HexColor("#C8102E"))
    c.rect(MARGEN, y - 4 * mm, W - 2 * MARGEN, 10 * mm, fill=1, stroke=0)
    c.setFillColor(colors.white)
    c.setFont("Helvetica-Bold", 13)
    c.drawString(MARGEN + 4 * mm, y + 1 * mm, "INGRESOS NETOS TOTALES")
    c.drawRightString(W - MARGEN - 4 * mm, y + 1 * mm, f"${resumen['ingresos_netos']:,.2f}")
    c.setFillColor(colors.black)
    y -= 14 * mm

    # ── Desglose por método de pago ───────────────────────────────────────────
    y = check_page(y, 14)
    y = encabezado_seccion("Desglose por Metodo de Pago", y)

    LABELS = {"efectivo": "Efectivo", "tarjeta": "Tarjeta", "transferencia": "Transferencia"}
    c.setFont("Helvetica-Bold", 9)
    c.drawString(MARGEN, y, "Metodo")
    c.drawString(COL2 - 20 * mm, y, "Transacciones")
    c.drawRightString(W - MARGEN, y, "Total")
    y -= 4 * mm
    linea_h(y)
    y -= 5 * mm

    c.setFont("Helvetica", 9)
    for metodo, datos in sorted(metodos.items()):
        y = check_page(y)
        c.drawString(MARGEN, y, LABELS.get(metodo, metodo.title()))
        c.drawString(COL2 - 20 * mm, y, str(datos["transacciones"]))
        c.drawRightString(W - MARGEN, y, f"${datos['total']:,.2f}")
        y -= 6 * mm

    y -= 4 * mm

    # ── Top 10 productos ──────────────────────────────────────────────────────
    y = check_page(y, 14)
    y = encabezado_seccion("Top 10 Productos Mas Vendidos", y)

    c.setFont("Helvetica-Bold", 9)
    c.drawString(MARGEN, y, "#")
    c.drawString(MARGEN + 8 * mm, y, "Producto")
    c.drawString(COL2 + 10 * mm, y, "Cantidad")
    c.drawRightString(W - MARGEN, y, "Ingresos")
    y -= 4 * mm
    linea_h(y)
    y -= 5 * mm

    c.setFont("Helvetica", 9)
    for i, prod in enumerate(top_prod, 1):
        y = check_page(y)
        c.drawString(MARGEN, y, str(i))
        nombre = prod["name"]
        if len(nombre) > 32:
            nombre = nombre[:32] + "..."
        c.drawString(MARGEN + 8 * mm, y, nombre)
        c.drawString(COL2 + 10 * mm, y, str(prod["cantidad"]))
        c.drawRightString(W - MARGEN, y, f"${prod['ingresos']:,.2f}")
        y -= 6 * mm

    y -= 4 * mm

    # ── Ventas por día ────────────────────────────────────────────────────────
    if por_dia:
        y = check_page(y, 14)
        y = encabezado_seccion("Ventas por Dia", y)

        c.setFont("Helvetica-Bold", 9)
        c.drawString(MARGEN, y, "Fecha")
        c.drawString(COL2, y, "Transacciones")
        c.drawRightString(W - MARGEN, y, "Total del dia")
        y -= 4 * mm
        linea_h(y)
        y -= 5 * mm

        c.setFont("Helvetica", 9)
        for row in por_dia:
            y = check_page(y)
            # Formatear fecha YYYY-MM-DD → DD/MM/YYYY
            try:
                dt = row["fecha"]
                partes = dt.split("-")
                fecha_fmt = f"{partes[2]}/{partes[1]}/{partes[0]}"
            except Exception:
                fecha_fmt = row["fecha"]
            c.drawString(MARGEN, y, fecha_fmt)
            c.drawString(COL2, y, str(row["ventas"]))
            c.drawRightString(W - MARGEN, y, f"${row['total']:,.2f}")
            y -= 6 * mm

    # ── Pie de página ─────────────────────────────────────────────────────────
    c.setFont("Helvetica", 7)
    c.setFillColor(colors.grey)
    c.drawCentredString(W / 2, MARGEN / 2, "Documento generado automaticamente por VentaIA")
    c.setFillColor(colors.black)

    c.save()
    return buffer.getvalue()
