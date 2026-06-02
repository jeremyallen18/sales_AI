# Proyecto Power BI — VentaIA (Avance 3er parcial)

Guía para construir el dashboard de Inteligencia de Negocios de VentaIA en **Power BI Desktop**, consumiendo los datos directamente desde el backend Flask vía el conector **Web (JSON)**.

> Este documento mapea cada paso a los criterios de la rúbrica: **Dashboard, KPIs finales, Interpretación de datos, Recomendaciones y Presentación final.**

---

## 0. Arquitectura del puente de datos

```
SQLite (instance/app.db)  →  Flask /api/bi/*  (JSON)  →  Power BI (conector Web)  →  Dashboard
```

El backend expone 3 endpoints en esquema estrella:

| Endpoint | Tabla en Power BI | Grano | Filas aprox. |
|---|---|---|---|
| `GET /api/bi/productos` | `productos` (dimensión) | 1 por producto | 8 |
| `GET /api/bi/ventas` | `ventas` (cabecera) | 1 por venta | 14 |
| `GET /api/bi/detalle` | `detalle` (**hechos**) | 1 por ítem vendido | 36 |

`detalle` es la tabla principal: trae `sale_id, fecha, client_name, product_id, product_name, category, quantity, price, subtotal`.

---

## 1. Levantar el backend

```powershell
cd C:\Users\jerem\Documents\sales_ai_app
python run.py
```

El servidor queda en `http://localhost:5000`. Verifica en el navegador que `http://localhost:5000/api/bi/detalle` devuelve JSON.

---

## 2. Conectar Power BI (conector Web)

1. Power BI Desktop → **Inicio → Obtener datos → Web**.
2. URL: `http://localhost:5000/api/bi/detalle` → **Aceptar**. (Acceso anónimo si lo pregunta.)
3. Se abre el **Editor de Power Query**. El JSON entra como un registro con un campo `data` (lista):
   - Clic en **List** junto a `data` → **A la tabla** (To Table).
   - En el ícono de expandir de la columna, **Expandir** todas las columnas.
4. **Importante — quita el prefijo `data.`**: al expandir, en el cuadro de expansión **desmarca "Usar el nombre de columna original como prefijo"**. Si ya quedaron como `data.fecha`, `data.subtotal`, etc., renómbralas (doble clic en el encabezado) quitando `data.`; de lo contrario el DAX de esta guía (que usa `detalle[fecha]`, `detalle[subtotal]`…) dará el error *"No se encuentra la columna"*.
5. **Tipos de datos**: marca `fecha` como *Fecha/Hora*, `subtotal/price` como *Número decimal*, `quantity` como *Número entero*. Renombra la consulta a **`detalle`**.
5. Repite los pasos 1-4 con `…/api/bi/productos` (consulta **`productos`**) y `…/api/bi/ventas` (consulta **`ventas`**).
6. **Cerrar y aplicar**.

> Para refrescar datos nuevos basta con tener el backend corriendo y pulsar **Actualizar** en Power BI.

---

## 3. Modelo de datos (relaciones)

En la vista **Modelo**, crea (Power BI suele detectarlas solo):

- `productos[id]` **1 → \*** `detalle[product_id]`
- `ventas[id]` **1 → \*** `detalle[sale_id]`

### Tabla calendario (opcional pero recomendada para tendencias)

Nueva tabla (Modelado → Nueva tabla):

```DAX
Calendario =
ADDCOLUMNS(
    CALENDAR ( MIN(detalle[fecha]), MAX(detalle[fecha]) ),
    "Año", YEAR([Date]),
    "Mes", FORMAT([Date], "YYYY-MM"),
    "Día", DAY([Date])
)
```

Relaciona `Calendario[Date]` **1 → \*** `detalle[fecha]` y marca la tabla como **Tabla de fechas**.

---

## 4. KPIs — Medidas DAX (criterio "KPIs finales")

Crea estas medidas (Modelado → Nueva medida). Cópialas tal cual:

```DAX
Ingresos Totales = SUM ( detalle[subtotal] )

Total Ventas = DISTINCTCOUNT ( detalle[sale_id] )

Unidades Vendidas = SUM ( detalle[quantity] )

Ticket Promedio = DIVIDE ( [Ingresos Totales], [Total Ventas] )

Productos en Stock Bajo = CALCULATE ( COUNTROWS ( productos ), productos[stock] <= 10 )

Precio Promedio Vendido = DIVIDE ( [Ingresos Totales], [Unidades Vendidas] )
```

