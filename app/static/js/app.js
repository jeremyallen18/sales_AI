/**
 * app.js — Logica frontend principal.
 * Maneja navegacion, fetch de datos, POS, inventario y chatbot.
 */

// ─── Configuración Power BI ───
// Pega aquí la URL de incrustación generada en Power BI Service (Publicar en web)
const POWERBI_EMBED_URL = 'https://app.powerbi.com/reportEmbed?reportId=bed502f6-efba-40bf-95e2-5525ee678cae&autoAuth=true&ctid=317936f4-343d-40e8-8b27-08d0f63c2c92&filterPaneEnabled=false';

// ─── Estado global ───
let allProducts = [];
let allSales = [];
let cart = {};
let combosInCart = {};   // { [comboId]: { combo, qty } }
let _allCombos = [];
let charts = {};
let pendingImageFile = null;  // Archivo de imagen pendiente para subir
let activeBranchId = null;

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
    historial: 'Historial de Ventas', inventario: 'Inventario', chatbot: 'Asistente IA',
    resenas: 'Reseñas', ofertas: 'Gestión de Ofertas', combos: 'Combos'
  };
  const titleEl = document.getElementById('pageTitle');
  if (titleEl) titleEl.textContent = titles[name] || name;

  if (name === 'dashboard') loadDashboard();
  if (name === 'ventas') loadPosProducts();
  if (name === 'historial') loadHistorial();
  if (name === 'inventario') loadInventory();
  if (name === 'sucursales') { loadBranches(); loadBranchComparison(); }
  if (name === 'resenas') loadReviews();
  if (name === 'ofertas') loadOffers();
  if (name === 'combos') loadCombos();
}

// ─── Dashboard ───
async function loadDashboard() {
  const tbodyRecientes = document.querySelector('#tbl-recientes tbody');
  if (tbodyRecientes) tbodyRecientes.innerHTML = UI.skeleton('tableRow', 5);
  try {
    const qBranch = activeBranchId ? `?branch_id=${activeBranchId}` : '';
    const [summaryRes, salesRes, invRes] = await Promise.all([
      fetch(`/api/analytics/summary${qBranch}`),
      fetch(`/api/sales/${qBranch}`),
      fetch(activeBranchId ? `/api/branches/${activeBranchId}/inventory` : '/api/inventory/aggregated')
    ]);
    const summary = await summaryRes.json();
    const sales = await salesRes.json();
    const rawInv = await invRes.json();
    const products = rawInv.map(p => ({ ...p, id: p.id ?? p.product_id, stock: p.stock ?? 0 }));
    allSales = sales;

    UI.animateCounter(document.getElementById('s-ingresos'), summary.ingresos_totales, { prefix: '$', decimals: 2 });
    UI.animateCounter(document.getElementById('s-ventas'), sales.length);
    UI.animateCounter(document.getElementById('s-productos'), products.length);

    const lowStockCount = Array.isArray(summary.productos_bajo_stock) ? summary.productos_bajo_stock.length : 0;
    UI.animateCounter(document.getElementById('s-bajo'), lowStockCount);
    const badge = document.getElementById('lowStockBadge');
    badge.style.display = lowStockCount > 0 ? 'inline' : 'none';

    renderSalesTable('tbl-recientes', sales.slice(0, 8));
    initPowerBIEmbed();
  } catch (e) {
    showToast('Error cargando dashboard', 'error');
  }
}

function initPowerBIEmbed() {
  const frame = document.getElementById('powerbi-frame');
  const placeholder = document.getElementById('powerbi-placeholder');
  const openLink = document.getElementById('powerbi-open-link');
  if (!frame) return;
  if (POWERBI_EMBED_URL) {
    if (!frame.src || frame.src !== POWERBI_EMBED_URL) frame.src = POWERBI_EMBED_URL;
    frame.style.display = 'block';
    if (placeholder) placeholder.style.display = 'none';
    if (openLink) { openLink.href = POWERBI_EMBED_URL; openLink.style.removeProperty('display'); }
  } else {
    frame.style.display = 'none';
    if (placeholder) placeholder.style.display = '';
  }
}

// ─── Tabla de ventas ───
function renderSalesTable(tableId, sales) {
  const tbody = document.querySelector('#' + tableId + ' tbody');
  if (!sales.length) {
    tbody.innerHTML = `<tr><td colspan="6">${UI.emptyState({ icon: 'receipt_long', title: 'Sin ventas registradas', hint: 'Las ventas que registres aparecerán aquí.' })}</td></tr>`;
    return;
  }
  tbody.innerHTML = sales.map((s, idx) => `
    <tr class="anim-fade-up" style="--stagger-i:${idx};cursor:pointer" onclick="openSaleDetail(${s.id})" title="Ver detalle">
      <td><span class="tag tag-green">#${String(s.id).padStart(4, '0')}</span></td>
      <td>${new Date(s.created_at).toLocaleString('es-MX')}</td>
      <td style="color:var(--color-on-surface-variant)">${s.client_name || '---'}</td>
      <td>${s.items.length} item(s)</td>
      <td style="font-weight:700;color:var(--color-primary);font-variant-numeric:tabular-nums">$${s.total_amount.toFixed(2)}</td>
      <td><button class="btn btn-ghost btn-sm" onclick="event.stopPropagation();downloadReceipt(${s.id})">PDF</button></td>
    </tr>`).join('');
}

// ─── Detalle de venta (modal) ───
const PAYMENT_LABELS = {
  efectivo: { icon: 'local_atm', label: 'Efectivo' },
  tarjeta: { icon: 'credit_card', label: 'Tarjeta' },
  transferencia: { icon: 'contactless', label: 'Transferencia' }
};

function openSaleDetail(saleId) {
  const s = allSales.find(v => v.id === saleId);
  if (!s) return;

  document.getElementById('saleDetailTitle').textContent = `Venta #${String(s.id).padStart(4, '0')}`;
  document.getElementById('saleDetailMeta').textContent =
    `${new Date(s.created_at).toLocaleString('es-MX')} · ${s.client_name || 'Cliente sin nombre'}`;

  const pay = PAYMENT_LABELS[s.payment_method] || { icon: 'payments', label: s.payment_method || 'Efectivo' };
  const subtotal = s.subtotal_amount || s.total_amount;
  const discount = s.discount_amount || 0;
  const tax = s.tax_amount || 0;

  const itemsHtml = s.items.map(i => `
    <div class="sale-item-row">
      <span class="sale-item-qty">×${i.quantity}</span>
      <span style="flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:var(--color-on-surface)">${i.product_name}</span>
      <span style="color:var(--color-on-surface-variant);font-variant-numeric:tabular-nums">$${i.price.toFixed(2)} c/u</span>
      <span style="font-weight:700;color:var(--color-on-surface);font-variant-numeric:tabular-nums;min-width:64px;text-align:right">$${(i.subtotal ?? i.price * i.quantity).toFixed(2)}</span>
    </div>`).join('');

  const row = (label, value, opts = {}) => `
    <div style="display:flex;justify-content:space-between;font-size:${opts.big ? '16px' : '12px'};font-weight:${opts.big ? '700' : '400'};color:${opts.color || 'var(--color-on-surface-variant)'}">
      <span>${label}</span><span style="font-variant-numeric:tabular-nums">${value}</span>
    </div>`;

  document.getElementById('saleDetailBody').innerHTML = `
    <div class="flex items-center gap-2 flex-wrap">
      <span class="tag tag-yellow"><span class="material-symbols-outlined align-middle mr-1" style="font-size:14px;">${pay.icon}</span>${pay.label}</span>
      <span class="tag ${s.payment_status === 'aprobado' ? 'tag-green' : 'tag-red'}">${s.payment_status || 'aprobado'}</span>
    </div>
    <div class="bg-surface-container-low rounded-xl px-4 py-1" style="background:var(--color-surface-container-low)">
      ${itemsHtml}
    </div>
    <div class="space-y-1.5">
      ${row('Subtotal', '$' + subtotal.toFixed(2))}
      ${discount > 0 ? row('Descuento', '-$' + discount.toFixed(2), { color: '#2E7D32' }) : ''}
      ${row('Total', '$' + s.total_amount.toFixed(2), { big: true, color: 'var(--color-primary)' })}
      ${row('IVA incluido (16%)', '$' + tax.toFixed(2))}
    </div>
    <button class="cta-ia w-full text-on-primary font-semibold text-sm py-2.5 rounded-xl flex items-center justify-center gap-2" onclick="downloadReceipt(${s.id})">
      <span class="material-symbols-outlined" style="font-size:18px;">receipt_long</span>
      Ver recibo
    </button>`;

  document.getElementById('modalSale').classList.add('open');
}


