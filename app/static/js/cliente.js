/* ════════════════════════════════════════════════════
   cliente.js — Tienda web para clientes (OXXO Go)
════════════════════════════════════════════════════ */

/* ── Estado ─────────────────────────────────────── */
const S = {
  products: [],
  offers: [],
  combos: [],
  cart: {},          // { [id]: { product, qty } }
  cartCombos: {},    // { [comboId]: { combo, qty } }
  category: 'all',
  search: '',
  loading: true,
  favorites: new Set(JSON.parse(localStorage.getItem('oxxo_favs') || '[]')),
  branch: null,      // { id, name, ... } o null = todas las tiendas
  ratings: {},       // { [product_id]: { avg_rating, total_reviews } }
  branchRatings: {}, // { [branch_id]: { avg_rating, total_reviews } }
}

const FAVS_CATEGORY = '__favs'

function toggleFav(id) {
  S.favorites.has(id) ? S.favorites.delete(id) : S.favorites.add(id)
  localStorage.setItem('oxxo_favs', JSON.stringify([...S.favorites]))
  if (S.favorites.size === 0 && S.category === FAVS_CATEGORY) S.category = 'all'
  renderCategories()
  renderProducts()
}

/* ── Utilidades ─────────────────────────────────── */
const ICONS = {
  bebidas: 'local_drink',   drinks: 'local_drink',
  snacks: 'fastfood',       botanas: 'fastfood',
  dulces: 'cookie',         candy: 'cookie',       chocolates: 'cookie',
  abarrotes: 'shopping_basket', groceries: 'shopping_basket',
  panadería: 'bakery_dining',   panaderia: 'bakery_dining',
  farmacia: 'medical_services', pharmacy: 'medical_services',
  lácteos: 'egg',           lacteos: 'egg',
  carnes: 'set_meal',       frutas: 'nutrition',   verduras: 'nutrition',
}

function catIcon(cat) {
  const k = (cat || '').toLowerCase()
  for (const [key, val] of Object.entries(ICONS))
    if (k.includes(key)) return val
  return 'category'
}

