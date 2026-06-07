/**
 * app.js — Logica frontend principal.
 * Maneja navegacion, fetch de datos, POS, inventario y chatbot.
 */

// ─── Estado global ───
let allProducts = [];
let cart = {};
let charts = {};
let pendingImageFile = null;  // Archivo de imagen pendiente para subir

// SVG placeholder para productos sin imagen
const PRODUCT_PLACEHOLDER_SVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M21 16V8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z"/></svg>';

// ─── Navegacion de paneles ───
function showPanel(name, btn) {
  document.querySelectorAll('.panel').forEach(p => p.classList.remove('active'));
  document.getElementById('panel-' + name).classList.add('active');

  document.querySelectorAll('.nav-btn').forEach(n => {
    n.classList.remove('nav-item-active');
  });
  if (btn) {
    btn.classList.add('nav-item-active');
  }

  const titles = {
    dashboard: 'Dashboard', ventas: 'Punto de Venta',
    historial: 'Historial de Ventas', inventario: 'Inventario', chatbot: 'Asistente IA'
  };
  const titleEl = document.getElementById('pageTitle');
  if (titleEl) titleEl.textContent = titles[name] || name;

  if (name === 'dashboard') loadDashboard();
  if (name === 'ventas') loadPosProducts();
  if (name === 'historial') loadHistorial();
  if (name === 'inventario') loadInventory();
}

// ─── Dashboard ───
async function loadDashboard() {
  try {
    const [summaryRes, salesRes, invRes] = await Promise.all([
      fetch('/api/analytics/summary'),
      fetch('/api/sales/'),
      fetch('/api/inventory/products')
    ]);
    const summary = await summaryRes.json();
    const sales = await salesRes.json();
    const products = await invRes.json();

    document.getElementById('s-ingresos').textContent = '$' + summary.ingresos_totales.toFixed(2);
    document.getElementById('s-ventas').textContent = sales.length;
    document.getElementById('s-productos').textContent = products.length;

    const lowStock = products.filter(p => p.stock <= 10);
    document.getElementById('s-bajo').textContent = lowStock.length;
    const badge = document.getElementById('lowStockBadge');
    badge.style.display = lowStock.length > 0 ? 'inline' : 'none';

    renderSalesTable('tbl-recientes', sales.slice(0, 8));
    renderLineChart(summary.ventas_recientes);
    renderBarChart(summary.top_productos);
  } catch (e) {
    showToast('Error cargando dashboard', 'error');
  }
}

// ─── Tabla de ventas ───
function renderSalesTable(tableId, sales) {
  const tbody = document.querySelector('#' + tableId + ' tbody');
  if (!sales.length) {
    tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;color:var(--text-muted)">Sin ventas registradas</td></tr>';
    return;
  }
  tbody.innerHTML = sales.map(s => `
    <tr>
      <td><span class="tag tag-green">#${String(s.id).padStart(4, '0')}</span></td>
      <td>${new Date(s.created_at).toLocaleString('es-MX')}</td>
      <td style="color:var(--text-dim)">${s.client_name || '---'}</td>
      <td>${s.items.length} item(s)</td>
      <td style="font-family:var(--mono);color:var(--accent)">$${s.total_amount.toFixed(2)}</td>
      <td><button class="btn btn-ghost btn-sm" onclick="downloadReceipt(${s.id})">PDF</button></td>
    </tr>`).join('');
}

// ─── Graficas ───
function renderLineChart(data) {
  const ctx = document.getElementById('chartIngresos').getContext('2d');
  if (charts.ingresos) charts.ingresos.destroy();
  charts.ingresos = new Chart(ctx, {
    type: 'line',
    data: {
      labels: data.map(d => d.day),
      datasets: [{
        data: data.map(d => d.total),
        borderColor: '#b5000b',
        backgroundColor: 'rgba(181,0,11,0.07)',
        fill: true,
        tension: 0.4,
        pointRadius: 3,
        pointBackgroundColor: '#b5000b'
      }]
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { ticks: { color: '#5e3f3b', font: { size: 10 } }, grid: { color: '#f0eded' } },
        y: { ticks: { color: '#5e3f3b', font: { size: 10 }, callback: v => '$' + v }, grid: { color: '#f0eded' } }
      }
    }
  });
}

function renderBarChart(data) {
  const ctx = document.getElementById('chartTop').getContext('2d');
  if (charts.top) charts.top.destroy();
  charts.top = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: data.map(d => d.name),
      datasets: [{
        label: 'Unidades vendidas',
        data: data.map(d => d.total_qty),
        backgroundColor: ['#b5000b', '#e30613', '#fed400', '#705d00', '#ffb4aa'],
        borderRadius: 6
      }]
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { ticks: { color: '#5e3f3b', font: { size: 10 } }, grid: { display: false } },
        y: { ticks: { color: '#5e3f3b', font: { size: 10 } }, grid: { color: '#f0eded' } }
      }
    }
  });
}