### Tendencia y comparativa (requiere tabla Calendario)

```DAX
Ingresos Mes Anterior =
CALCULATE ( [Ingresos Totales], DATEADD ( Calendario[Date], -1, MONTH ) )

% Crecimiento Ingresos =
DIVIDE ( [Ingresos Totales] - [Ingresos Mes Anterior], [Ingresos Mes Anterior] )
```

> **Meta de ejemplo** (la rúbrica valora metas/comparativas): define una meta de ingresos y compárala:
> ```DAX
> Meta Ingresos = 50000
> % Cumplimiento Meta = DIVIDE ( [Ingresos Totales], [Meta Ingresos] )
> ```

---

## 5. Dashboard — visuales sugeridos (criterio "Dashboard")

Distribución recomendada en **una página**:

**Fila superior — Tarjetas KPI:**
- Tarjeta: `Ingresos Totales`
- Tarjeta: `Total Ventas`
- Tarjeta: `Ticket Promedio`
- Tarjeta: `Unidades Vendidas`
- Tarjeta: `Productos en Stock Bajo`

**Fila media:**
- **Gráfico de líneas** — Eje: `Calendario[Date]` (o `detalle[fecha]`); Valores: `Ingresos Totales`. → tendencia.
- **Gráfico de barras** — Eje: `detalle[product_name]`; Valores: `Unidades Vendidas`, ordenado desc. → top productos.

**Fila inferior:**
- **Gráfico de anillo/pastel** — Leyenda: `detalle[category]`; Valores: `Ingresos Totales`. → mix por categoría.
- **Tabla** — `productos[name], stock, category`, filtrada a `stock <= 10`. → reabastecimiento.

**Interactividad (exigida por la rúbrica):**
- **Segmentador** por `detalle[category]`.
- **Segmentador** de rango de fechas por `Calendario[Date]`.
- Botones de navegación si agregas más páginas.

> Diseño: usa el tema navy de la marca (#0A1A3F aprox.), títulos claros, alinea los visuales en cuadrícula.

---

## 6. Interpretación de datos (criterio de rúbrica)

Redacta el análisis respondiendo (con los números reales del dashboard):

- ¿Qué **categoría** y qué **producto** concentran la mayor parte de los ingresos? ¿Hay dependencia de pocos productos?
- ¿La **tendencia** de ingresos es al alza, estable o a la baja? ¿Hay picos/anomalías en fechas concretas?
- ¿Cuál es el **ticket promedio** y qué dice del comportamiento de compra?
- ¿Qué productos tienen **stock bajo** y a la vez alta rotación (riesgo de quiebre)?
- ¿Qué productos **no rotan** (mucho stock, pocas ventas)?

## 7. Recomendaciones para la toma de decisiones (criterio de rúbrica)

Plantilla — escribe 3-4 acciones concretas derivadas de los datos:

1. **Reabastecer** los productos top con stock ≤ 10 para evitar quiebres de venta.
2. **Promocionar / liquidar** productos de baja rotación para liberar inventario.
3. **Reforzar** la categoría líder (más surtido/visibilidad) y evaluar por qué las demás venden menos.
4. **Subir el ticket promedio** con paquetes o ventas cruzadas de productos complementarios.

## 8. Guion de presentación final (criterio de rúbrica)

1. **Problema / objetivo del negocio** (qué decisiones queremos apoyar).
2. **Origen de datos**: app VentaIA (Flask + SQLite) → API JSON → Power BI.
3. **Recorrido del dashboard** y su interactividad.
4. **KPIs** y qué significan.
5. **Hallazgos** (interpretación) y **recomendaciones**.
6. **Conclusiones** y próximos pasos del proyecto.

---

## Estado del avance

- [x] Puente de datos en Python (`/api/bi/productos`, `/api/bi/ventas`, `/api/bi/detalle`).
- [x] Guía de conexión + modelo + medidas DAX de KPIs.
- [ ] Construcción del `.pbix` en Power BI Desktop (manual).
- [ ] Redacción final de interpretación y recomendaciones con los números reales.
- [ ] (Opcional) Ampliar datos de prueba si las tendencias se ven pobres.
