# ⚡ VentaIA — Sistema de Ventas con Inteligencia Artificial

Sistema completo de gestión de ventas con chatbot IA integrado, construido con Flask + SQLite + OpenRouter.

---

## 🚀 Instalación rápida

### 1. Crear entorno virtual e instalar dependencias
```bash
cd sales_ai_app
python -m venv venv

# Windows:
venv\Scripts\activate
# Mac/Linux:
source venv/bin/activate

pip install -r requirements.txt
```

### 2. Configurar variables de entorno
```bash
# Copiar el archivo de ejemplo
cp .env.example .env

# Editar .env y pegar tu API key de OpenRouter
```

### 3. Obtener API Key de OpenRouter
1. Registrarse en https://openrouter.ai (gratis)
2. Ir a "Keys" → "Create Key"
3. Copiar la key y pegarla en `.env` como `OPENROUTER_API_KEY`

### 4. Ejecutar
```bash
python run.py
```

Abrir en el navegador: **http://localhost:5000**

**Login:** `admin` / `admin123`

---

## 🗂️ Módulos del sistema

| Módulo | Ruta | Función |
|---|---|---|
| Dashboard | `/dashboard` | Estadísticas y gráficas |
| Punto de Venta | Panel POS | Registrar ventas con carrito |
| Historial | Panel historial | Ver ventas y descargar recibos PDF |
| Inventario | Panel inventario | CRUD de productos |
| Asistente IA | Panel chatbot | Análisis con datos reales |

---

## 🤖 Cómo funciona el chatbot

El asistente **NO** es un chatbot genérico. Antes de responder, el sistema:

1. Consulta la base de datos real (ingresos, top productos, stock bajo)
2. Construye un prompt estructurado con esos datos
3. Envía la pregunta + contexto a OpenRouter
4. Transmite la respuesta en tiempo real (streaming SSE)

Esto garantiza respuestas específicas sobre **tu negocio**, no respuestas genéricas.

---

## 📁 Estructura del proyecto

```
sales_ai_app/
├── run.py                    ← Punto de entrada
├── requirements.txt
├── .env.example              ← Plantilla de configuración
├── app/
│   ├── __init__.py           ← Factory de Flask
│   ├── config.py             ← Variables de entorno
│   ├── models/               ← Product, Sale, SaleItem
│   ├── routes/               ← Endpoints REST
│   ├── services/             ← Lógica de negocio
│   │   ├── ai_service.py     ← Wrapper de OpenRouter
│   │   ├── chatbot_service.py← Inyección de contexto IA
│   │   ├── analytics_service.py ← Queries SQL métricas
│   │   ├── sales_service.py  ← Registro de ventas
│   │   ├── inventory_service.py ← CRUD inventario
│   │   └── pdf_service.py    ← Generación de recibos
│   ├── templates/
│   │   ├── login.html
│   │   └── dashboard.html    ← SPA principal
│   └── static/js/app.js      ← Frontend JS completo
└── instance/app.db           ← Base de datos (se crea automáticamente)
```