function esc(str) {
  return String(str ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

function starsHtml(avg = 0, size = 13) {
  const rounded = Math.round(avg || 0)
  return [1,2,3,4,5].map(i =>
    `<span class="material-symbols-outlined text-[${size}px] ${i <= rounded ? 'text-secondary-container' : 'text-outline-variant'}"
      style="font-variation-settings:'FILL' ${i <= rounded ? 1 : 0}">star</span>`
  ).join('')
}

const fmt          = n  => `$${Number(n).toFixed(2)}`
const _comboCartTotal = () => Object.values(S.cartCombos).reduce((s, { combo, qty }) => s + combo.price * qty, 0)
const cartCount    = () => Object.values(S.cart).reduce((s, i) => s + i.qty, 0) + Object.values(S.cartCombos).reduce((s, { qty }) => s + qty, 0)
const cartSubtotal = () => Object.values(S.cart).reduce((s, i) => s + i.product.price * i.qty, 0) + _comboCartTotal()
const cartDiscount = () => Object.values(S.cart).reduce((s, i) => s + i.product.price * (i.product.discount_pct || 0) / 100 * i.qty, 0)
const cartTotal    = () => cartSubtotal() - cartDiscount()
const cartTax      = () => cartTotal() * (0.16 / 1.16)
const allCats    = () => [...new Set(S.products.map(p => p.category).filter(Boolean))].sort()
const filtered   = () => S.products.filter(p => {
  const okCat    = S.category === 'all'
    || (S.category === FAVS_CATEGORY ? S.favorites.has(p.id) : p.category === S.category)
  const okSearch = !S.search || p.name.toLowerCase().includes(S.search.toLowerCase())
  return okCat && okSearch && p.stock > 0
})

/* ── API ────────────────────────────────────────── */
async function loadRatings() {
  try {
    const data = await (await fetch('/api/products/ratings')).json()
    S.ratings = data
    renderProducts()
  } catch {}
}

async function loadProducts() {
  S.loading = true
  renderProducts()
  try {
    const url = S.branch
      ? `/api/branches/${S.branch.id}/inventory`
      : '/api/inventory/aggregated'
    const raw = await (await fetch(url)).json()
    S.products = raw.map(p => ({
      id: p.product_id ?? p.id,
      name: p.name,
      price: p.effective_price ?? p.price,
      discount_pct: p.effective_discount ?? p.discount_pct ?? 0,
      stock: p.stock ?? 0,
      category: p.category ?? 'General',
      image_url: p.image_url ?? null,
    }))
  } catch { S.products = [] }
  S.loading = false
  renderCategories()
  renderProducts()
}

async function postSale(payload) {
  const headers = { 'Content-Type': 'application/json' }
  const token = localStorage.getItem('customer_token')
  if (token) headers['Authorization'] = 'Bearer ' + token
  const res = await fetch('/api/sales/', {
    method: 'POST',
    headers,
    body: JSON.stringify(payload),
  })
  if (!res.ok) throw new Error((await res.json()).error || 'Error al procesar la venta')
  return res.json()
}

/* ── Carrito ────────────────────────────────────── */
function addToCartById(id) {
  const p = S.products.find(p => p.id === id)
  if (!p || p.stock <= 0) return
  S.cart[id] ? S.cart[id].qty++ : (S.cart[id] = { product: p, qty: 1 })
  updateBadge()
  renderProducts()
}

function removeFromCart(id) {
  delete S.cart[id]
  updateBadge()
  renderCart()
}

function updateQty(id, delta) {
  if (!S.cart[id]) return
  S.cart[id].qty = Math.max(0, S.cart[id].qty + delta)
  if (!S.cart[id].qty) delete S.cart[id]
  updateBadge()
  renderCart()
}

function addComboToCart(combo) {
  if (S.cartCombos[combo.id]) {
    S.cartCombos[combo.id].qty++
  } else {
    S.cartCombos[combo.id] = { combo, qty: 1 }
  }
  updateBadge()
  renderCart()
}

function removeComboFromCart(comboId) {
  delete S.cartCombos[comboId]
  updateBadge()
  renderCart()
}

function updateComboQty(comboId, delta) {
  if (!S.cartCombos[comboId]) return
  S.cartCombos[comboId].qty = Math.max(0, S.cartCombos[comboId].qty + delta)
  if (!S.cartCombos[comboId].qty) delete S.cartCombos[comboId]
  updateBadge()
  renderCart()
}

function clearCart() {
  S.cart = {}
  S.cartCombos = {}
  updateBadge()
}

/* ── Render: Productos ──────────────────────────── */
function renderProducts() {
  const el = document.getElementById('products-grid')
  if (!el) return

  const titleEl = document.getElementById('section-title')
  if (titleEl) {
    if (S.search)                            titleEl.textContent = `Resultados: "${S.search}"`
    else if (S.category === FAVS_CATEGORY)   titleEl.textContent = 'Mis favoritos'
    else if (S.category !== 'all')           titleEl.textContent = S.category
    else                                     titleEl.textContent = 'Todos los productos'
  }

  if (S.loading) {
    el.innerHTML = UI.skeleton('product', 8)
    return
  }

  const products = filtered()
  if (!products.length) {
    const isFavs = S.category === FAVS_CATEGORY && !S.search
    el.innerHTML = `<div class="col-span-full">${UI.emptyState({
      icon: isFavs ? 'favorite' : 'search_off',
      title: isFavs ? 'Aún no tienes favoritos' : 'Sin resultados',
      hint: isFavs ? 'Toca el corazón de un producto para guardarlo aquí.' : 'No encontramos productos con ese filtro.',
      action: `<button onclick="resetFilters()" class="btn-brand text-on-primary font-label-lg font-bold px-6 py-2.5 rounded-full mt-2 active:scale-95">Ver todo</button>`
    })}</div>`
    return
  }

  el.innerHTML = products.map((p, idx) => {
    const inCart   = S.cart[p.id]?.qty || 0
    const img      = p.image_url
      ? `<img src="${esc(p.image_url)}" alt="${esc(p.name)}" class="product-img w-3/4 h-3/4 object-contain"/>`
      : `<span class="material-symbols-outlined text-[64px] text-on-surface-variant/25">${catIcon(p.category)}</span>`
    const discPct    = p.discount_pct || 0
    const discPrice  = p.price * (1 - discPct / 100)
    const lowBadge   = p.stock <= 5
      ? `<div class="absolute top-2 left-2 z-10"><span class="bg-error text-on-error text-[11px] font-bold px-2 py-0.5 rounded-sm shadow-sm">¡Últimos!</span></div>`
      : ''
    const discBadge  = discPct > 0
      ? `<div class="absolute top-2 left-2 z-10"><span class="badge-discount text-[11px] font-extrabold px-2 py-0.5 rounded-full">−${discPct % 1 === 0 ? discPct : discPct.toFixed(1)}%</span></div>`
      : ''
    const cartBadge  = inCart
      ? `<div class="absolute top-11 right-2 z-10 bg-primary text-on-primary text-xs font-bold rounded-full w-6 h-6 flex items-center justify-center shadow">${inCart}</div>`
      : ''
    const isFav      = S.favorites.has(p.id)
    const favBtn     = `
      <button onclick="event.stopPropagation();toggleFav(${p.id})" aria-label="${isFav ? 'Quitar de favoritos' : 'Agregar a favoritos'}"
        class="fav-btn ${isFav ? 'fav-active' : ''} absolute top-2 right-2 z-10 w-8 h-8 rounded-full flex items-center justify-center active:scale-90">
        <span class="material-symbols-outlined text-[18px]" ${isFav ? "style=\"font-variation-settings:'FILL' 1\"" : ''}>favorite</span>
      </button>`
    const priceBlock = discPct > 0
      ? `<div class="flex flex-col leading-tight">
           <span class="text-[11px] text-on-surface-variant line-through">${fmt(p.price)}</span>
           <span class="font-display text-headline-md text-green-600 font-bold">${fmt(discPrice)}</span>
         </div>`
      : `<span class="font-display text-headline-md text-primary font-bold">${fmt(p.price)}</span>`

    const ratingInfo = S.ratings[String(p.id)] || S.ratings[p.id]
    const ratingBlock = ratingInfo
      ? `<button onclick="event.stopPropagation();openProductReviewModal(${p.id})"
           class="flex items-center gap-0.5 mb-1.5 hover:opacity-80 active:scale-95 transition-transform">
           ${starsHtml(ratingInfo.avg_rating, 12)}
           <span class="text-[11px] text-on-surface-variant ml-0.5">(${ratingInfo.total_reviews})</span>
         </button>`
      : `<button onclick="event.stopPropagation();openProductReviewModal(${p.id})"
           class="text-[11px] text-on-surface-variant/70 mb-1.5 hover:text-primary active:scale-95 transition-transform flex items-center gap-0.5">
           <span class="material-symbols-outlined text-[12px]">rate_review</span> Reseñar
         </button>`

    return `
      <div onclick="addToCartById(${p.id})"
        class="product-card anim-fade-up bg-surface-container-lowest rounded-2xl p-4 relative flex flex-col cursor-pointer border border-surface-variant/50" style="--stagger-i:${Math.min(idx, 12)}">
        ${p.stock <= 5 ? lowBadge : discBadge}${favBtn}${cartBadge}
        <div class="w-full aspect-square mb-4 relative bg-surface-container-low rounded-xl overflow-hidden flex items-center justify-center">
          ${img}
        </div>
        <div class="flex-1 flex flex-col">
          <p class="text-on-surface font-medium line-clamp-2 mb-1 text-[15px] leading-snug">${esc(p.name)}</p>
          <p class="font-label-md text-label-md text-on-surface-variant mb-1">${esc(p.category)}</p>
          ${ratingBlock}
          <div class="mt-auto flex items-center justify-between pt-2">
            ${priceBlock}
            <button onclick="event.stopPropagation();addToCartById(${p.id})"
              class="btn-brand w-10 h-10 rounded-full text-on-primary flex items-center justify-center active:scale-90">
              <span class="material-symbols-outlined font-bold">add</span>
            </button>
          </div>
        </div>
      </div>`
  }).join('')
}

/* ── Render: Categorías ─────────────────────────── */
function renderCategories() {
  const cats = allCats()
  const allActive = S.category === 'all'

  const sidebarBtn = (cat, active) => `
    <button onclick="setCategory('${esc(cat)}')"
      class="${active
        ? 'bg-secondary-container text-on-secondary-container font-bold'
        : 'text-on-surface-variant hover:bg-surface-container-high'}
             flex items-center gap-3 px-4 py-3 rounded-lg transition-all w-full text-left font-label-lg text-label-lg">
      <span class="material-symbols-outlined"${active ? " style=\"font-variation-settings:'FILL' 1\"" : ''}>${catIcon(cat)}</span>
      <span>${esc(cat)}</span>
    </button>`

  const chip = (cat, label, icon, active) => `
    <div onclick="setCategory('${esc(cat)}')" class="snap-start shrink-0 flex flex-col items-center gap-2 cursor-pointer">
      <div class="w-16 h-16 rounded-full flex items-center justify-center transition-all active:scale-90 ${active ? 'cat-chip-active' : 'bg-surface-container-high shadow-sm'}">
        <span class="material-symbols-outlined text-[28px] ${active ? '' : 'text-primary'}"
          ${active ? "style=\"font-variation-settings:'FILL' 1\"" : ''}>${icon}</span>
      </div>
      <span class="font-label-md text-label-md text-on-surface text-center leading-tight ${active ? 'font-bold' : ''}">${esc(label)}</span>
    </div>`

  const todosSidebar = `
    <button onclick="setCategory('all')"
      class="${allActive
        ? 'bg-secondary-container text-on-secondary-container font-bold'
        : 'text-on-surface-variant hover:bg-surface-container-high'}
             flex items-center gap-3 px-4 py-3 rounded-lg transition-all w-full text-left font-label-lg text-label-lg">
      <span class="material-symbols-outlined" ${allActive ? "style=\"font-variation-settings:'FILL' 1\"" : ''}>grid_view</span>
      <span>Todos</span>
    </button>`

  const favsActive = S.category === FAVS_CATEGORY
  const favsSidebar = `
    <button onclick="setCategory('${FAVS_CATEGORY}')"
      class="${favsActive
        ? 'bg-secondary-container text-on-secondary-container font-bold'
        : 'text-on-surface-variant hover:bg-surface-container-high'}
             flex items-center gap-3 px-4 py-3 rounded-lg transition-all w-full text-left font-label-lg text-label-lg">
      <span class="material-symbols-outlined text-primary" ${favsActive ? "style=\"font-variation-settings:'FILL' 1\"" : ''}>favorite</span>
      <span>Favoritos</span>
      ${S.favorites.size ? `<span class="ml-auto text-xs font-bold bg-primary text-on-primary rounded-full px-2 py-0.5">${S.favorites.size}</span>` : ''}
    </button>`

  const sidebar = document.getElementById('sidebar-cats')
  if (sidebar) sidebar.innerHTML = todosSidebar + favsSidebar + cats.map(c => sidebarBtn(c, S.category === c)).join('')

  const chipsEl = document.getElementById('mobile-cats')
  if (chipsEl)
    chipsEl.innerHTML =
      chip('all', 'Todos', 'grid_view', allActive) +
      chip(FAVS_CATEGORY, 'Favoritos', 'favorite', favsActive) +
      cats.map(c => chip(c, c, catIcon(c), S.category === c)).join('')
}

/* ── Render: Carrito ────────────────────────────── */
function renderCart() {
  const items       = Object.values(S.cart)
  const emptyEl     = document.getElementById('cart-empty')
  const itemsWrap   = document.getElementById('cart-items-wrap')
  const listEl      = document.getElementById('cart-items-list')
  const countLabel  = document.getElementById('cart-count-label')
  const subtotalEl  = document.getElementById('summary-subtotal')
  const totalEl     = document.getElementById('summary-total')

  const comboValues = Object.values(S.cartCombos)
  const totalEntries = items.length + comboValues.length
  if (countLabel) countLabel.textContent = `${totalEntries} ${totalEntries === 1 ? 'producto' : 'artículos'}`
  if (emptyEl)    emptyEl.classList.toggle('hidden', totalEntries > 0)
  if (itemsWrap)  itemsWrap.classList.toggle('hidden', totalEntries === 0)

  const subtotal = cartSubtotal()
  const discount = cartDiscount()
  const total    = cartTotal()
  const tax      = cartTax()

  if (subtotalEl) subtotalEl.textContent = fmt(subtotal)

  const discountRow = document.getElementById('summary-discount-row')
  const discountEl  = document.getElementById('summary-discount')
  if (discountRow) discountRow.classList.toggle('hidden', discount === 0)
  if (discountEl)  discountEl.textContent = `-${fmt(discount)}`

  const taxEl = document.getElementById('summary-tax')
  if (taxEl) taxEl.textContent = fmt(tax)

  if (totalEl) totalEl.textContent = fmt(total)

  if (!listEl) return

  const productHtml = items.map(({ product: p, qty }) => `
    <div class="bg-surface rounded-xl shadow-[0_4px_12px_rgba(0,0,0,0.02)] p-md flex gap-md items-center border border-outline-variant/20 hover:border-outline-variant/40 transition-colors relative group overflow-hidden">
      <div class="absolute left-0 top-0 bottom-0 w-1 bg-transparent group-hover:bg-primary transition-colors"></div>
      <div class="w-24 h-24 bg-surface-container-low rounded-lg flex-shrink-0 flex items-center justify-center p-2 overflow-hidden">
        ${p.image_url
          ? `<img src="${esc(p.image_url)}" alt="${esc(p.name)}" class="w-full h-full object-contain mix-blend-multiply"/>`
          : `<span class="material-symbols-outlined text-[40px] text-on-surface-variant/25">${catIcon(p.category)}</span>`}
      </div>
      <div class="flex-grow flex flex-col justify-between min-h-[96px]">
        <div class="flex justify-between items-start gap-sm">
          <div>
            <h3 class="font-label-lg text-label-lg text-on-surface font-bold leading-tight">${esc(p.name)}</h3>
            <p class="font-label-md text-label-md text-on-surface-variant mt-xs">${esc(p.category)}</p>
          </div>
          <button onclick="removeFromCart(${p.id})" class="text-outline hover:text-error p-1 -mr-1 rounded-full hover:bg-error-container/20 transition-colors">
            <span class="material-symbols-outlined text-[20px]">delete</span>
          </button>
        </div>
        <div class="flex justify-between items-end mt-sm">
          <span class="font-display text-headline-md font-extrabold text-primary tracking-tight">${fmt(p.price * qty)}</span>
          <div class="flex items-center bg-surface-container rounded-full border border-outline-variant/30 h-10">
            <button onclick="updateQty(${p.id},-1)" class="w-10 h-full flex items-center justify-center text-on-surface hover:bg-surface-variant rounded-l-full transition-colors active:scale-95">
              <span class="material-symbols-outlined text-[18px]">remove</span>
            </button>
            <span class="w-8 text-center font-label-lg text-label-lg font-bold text-on-surface">${qty}</span>
            <button onclick="updateQty(${p.id},1)" class="w-10 h-full flex items-center justify-center text-on-surface hover:bg-surface-variant rounded-r-full transition-colors active:scale-95">
              <span class="material-symbols-outlined text-[18px]">add</span>
            </button>
          </div>
        </div>
      </div>
    </div>`).join('')

  const comboHtml = Object.values(S.cartCombos).map(({ combo, qty }) => `
    <div class="bg-surface rounded-xl shadow-[0_4px_12px_rgba(0,0,0,0.02)] p-md flex gap-md items-center border border-purple-200 relative group overflow-hidden">
      <div class="absolute left-0 top-0 bottom-0 w-1 bg-purple-400"></div>
      <div class="w-24 h-24 bg-purple-50 rounded-lg flex-shrink-0 flex items-center justify-center">
        <span class="material-symbols-outlined text-[40px] text-purple-400" style="font-variation-settings:'FILL' 1">dining</span>
      </div>
      <div class="flex-grow flex flex-col justify-between min-h-[96px]">
        <div class="flex justify-between items-start gap-sm">
          <div>
            <span class="inline-block text-[10px] font-bold px-2 py-0.5 rounded-full bg-purple-100 text-purple-800 mb-1">COMBO</span>
            <h3 class="font-label-lg text-label-lg text-on-surface font-bold leading-tight">${esc(combo.name)}</h3>
            <p class="text-xs text-on-surface-variant mt-0.5">${(combo.items||[]).map(ci=>`${ci.product_name} x${ci.quantity}`).join(' · ')}</p>
          </div>
          <button onclick="removeComboFromCart(${combo.id})" class="text-outline hover:text-error p-1 -mr-1 rounded-full hover:bg-error-container/20 transition-colors">
            <span class="material-symbols-outlined text-[20px]">delete</span>
          </button>
        </div>
        <div class="flex justify-between items-end mt-sm">
          <span class="font-display text-headline-md font-extrabold text-primary tracking-tight">${fmt(combo.price * qty)}</span>
          <div class="flex items-center bg-surface-container rounded-full border border-outline-variant/30 h-10">
            <button onclick="updateComboQty(${combo.id},-1)" class="w-10 h-full flex items-center justify-center text-on-surface hover:bg-surface-variant rounded-l-full transition-colors active:scale-95">
              <span class="material-symbols-outlined text-[18px]">remove</span>
            </button>
            <span class="w-8 text-center font-label-lg text-label-lg font-bold text-on-surface">${qty}</span>
            <button onclick="updateComboQty(${combo.id},1)" class="w-10 h-full flex items-center justify-center text-on-surface hover:bg-surface-variant rounded-r-full transition-colors active:scale-95">
              <span class="material-symbols-outlined text-[18px]">add</span>
            </button>
          </div>
        </div>
      </div>
    </div>`).join('')

  listEl.innerHTML = productHtml + comboHtml
}

/* ── Badge carrito ──────────────────────────────── */
function updateBadge() {
  const count = cartCount()
  document.querySelectorAll('.cart-badge').forEach(el => {
    el.textContent = count
    el.classList.toggle('hidden', count === 0)
    el.classList.remove('scale-125')
    void el.offsetWidth
    el.classList.add('scale-125')
    setTimeout(() => el.classList.remove('scale-125'), 200)
  })
}

/* ── Navegación entre vistas ────────────────────── */
function showView(name) {
  document.getElementById('view-store').classList.toggle('hidden', name !== 'store')
  document.getElementById('view-cart').classList.toggle('hidden', name !== 'cart')
  const offersEl = document.getElementById('view-offers')
  if (offersEl) offersEl.classList.toggle('hidden', name !== 'offers')
  const combosEl = document.getElementById('view-combos')
  if (combosEl) combosEl.classList.toggle('hidden', name !== 'combos')

  document.querySelectorAll('[data-nav]').forEach(btn => {
    const active = btn.dataset.nav === name
    btn.classList.toggle('bg-secondary-container',    active)
    btn.classList.toggle('text-on-secondary-container', active)
    btn.classList.toggle('rounded-full',              active)
    btn.classList.toggle('px-4',                      active)
    btn.classList.toggle('font-bold',                 active)
    btn.classList.toggle('text-on-surface-variant',   !active)
  })

  if (name === 'cart') renderCart()
  if (name === 'offers') loadClientOffers()
  if (name === 'combos') loadClientCombos()
  window.scrollTo(0, 0)
}

const showStore  = () => showView('store')
const showCart   = () => showView('cart')
const showOffers = () => showView('offers')
const showCombos = () => showView('combos')

/* ── Ofertas cliente ─────────────────────────────── */
async function loadClientOffers() {
  const grid = document.getElementById('client-offers-grid')
  if (!grid) return
  grid.innerHTML = '<div class="col-span-full py-10 text-center text-on-surface-variant text-sm">Cargando ofertas...</div>'
  try {
    const branchId = S.branch?.id
    const q = branchId ? `?branch_id=${branchId}` : ''
    const res = await fetch(`/api/branches/offers${q}`)
    const items = await res.json()
    if (!res.ok) throw new Error(items.error || 'Error')
    S.offers = items
    renderClientOffers()
    renderClientOffersRow()
  } catch {
    grid.innerHTML = '<div class="col-span-full py-8 text-center text-on-surface-variant text-sm">Sin ofertas disponibles.</div>'
  }
}

function renderClientOffers() {
  const grid = document.getElementById('client-offers-grid')
  if (!grid) return
  if (!S.offers?.length) {
    grid.innerHTML = '<div class="col-span-full py-8 text-center text-on-surface-variant text-sm">Sin ofertas disponibles.</div>'
    return
  }
  grid.innerHTML = S.offers.map(item => {
    const price = item.effective_price ?? item.price ?? 0
    const disc  = item.effective_discount ?? item.discount_pct ?? 0
    const badge = item.offer_badge ? `<span class="absolute top-2 left-2 z-10 text-xs font-bold px-2 py-0.5 rounded-full bg-amber-400 text-black">${item.offer_badge}</span>` : ''
    const imgHtml = item.image_url
      ? `<img src="${item.image_url}" alt="${item.name}" class="w-full h-36 object-cover rounded-t-2xl">`
      : `<div class="w-full h-36 bg-surface-container flex items-center justify-center rounded-t-2xl"><span class="material-symbols-outlined text-5xl text-outline">inventory_2</span></div>`
    return `
      <div class="relative bg-surface-container-lowest rounded-2xl overflow-hidden border border-outline-variant/30 flex flex-col active:scale-[0.98] transition-transform">
        ${badge}
        ${imgHtml}
        <div class="p-3 flex flex-col gap-1.5 flex-1">
          <p class="font-semibold text-on-surface text-sm leading-snug line-clamp-2">${item.name || '—'}</p>
          <div class="flex items-center gap-2 mt-auto">
            <span class="text-primary font-bold text-base">$${price.toFixed(2)}</span>
            ${disc > 0 ? `<span class="text-xs font-semibold text-green-700 bg-green-100 px-2 py-0.5 rounded-full">-${disc}%</span>` : ''}
          </div>
          <button onclick="addToCartById(${item.product_id ?? item.id})"
            class="mt-1 w-full btn-brand text-on-primary text-xs font-bold py-2 rounded-xl">
            Agregar
          </button>
        </div>
      </div>`
  }).join('')
}

/* ── Combos cliente ──────────────────────────────── */
async function loadClientCombos() {
  const grid = document.getElementById('client-combos-grid')
  if (!grid) return
  grid.innerHTML = '<div class="col-span-full py-10 text-center text-on-surface-variant text-sm">Cargando combos...</div>'
  try {
    const branchId = S.branch?.id
    const q = branchId ? `?branch_id=${branchId}` : ''
    const res = await fetch(`/api/combos/${q}`)
    const items = await res.json()
    if (!res.ok) throw new Error(items.error || 'Error')
    S.combos = items
    renderClientCombos()
    renderClientCombosRow()
  } catch {
    if (grid) grid.innerHTML = '<div class="col-span-full py-8 text-center text-on-surface-variant text-sm">Sin combos disponibles.</div>'
  }
}

function _comboCardHtml(combo, compact = false) {
  const imgHtml = combo.image_url
    ? `<img src="${combo.image_url}" alt="${combo.name}" class="w-full ${compact ? 'h-24' : 'h-36'} object-cover ${compact ? 'rounded-t-xl' : 'rounded-t-2xl'}">`
    : `<div class="w-full ${compact ? 'h-24' : 'h-36'} bg-purple-50 flex items-center justify-center ${compact ? 'rounded-t-xl' : 'rounded-t-2xl'}">
         <span class="material-symbols-outlined ${compact ? 'text-3xl' : 'text-5xl'} text-purple-400" style="font-variation-settings:'FILL' 1">dining</span>
       </div>`
  const productsList = (combo.items || []).map(ci => `${ci.product_name} x${ci.quantity}`).join(' · ')
  return `
    <div class="relative ${compact ? 'flex-shrink-0 w-44' : ''} bg-surface-container-lowest rounded-${compact?'xl':'2xl'} overflow-hidden border border-purple-100 flex flex-col active:scale-[0.98] transition-transform">
      <span class="absolute top-2 left-2 z-10 text-[10px] font-bold px-2 py-0.5 rounded-full bg-purple-600 text-white">COMBO</span>
      ${imgHtml}
      <div class="p-${compact?'2':'3'} flex flex-col gap-1.5 flex-1">
        <p class="font-semibold text-on-surface text-${compact?'xs':'sm'} leading-snug line-clamp-2">${combo.name}</p>
        ${!compact && combo.description ? `<p class="text-xs text-on-surface-variant">${combo.description}</p>` : ''}
        <p class="text-[10px] text-on-surface-variant line-clamp-1">${productsList}</p>
        <div class="flex items-center justify-between mt-auto pt-1">
          <span class="text-primary font-bold text-${compact?'sm':'base'}">${fmt(combo.price)}</span>
        </div>
        <button onclick='addComboToCart(${JSON.stringify(combo)})'
          class="w-full btn-brand text-on-primary text-${compact?'[10px]':'xs'} font-bold py-${compact?'1.5':'2'} rounded-${compact?'lg':'xl'}">
          Agregar combo
        </button>
      </div>
    </div>`
}

function renderClientCombos() {
  const grid = document.getElementById('client-combos-grid')
  if (!grid) return
  if (!S.combos?.length) {
    grid.innerHTML = '<div class="col-span-full py-8 text-center text-on-surface-variant text-sm">Sin combos disponibles.</div>'
    return
  }
  grid.innerHTML = S.combos.map(c => _comboCardHtml(c)).join('')
}

function renderClientCombosRow() {
  const row = document.getElementById('combos-row')
  const section = document.getElementById('combos-preview-section')
  if (!row || !S.combos?.length) {
    if (section) section.classList.add('hidden')
    return
  }
  if (section) section.classList.remove('hidden')
  row.innerHTML = S.combos.slice(0, 6).map(c => _comboCardHtml(c, true)).join('')
}

function renderClientOffersRow() {
  const row = document.getElementById('offers-row')
  if (!row || !S.offers?.length) {
    const section = document.getElementById('offers-preview-section')
    if (section) section.classList.add('hidden')
    return
  }
  const section = document.getElementById('offers-preview-section')
  if (section) section.classList.remove('hidden')
  row.innerHTML = S.offers.slice(0, 8).map(item => {
    const price = item.effective_price ?? item.price ?? 0
    const disc  = item.effective_discount ?? item.discount_pct ?? 0
    const badge = item.offer_badge ? `<span class="absolute top-1.5 left-1.5 text-[10px] font-bold px-1.5 py-0.5 rounded-full bg-amber-400 text-black leading-none">${item.offer_badge}</span>` : ''
    const imgHtml = item.image_url
      ? `<img src="${item.image_url}" alt="${item.name}" class="w-full h-24 object-cover rounded-t-xl">`
      : `<div class="w-full h-24 bg-surface-container flex items-center justify-center rounded-t-xl"><span class="material-symbols-outlined text-3xl text-outline">inventory_2</span></div>`
    return `
      <div class="relative flex-shrink-0 w-36 bg-surface-container-lowest rounded-xl overflow-hidden border border-outline-variant/30 flex flex-col active:scale-[0.98] transition-transform">
        ${badge}
        ${imgHtml}
        <div class="p-2 flex flex-col gap-1 flex-1">
          <p class="font-medium text-on-surface text-xs leading-snug line-clamp-2">${item.name || '—'}</p>
          <div class="flex items-center gap-1 flex-wrap">
            <span class="text-primary font-bold text-sm">$${price.toFixed(2)}</span>
            ${disc > 0 ? `<span class="text-[10px] font-semibold text-green-700 bg-green-100 px-1.5 py-0.5 rounded-full">-${disc}%</span>` : ''}
          </div>
          <button onclick="addToCartById(${item.product_id ?? item.id})"
            class="mt-auto w-full btn-brand text-on-primary text-[10px] font-bold py-1.5 rounded-lg">
            Agregar
          </button>
        </div>
      </div>`
  }).join('')
}

function resetFilters() {
  S.category = 'all'
  S.search = ''
  const d = document.getElementById('search-input'); if (d) d.value = ''
  const m = document.getElementById('search-mobile'); if (m) m.value = ''
  renderCategories()
  renderProducts()
}

/* ── Categorías ─────────────────────────────────── */
function setCategory(cat) {
  S.category = cat
  renderCategories()
  renderProducts()
  if (window.innerWidth < 1024)
    document.getElementById('products-section')?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

/* ── Checkout modal ─────────────────────────────── */
let _method     = 'efectivo'
let _processing = false

const METHOD_ACTIVE   = 'flex flex-col items-center gap-1 py-3 rounded-xl border-2 border-primary bg-primary/10 text-primary transition-all cursor-pointer'
const METHOD_INACTIVE = 'flex flex-col items-center gap-1 py-3 rounded-xl border-2 border-surface-variant bg-surface-container text-on-surface-variant transition-all cursor-pointer'

function openCheckout() {
  if (!cartCount()) return
  _method     = 'efectivo'
  _processing = false

  // Limpiar formulario
  ;['checkout-name','cash-amount','card-number','card-holder','card-expiry','card-cvv']
    .forEach(id => { const el = document.getElementById(id); if (el) el.value = '' })

  // Pre-fill name from Google profile if signed in
  const savedName = localStorage.getItem('customer_display_name')
  const nameEl = document.getElementById('checkout-name')
  if (savedName && nameEl) nameEl.value = savedName
  document.getElementById('change-display')?.classList.add('hidden')
  document.getElementById('insuf-display')?.classList.add('hidden')
  const subtotal = cartSubtotal()
  const discount = cartDiscount()
  const total    = cartTotal()
  const tax      = cartTax()

  document.getElementById('checkout-subtotal').textContent = fmt(subtotal)
  document.getElementById('checkout-total').textContent    = fmt(total)
  document.getElementById('checkout-tax').textContent      = fmt(tax)

  const dRow = document.getElementById('checkout-discount-row')
  const dEl  = document.getElementById('checkout-discount')
  if (dRow) dRow.classList.toggle('hidden', discount === 0)
  if (dEl)  dEl.textContent = `-${fmt(discount)}`

  updateMethodUI()
  document.getElementById('modal-checkout').classList.remove('hidden')
  document.body.style.overflow = 'hidden'
}

function closeCheckout() {
  document.getElementById('modal-checkout').classList.add('hidden')
  document.body.style.overflow = ''
}

function selectMethod(m) {
  _method = m
  updateMethodUI()
}

function updateMethodUI() {
  document.querySelectorAll('[data-method]').forEach(btn => {
    btn.className = btn.dataset.method === _method ? METHOD_ACTIVE : METHOD_INACTIVE
  })
  document.getElementById('cash-section')?.classList.toggle('hidden', _method !== 'efectivo')
  document.getElementById('card-section')?.classList.toggle('hidden', _method !== 'tarjeta')
}

function onCashInput() {
  const received = parseFloat(document.getElementById('cash-amount').value) || 0
  const total    = cartTotal()
  const cashVal  = document.getElementById('cash-amount').value

  if (!cashVal) {
    document.getElementById('change-display')?.classList.add('hidden')
    document.getElementById('insuf-display')?.classList.add('hidden')
    return
  }
  if (received >= total) {
    document.getElementById('change-display')?.classList.remove('hidden')
    document.getElementById('insuf-display')?.classList.add('hidden')
    const changeEl = document.getElementById('change-amount')
    if (changeEl) changeEl.textContent = fmt(received - total)
  } else {
    document.getElementById('change-display')?.classList.add('hidden')
    document.getElementById('insuf-display')?.classList.remove('hidden')
    const missingEl = document.getElementById('missing-amount')
    if (missingEl) missingEl.textContent = fmt(total - received)
  }
}

async function confirmCheckout() {
  if (_processing) return

  if (_method === 'efectivo') {
    const cashVal = document.getElementById('cash-amount').value
    if (cashVal && parseFloat(cashVal) < cartTotal()) {
      toast('El monto recibido es menor al total', 'error'); return
    }
  }

  if (_method === 'tarjeta') {
    const num    = (document.getElementById('card-number').value || '').replace(/\s/g, '')
    const holder = (document.getElementById('card-holder').value || '').trim()
    const exp    = document.getElementById('card-expiry').value || ''
    const cvv    = document.getElementById('card-cvv').value || ''
    if (num.length < 16 || !holder || exp.length < 5 || cvv.length < 3) {
      toast('Completa todos los datos de la tarjeta', 'error'); return
    }
  }

  const productItems = Object.values(S.cart).map(({ product, qty }) => ({ product_id: product.id, quantity: qty }))
  const comboItems = Object.values(S.cartCombos).flatMap(({ combo, qty }) => {
    const naturalTotal = (combo.items || []).reduce((s, ci) => s + (ci.product_price || 0) * ci.quantity, 0)
    return (combo.items || []).map(ci => ({
      product_id: ci.product_id,
      quantity: ci.quantity * qty,
      ...(naturalTotal > 0 && {
        price_override: +((combo.price * (ci.product_price * ci.quantity) / naturalTotal) / ci.quantity).toFixed(4),
      }),
    }))
  })
  const items = [...productItems, ...comboItems]
  _processing = true

  const btn = document.getElementById('confirm-btn')
  if (btn) { btn.disabled = true; btn.textContent = 'Procesando...' }

  try {
    const sale = await postSale({
      items,
      client_name:    (document.getElementById('checkout-name').value || '').trim(),
      payment_method: _method,
      ...(S.branch && { branch_id: S.branch.id }),
    })
    saveMyOrder(sale)
    closeCheckout()
    clearCart()
    showStore()
    renderProducts()
    toast('Compra realizada con exito', 'success')
  } catch (e) {
    toast(e.message, 'error')
  } finally {
    _processing = false
    if (btn) {
      btn.disabled = false
      btn.innerHTML = 'Confirmar compra <span class="material-symbols-outlined text-[20px]">arrow_forward</span>'
    }
  }
}

/* ── Mis pedidos (historial local del dispositivo) ─ */
const ORDERS_KEY = 'oxxo_orders'

function saveMyOrder(sale) {
  if (!sale) return
  const orders = JSON.parse(localStorage.getItem(ORDERS_KEY) || '[]')
  orders.unshift({
    id: sale.id,
    date: sale.created_at || new Date().toISOString(),
    total: sale.total_amount,
    method: sale.payment_method || _method,
    items: (sale.items || []).map(i => ({ name: i.product_name, qty: i.quantity })),
  })
  localStorage.setItem(ORDERS_KEY, JSON.stringify(orders.slice(0, 20)))
}

const PAY_ICONS = { efectivo: 'payments', tarjeta: 'credit_card', transferencia: 'account_balance' }

function renderMyOrders() {
  const section = document.getElementById('my-orders')
  const list = document.getElementById('orders-list')
  if (!section || !list) return
  const orders = JSON.parse(localStorage.getItem(ORDERS_KEY) || '[]')
  section.classList.toggle('hidden', orders.length === 0)
  if (!orders.length) return
  list.innerHTML = orders.slice(0, 5).map(o => `
    <div class="flex items-center gap-3 py-2.5 border-b border-outline-variant/20 last:border-b-0">
      <div class="w-9 h-9 rounded-xl bg-surface-container flex items-center justify-center flex-shrink-0">
        <span class="material-symbols-outlined text-primary text-[18px]">${PAY_ICONS[o.method] || 'receipt_long'}</span>
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-[13px] font-bold text-on-surface truncate">
          ${o.id ? `Pedido #${String(o.id).padStart(4, '0')}` : 'Pedido'}
          <span class="font-normal text-on-surface-variant">· ${new Date(o.date).toLocaleDateString('es-MX', { day: 'numeric', month: 'short' })}</span>
        </p>
        <p class="text-[12px] text-on-surface-variant truncate">${o.items.map(i => `${esc(i.name)} x${i.qty}`).join(', ')}</p>
      </div>
      <span class="font-display text-[15px] font-extrabold text-primary flex-shrink-0">${fmt(o.total)}</span>
    </div>`).join('')
}

/* ── Toast ──────────────────────────────────────── */
function toast(msg, type = 'success') {
  UI.toast(msg, type)
}

/* ── Formatters de tarjeta ──────────────────────── */
function fmtCardNum(inp) {
  const v = inp.value.replace(/\D/g, '').slice(0, 16)
  inp.value = v.match(/.{1,4}/g)?.join(' ') ?? v
}

function fmtExpiry(inp) {
  let v = inp.value.replace(/\D/g, '').slice(0, 4)
  if (v.length > 2) v = v.slice(0, 2) + '/' + v.slice(2)
  inp.value = v
}

/* ── Hero Slider ────────────────────────────────── */
const slider = { current: 0, total: 4, timer: null }

function goToSlide(i, instant = false) {
  slider.current = ((i % slider.total) + slider.total) % slider.total
  document.querySelectorAll('.hero-slide').forEach((slide, idx) => {
    slide.style.transition = instant ? 'none' : 'transform 0.5s cubic-bezier(0.25,0.46,0.45,0.94)'
    slide.style.transform   = `translateX(${(idx - slider.current) * 100}%)`
    slide.classList.toggle('slide-active', idx === slider.current)
  })
  updateDots()
}

function nextSlide() {
  const next = (slider.current + 1) % slider.total
  if (next === 0) {
    // Wrap-around: instant reset luego smooth al primero
    goToSlide(slider.current + 1, true)   // posición sin animación
    requestAnimationFrame(() => requestAnimationFrame(() => goToSlide(0)))
  } else {
    goToSlide(next)
  }
  resetTimer()
}

function prevSlide() {
  goToSlide(slider.current - 1)
  resetTimer()
}

function updateDots() {
  document.querySelectorAll('.hero-dot').forEach((dot, i) => {
    if (i === slider.current) {
      dot.style.width = '24px'; dot.style.height = '6px'
      dot.style.background = 'white'; dot.style.opacity = '1'
    } else {
      dot.style.width = '6px'; dot.style.height = '6px'
      dot.style.background = 'white'; dot.style.opacity = '0.5'
    }
  })
}

function resetTimer() {
  clearInterval(slider.timer)
  slider.timer = setInterval(nextSlide, 4500)
}

function pauseSlider()  { clearInterval(slider.timer) }
function resumeSlider() { resetTimer() }

function initSlider() {
  document.querySelector('.hero-slide')?.classList.add('slide-active')
  updateDots()
  resetTimer()
}

/* ── Chatbot ────────────────────────────────────── */
const chatState = { open: false, loading: false }

function toggleChat() {
  chatState.open = !chatState.open
  const panel   = document.getElementById('chat-panel')
  const fab     = document.getElementById('chat-fab')
  const fabIcon = document.getElementById('chat-fab-icon')
  panel.classList.toggle('hidden', !chatState.open)
  if (fab) fab.classList.toggle('chat-open', chatState.open)
  if (fabIcon) fabIcon.textContent = chatState.open ? 'close' : 'chat'
  if (chatState.open) {
    document.getElementById('chat-input')?.focus()
    scrollChatBottom()
  }
}

function scrollChatBottom() {
  const el = document.getElementById('chat-messages')
  if (el) el.scrollTop = el.scrollHeight
}

function appendChatMsg(role, text) {
  const msgs = document.getElementById('chat-messages')
  if (!msgs) return
  const isUser = role === 'user'
  const div = document.createElement('div')
  div.className = `flex gap-2 items-end ${isUser ? 'flex-row-reverse chat-msg-user' : 'chat-msg-ai'}`
  div.innerHTML = isUser
    ? `<div class="bg-primary text-on-primary rounded-2xl rounded-br-sm px-3 py-2 max-w-[82%] shadow-sm">
         <p class="text-[13px] leading-relaxed">${esc(text)}</p>
       </div>`
    : `<div class="w-7 h-7 bg-primary rounded-full flex-shrink-0 flex items-center justify-center mb-0.5">
         <span class="material-symbols-outlined text-on-primary text-[14px]" style="font-variation-settings:'FILL' 1">smart_toy</span>
       </div>
       <div class="bg-surface-container rounded-2xl rounded-bl-sm px-3 py-2 max-w-[82%] shadow-sm">
         <p class="text-on-surface text-[13px] leading-relaxed">${esc(text)}</p>
       </div>`
  msgs.appendChild(div)
  scrollChatBottom()
}

function showTypingIndicator() {
  const msgs = document.getElementById('chat-messages')
  if (!msgs) return
  const div = document.createElement('div')
  div.id = 'chat-typing'
  div.className = 'flex gap-2 items-end'
  div.innerHTML = `
    <div class="w-7 h-7 bg-primary rounded-full flex-shrink-0 flex items-center justify-center mb-0.5">
      <span class="material-symbols-outlined text-on-primary text-[14px]" style="font-variation-settings:'FILL' 1">smart_toy</span>
    </div>
    <div class="bg-surface-container rounded-2xl rounded-bl-sm px-4 py-3 shadow-sm">
      <div class="flex gap-1.5 items-center h-4">
        <span class="w-2 h-2 bg-on-surface-variant/50 rounded-full animate-bounce" style="animation-delay:0ms"></span>
        <span class="w-2 h-2 bg-on-surface-variant/50 rounded-full animate-bounce" style="animation-delay:150ms"></span>
        <span class="w-2 h-2 bg-on-surface-variant/50 rounded-full animate-bounce" style="animation-delay:300ms"></span>
      </div>
    </div>`
  msgs.appendChild(div)
  scrollChatBottom()
}

function hideTypingIndicator() {
  const el = document.getElementById('chat-typing')
  if (!el) return
  el.classList.add('msg-leaving')
  setTimeout(() => el.remove(), 160)
}

function useSuggestion(text) {
  const input = document.getElementById('chat-input')
  if (input) { input.value = text; input.focus() }
  document.getElementById('chat-suggestions')?.classList.add('hidden')
  sendChatMessage()
}

async function sendChatMessage() {
  if (chatState.loading) return
  const input = document.getElementById('chat-input')
  const msg   = input?.value.trim()
  if (!msg) return

  input.value = ''
  appendChatMsg('user', msg)

  const sendBtn = document.getElementById('chat-send-btn')
  chatState.loading = true
  if (sendBtn) {
    sendBtn.disabled = true
    sendBtn.classList.add('is-sending')
    setTimeout(() => sendBtn.classList.remove('is-sending'), 500)
  }

  showTypingIndicator()

  try {
    const res  = await fetch('/tienda/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: msg, ...(S.branch && { branch_id: S.branch.id }) }),
    })
    const data = await res.json()
    hideTypingIndicator()
    appendChatMsg('ai', data.response || data.error || 'Sin respuesta del asistente')
  } catch {
    hideTypingIndicator()
    appendChatMsg('ai', 'Ocurrió un error de conexión. Intenta de nuevo.')
  } finally {
    chatState.loading = false
    if (sendBtn) sendBtn.disabled = false
    input?.focus()
  }
}

/* ── Selector de sucursal con mapa Leaflet ──────── */
let _leafletMap    = null
let _branchMarkers = {}
let _branchMapData = []

async function openBranchSelector() {
  const modal = document.getElementById('modal-branch-selector')
  modal.classList.remove('hidden')
  modal.classList.add('flex')
  document.body.style.overflow = 'hidden'
  _loadBranchesForMap()
}

function closeBranchSelector() {
  const modal = document.getElementById('modal-branch-selector')
  modal.classList.add('hidden')
  modal.classList.remove('flex')
  document.body.style.overflow = ''
}

async function _loadBranchesForMap() {
  const list = document.getElementById('branch-selector-list')
  list.innerHTML = '<p class="text-center text-on-surface-variant text-sm py-6">Cargando tiendas...</p>'
  try {
    const branches = await (await fetch('/api/branches/?active_only=true')).json()
    if (!Array.isArray(branches)) throw new Error()
    _branchMapData = branches
    const ratings = await Promise.all(
      branches.map(b =>
        fetch(`/api/branches/${b.id}/reviews`)
          .then(r => r.json())
          .then(d => ({ id: b.id, avg: d.average_rating || 0, count: d.total_reviews || 0 }))
          .catch(() => ({ id: b.id, avg: 0, count: 0 }))
      )
    )
    S.branchRatings = Object.fromEntries(ratings.map(r => [r.id, r]))
    _renderBranchMapList()
    _initOrUpdateMap()
  } catch {
    list.innerHTML = '<p class="text-center text-error text-sm py-6">Error al cargar tiendas.</p>'
  }
}

function _renderBranchMapList() {
  // "Todas" button state
  const allBtn = document.getElementById('branch-selector-all')
  const isAllSel = S.branch === null
  if (allBtn) {
    allBtn.className = `w-full text-left px-4 py-3 border-b border-outline-variant/20 flex items-center gap-3 transition-colors flex-shrink-0 ${isAllSel ? 'bg-primary/5' : 'hover:bg-surface-container'}`
    allBtn.querySelector('.branch-all-check')?.classList.toggle('hidden', !isAllSel)
  }

  const list = document.getElementById('branch-selector-list')
  if (!list) return
  list.innerHTML = _branchMapData.map(b => _branchCardHtml(b)).join('')
}

function _branchCardHtml(b) {
  const isSelected = S.branch?.id === b.id
  const rating     = S.branchRatings[b.id]
  const ratingRow  = (rating && rating.count > 0)
    ? `<div class="flex items-center gap-0.5 mt-1">
         ${starsHtml(rating.avg, 11)}
         <span class="text-[10px] text-on-surface-variant ml-0.5">${rating.avg.toFixed(1)} (${rating.count})</span>
       </div>` : ''
  const addr = [b.address, b.city].filter(Boolean).join(', ')
  return `
    <button id="branch-card-${b.id}" onclick="_selectBranchOnMap(${b.id})"
      class="w-full text-left p-3 rounded-xl border transition-all active:scale-[0.98]
        ${isSelected ? 'border-primary bg-primary/5' : 'border-outline-variant/40 hover:border-primary/40 hover:bg-surface-container-high'}">
      <div class="flex items-start gap-2">
        <span class="material-symbols-outlined text-primary text-[18px] mt-0.5 flex-shrink-0"
          style="font-variation-settings:'FILL' ${isSelected ? 1 : 0}">storefront</span>
        <div class="flex-1 min-w-0">
          <p class="font-semibold text-on-surface text-sm leading-tight">${esc(b.name)}</p>
          ${addr ? `<p class="text-on-surface-variant text-xs mt-0.5 truncate">${esc(addr)}</p>` : ''}
          ${b.opening_time ? `<p class="text-on-surface-variant text-xs mt-0.5">
            <span class="material-symbols-outlined text-[12px] align-middle">schedule</span>
            ${esc(b.opening_time)} – ${esc(b.closing_time)}</p>` : ''}
          ${ratingRow}
          ${isSelected ? `
          <div class="flex gap-2 mt-2">
            <button onclick="event.stopPropagation();selectBranch(${b.id})"
              class="flex-1 btn-brand text-on-primary text-xs font-bold py-2 rounded-lg">
              Ir a esta tienda
            </button>
            <button onclick="event.stopPropagation();openBranchReviewModal(${b.id})"
              class="px-3 py-2 rounded-lg border border-primary text-primary text-xs font-semibold hover:bg-primary/5 transition-colors">
              <span class="material-symbols-outlined text-[14px]">rate_review</span>
            </button>
          </div>` : ''}
        </div>
        ${isSelected ? `<span class="material-symbols-outlined text-primary text-lg flex-shrink-0"
          style="font-variation-settings:'FILL' 1">check_circle</span>` : ''}
      </div>
    </button>`
}

function _markerIcon(active) {
  const size = active ? 46 : 36
  return L.divIcon({
    className: '',
    html: `<div class="branch-map-marker${active ? ' active' : ''}">
             <span class="material-symbols-outlined">storefront</span>
           </div>`,
    iconSize:   [size, size],
    iconAnchor: [size / 2, size / 2],
  })
}

function _initOrUpdateMap() {
  const withGeo = _branchMapData.filter(b => b.latitude && b.longitude)
  const noMapEl = document.getElementById('branch-no-map')

  if (!withGeo.length) {
    if (noMapEl) noMapEl.classList.remove('hidden')
    return
  }
  if (noMapEl) noMapEl.classList.add('hidden')

  if (!_leafletMap) {
    _leafletMap = L.map('branch-leaflet-map', { zoomControl: true })
      .setView([withGeo[0].latitude, withGeo[0].longitude], 12)
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap',
      maxZoom: 19,
    }).addTo(_leafletMap)
  }

  // Limpiar marcadores anteriores
  Object.values(_branchMarkers).forEach(m => m.remove())
  _branchMarkers = {}

  withGeo.forEach(b => {
    const isActive = S.branch?.id === b.id
    const marker = L.marker([b.latitude, b.longitude], { icon: _markerIcon(isActive) })
      .addTo(_leafletMap)
    marker.on('click', () => _selectBranchOnMap(b.id))
    _branchMarkers[b.id] = marker
  })

  if (withGeo.length > 1) {
    _leafletMap.fitBounds(withGeo.map(b => [b.latitude, b.longitude]), { padding: [40, 40] })
  } else {
    _leafletMap.setView([withGeo[0].latitude, withGeo[0].longitude], 14)
  }

  setTimeout(() => _leafletMap?.invalidateSize(), 250)
}

function _selectBranchOnMap(branchId) {
  // Actualizar tarjetas de la lista
  _branchMapData.forEach(b => {
    const card = document.getElementById(`branch-card-${b.id}`)
    if (!card) return
    // Simular S.branch para el render
    const prevBranch = S.branch
    S.branch = { id: branchId }
    card.outerHTML = _branchCardHtml(b)
    S.branch = prevBranch
  })

  // Re-seleccionar los nodos (outerHTML los reemplaza)
  const targetCard = document.getElementById(`branch-card-${branchId}`)
  if (targetCard) targetCard.scrollIntoView({ behavior: 'smooth', block: 'nearest' })

  // Actualizar marcadores
  Object.entries(_branchMarkers).forEach(([id, marker]) => {
    marker.setIcon(_markerIcon(parseInt(id) === branchId))
  })

  // Volar al marcador
  const branch = _branchMapData.find(b => b.id === branchId)
  if (branch?.latitude && branch?.longitude && _leafletMap) {
    _leafletMap.flyTo([branch.latitude, branch.longitude], 15, { duration: 0.7 })
  }

  // Deseleccionar "Todas"
  const allBtn = document.getElementById('branch-selector-all')
  if (allBtn) {
    allBtn.className = 'w-full text-left px-4 py-3 border-b border-outline-variant/20 flex items-center gap-3 transition-colors flex-shrink-0 hover:bg-surface-container'
    allBtn.querySelector('.branch-all-check')?.classList.add('hidden')
  }
}

function selectBranch(branchId) {
  if (branchId === null || branchId === 'null') {
    S.branch = null
    document.getElementById('branch-label-text').textContent = 'Todas las tiendas'
    _updateBranchRatingBar(null)
    closeBranchSelector()
    S.category = 'all'
    S.search   = ''
    loadProducts()
    loadClientOffers()
    loadClientCombos()
  } else {
    fetch(`/api/branches/${branchId}`)
      .then(r => r.json())
      .then(b => {
        S.branch = b
        document.getElementById('branch-label-text').textContent = b.name
        _updateBranchRatingBar(branchId)
      })
      .catch(() => {
        S.branch = { id: branchId, name: `Tienda #${branchId}` }
        document.getElementById('branch-label-text').textContent = S.branch.name
      })
      .finally(() => {
        closeBranchSelector()
        S.category = 'all'
        S.search   = ''
        loadProducts()
        loadClientOffers()
        loadClientCombos()
      })
  }
}

function _updateBranchRatingBar(branchId) {
  const el = document.getElementById('branch-rating-stars')
  if (!el) return
  const r = branchId ? S.branchRatings[branchId] : null
  if (r && r.count > 0) {
    el.innerHTML = starsHtml(r.avg, 11) + `<span class="ml-0.5 text-[10px] text-on-surface-variant">${r.avg.toFixed(1)}</span>`
    el.classList.remove('hidden')
  } else {
    el.classList.add('hidden')
  }
}

/* ── Reseñas de producto ─────────────────────────── */
let _reviewProductId = null
let _selectedRating  = 0

async function openProductReviewModal(productId) {
  _reviewProductId = productId
  _selectedRating  = 0
  const product = S.products.find(p => p.id === productId)
  document.getElementById('review-modal-title').textContent = product?.name || 'Reseñas'
  const modal = document.getElementById('modal-product-review')
  modal.classList.remove('hidden')
  modal.classList.add('flex')
  document.body.style.overflow = 'hidden'
  await _loadProductReviews(productId)
}

function closeProductReviewModal() {
  document.getElementById('modal-product-review')?.classList.replace('flex', 'hidden')
  document.body.style.overflow = ''
}

async function _loadProductReviews(pid) {
  const list = document.getElementById('review-list')
  if (!list) return
  list.innerHTML = '<p class="text-center text-sm text-on-surface-variant py-4">Cargando...</p>'
  try {
    const data = await (await fetch(`/api/products/${pid}/reviews`)).json()
    list.innerHTML = data.reviews.length
      ? data.reviews.map(r => _reviewItemHtml(r)).join('')
      : '<p class="text-center text-sm text-on-surface-variant py-6">Sin reseñas aún. ¡Sé el primero!</p>'
    const token = localStorage.getItem('customer_token')
    document.getElementById('review-form')?.classList.toggle('hidden', !token)
    document.getElementById('review-login-hint')?.classList.toggle('hidden', !!token)
    _renderStarSelector(0)
  } catch {
    list.innerHTML = '<p class="text-center text-sm text-error py-4">Error al cargar reseñas.</p>'
  }
}

function _reviewItemHtml(r) {
  const date = new Date(r.created_at).toLocaleDateString('es-MX', { day:'numeric', month:'short', year:'numeric' })
  return `
    <div class="flex flex-col gap-1 p-3 rounded-xl bg-surface-container">
      <div class="flex items-center justify-between">
        <span class="text-xs font-semibold text-on-surface">${esc(r.customer_name || 'Cliente')}</span>
        <span class="text-[10px] text-on-surface-variant">${date}</span>
      </div>
      <div class="flex items-center gap-0.5">${starsHtml(r.rating, 12)}</div>
      ${r.comment ? `<p class="text-xs text-on-surface-variant mt-0.5">${esc(r.comment)}</p>` : ''}
    </div>`
}

function _renderStarSelector(selected) {
  _selectedRating = selected
  const el = document.getElementById('star-selector')
  if (!el) return
  el.innerHTML = [1,2,3,4,5].map(i =>
    `<button onclick="_renderStarSelector(${i})" type="button"
       class="text-[28px] transition-transform active:scale-90 ${i <= selected ? 'text-secondary-container' : 'text-outline-variant'}"
       style="font-variation-settings:'FILL' ${i <= selected ? 1 : 0}; font-family: 'Material Symbols Outlined'">star</button>`
  ).join('')
}

async function submitProductReview() {
  if (!_selectedRating) {
    alert('Selecciona una calificación con estrellas.')
    return
  }
  const comment = document.getElementById('review-comment')?.value.trim() || ''
  const token = localStorage.getItem('customer_token')
  const btn = document.querySelector('#review-form button[onclick="submitProductReview()"]')
  if (btn) { btn.disabled = true; btn.textContent = 'Publicando...' }
  try {
    const res = await fetch(`/api/products/${_reviewProductId}/reviews`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({ rating: _selectedRating, comment }),
    })
    if (!res.ok) throw new Error((await res.json()).error || 'Error')
    // Update local ratings cache
    S.ratings = {}
    loadRatings()
    await _loadProductReviews(_reviewProductId)
    if (document.getElementById('review-comment')) document.getElementById('review-comment').value = ''
    _renderStarSelector(0)
  } catch (e) {
    alert(e.message || 'Error al publicar la reseña.')
  } finally {
    if (btn) { btn.disabled = false; btn.textContent = 'Publicar reseña' }
  }
}