// ─── POS: cargar productos ───
async function loadPosProducts() {
  const grid = document.getElementById('posProductsGrid');
  if (grid && !allProducts.length) grid.innerHTML = UI.skeleton('card', 8);
  const url = activeBranchId ? `/api/branches/${activeBranchId}/inventory` : '/api/inventory/aggregated';
  const res = await fetch(url);
  const raw = await res.json();
  allProducts = raw.map(p => ({
    id: p.product_id ?? p.id,
    name: p.name,
    price: p.effective_price ?? p.price,
    discount_pct: p.effective_discount ?? p.discount_pct ?? 0,
    stock: p.stock ?? 0,
    category: p.category ?? 'General',
    image_url: p.image_url ?? null,
  }));

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
  if (!filtered.length) {
    grid.innerHTML = `<div class="col-span-full">${UI.emptyState({ icon: 'search_off', title: 'Sin resultados', hint: 'Prueba con otra búsqueda o categoría.' })}</div>`;
    return;
  }
  grid.innerHTML = filtered.map((p, idx) => {
    const hasDiscount = (p.discount_pct || 0) > 0;
    const finalPrice = p.price * (1 - (p.discount_pct || 0) / 100);
    const priceHtml = hasDiscount
      ? `<div class="prod-price">$${finalPrice.toFixed(2)} <span style="font-size:11px;font-weight:500;color:var(--color-on-surface-variant);text-decoration:line-through">$${p.price.toFixed(2)}</span></div>`
      : `<div class="prod-price">$${p.price.toFixed(2)}</div>`;
    return `
    <div class="prod-card anim-fade-up ${p.stock === 0 ? 'out-of-stock' : ''}" style="--stagger-i:${Math.min(idx, 12)}" onclick="addToCart(${p.id})">
      ${hasDiscount ? `<span class="prod-discount">-${p.discount_pct}%</span>` : ''}
      ${productImgHtml(p, 56)}
      <div class="prod-name">${p.name}</div>
      ${priceHtml}
      <div class="prod-stock">${p.stock > 0 ? 'Stock: ' + p.stock : 'Sin stock'}</div>
    </div>`;
  }).join('');
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
  const productItems = Object.values(cart);
  const comboEntries  = Object.values(combosInCart);
  const hasItems = productItems.length > 0 || comboEntries.length > 0;

  if (!hasItems) {
    container.innerHTML = '<div style="text-align:center;padding:32px;color:var(--color-on-surface-variant);font-size:13px">Carrito vacío</div>';
    document.getElementById('cartTotal').innerHTML = '$0.00 <span>total</span>';
    document.getElementById('btnConfirmar').disabled = true;
    return;
  }

  // Totales de productos normales
  const subtotalBruto = productItems.reduce((s, i) => s + i.product.price * i.qty, 0);
  const subtotalNeto  = productItems.reduce((s, i) => {
    const dp = i.product.price * (1 - (i.product.discount_pct || 0) / 100);
    return s + dp * i.qty;
  }, 0);
  // Totales de combos
  const comboTotal = comboEntries.reduce((s, { combo, qty }) => s + combo.price * qty, 0);

  const descuento = subtotalBruto - subtotalNeto;
  const grandTotal = subtotalNeto + comboTotal;
  const iva = grandTotal * (0.16 / 1.16);

  const productHtml = productItems.map(i => {
    const dp = i.product.price * (1 - (i.product.discount_pct || 0) / 100);
    return `
    <div class="cart-item">
      <div class="ci-name">${i.product.name}${i.product.discount_pct > 0 ? ` <span style="font-size:11px;color:#2E7D32;font-weight:700">-${i.product.discount_pct}%</span>` : ''}</div>
      <div class="ci-qty">
        <button class="qty-btn" onclick="changeQty(${i.product.id}, -1)">-</button>
        <span style="font-variant-numeric:tabular-nums;font-size:13px">${i.qty}</span>
        <button class="qty-btn" onclick="changeQty(${i.product.id}, 1)">+</button>
      </div>
      <div class="ci-price">$${(dp * i.qty).toFixed(2)}</div>
    </div>`;
  }).join('');

  const comboHtml = comboEntries.map(({ combo, qty }) => `
    <div class="cart-item" style="border-left:3px solid var(--color-tertiary,#9c27b0);background:var(--color-tertiary-container,#f3e5f5)20">
      <div class="ci-name" style="color:var(--color-on-surface)">
        <span style="font-size:10px;font-weight:700;background:#9c27b0;color:#fff;padding:1px 6px;border-radius:8px;margin-right:4px">COMBO</span>
        ${combo.name}
        <div style="font-size:10px;color:var(--color-on-surface-variant);margin-top:2px">${combo.items.map(ci => `${ci.product_name} x${ci.quantity}`).join(' + ')}</div>
      </div>
      <div class="ci-qty">
        <button class="qty-btn" onclick="changeComboQty(${combo.id}, -1)">-</button>
        <span style="font-variant-numeric:tabular-nums;font-size:13px">${qty}</span>
        <button class="qty-btn" onclick="changeComboQty(${combo.id}, 1)">+</button>
      </div>
      <div class="ci-price">$${(combo.price * qty).toFixed(2)}</div>
    </div>`).join('');

  container.innerHTML = productHtml + comboHtml;

  const discountRow = descuento > 0
    ? `<div style="display:flex;justify-content:space-between;font-size:12px;color:#2E7D32;font-weight:600"><span>Descuento</span><span>-$${descuento.toFixed(2)}</span></div>`
    : '';
  document.getElementById('cartTotal').innerHTML = `
    <div style="font-size:12px;color:var(--color-on-surface-variant);margin-bottom:4px;display:flex;justify-content:space-between"><span>Subtotal</span><span>$${(subtotalBruto + comboTotal).toFixed(2)}</span></div>
    ${discountRow}
    <div style="display:flex;justify-content:space-between;font-weight:700;font-size:16px;margin:4px 0"><span>A pagar</span><span style="color:var(--color-primary)">$${grandTotal.toFixed(2)}</span></div>
    <div style="font-size:11px;color:var(--color-on-surface-variant);display:flex;justify-content:space-between"><span>IVA incluido (16%)</span><span>$${iva.toFixed(2)}</span></div>`;
  document.getElementById('btnConfirmar').disabled = false;
}

function changeComboQty(comboId, delta) {
  if (!combosInCart[comboId]) return;
  combosInCart[comboId].qty += delta;
  if (combosInCart[comboId].qty <= 0) delete combosInCart[comboId];
  renderCart();
}

function clearCart() {
  cart = {};
  combosInCart = {};
  renderCart();
  document.getElementById('clientName').value = '';
}

