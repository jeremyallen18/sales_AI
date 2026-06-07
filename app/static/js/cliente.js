/* ════════════════════════════════════════════════════
   cliente.js — Tienda web para clientes (OXXO Go)
════════════════════════════════════════════════════ */

/* ── Estado ─────────────────────────────────────── */
const S = {
  products: [],
  cart: {},       // { [id]: { product, qty } }
  category: 'all',
  search: '',
  loading: true,
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

const fmt          = n  => `$${Number(n).toFixed(2)}`
const cartCount    = () => Object.values(S.cart).reduce((s, i) => s + i.qty, 0)
const cartSubtotal = () => Object.values(S.cart).reduce((s, i) => s + i.product.price * i.qty, 0)
const cartDiscount = () => Object.values(S.cart).reduce((s, i) => s + i.product.price * (i.product.discount_pct || 0) / 100 * i.qty, 0)
const cartTotal    = () => cartSubtotal() - cartDiscount()
const cartTax      = () => cartTotal() * (0.16 / 1.16)
const allCats    = () => [...new Set(S.products.map(p => p.category).filter(Boolean))].sort()
const filtered   = () => S.products.filter(p => {
  const okCat    = S.category === 'all' || p.category === S.category
  const okSearch = !S.search || p.name.toLowerCase().includes(S.search.toLowerCase())
  return okCat && okSearch && p.stock > 0
})

/* ── API ────────────────────────────────────────── */
async function loadProducts() {
  try {
    const res = await fetch('/api/inventory/products')
    S.products = await res.json()
  } catch { S.products = [] }
  S.loading = false
  renderCategories()
  renderProducts()
}

async function postSale(payload) {
  const res = await fetch('/api/sales/', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
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

function clearCart() {
  S.cart = {}
  updateBadge()
}

/* ── Render: Productos ──────────────────────────── */
function renderProducts() {
  const el = document.getElementById('products-grid')
  if (!el) return

  const titleEl = document.getElementById('section-title')
  if (titleEl) {
    if (S.search)              titleEl.textContent = `Resultados: "${S.search}"`
    else if (S.category !== 'all') titleEl.textContent = S.category
    else                           titleEl.textContent = 'Todos los productos'
  }

  if (S.loading) {
    el.innerHTML = Array(8).fill(`
      <div class="bg-surface-container-lowest rounded-xl p-4 animate-pulse border border-surface-variant/30">
        <div class="w-full aspect-square bg-surface-container-high rounded-lg mb-4"></div>
        <div class="h-4 bg-surface-container-high rounded mb-2 w-3/4"></div>
        <div class="h-6 bg-surface-container-high rounded w-1/2"></div>
      </div>`).join('')
    return
  }

  const products = filtered()
  if (!products.length) {
    el.innerHTML = `
      <div class="col-span-full flex flex-col items-center py-20 gap-4 text-on-surface-variant">
        <span class="material-symbols-outlined text-[72px]">search_off</span>
        <p class="font-display text-headline-md font-bold">Sin resultados</p>
        <button onclick="S.category='all';S.search='';
          document.getElementById('search-input')&&(document.getElementById('search-input').value='');
          document.getElementById('search-mobile')&&(document.getElementById('search-mobile').value='');
          renderCategories();renderProducts()"
          class="text-primary font-label-lg font-bold hover:underline">Ver todo</button>
      </div>`
    return
  }

  el.innerHTML = products.map(p => {
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
      ? `<div class="absolute top-2 left-2 z-10"><span class="bg-green-600 text-white text-[11px] font-extrabold px-2 py-0.5 rounded-sm shadow-sm">−${discPct % 1 === 0 ? discPct : discPct.toFixed(1)}%</span></div>`
      : ''
    const cartBadge  = inCart
      ? `<div class="absolute top-2 right-2 z-10 bg-primary text-on-primary text-xs font-bold rounded-full w-6 h-6 flex items-center justify-center shadow">${inCart}</div>`
      : ''
    const priceBlock = discPct > 0
      ? `<div class="flex flex-col leading-tight">
           <span class="text-[11px] text-on-surface-variant line-through">${fmt(p.price)}</span>
           <span class="font-display text-headline-md text-green-600 font-bold">${fmt(discPrice)}</span>
         </div>`
      : `<span class="font-display text-headline-md text-primary font-bold">${fmt(p.price)}</span>`

    return `
      <div onclick="addToCartById(${p.id})"
        class="product-card bg-surface-container-lowest rounded-xl p-4 shadow-[0_4px_12px_rgba(0,0,0,0.05)] hover:shadow-[0_8px_24px_rgba(0,0,0,0.10)] transition-shadow relative flex flex-col cursor-pointer border border-surface-variant/50">
        ${p.stock <= 5 ? lowBadge : discBadge}${cartBadge}
        <div class="w-full aspect-square mb-4 relative bg-surface-container-low rounded-lg overflow-hidden flex items-center justify-center">
          ${img}
        </div>
        <div class="flex-1 flex flex-col">
          <p class="text-on-surface font-medium line-clamp-2 mb-1 text-[15px] leading-snug">${esc(p.name)}</p>
          <p class="font-label-md text-label-md text-on-surface-variant mb-2">${esc(p.category)}</p>
          <div class="mt-auto flex items-center justify-between pt-2">
            ${priceBlock}
            <button onclick="event.stopPropagation();addToCartById(${p.id})"
              class="w-10 h-10 rounded-full bg-primary text-on-primary flex items-center justify-center hover:bg-primary-container transition-colors shadow-sm active:scale-90">
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
      <div class="w-16 h-16 rounded-full flex items-center justify-center shadow-sm transition-all active:scale-90 ${active ? 'bg-secondary-container' : 'bg-surface-container-high'}">
        <span class="material-symbols-outlined text-[28px] ${active ? 'text-on-secondary-container' : 'text-primary'}"
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

  const sidebar = document.getElementById('sidebar-cats')
  if (sidebar) sidebar.innerHTML = todosSidebar + cats.map(c => sidebarBtn(c, S.category === c)).join('')

  const chipsEl = document.getElementById('mobile-cats')
  if (chipsEl)
    chipsEl.innerHTML =
      chip('all', 'Todos', 'grid_view', allActive) +
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

  if (countLabel) countLabel.textContent = `${items.length} ${items.length === 1 ? 'producto' : 'productos'}`
  if (emptyEl)    emptyEl.classList.toggle('hidden', items.length > 0)
  if (itemsWrap)  itemsWrap.classList.toggle('hidden', items.length === 0)

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
  listEl.innerHTML = items.map(({ product: p, qty }) => `
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
  window.scrollTo(0, 0)
}

const showStore = () => showView('store')
const showCart  = () => showView('cart')

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

  const items = Object.values(S.cart).map(({ product, qty }) => ({ product_id: product.id, quantity: qty }))
  _processing = true

  const btn = document.getElementById('confirm-btn')
  if (btn) { btn.disabled = true; btn.textContent = 'Procesando...' }

  try {
    await postSale({
      items,
      client_name:    (document.getElementById('checkout-name').value || '').trim(),
      payment_method: _method,
    })
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

/* ── Toast ──────────────────────────────────────── */
function toast(msg, type = 'success') {
  const el = document.getElementById(type === 'success' ? 'toast-success' : 'toast-error')
  if (!el) return
  el.querySelector('.toast-msg').textContent = msg
  el.style.opacity = '0'
  el.classList.remove('hidden')
  requestAnimationFrame(() => requestAnimationFrame(() => { el.style.opacity = '1' }))
  setTimeout(() => { el.style.opacity = '0' }, 3400)
  setTimeout(() => el.classList.add('hidden'), 3800)
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
  updateDots()
  resetTimer()
}

/* ── Chatbot ────────────────────────────────────── */
const chatState = { open: false, loading: false }

function toggleChat() {
  chatState.open = !chatState.open
  const panel   = document.getElementById('chat-panel')
  const fabIcon = document.getElementById('chat-fab-icon')
  panel.classList.toggle('hidden', !chatState.open)
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
  div.className = `flex gap-2 items-end ${isUser ? 'flex-row-reverse' : ''}`
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
  document.getElementById('chat-typing')?.remove()
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
  if (sendBtn) sendBtn.disabled = true

  showTypingIndicator()

  try {
    const res  = await fetch('/tienda/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: msg }),
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

/* ── Init ───────────────────────────────────────── */
document.addEventListener('DOMContentLoaded', () => {
  loadProducts()
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