/* ── Reseñas de sucursal ─────────────────────────── */
let _reviewBranchId   = null
let _selectedBranchRating = 0

async function openBranchReviewModal(branchId) {
  _reviewBranchId = branchId
  _selectedBranchRating = 0
  const modal = document.getElementById('modal-branch-review')
  if (!modal) return
  modal.classList.remove('hidden')
  modal.classList.add('flex')
  document.body.style.overflow = 'hidden'
  _renderBranchStarSelector(0)
}

function closeBranchReviewModal() {
  document.getElementById('modal-branch-review')?.classList.replace('flex', 'hidden')
  document.body.style.overflow = ''
}

function _renderBranchStarSelector(selected) {
  _selectedBranchRating = selected
  const el = document.getElementById('branch-star-selector')
  if (!el) return
  el.innerHTML = [1,2,3,4,5].map(i =>
    `<button onclick="_renderBranchStarSelector(${i})" type="button"
       class="text-[28px] transition-transform active:scale-90 ${i <= selected ? 'text-secondary-container' : 'text-outline-variant'}"
       style="font-variation-settings:'FILL' ${i <= selected ? 1 : 0}; font-family: 'Material Symbols Outlined'">star</button>`
  ).join('')
}

async function submitBranchReview() {
  if (!_selectedBranchRating) {
    alert('Selecciona una calificación con estrellas.')
    return
  }
  const comment = document.getElementById('branch-review-comment')?.value.trim() || ''
  const token = localStorage.getItem('customer_token')
  const btn = document.querySelector('#modal-branch-review button[onclick="submitBranchReview()"]')
  if (btn) { btn.disabled = true; btn.textContent = 'Publicando...' }
  try {
    const res = await fetch(`/api/branches/${_reviewBranchId}/reviews`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
      body: JSON.stringify({ rating: _selectedBranchRating, comment }),
    })
    if (!res.ok) throw new Error((await res.json()).error || 'Error')
    closeBranchReviewModal()
    // Refresh branch ratings cache
    S.branchRatings = {}
    if (document.getElementById('branch-review-comment')) document.getElementById('branch-review-comment').value = ''
  } catch (e) {
    alert(e.message || 'Error al publicar la reseña.')
  } finally {
    if (btn) { btn.disabled = false; btn.textContent = 'Publicar reseña' }
  }
}

/* ── Init ───────────────────────────────────────── */
document.addEventListener('DOMContentLoaded', () => {
  loadProducts()
  loadClientOffers()
  loadClientCombos()
  loadRatings()
  updateBadge()
  initSlider()

  // Sincronizar ambos inputs de búsqueda
  const syncSearch = e => { S.search = e.target.value; renderProducts() }
  document.getElementById('search-input')?.addEventListener('input', syncSearch)
  document.getElementById('search-mobile')?.addEventListener('input', syncSearch)

  // Cerrar modal al hacer click en el fondo
  document.getElementById('modal-checkout')?.addEventListener('click', e => {
    if (e.target.id === 'modal-checkout') closeCheckout()
  })
})
