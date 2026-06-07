const API = '/api';
let allProducts = [];
let cart = [];
let activeCategory = '';

// ─── Init ───
document.addEventListener('DOMContentLoaded', loadProducts);

async function loadProducts() {
  try {
    const res = await fetch(`${API}/inventory/products`);
    allProducts = await res.json();
    allProducts = allProducts.filter(p => p.stock > 0);
    renderCategories();
    renderProducts();
  } catch (e) {
    document.getElementById('productsContainer').innerHTML =
      '<div class="col-span-full text-center py-12 text-error">Error al cargar productos del servidor.</div>';
  }
}

// ─── Categories ───
function renderCategories() {
  const cats = [...new Set(allProducts.map(p => p.category))].sort();
  const bar = document.getElementById('categoriesBar');
  
  let html = `<button onclick="selectCategory('')" class="cat-chip px-5 py-2.5 rounded-full bg-surface-container text-sm font-medium border border-outline-variant/20 active">Todos</button>`;
  
  html += cats.map(c => `
    <button onclick="selectCategory('${c}')" class="cat-chip px-5 py-2.5 rounded-full bg-surface-container text-sm font-medium border border-outline-variant/20">
      ${c}
    </button>
  `).join('');
  
  bar.innerHTML = html;
}

function selectCategory(cat) {
  activeCategory = cat;
  document.querySelectorAll('.cat-chip').forEach(el => {
    const isActive = (cat === '' && el.textContent.trim() === 'Todos') || el.textContent.trim() === cat;
    el.classList.toggle('active', isActive);
    if(isActive) {
      el.classList.add('bg-primary', 'text-on-primary');
      el.classList.remove('bg-surface-container', 'text-on-surface');
    } else {
      el.classList.remove('bg-primary', 'text-on-primary');
      el.classList.add('bg-surface-container', 'text-on-surface');
    }
  });
  filterProducts();
}

// ─── Filter & Render ───
function filterProducts() {
  const q = document.getElementById('searchInput').value.toLowerCase();
  const filtered = allProducts.filter(p => {
    const matchCat = !activeCategory || p.category === activeCategory;
    const matchSearch = !q || p.name.toLowerCase().includes(q) || p.category.toLowerCase().includes(q);
    return matchCat && matchSearch;
  });
  renderProducts(filtered);
}