// ─── POS: cargar productos ───
async function loadPosProducts() {
  const res = await fetch('/api/inventory/products');
  allProducts = await res.json();

  const cats = [...new Set(allProducts.map(p => p.category))];
  const catSel = document.getElementById('posCategory');
  catSel.innerHTML = '<option value="">Todas</option>' + cats.map(c => `<option>${c}</option>`).join('');

  filterPosProducts();
}

function productImgHtml(p, size) {
  if (p.image_url) {
    return `<img src="${p.image_url}" alt="${p.name}" style="width:${size}px;height:${size}px;object-fit:cover;border-radius:8px">`;
  }
  return `<div class="prod-img" style="width:${size}px;height:${size}px">${PRODUCT_PLACEHOLDER_SVG}</div>`;
}

function filterPosProducts() {
  const q = document.getElementById('posSearch').value.toLowerCase();
  const cat = document.getElementById('posCategory').value;
  const filtered = allProducts.filter(p =>
    p.name.toLowerCase().includes(q) && (!cat || p.category === cat)
  );
  const grid = document.getElementById('posProductsGrid');
  grid.innerHTML = filtered.map(p => `
    <div class="prod-card ${p.stock === 0 ? 'out-of-stock' : ''}" onclick="addToCart(${p.id})">
      ${productImgHtml(p, 56)}
      <div class="prod-name">${p.name}</div>
      <div class="prod-price">$${p.price.toFixed(2)}</div>
      <div class="prod-stock">${p.stock > 0 ? 'Stock: ' + p.stock : 'Sin stock'}</div>
    </div>`).join('');
}

// ─── Carrito ───
function addToCart(productId) {
  const product = allProducts.find(p => p.id === productId);
  if (!product) return;
  if (cart[productId]) {
    if (cart[productId].qty >= product.stock) { showToast('Stock insuficiente', 'error'); return; }
    cart[productId].qty++;
  } else {
    cart[productId] = { product, qty: 1 };
  }
  renderCart();
}

function changeQty(productId, delta) {
  if (!cart[productId]) return;
  cart[productId].qty += delta;
  if (cart[productId].qty <= 0) delete cart[productId];
  renderCart();
}

function renderCart() {
  const container = document.getElementById('cartItems');
  const items = Object.values(cart);
  if (!items.length) {
    container.innerHTML = '<div style="text-align:center;padding:32px;color:var(--text-muted);font-size:13px">Carrito vacio</div>';
    document.getElementById('cartTotal').innerHTML = '$0.00 <span>total</span>';
    document.getElementById('btnConfirmar').disabled = true;
    return;
  }
  const total = items.reduce((s, i) => s + i.product.price * i.qty, 0);
  container.innerHTML = items.map(i => `
    <div class="cart-item">
      <div class="ci-name">${i.product.name}</div>
      <div class="ci-qty">
        <button class="qty-btn" onclick="changeQty(${i.product.id}, -1)">-</button>
        <span style="font-family:var(--mono);font-size:13px">${i.qty}</span>
        <button class="qty-btn" onclick="changeQty(${i.product.id}, 1)">+</button>
      </div>
      <div class="ci-price">$${(i.product.price * i.qty).toFixed(2)}</div>
    </div>`).join('');
  document.getElementById('cartTotal').innerHTML = `$${total.toFixed(2)} <span>total</span>`;
  document.getElementById('btnConfirmar').disabled = false;
}

function clearCart() {
  cart = {};
  renderCart();
  document.getElementById('clientName').value = '';
}

// ─── Confirmar venta con nombre de cliente ───
async function confirmarVenta() {
  const items = Object.values(cart).map(i => ({ product_id: i.product.id, quantity: i.qty }));
  const clientName = document.getElementById('clientName').value.trim();
  try {
    const res = await fetch('/api/sales/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ items, client_name: clientName })
    });
    const data = await res.json();
    if (!res.ok) { showToast(data.error || 'Error al registrar', 'error'); return; }
    showToast(`Venta #${String(data.id).padStart(4, '0')} registrada - $${data.total_amount.toFixed(2)}`, 'success');
    clearCart();
    loadPosProducts();
  } catch (e) {
    showToast('Error de conexion', 'error');
  }
}