// ─── Confirmar venta con nombre de cliente ───
async function confirmarVenta() {
  // Productos normales
  const productItems = Object.values(cart).map(i => ({ product_id: i.product.id, quantity: i.qty }));

  // Combos → expandir con price_override proporcional al precio natural de cada producto
  const comboItemsExpanded = Object.values(combosInCart).flatMap(({ combo, qty }) => {
    const naturalTotal = combo.items.reduce((s, ci) => s + (ci.product_price || 0) * ci.quantity, 0);
    return combo.items.map(ci => ({
      product_id: ci.product_id,
      quantity: ci.quantity * qty,
      ...(naturalTotal > 0 && {
        price_override: +((combo.price * (ci.product_price * ci.quantity) / naturalTotal) / ci.quantity).toFixed(4),
      }),
    }));
  });

  const items = [...productItems, ...comboItemsExpanded];
  const clientName = document.getElementById('clientName').value.trim();
  try {
    const res = await fetch('/api/sales/', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ items, client_name: clientName, ...(activeBranchId && { branch_id: activeBranchId }) })
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
  const tbody = document.querySelector('#tbl-historial tbody');
  if (tbody) tbody.innerHTML = UI.skeleton('tableRow', 6);
  const qBranch = activeBranchId ? `?branch_id=${activeBranchId}` : '';
  const res = await fetch(`/api/sales/${qBranch}`);
  const sales = await res.json();
  allSales = sales;
  if (!sales.length) {
    tbody.innerHTML = `<tr><td colspan="7">${UI.emptyState({ icon: 'history', title: 'Sin ventas', hint: 'Aún no hay transacciones registradas.' })}</td></tr>`;
    return;
  }
  tbody.innerHTML = sales.map((s, idx) => `
    <tr class="anim-fade-up" style="--stagger-i:${Math.min(idx, 10)};cursor:pointer" onclick="openSaleDetail(${s.id})" title="Ver detalle">
      <td><span class="tag tag-green">#${String(s.id).padStart(4, '0')}</span></td>
      <td>${new Date(s.created_at).toLocaleString('es-MX')}</td>
      <td style="color:var(--color-on-surface-variant)">
        ${s.branch_name
          ? `<span class="inline-flex items-center gap-1"><span class="material-symbols-outlined" style="font-size:14px;color:var(--color-primary)">store</span>${s.branch_name}</span>`
          : '<span style="opacity:.45">—</span>'}
      </td>
      <td style="color:var(--color-on-surface-variant)">${s.client_name || '---'}</td>
      <td style="font-size:12px;color:var(--color-on-surface-variant)">${s.items.map(i => i.product_name + ' x' + i.quantity).join(', ')}</td>
      <td style="font-weight:700;color:var(--color-primary);font-variant-numeric:tabular-nums">$${s.total_amount.toFixed(2)}</td>
      <td><button class="btn btn-ghost btn-sm" onclick="event.stopPropagation();downloadReceipt(${s.id})">Recibo</button></td>
    </tr>`).join('');
}

function downloadReceipt(saleId) {
  window.open(`/api/sales/${saleId}/receipt`, '_blank');
}

// ─── Exportar historial a CSV ───
function downloadCorte(tipo) {
  const isSemanal = tipo === 'semanal';
  const offset = isSemanal
    ? document.getElementById('corteWeekOffset').value
    : document.getElementById('corteMonthOffset').value;
  const param = isSemanal ? `semanas_atras=${offset}` : `meses_atras=${offset}`;
  const branch = activeBranchId ? `&branch_id=${activeBranchId}` : '';
  const url = `/api/cortes/${tipo}/pdf?${param}${branch}`;
  const a = document.createElement('a');
  a.href = url;
  a.download = '';
  document.body.appendChild(a);
  a.click();
  a.remove();
  showToast(`Generando corte ${isSemanal ? 'semanal' : 'mensual'}…`, 'info');
}

async function exportSalesCSV() {
  let sales = allSales;
  if (!sales.length) {
    try {
      sales = await (await fetch('/api/sales/')).json();
      allSales = sales;
    } catch (e) {
      showToast('Error al obtener las ventas', 'error');
      return;
    }
  }
  if (!sales.length) { showToast('No hay ventas para exportar', 'warn'); return; }

  const csvCell = v => {
    const s = String(v ?? '');
    return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
  };
  const header = ['ID', 'Fecha', 'Tienda', 'Cliente', 'Método de pago', 'Estado', 'Subtotal', 'Descuento', 'IVA', 'Total', 'Productos'];
  const rows = sales.map(s => [
    s.id,
    new Date(s.created_at).toLocaleString('es-MX'),
    s.branch_name || '',
    s.client_name || '',
    s.payment_method || 'efectivo',
    s.payment_status || 'aprobado',
    (s.subtotal_amount || s.total_amount).toFixed(2),
    (s.discount_amount || 0).toFixed(2),
    (s.tax_amount || 0).toFixed(2),
    s.total_amount.toFixed(2),
    s.items.map(i => `${i.product_name} x${i.quantity}`).join('; ')
  ]);
  // BOM para que Excel detecte UTF-8 (acentos)
  const csv = '\uFEFF' + [header, ...rows].map(r => r.map(csvCell).join(',')).join('\r\n');

  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `ventas_${new Date().toISOString().slice(0, 10)}.csv`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(a.href);
  showToast(`${sales.length} ventas exportadas`, 'success');
}

// ─── Inventario ───
async function loadInventory() {
  const tbody = document.querySelector('#tbl-inventario tbody');
  if (tbody && !allProducts.length) tbody.innerHTML = UI.skeleton('tableRow', 6);
  const url = activeBranchId ? `/api/branches/${activeBranchId}/inventory` : '/api/inventory/aggregated';
  const res = await fetch(url);
  const raw = await res.json();
  allProducts = raw.map(p => ({
    id: p.product_id ?? p.id,
    name: p.name,
    price: p.effective_price ?? p.price,
    discount_pct: p.effective_discount ?? p.discount_pct ?? 0,
    stock: p.stock ?? 0,
    category: p.category ?? 'General',
    image_url: p.image_url ?? null,
  }));
  renderInventoryTable(allProducts);
}

function filterInventory() {
  const q = document.getElementById('invSearch').value.toLowerCase();
  renderInventoryTable(allProducts.filter(p => p.name.toLowerCase().includes(q) || p.category.toLowerCase().includes(q)));
}

function renderInventoryTable(products) {
  const tbody = document.querySelector('#tbl-inventario tbody');
  if (!products.length) {
    tbody.innerHTML = `<tr><td colspan="6">${UI.emptyState({ icon: 'inventory_2', title: 'Sin productos', hint: 'Agrega tu primer producto con el botón "Agregar Producto".' })}</td></tr>`;
    return;
  }
  tbody.innerHTML = products.map((p, idx) => {
    const stockTag = p.stock === 0 ? 'tag-red' : p.stock <= 10 ? 'tag-yellow' : 'tag-green';
    const stockLabel = p.stock === 0 ? 'Agotado' : p.stock <= 10 ? 'Bajo' : 'OK';
    const imgHtml = p.image_url
      ? `<div class="inv-product-img"><img src="${p.image_url}" alt="${p.name}"></div>`
      : `<div class="inv-product-img">${PRODUCT_PLACEHOLDER_SVG}</div>`;
    return `<tr class="anim-fade-up" style="--stagger-i:${Math.min(idx, 10)}">
      <td><div class="product-name-cell">${imgHtml}${p.name}</div></td>
      <td><span class="tag tag-neutral">${p.category}</span></td>
      <td style="font-variant-numeric:tabular-nums">$${p.price.toFixed(2)}</td>
      <td style="font-variant-numeric:tabular-nums">${p.stock}</td>
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
      document.getElementById('fDiscount').value = p.discount_pct || 0;
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
    ['fName', 'fCategory', 'fPrice', 'fStock', 'fDiscount'].forEach(id => document.getElementById(id).value = '');
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
    stock: document.getElementById('fStock').value,
    discount_pct: parseFloat(document.getElementById('fDiscount').value) || 0
  };
  if (!data.name || !data.price) { showToast('Nombre y precio son requeridos', 'error'); return; }

  const url = id ? `/api/inventory/products/${id}` : '/api/inventory/products';
  const method = id ? 'PUT' : 'POST';
  const res = await fetch(url, { method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) });
  if (!res.ok) { showToast('Error al guardar', 'error'); return; }

  const product = await res.json();

  // Si hay sucursal activa, sincronizar el stock en esa sucursal también
  if (id && activeBranchId) {
    await fetch(`/api/branches/${activeBranchId}/inventory/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ stock: parseInt(data.stock) || 0 }),
    });
  }

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
  const btnSend = document.getElementById('btnSend');
  btnSend.disabled = true;
  btnSend.classList.add('is-sending');
  setTimeout(() => btnSend.classList.remove('is-sending'), 500);

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
            if (!aiMsgId) {
              aiMsgId = addMessage('', 'ai');
              document.getElementById(aiMsgId).classList.add('msg-streaming');
            }
            updateMessage(aiMsgId, fullText);
          }
        } catch (e) { }
      }
    }
    if (aiMsgId) {
      const aiEl = document.getElementById(aiMsgId);
      if (aiEl) aiEl.classList.remove('msg-streaming');
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
  if (!el) return;
  el.classList.add('msg-leaving');
  setTimeout(() => el.remove(), 160);
}