function renderProducts(list) {
  list = list || allProducts;
  const container = document.getElementById('productsContainer');
  
  if (!list.length) {
    container.innerHTML = '<div class="col-span-full py-20 text-center text-outline">No encontramos productos con esos criterios.</div>';
    return;
  }

  container.innerHTML = list.map(p => {
    const inCart = cart.find(c => c.id === p.id);
    const available = p.stock - (inCart ? inCart.qty : 0);
    const stockStatus = available <= 0 ? 'Agotado' : available <= 5 ? `¡Solo ${available}!` : `Hay stock`;
    const stockColor = available <= 0 ? 'text-error' : available <= 5 ? 'text-tertiary' : 'text-outline';
    
    return `
      <div class="product-card group bg-surface-container-low border border-outline-variant/10 rounded-2xl overflow-hidden flex flex-col">
        <div class="aspect-square bg-surface-container-high relative overflow-hidden">
          ${p.image_url 
            ? `<img src="${p.image_url}" class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110" alt="${esc(p.name)}">`
            : `<div class="w-full h-full flex items-center justify-center bg-surface-container-highest text-outline/30">
                 <span class="material-symbols-outlined text-5xl">image_not_supported</span>
               </div>`
          }
          <div class="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
             <button onclick="addToCart(${p.id})" class="bg-primary text-on-primary w-14 h-14 rounded-full flex items-center justify-center shadow-xl translate-y-4 group-hover:translate-y-0 transition-transform">
               <span class="material-symbols-outlined">add_shopping_cart</span>
             </button>
          </div>
        </div>
        <div class="p-5 flex-1 flex flex-col">
          <div class="flex justify-between items-start mb-1">
            <span class="text-[10px] uppercase tracking-widest text-primary font-bold">${esc(p.category)}</span>
            <span class="text-xs font-medium ${stockColor}">${stockStatus}</span>
          </div>
          <h3 class="text-lg font-bold mb-2 group-hover:text-primary transition-colors">${esc(p.name)}</h3>
          <div class="mt-auto flex items-center justify-between pt-4 border-t border-outline-variant/5">
            <span class="text-xl font-bold">$${p.price.toFixed(2)}</span>
            <button onclick="addToCart(${p.id})" class="text-primary p-2 hover:bg-primary/10 rounded-lg transition-colors md:hidden">
              <span class="material-symbols-outlined">add_circle</span>
            </button>
          </div>
        </div>
      </div>
    `;
  }).join('');
}

// ─── Cart Logic ───
function addToCart(pid) {
  const p = allProducts.find(x => x.id === pid);
  if (!p) return;
  const existing = cart.find(c => c.id === pid);
  const currentQty = existing ? existing.qty : 0;
  
  if (currentQty >= p.stock) {
    showToast('Lo sentimos, no hay más unidades disponibles.');
    return;
  }
  
  if (existing) {
    existing.qty++;
  } else {
    cart.push({ ...p, qty: 1 });
  }
  
  updateCartUI();
  renderProducts(getFilteredList());
  showToast(`+1 ${p.name}`);
}

function changeQty(pid, delta) {
  const item = cart.find(c => c.id === pid);
  if (!item) return;
  
  item.qty += delta;
  if (item.qty <= 0) {
    cart = cart.filter(c => c.id !== pid);
  } else if (item.qty > item.stock) {
    item.qty = item.stock;
    showToast('Límite de stock alcanzado');
  }
  
  updateCartUI();
  renderProducts(getFilteredList());
}

function clearCart() {
  cart = [];
  updateCartUI();
  renderProducts(getFilteredList());
  showToast('Carrito vaciado');
}

function updateCartUI() {
  const badge = document.getElementById('cartBadge');
  const body = document.getElementById('cartBody');
  const footer = document.getElementById('cartFooter');
  const totalEl = document.getElementById('cartTotal');
  
  const totalQty = cart.reduce((s, c) => s + c.qty, 0);
  const totalPrice = cart.reduce((s, c) => s + c.qty * c.price, 0);

  if (totalQty > 0) {
    badge.textContent = totalQty;
    badge.classList.remove('scale-0');
    badge.classList.add('scale-100');
  } else {
    badge.classList.remove('scale-100');
    badge.classList.add('scale-0');
  }

  if (cart.length === 0) {
    body.innerHTML = `
      <div class="h-full flex flex-col items-center justify-center opacity-50 py-20">
        <span class="material-symbols-outlined text-6xl mb-4">shopping_cart_off</span>
        <p class="text-sm">Tu carrito está esperando por ti</p>
      </div>
    `;
    footer.style.display = 'none';
    return;
  }

  footer.style.display = 'block';
  totalEl.textContent = `$${totalPrice.toFixed(2)}`;
  
  body.innerHTML = cart.map(c => `
    <div class="flex gap-4 mb-6 animate-in slide-in-from-right-4 duration-300">
      <div class="w-16 h-16 bg-surface-container rounded-lg overflow-hidden flex-shrink-0">
        ${c.image_url ? `<img src="${c.image_url}" class="w-full h-full object-cover">` : '<div class="w-full h-full flex items-center justify-center text-outline/30"><span class="material-symbols-outlined">image</span></div>'}
      </div>
      <div class="flex-1 flex flex-col justify-center">
        <h4 class="text-sm font-bold leading-tight">${esc(c.name)}</h4>
        <span class="text-xs text-outline mt-1">$${c.price.toFixed(2)}</span>
      </div>
      <div class="flex items-center gap-3 bg-surface-container-low rounded-lg px-2 h-10 border border-outline-variant/10">
        <button onclick="changeQty(${c.id}, -1)" class="w-6 h-6 flex items-center justify-center hover:text-primary transition-colors text-lg">-</button>
        <span class="text-sm font-mono font-bold min-w-[20px] text-center">${c.qty}</span>
        <button onclick="changeQty(${c.id}, 1)" class="w-6 h-6 flex items-center justify-center hover:text-primary transition-colors text-lg">+</button>
      </div>
    </div>
  `).join('');
}

function getFilteredList() {
  const q = document.getElementById('searchInput').value.toLowerCase();
  return allProducts.filter(p => {
    const matchCat = !activeCategory || p.category === activeCategory;
    const matchSearch = !q || p.name.toLowerCase().includes(q);
    return matchCat && matchSearch;
  });
}

function toggleCart() {
  const overlay = document.getElementById('cartOverlay');
  const drawer = document.getElementById('cartDrawer');
  const isOpen = drawer.classList.contains('open');
  
  if (!isOpen) {
    overlay.classList.remove('hidden');
    setTimeout(() => overlay.classList.add('opacity-100'), 10);
    drawer.classList.add('open');
    document.body.style.overflow = 'hidden';
  } else {
    overlay.classList.remove('opacity-100');
    drawer.classList.remove('open');
    document.body.style.overflow = '';
    setTimeout(() => overlay.classList.add('hidden'), 400);
  }
}

async function checkout() {
  if (!cart.length) return;
  const btn = document.getElementById('checkoutBtn');
  const originalText = btn.innerHTML;
  btn.disabled = true;
  btn.innerHTML = '<span class="loader-spin material-symbols-outlined text-xl">progress_activity</span>';

  const clientName = document.getElementById('clientNameInput').value.trim();
  const items = cart.map(c => ({ product_id: c.id, quantity: c.qty }));

  try {
    const res = await fetch(`${API}/sales/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ items, client_name: clientName })
    });

    if (!res.ok) {
      const err = await res.json();
      throw new Error(err.error || 'Error al procesar el pago');
    }

    const sale = await res.json();
    cart = [];
    updateCartUI();
    toggleCart();

    document.getElementById('successOrderId').textContent = `#${String(sale.id).padStart(4, '0')}`;
    const modal = document.getElementById('successModal');
    modal.classList.remove('hidden');
    setTimeout(() => modal.classList.add('opacity-100'), 10);

    await loadProducts();
  } catch (e) {
    showToast(e.message);
  } finally {
    btn.disabled = false;
    btn.innerHTML = originalText;
  }
}

function closeSuccessModal() {
  const modal = document.getElementById('successModal');
  modal.classList.remove('opacity-100');
  setTimeout(() => modal.classList.add('hidden'), 300);
}

function esc(s) {
  const d = document.createElement('div');
  d.textContent = s;
  return d.innerHTML;
}

function showToast(msg) {
  const t = document.getElementById('toast');
  const tm = document.getElementById('toastMsg');
  tm.textContent = msg;
  t.classList.add('show');
  clearTimeout(t._timer);
  t._timer = setTimeout(() => t.classList.remove('show'), 3000);
}