// ─── Historial ───
async function loadHistorial() {
  const res = await fetch('/api/sales/');
  const sales = await res.json();
  const tbody = document.querySelector('#tbl-historial tbody');
  if (!sales.length) {
    tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;color:var(--text-muted)">Sin ventas</td></tr>';
    return;
  }
  tbody.innerHTML = sales.map(s => `
    <tr>
      <td><span class="tag tag-green">#${String(s.id).padStart(4, '0')}</span></td>
      <td>${new Date(s.created_at).toLocaleString('es-MX')}</td>
      <td style="color:var(--text-dim)">${s.client_name || '---'}</td>
      <td style="font-size:12px;color:var(--text-muted)">${s.items.map(i => i.product_name + ' x' + i.quantity).join(', ')}</td>
      <td style="font-family:var(--mono);color:var(--accent)">$${s.total_amount.toFixed(2)}</td>
      <td><button class="btn btn-ghost btn-sm" onclick="downloadReceipt(${s.id})">Recibo</button></td>
    </tr>`).join('');
}

function downloadReceipt(saleId) {
  window.open(`/api/sales/${saleId}/receipt`, '_blank');
}

// ─── Inventario ───
async function loadInventory() {
  const res = await fetch('/api/inventory/products');
  allProducts = await res.json();
  renderInventoryTable(allProducts);
}

function filterInventory() {
  const q = document.getElementById('invSearch').value.toLowerCase();
  renderInventoryTable(allProducts.filter(p => p.name.toLowerCase().includes(q) || p.category.toLowerCase().includes(q)));
}

function renderInventoryTable(products) {
  const tbody = document.querySelector('#tbl-inventario tbody');
  if (!products.length) {
    tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;color:var(--text-muted)">Sin productos</td></tr>';
    return;
  }
  tbody.innerHTML = products.map(p => {
    const stockTag = p.stock === 0 ? 'tag-red' : p.stock <= 10 ? 'tag-yellow' : 'tag-green';
    const stockLabel = p.stock === 0 ? 'Agotado' : p.stock <= 10 ? 'Bajo' : 'OK';
    const imgHtml = p.image_url
      ? `<div class="inv-product-img"><img src="${p.image_url}" alt="${p.name}"></div>`
      : `<div class="inv-product-img">${PRODUCT_PLACEHOLDER_SVG}</div>`;
    return `<tr>
      <td><div class="product-name-cell">${imgHtml}${p.name}</div></td>
      <td><span class="tag" style="background:rgba(99,102,241,.08);color:#818cf8">${p.category}</span></td>
      <td style="font-family:var(--mono)">$${p.price.toFixed(2)}</td>
      <td style="font-family:var(--mono)">${p.stock}</td>
      <td><span class="tag ${stockTag}">${stockLabel}</span></td>
      <td style="display:flex;gap:6px">
        <button class="btn btn-ghost btn-sm" onclick="openModalProduct(${p.id})">Editar</button>
        <button class="btn btn-danger btn-sm" onclick="deleteProduct(${p.id})">Eliminar</button>
      </td>
    </tr>`;
  }).join('');
}

// ─── Modal de producto con imagen ───
function openModalProduct(productId = null) {
  document.getElementById('editProductId').value = productId || '';
  document.getElementById('modalProductTitle').textContent = productId ? 'Editar Producto' : 'Agregar Producto';
  pendingImageFile = null;

  // Reset image preview area
  const preview = document.getElementById('imagePreview');
  const placeholder = document.getElementById('uploadPlaceholder');
  const lbl = document.getElementById('uploadLabel');
  const fileInput = document.getElementById('fImage');
  fileInput.value = '';

  if (productId) {
    const p = allProducts.find(pr => pr.id === productId);
    if (p) {
      document.getElementById('fName').value = p.name;
      document.getElementById('fCategory').value = p.category;
      document.getElementById('fPrice').value = p.price;
      document.getElementById('fStock').value = p.stock;
      if (p.image_url) {
        preview.src = p.image_url;
        preview.style.display = 'block';
        placeholder.style.display = 'none';
        lbl.textContent = 'Haz clic para cambiar la imagen';
      } else {
        preview.style.display = 'none';
        placeholder.style.display = '';
        lbl.textContent = 'Haz clic o arrastra una imagen';
      }
    }
  } else {
    ['fName', 'fCategory', 'fPrice', 'fStock'].forEach(id => document.getElementById(id).value = '');
    preview.style.display = 'none';
    placeholder.style.display = '';
    lbl.textContent = 'Haz clic o arrastra una imagen';
  }
  document.getElementById('modalProduct').classList.add('open');
}

function previewProductImage(input) {
  if (input.files && input.files[0]) {
    pendingImageFile = input.files[0];
    const reader = new FileReader();
    reader.onload = function (e) {
      const preview = document.getElementById('imagePreview');
      if (preview) {
        preview.src = e.target.result;
        preview.style.display = 'block';
      }
      const placeholder = document.getElementById('uploadPlaceholder');
      if (placeholder) placeholder.style.display = 'none';
      const lbl = document.getElementById('uploadLabel');
      if (lbl) lbl.textContent = 'Haz clic para cambiar la imagen';
    };
    reader.readAsDataURL(input.files[0]);
  }
}

function closeModal(id) { document.getElementById(id).classList.remove('open'); }