// ─── Toast ───
function showToast(msg, type = 'success') {
  UI.toast(msg, type);
}

// ══════════════════════════════════════════════════════════════════════════════
// ─── SUCURSALES ───────────────────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════

let _branchCompChart = null;
let _branchMap = null;
let _branchMarker = null;

// ── Mapa Leaflet en modal de sucursal ─────────────────────────────────────────

function initBranchMap(lat, lng) {
  const defLat = lat || 19.4326;
  const defLng = lng || -99.1332;

  if (_branchMap) {
    _branchMap.remove();
    _branchMap = null;
    _branchMarker = null;
  }

  _branchMap = L.map('branchMap').setView([defLat, defLng], lat ? 15 : 5);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© OpenStreetMap',
    maxZoom: 19,
  }).addTo(_branchMap);

  if (lat && lng) {
    _branchMarker = L.marker([lat, lng], { draggable: true }).addTo(_branchMap);
    _branchMarker.on('dragend', e => {
      const p = e.target.getLatLng();
      document.getElementById('bLat').value = p.lat.toFixed(6);
      document.getElementById('bLng').value = p.lng.toFixed(6);
    });
  }

  _branchMap.on('click', e => {
    const { lat, lng } = e.latlng;
    document.getElementById('bLat').value = lat.toFixed(6);
    document.getElementById('bLng').value = lng.toFixed(6);
    if (_branchMarker) {
      _branchMarker.setLatLng([lat, lng]);
    } else {
      _branchMarker = L.marker([lat, lng], { draggable: true }).addTo(_branchMap);
      _branchMarker.on('dragend', ev => {
        const p = ev.target.getLatLng();
        document.getElementById('bLat').value = p.lat.toFixed(6);
        document.getElementById('bLng').value = p.lng.toFixed(6);
      });
    }
  });

  setTimeout(() => _branchMap && _branchMap.invalidateSize(), 200);
}

function syncMapFromInputs() {
  const lat = parseFloat(document.getElementById('bLat').value);
  const lng = parseFloat(document.getElementById('bLng').value);
  if (!_branchMap || isNaN(lat) || isNaN(lng)) return;
  _branchMap.setView([lat, lng], 15);
  if (_branchMarker) {
    _branchMarker.setLatLng([lat, lng]);
  } else {
    _branchMarker = L.marker([lat, lng], { draggable: true }).addTo(_branchMap);
  }
}

// ─── Selector de sucursal activa ───
async function loadBranchSelector() {
  const sel = document.getElementById('branchSelector');
  if (!sel) return;
  try {
    const res = await fetch('/api/branches/?active_only=false');
    const branches = await res.json();
    if (!Array.isArray(branches) || !branches.length) return;
    sel.innerHTML = '<option value="">Todas las sucursales</option>' +
      branches.map(b => `<option value="${b.id}">${b.name}</option>`).join('');
    sel.style.display = '';
  } catch (_) {}
}

function setActiveBranch(value) {
  activeBranchId = value ? parseInt(value) : null;
  const active = document.querySelector('.panel.active');
  if (!active) return;
  const panelId = active.id.replace('panel-', '');
  if (panelId === 'dashboard') loadDashboard();
  else if (panelId === 'ventas') loadPosProducts();
  else if (panelId === 'historial') loadHistorial();
  else if (panelId === 'inventario') loadInventory();
  else if (panelId === 'ofertas') loadOffers();
  else if (panelId === 'combos') loadCombos();
}

// ── CRUD de sucursales ────────────────────────────────────────────────────────

async function loadBranches() {
  const tbody = document.getElementById('branches-tbody');
  if (!tbody) return;
  tbody.innerHTML = '<tr><td colspan="6" class="px-5 py-8 text-center text-on-surface-variant text-sm">Cargando...</td></tr>';
  try {
    const res = await fetch('/api/branches/?active_only=false');
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Error al cargar sucursales');
    if (!data.length) {
      tbody.innerHTML = '<tr><td colspan="6" class="px-5 py-8 text-center text-on-surface-variant text-sm">Sin sucursales registradas.</td></tr>';
      return;
    }
    tbody.innerHTML = data.map(b => `
      <tr class="hover:bg-surface-container-low transition-colors">
        <td class="px-5 py-3 font-medium text-on-surface">${b.name}</td>
        <td class="px-5 py-3 text-on-surface-variant text-xs">${b.city || '—'}${b.state ? ', ' + b.state : ''}</td>
        <td class="px-5 py-3 text-on-surface-variant text-xs">${b.opening_time || '—'} – ${b.closing_time || '—'}</td>
        <td class="px-5 py-3">
          <span class="inline-flex items-center gap-1 text-xs font-medium px-2 py-0.5 rounded-full ${b.is_active ? 'bg-green-100 text-green-700' : 'bg-surface-container text-on-surface-variant'}">
            ${b.is_active ? 'Activa' : 'Inactiva'}
          </span>
        </td>
        <td class="px-5 py-3">
          <div class="flex items-center gap-1">
            <button onclick="openBranchStock(${b.id}, '${b.name.replace(/'/g, '&#39;')}')" class="p-1.5 rounded-lg hover:bg-blue-50 text-on-surface-variant hover:text-blue-600 transition-colors" title="Inventario">
              <span class="material-symbols-outlined text-base">inventory_2</span>
            </button>
            <button onclick="openBranchHistory(${b.id}, '${b.name.replace(/'/g, '&#39;')}')" class="p-1.5 rounded-lg hover:bg-amber-50 text-on-surface-variant hover:text-amber-600 transition-colors" title="Historial">
              <span class="material-symbols-outlined text-base">history</span>
            </button>
            <button onclick="openBranchModal(${b.id})" class="p-1.5 rounded-lg hover:bg-surface-container text-on-surface-variant hover:text-primary transition-colors" title="Editar">
              <span class="material-symbols-outlined text-base">edit</span>
            </button>
            <button onclick="deleteBranch(${b.id}, '${b.name.replace(/'/g, '&#39;')}')" class="p-1.5 rounded-lg hover:bg-red-50 text-on-surface-variant hover:text-red-600 transition-colors" title="Eliminar">
              <span class="material-symbols-outlined text-base">delete</span>
            </button>
          </div>
        </td>
      </tr>`).join('');
  } catch (e) {
    tbody.innerHTML = `<tr><td colspan="6" class="px-5 py-8 text-center text-red-500 text-sm">${e.message}</td></tr>`;
  }
}

async function openBranchModal(id = null) {
  document.getElementById('bId').value = '';
  document.getElementById('bName').value = '';
  document.getElementById('bCity').value = '';
  document.getElementById('bState').value = '';
  document.getElementById('bAddress').value = '';
  document.getElementById('bOpening').value = '08:00';
  document.getElementById('bClosing').value = '22:00';
  document.getElementById('bLat').value = '';
  document.getElementById('bLng').value = '';
  document.getElementById('bPhone').value = '';
  document.getElementById('branchModalTitle').textContent = id ? 'Editar Sucursal' : 'Nueva Sucursal';

  if (id) {
    try {
      const res = await fetch(`/api/branches/${id}`);
      const b = await res.json();
      document.getElementById('bId').value = b.id;
      document.getElementById('bName').value = b.name || '';
      document.getElementById('bCity').value = b.city || '';
      document.getElementById('bState').value = b.state || '';
      document.getElementById('bAddress').value = b.address || '';
      document.getElementById('bOpening').value = b.opening_time || '08:00';
      document.getElementById('bClosing').value = b.closing_time || '22:00';
      document.getElementById('bLat').value = b.latitude ?? '';
      document.getElementById('bLng').value = b.longitude ?? '';
      document.getElementById('bPhone').value = b.phone || '';
    } catch (e) { showToast('Error al cargar sucursal', 'error'); return; }
  }

  const modal = document.getElementById('modalBranch');
  modal.style.display = 'flex';
  // Inicializar mapa después de que el modal sea visible
  setTimeout(() => {
    const lat = parseFloat(document.getElementById('bLat').value) || null;
    const lng = parseFloat(document.getElementById('bLng').value) || null;
    initBranchMap(lat, lng);
  }, 150);
}

function closeBranchModal() {
  document.getElementById('modalBranch').style.display = 'none';
}