async function saveProduct() {
  const id = document.getElementById('editProductId').value;
  const data = {
    name: document.getElementById('fName').value,
    category: document.getElementById('fCategory').value,
    price: document.getElementById('fPrice').value,
    stock: document.getElementById('fStock').value
  };
  if (!data.name || !data.price) { showToast('Nombre y precio son requeridos', 'error'); return; }

  const url = id ? `/api/inventory/products/${id}` : '/api/inventory/products';
  const method = id ? 'PUT' : 'POST';
  const res = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) });

  if (res.ok) {
    const product = await res.json();
    if (pendingImageFile) {
      const formData = new FormData();
      formData.append('image', pendingImageFile);
      await fetch(`/api/inventory/products/${product.id}/image`, { method: 'POST', body: formData });
      pendingImageFile = null;
    }
    showToast(id ? 'Producto actualizado' : 'Producto creado', 'success');
    closeModal('modalProduct');
    loadInventory();
    loadPosProducts();
  } else {
    showToast('Error al guardar', 'error');
  }
}

async function deleteProduct(pid) {
  if (!confirm('Eliminar este producto?')) return;
  const res = await fetch(`/api/inventory/products/${pid}`, { method: 'DELETE' });
  if (res.ok) { showToast('Producto eliminado', 'success'); loadInventory(); }
}

// ─── Chatbot con streaming SSE ───
function sendSuggestion(el) {
  document.getElementById('chatInput').value = el.textContent;
  sendChat();
}

async function sendChat() {
  const input = document.getElementById('chatInput');
  const msg = input.value.trim();
  if (!msg) return;

  addMessage(msg, 'user');
  input.value = '';
  document.getElementById('btnSend').disabled = true;

  const typingId = 'typing-' + Date.now();
  addTypingIndicator(typingId);

  try {
    const res = await fetch('/api/chat/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: msg })
    });

    if (!res.ok) {
      removeTypingIndicator(typingId);
      addMessage('Error al conectar con el asistente. Verifica que OPENROUTER_API_KEY esté configurada.', 'ai');
      document.getElementById('btnSend').disabled = false;
      return;
    }

    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let aiMsgId = null;
    let fullText = '';

    removeTypingIndicator(typingId);

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      const text = decoder.decode(value);
      const lines = text.split('\n').filter(l => l.startsWith('data: '));

      for (const line of lines) {
        const data = line.slice(6);
        if (data === '[DONE]') break;
        try {
          const parsed = JSON.parse(data);
          if (parsed.error) {
            removeTypingIndicator(typingId);
            if (!aiMsgId) aiMsgId = addMessage(parsed.error, 'ai');
            else updateMessage(aiMsgId, parsed.error);
            break;
          }
          if (parsed.token) {
            fullText += parsed.token;
            if (!aiMsgId) aiMsgId = addMessage('', 'ai');
            updateMessage(aiMsgId, fullText);
          }
        } catch (e) { }
      }
    }
  } catch (e) {
    removeTypingIndicator(typingId);
    addMessage('Error al conectar con el asistente. Verifica que OPENROUTER_API_KEY este configurada.', 'ai');
  }
  document.getElementById('btnSend').disabled = false;
}

function addMessage(text, role) {
  const id = 'msg-' + Date.now();
  const div = document.createElement('div');
  div.className = `msg msg-${role}`;
  div.id = id;
  if (role === 'ai') {
    div.innerHTML = marked.parse(text || '');
  } else {
    div.textContent = text;
  }
  document.getElementById('chatMessages').appendChild(div);
  div.scrollIntoView({ behavior: 'smooth' });
  return id;
}

function updateMessage(id, text) {
  const el = document.getElementById(id);
  if (!el) return;
  if (el.classList.contains('msg-ai')) {
    el.innerHTML = marked.parse(text || '');
  } else {
    el.textContent = text;
  }
  el.scrollIntoView({ behavior: 'smooth' });
}

function addTypingIndicator(id) {
  const div = document.createElement('div');
  div.className = 'msg msg-ai';
  div.id = id;
  div.innerHTML = '<div class="typing-indicator"><span class="dot"></span><span class="dot"></span><span class="dot"></span></div>';
  document.getElementById('chatMessages').appendChild(div);
  div.scrollIntoView({ behavior: 'smooth' });
}

function removeTypingIndicator(id) {
  const el = document.getElementById(id);
  if (el) el.remove();
}

// ─── Toast ───
function showToast(msg, type = 'success') {
  const container = document.getElementById('toast');
  const div = document.createElement('div');
  div.className = `toast-item toast-${type}`;
  div.textContent = msg;
  container.appendChild(div);
  setTimeout(() => div.remove(), 4000);
}

// ─── Init ───
document.addEventListener('DOMContentLoaded', () => {
  loadDashboard();
});