async function saveBranch() {
  const id = document.getElementById('bId').value;
  const name = document.getElementById('bName').value.trim();
  if (!name) { showToast('El nombre es requerido', 'error'); return; }

  const payload = {
    name,
    city: document.getElementById('bCity').value.trim(),
    state: document.getElementById('bState').value.trim(),
    address: document.getElementById('bAddress').value.trim(),
    opening_time: document.getElementById('bOpening').value.trim(),
    closing_time: document.getElementById('bClosing').value.trim(),
    phone: document.getElementById('bPhone').value.trim(),
    latitude: parseFloat(document.getElementById('bLat').value) || null,
    longitude: parseFloat(document.getElementById('bLng').value) || null,
    is_active: true,
  };

  const url = id ? `/api/branches/${id}` : '/api/branches/';
  const method = id ? 'PUT' : 'POST';

  try {
    const res = await fetch(url, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Error al guardar');
    showToast(id ? 'Sucursal actualizada' : 'Sucursal creada');
    closeBranchModal();
    loadBranches();
    loadBranchComparison();
  } catch (e) { showToast(e.message, 'error'); }
}

async function deleteBranch(id, name) {
  if (!confirm(`¿Eliminar la sucursal "${name}"? Esta acción no se puede deshacer.`)) return;
  try {
    const res = await fetch(`/api/branches/${id}`, { method: 'DELETE' });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Error al eliminar');
    showToast('Sucursal eliminada');
    loadBranches();
    loadBranchComparison();
  } catch (e) { showToast(e.message, 'error'); }
}

async function loadBranchComparison() {
  const canvas = document.getElementById('branchComparisonChart');
  if (!canvas) return;
  try {
    const res = await fetch('/api/analytics/branch-comparison');
    if (!res.ok) return;
    const data = await res.json();
    const labels = data.map(d => d.branch_name || `Sucursal ${d.branch_id}`);
    const values = data.map(d => d.total_revenue ?? 0);

    if (_branchCompChart) { _branchCompChart.destroy(); _branchCompChart = null; }
    _branchCompChart = new Chart(canvas, {
      type: 'bar',
      data: {
        labels,
        datasets: [{
          label: 'Ingresos ($)',
          data: values,
          backgroundColor: 'rgba(237,28,36,0.75)',
          borderRadius: 6,
          borderSkipped: false,
        }],
      },
      options: {
        responsive: true,
        plugins: { legend: { display: false } },
        scales: {
          y: { beginAtZero: true, ticks: { callback: v => '$' + v.toLocaleString() } },
        },
      },
    });
  } catch (_) { /* silencioso si no hay datos */ }
}

// ── Inventario por sucursal ───────────────────────────────────────────────────

async function openBranchStock(branchId, branchName) {
  document.getElementById('branchStockTitle').textContent = `Inventario — ${branchName}`;
  const body = document.getElementById('branchStockBody');
  body.innerHTML = '<div class="py-10 text-center text-on-surface-variant text-sm">Cargando...</div>';
  document.getElementById('modalBranchStock').style.display = 'flex';

  try {
    const res = await fetch(`/api/branches/${branchId}/inventory`);
    const items = await res.json();
    if (!res.ok) throw new Error(items.error || 'Error');
    if (!items.length) {
      body.innerHTML = '<div class="py-8 text-center text-on-surface-variant text-sm">Sin productos en esta sucursal.</div>';
      return;
    }
    body.innerHTML = `
      <table class="w-full text-sm">
        <thead class="bg-surface-container-low">
          <tr>
            <th class="text-left px-4 py-2.5 text-xs font-semibold text-on-surface-variant">Producto</th>
            <th class="text-right px-4 py-2.5 text-xs font-semibold text-on-surface-variant">Stock</th>
            <th class="text-right px-4 py-2.5 text-xs font-semibold text-on-surface-variant">Precio</th>
            <th class="text-right px-4 py-2.5 text-xs font-semibold text-on-surface-variant">Descuento</th>
            <th class="text-left px-4 py-2.5 text-xs font-semibold text-on-surface-variant">Oferta</th>
            <th class="px-4 py-2.5"></th>
          </tr>
        </thead>
        <tbody class="divide-y divide-surface-container-highest">
          ${items.map(item => `
            <tr class="hover:bg-surface-container-low transition-colors" id="stock-row-${item.product_id ?? item.id}">
              <td class="px-4 py-3 font-medium text-on-surface">${item.name || item.product_name || '—'}</td>
              <td class="px-4 py-3 text-right">
                <span class="font-semibold ${(item.stock ?? 0) === 0 ? 'text-error' : 'text-on-surface'}">${item.stock ?? 0}</span>
              </td>
              <td class="px-4 py-3 text-right text-on-surface-variant">$${(item.effective_price ?? item.price ?? 0).toFixed(2)}</td>
              <td class="px-4 py-3 text-right text-on-surface-variant">${item.effective_discount ?? item.discount_pct ?? 0}%</td>
              <td class="px-4 py-3">
                ${item.offer_badge ? `<span class="inline-block text-xs font-bold px-2 py-0.5 rounded-full bg-amber-100 text-amber-800">${item.offer_badge}</span>` : '<span class="text-on-surface-variant text-xs">—</span>'}
              </td>
              <td class="px-4 py-3 text-right">
                <button onclick="openOfferModal(${branchId}, ${item.product_id ?? item.id}, '${(item.name || item.product_name || '').replace(/'/g,'&#39;')}', ${item.discount_pct ?? 0}, '${(item.offer_badge || '').replace(/'/g,'&#39;')}')"
                  class="text-xs px-2.5 py-1 bg-amber-50 text-amber-700 rounded-lg hover:bg-amber-200 transition-colors font-medium mr-1">
                  Oferta
                </button>
                <button onclick="editBranchStockItem(${branchId}, ${item.product_id ?? item.id}, '${(item.name || item.product_name || '').replace(/'/g,'&#39;')}', ${item.stock ?? 0}, ${item.price ?? 'null'}, ${item.discount_pct ?? 'null'})"
                  class="text-xs px-2.5 py-1 bg-surface-container rounded-lg hover:bg-primary hover:text-on-primary transition-colors font-medium">
                  Editar
                </button>
              </td>
            </tr>`).join('')}
        </tbody>
      </table>`;
  } catch (e) {
    body.innerHTML = `<div class="py-8 text-center text-error text-sm">${e.message}</div>`;
  }
}

function editBranchStockItem(branchId, productId, productName, stock, price, discount) {
  const newStock    = prompt(`Stock actual: ${stock}\nNuevo stock para "${productName}":`, stock);
  if (newStock === null) return;
  const newPrice    = prompt(`Precio override (vacío = usar precio global):`, price ?? '');
  const newDiscount = prompt(`Descuento % override (vacío = usar descuento global):`, discount ?? '');

  const payload = {
    stock: parseInt(newStock) || 0,
    price: newPrice !== '' && newPrice !== null ? parseFloat(newPrice) : null,
    discount_pct: newDiscount !== '' && newDiscount !== null ? parseFloat(newDiscount) : null,
  };

  fetch(`/api/branches/${branchId}/inventory/${productId}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
    .then(r => r.json())
    .then(() => {
      showToast('Stock actualizado');
      openBranchStock(branchId, document.getElementById('branchStockTitle').textContent.replace('Inventario — ', ''));
    })
    .catch(e => showToast(e.message, 'error'));
}

// ── Ofertas ───────────────────────────────────────────────────────────────────

let _offerBranchId = null;
let _offerProductId = null;

async function loadOffers() {
  const grid = document.getElementById('offers-grid');
  if (!grid) return;
  grid.innerHTML = '<div class="col-span-full py-10 text-center text-on-surface-variant text-sm">Cargando...</div>';
  try {
    const q = activeBranchId ? `?branch_id=${activeBranchId}` : '';
    const res = await fetch(`/api/branches/offers${q}`);
    const items = await res.json();
    if (!res.ok) throw new Error(items.error || 'Error');
    if (!items.length) {
      grid.innerHTML = '<div class="col-span-full py-10 text-center text-on-surface-variant text-sm">Sin ofertas activas.</div>';
      return;
    }
    grid.innerHTML = items.map(item => _offerCardHtml(item)).join('');
  } catch (e) {
    grid.innerHTML = `<div class="col-span-full py-8 text-center text-error text-sm">${e.message}</div>`;
  }
}

function _offerCardHtml(item) {
  const badge = item.offer_badge ? `<span class="inline-block text-xs font-bold px-2 py-0.5 rounded-full bg-amber-100 text-amber-800 mb-1">${item.offer_badge}</span>` : '';
  const disc = item.effective_discount ?? item.discount_pct ?? 0;
  const price = item.effective_price ?? item.price ?? 0;
  const branchName = item.branch_name ? `<span class="text-xs text-on-surface-variant">${item.branch_name}</span>` : '';
  return `
    <div class="bg-surface-container rounded-xl p-4 flex flex-col gap-2 border border-outline-variant hover:shadow-md transition-shadow">
      <div class="flex items-start justify-between gap-2">
        <p class="font-semibold text-on-surface text-sm leading-snug">${item.name || item.product_name || '—'}</p>
        ${badge}
      </div>
      ${branchName}
      <div class="flex items-center gap-3 mt-auto pt-2">
        <span class="text-lg font-bold text-primary">$${price.toFixed(2)}</span>
        ${disc > 0 ? `<span class="text-xs font-semibold text-green-700 bg-green-100 px-2 py-0.5 rounded-full">-${disc}%</span>` : ''}
      </div>
      <button onclick="openOfferModal(${item.branch_id}, ${item.product_id ?? item.id}, '${(item.name || '').replace(/'/g,'&#39;')}', ${disc}, '${(item.offer_badge || '').replace(/'/g,'&#39;')}')"
        class="mt-1 text-xs px-3 py-1.5 rounded-lg bg-amber-50 text-amber-700 hover:bg-amber-200 transition-colors font-medium self-start">
        Editar oferta
      </button>
    </div>`;
}

function openOfferModal(branchId, productId, productName, currentDiscount, currentBadge) {
  _offerBranchId = branchId;
  _offerProductId = productId;
  document.getElementById('offerModalTitle').textContent = productName;
  document.getElementById('offerDiscountInput').value = currentDiscount || 0;
  document.getElementById('offerBadgeInput').value = currentBadge || '';
  document.getElementById('modal-offer').style.display = 'flex';
}

function closeOfferModal() {
  document.getElementById('modal-offer').style.display = 'none';
  _offerBranchId = null;
  _offerProductId = null;
}

async function saveOffer(clear = false) {
  if (!_offerBranchId || !_offerProductId) return;
  const discount = clear ? 0 : (parseFloat(document.getElementById('offerDiscountInput').value) || 0);
  const badge = clear ? '' : document.getElementById('offerBadgeInput').value.trim();
  try {
    const res = await fetch(`/api/branches/${_offerBranchId}/inventory/${_offerProductId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ discount_pct: discount, offer_badge: badge }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Error');
    showToast(clear ? 'Oferta eliminada' : 'Oferta guardada');
    closeOfferModal();
    loadOffers();
  } catch (e) {
    showToast(e.message, 'error');
  }
}

// ── Combos admin ─────────────────────────────────────────────────────────────

async function loadCombos() {
  const grid = document.getElementById('combos-grid');
  if (!grid) return;
  grid.innerHTML = '<div class="col-span-full py-10 text-center text-on-surface-variant text-sm">Cargando...</div>';
  try {
    const res = await fetch('/api/combos/all');
    _allCombos = await res.json();
    if (!res.ok) throw new Error(_allCombos.error || 'Error');
    if (!_allCombos.length) {
      grid.innerHTML = '<div class="col-span-full py-10 text-center text-on-surface-variant text-sm">Sin combos. Crea el primero con el botón superior.</div>';
      return;
    }
    grid.innerHTML = _allCombos.map(_comboAdminCardHtml).join('');
  } catch (e) {
    grid.innerHTML = `<div class="col-span-full py-8 text-center text-error text-sm">${e.message}</div>`;
  }
}

function _comboAdminCardHtml(c) {
  const statusBadge = c.is_active
    ? '<span class="text-xs font-semibold text-green-700 bg-green-100 px-2 py-0.5 rounded-full">Activo</span>'
    : '<span class="text-xs font-semibold text-on-surface-variant bg-surface-container px-2 py-0.5 rounded-full">Inactivo</span>';
  const itemsList = c.items.length
    ? c.items.map(ci => `<li class="text-xs text-on-surface-variant">× ${ci.quantity} ${ci.product_name}</li>`).join('')
    : '<li class="text-xs text-on-surface-variant italic">Sin productos</li>';
  return `
    <div class="bg-surface-container-lowest rounded-2xl border border-outline-variant/30 p-4 flex flex-col gap-3 hover:shadow-md transition-shadow">
      <div class="flex items-start justify-between gap-2">
        <div>
          <p class="font-semibold text-on-surface leading-snug">${c.name}</p>
          ${c.description ? `<p class="text-xs text-on-surface-variant mt-0.5">${c.description}</p>` : ''}
        </div>
        ${statusBadge}
      </div>
      <ul class="space-y-0.5 pl-1">${itemsList}</ul>
      <div class="flex items-center justify-between mt-auto pt-2 border-t border-outline-variant/20">
        <span class="text-xl font-extrabold text-primary">$${(c.price || 0).toFixed(2)}</span>
        <div class="flex gap-2">
          <button onclick="openComboModal(${c.id})"
            class="text-xs px-3 py-1.5 rounded-lg bg-surface-container hover:bg-primary hover:text-on-primary transition-colors font-medium">
            Editar
          </button>
          <button onclick="deleteCombo(${c.id}, '${c.name.replace(/'/g,'&#39;')}')"
            class="text-xs px-3 py-1.5 rounded-lg border border-error/30 text-error hover:bg-error/10 transition-colors font-medium">
            Eliminar
          </button>
        </div>
      </div>
    </div>`;
}

async function openComboModal(id = null) {
  // Asegurar que allProducts esté cargado
  if (!allProducts.length) {
    try {
      const r = await fetch('/api/inventory/products');
      allProducts = await r.json();
    } catch {}
  }
  // Cargar sucursales en el select
  const branchSel = document.getElementById('cBranch');
  branchSel.innerHTML = '<option value="">Global (todas las sucursales)</option>';
  try {
    const r = await fetch('/api/branches/?active_only=false');
    const branches = await r.json();
    branches.forEach(b => {
      branchSel.innerHTML += `<option value="${b.id}">${b.name}</option>`;
    });
  } catch {}

  document.getElementById('cItemsContainer').innerHTML = '';
  document.getElementById('cId').value = id || '';
  document.getElementById('comboModalTitle').textContent = id ? 'Editar Combo' : 'Nuevo Combo';

  if (id) {
    const combo = _allCombos.find(c => c.id === id)
      || await fetch(`/api/combos/${id}`).then(r => r.json()).catch(() => null);
    if (combo) {
      document.getElementById('cName').value  = combo.name;
      document.getElementById('cDesc').value  = combo.description || '';
      document.getElementById('cPrice').value = combo.price;
      branchSel.value = combo.branch_id || '';
      document.getElementById('cActive').checked = combo.is_active;
      (combo.items || []).forEach(ci => addComboItemRow(ci.product_id, ci.quantity));
    }
  } else {
    document.getElementById('cName').value  = '';
    document.getElementById('cDesc').value  = '';
    document.getElementById('cPrice').value = '';
    document.getElementById('cActive').checked = true;
    addComboItemRow();
  }
  document.getElementById('modal-combo').style.display = 'flex';
}

function closeComboModal() {
  document.getElementById('modal-combo').style.display = 'none';
}

function addComboItemRow(productId = '', qty = 1) {
  const container = document.getElementById('cItemsContainer');
  const row = document.createElement('div');
  row.className = 'combo-item-row flex gap-2 items-center';
  const opts = allProducts.map(p =>
    `<option value="${p.id}" ${p.id == productId ? 'selected' : ''}>${p.name} ($${(p.price||0).toFixed(2)})</option>`
  ).join('');
  row.innerHTML = `
    <select class="modal-input flex-1 combo-product-select text-sm">
      <option value="">Seleccionar producto...</option>
      ${opts}
    </select>
    <input type="number" min="1" value="${qty}" class="modal-input w-20 combo-qty-input text-sm" placeholder="Cant." />
    <button onclick="this.closest('.combo-item-row').remove()"
      class="w-8 h-8 flex-shrink-0 flex items-center justify-center text-error hover:bg-error/10 rounded-lg text-xl font-bold leading-none">×</button>`;
  container.appendChild(row);
}

async function saveCombo() {
  const id    = document.getElementById('cId').value;
  const name  = document.getElementById('cName').value.trim();
  const price = parseFloat(document.getElementById('cPrice').value);
  if (!name)  { showToast('El nombre es requerido', 'error'); return; }
  if (!price) { showToast('El precio es requerido', 'error'); return; }

  const rows = document.getElementById('cItemsContainer').querySelectorAll('.combo-item-row');
  const items = [];
  rows.forEach(row => {
    const pid = parseInt(row.querySelector('.combo-product-select')?.value || '0');
    const qty = parseInt(row.querySelector('.combo-qty-input')?.value || '1') || 1;
    if (pid) items.push({ product_id: pid, quantity: qty });
  });

  const payload = {
    name,
    description: document.getElementById('cDesc').value.trim(),
    price,
    branch_id: parseInt(document.getElementById('cBranch').value) || null,
    is_active: document.getElementById('cActive').checked,
    items,
  };

  try {
    const res = await fetch(id ? `/api/combos/${id}` : '/api/combos/', {
      method: id ? 'PUT' : 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Error');
    showToast(id ? 'Combo actualizado' : 'Combo creado');
    closeComboModal();
    loadCombos();
  } catch (e) {
    showToast(e.message, 'error');
  }
}

async function deleteCombo(id, name) {
  if (!confirm(`¿Eliminar el combo "${name}"?`)) return;
  try {
    const res = await fetch(`/api/combos/${id}`, { method: 'DELETE' });
    if (!res.ok) throw new Error((await res.json()).error || 'Error');
    showToast('Combo eliminado');
    loadCombos();
  } catch (e) {
    showToast(e.message, 'error');
  }
}

async function openPosCombosSheet() {
  const list = document.getElementById('pos-combos-list');
  list.innerHTML = '<div class="py-8 text-center text-on-surface-variant text-sm">Cargando...</div>';
  document.getElementById('modal-pos-combos').style.display = 'flex';
  try {
    const q = activeBranchId ? `?branch_id=${activeBranchId}` : '';
    const res = await fetch(`/api/combos/${q}`);
    const combos = await res.json();
    if (!combos.length) {
      list.innerHTML = '<div class="py-8 text-center text-on-surface-variant text-sm">Sin combos disponibles.</div>';
      return;
    }
    list.innerHTML = combos.map(c => `
      <div class="flex items-center gap-3 p-3 rounded-xl border border-outline-variant/30 bg-surface-container hover:bg-surface-container-high transition-colors">
        <div class="flex-1 min-w-0">
          <p class="font-semibold text-on-surface text-sm">${c.name}</p>
          ${c.description ? `<p class="text-xs text-on-surface-variant mt-0.5">${c.description}</p>` : ''}
          <p class="text-xs text-on-surface-variant mt-1">${(c.items||[]).map(ci=>`${ci.product_name} x${ci.quantity}`).join(' · ')}</p>
        </div>
        <div class="text-right shrink-0">
          <p class="text-lg font-extrabold text-primary">$${(c.price||0).toFixed(2)}</p>
          <button onclick="addComboToCartPOS(${JSON.stringify(c).replace(/"/g,'&quot;')}); document.getElementById('modal-pos-combos').style.display='none';"
            class="mt-1 text-xs px-3 py-1.5 rounded-lg bg-primary text-on-primary hover:bg-primary/90 transition-colors font-semibold">
            Agregar
          </button>
        </div>
      </div>`).join('');
  } catch (e) {
    list.innerHTML = `<div class="py-8 text-center text-error text-sm">${e.message}</div>`;
  }
}

// Agregar combo al carrito del POS
function addComboToCartPOS(combo) {
  if (combosInCart[combo.id]) {
    combosInCart[combo.id].qty++;
  } else {
    combosInCart[combo.id] = { combo, qty: 1 };
  }
  renderCart();
  showToast(`Combo "${combo.name}" agregado`);
}

// ── Historial por sucursal ────────────────────────────────────────────────────

async function openBranchHistory(branchId, branchName) {
  document.getElementById('branchHistoryTitle').textContent = `Historial — ${branchName}`;
  const body = document.getElementById('branchHistoryBody');
  body.innerHTML = '<div class="py-10 text-center text-on-surface-variant text-sm">Cargando...</div>';
  document.getElementById('modalBranchHistory').style.display = 'flex';

  try {
    const res = await fetch(`/api/sales/?branch_id=${branchId}`);
    const sales = await res.json();
    if (!res.ok) throw new Error(sales.error || 'Error');
    if (!sales.length) {
      body.innerHTML = '<div class="py-8 text-center text-on-surface-variant text-sm">Sin ventas registradas en esta sucursal.</div>';
      return;
    }
    const total = sales.reduce((s, v) => s + (v.total || 0), 0);
    body.innerHTML = `
      <div class="flex items-center justify-between mb-4 px-1">
        <p class="text-sm text-on-surface-variant">${sales.length} venta(s)</p>
        <p class="font-bold text-primary text-lg">Total: $${total.toFixed(2)}</p>
      </div>
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead class="bg-surface-container-low">
            <tr>
              <th class="text-left px-4 py-2.5 text-xs font-semibold text-on-surface-variant">#</th>
              <th class="text-left px-4 py-2.5 text-xs font-semibold text-on-surface-variant">Cliente</th>
              <th class="text-right px-4 py-2.5 text-xs font-semibold text-on-surface-variant">Total</th>
              <th class="text-left px-4 py-2.5 text-xs font-semibold text-on-surface-variant">Método</th>
              <th class="text-left px-4 py-2.5 text-xs font-semibold text-on-surface-variant">Fecha</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-surface-container-highest">
            ${sales.map(s => `
              <tr class="hover:bg-surface-container-low transition-colors">
                <td class="px-4 py-3 text-on-surface-variant text-xs">#${s.id}</td>
                <td class="px-4 py-3 text-on-surface">${s.customer_name || '—'}</td>
                <td class="px-4 py-3 text-right font-semibold text-primary">$${(s.total || 0).toFixed(2)}</td>
                <td class="px-4 py-3 text-xs text-on-surface-variant">${s.payment_method || '—'}</td>
                <td class="px-4 py-3 text-xs text-on-surface-variant">${s.created_at ? new Date(s.created_at).toLocaleDateString('es-MX') : '—'}</td>
              </tr>`).join('')}
          </tbody>
        </table>
      </div>`;
  } catch (e) {
    body.innerHTML = `<div class="py-8 text-center text-error text-sm">${e.message}</div>`;
  }
}

// ─── Panel: Reseñas ──────────────────────────────────────────────────────────

function _adminStarsHtml(avg = 0) {
  const rounded = Math.round(avg || 0);
  return [1,2,3,4,5].map(i =>
    `<span class="material-symbols-outlined text-[13px] ${i <= rounded ? 'text-secondary' : 'text-outline-variant'}"
      style="font-variation-settings:'FILL' ${i <= rounded ? 1 : 0}">star</span>`
  ).join('');
}

function _ratingBadgeClass(avg) {
  if (avg >= 4) return 'bg-green-100 text-green-800';
  if (avg >= 3) return 'bg-yellow-100 text-yellow-800';
  if (avg > 0)  return 'bg-red-100 text-red-800';
  return 'bg-surface-container text-on-surface-variant';
}

async function loadReviews() {
  try {
    const data = await (await fetch('/api/analytics/reviews')).json();

    // Stat cards
    const totalBranchReviews  = data.branches.reduce((s, b) => s + b.total_reviews, 0);
    const totalProductReviews = data.products.reduce((s, p) => s + p.total_reviews, 0);
    const totalReviews        = totalBranchReviews + totalProductReviews;

    const branchesWithReviews = data.branches.filter(b => b.total_reviews > 0);
    const productsWithReviews = data.products.filter(p => p.total_reviews > 0);
    const avgBranch = branchesWithReviews.length
      ? (branchesWithReviews.reduce((s, b) => s + b.avg_rating, 0) / branchesWithReviews.length).toFixed(1)
      : null;
    const avgProduct = productsWithReviews.length
      ? (productsWithReviews.reduce((s, p) => s + p.avg_rating, 0) / productsWithReviews.length).toFixed(1)
      : null;

    document.getElementById('r-total').textContent = totalReviews;
    document.getElementById('r-branch-avg').innerHTML = avgBranch
      ? `${_adminStarsHtml(avgBranch)} <span class="text-base">${avgBranch}</span>` : '—';
    document.getElementById('r-product-avg').innerHTML = avgProduct
      ? `${_adminStarsHtml(avgProduct)} <span class="text-base">${avgProduct}</span>` : '—';

    // Branch ratings table
    const branchTbody = document.getElementById('tbl-branch-ratings');
    if (branchTbody) {
      const sorted = [...data.branches].sort((a, b) => (b.avg_rating || 0) - (a.avg_rating || 0));
      branchTbody.innerHTML = sorted.map(b => `
        <tr class="hover:bg-surface-container/50 transition-colors">
          <td class="px-4 py-3 font-medium text-on-surface text-sm">${b.name}</td>
          <td class="px-4 py-3 text-center">
            ${b.total_reviews > 0
              ? `<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-bold ${_ratingBadgeClass(b.avg_rating)}">
                   ${_adminStarsHtml(b.avg_rating)} ${b.avg_rating.toFixed(1)}
                 </span>`
              : '<span class="text-xs text-on-surface-variant">Sin reseñas</span>'}
          </td>
          <td class="px-4 py-3 text-center text-xs text-on-surface-variant">${b.total_reviews}</td>
        </tr>`).join('');
    }

    // Product ratings table (top 10 with reviews)
    const productTbody = document.getElementById('tbl-product-ratings');
    if (productTbody) {
      const sorted = [...data.products]
        .filter(p => p.total_reviews > 0)
        .sort((a, b) => b.avg_rating - a.avg_rating)
        .slice(0, 10);
      productTbody.innerHTML = sorted.length
        ? sorted.map(p => `
            <tr class="hover:bg-surface-container/50 transition-colors">
              <td class="px-4 py-3 font-medium text-on-surface text-sm">${p.name}</td>
              <td class="px-4 py-3 text-center">
                <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-bold ${_ratingBadgeClass(p.avg_rating)}">
                  ${_adminStarsHtml(p.avg_rating)} ${p.avg_rating.toFixed(1)}
                </span>
              </td>
              <td class="px-4 py-3 text-center text-xs text-on-surface-variant">${p.total_reviews}</td>
            </tr>`).join('')
        : '<tr><td colspan="3" class="px-4 py-8 text-center text-on-surface-variant text-sm">Sin reseñas de productos aún.</td></tr>';
    }

    // Recent reviews feed
    const feed = document.getElementById('review-feed');
    if (feed) {
      feed.innerHTML = data.recent.length
        ? data.recent.map(r => {
            const date = new Date(r.created_at).toLocaleDateString('es-MX', { day:'numeric', month:'short', year:'numeric' });
            const icon = r.type === 'branch' ? 'store_mall_directory' : 'shopping_bag';
            return `
              <div class="px-5 py-4 flex items-start gap-4">
                <div class="icon-tile w-10 h-10 shrink-0">
                  <span class="material-symbols-outlined text-lg" style="font-variation-settings:'FILL' 1">${icon}</span>
                </div>
                <div class="flex-1 min-w-0">
                  <div class="flex items-center justify-between gap-2 mb-0.5">
                    <p class="font-semibold text-on-surface text-sm truncate">${r.target_name}</p>
                    <span class="text-[11px] text-on-surface-variant shrink-0">${date}</span>
                  </div>
                  <div class="flex items-center gap-1 mb-1">${_adminStarsHtml(r.rating)}</div>
                  <p class="text-xs text-on-surface-variant">${r.customer_name || 'Cliente'}</p>
                  ${r.comment ? `<p class="text-xs text-on-surface mt-1 line-clamp-2">${r.comment}</p>` : ''}
                </div>
              </div>`;
          }).join('')
        : '<div class="px-5 py-8 text-center text-on-surface-variant text-sm">Sin reseñas aún.</div>';
    }
  } catch (e) {
    console.error('loadReviews error:', e);
  }
}

// ─── Init ───
document.addEventListener('DOMContentLoaded', () => {
  loadBranchSelector();
  loadDashboard();
  // Cerrar modal de detalle al hacer clic en el fondo
  const modalSale = document.getElementById('modalSale');
  if (modalSale) modalSale.addEventListener('click', e => {
    if (e.target === modalSale) closeModal('modalSale');
  });
});
