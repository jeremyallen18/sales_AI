/* ════════════════════════════════════════════════════
   ui.js — Helpers de UX compartidos (VentaIA / OXXO Go)
   Skeletons, contadores animados, estados vacíos y toasts.
   Cargar ANTES de app.js / cliente.js.
════════════════════════════════════════════════════ */
(function () {
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ── Skeletons ─────────────────────────────────── */
  function skeleton(type, count = 1) {
    const variants = {
      card: '<div class="skeleton skeleton-card"></div>',
      row: '<div class="skeleton skeleton-row"></div>',
      text: '<div class="skeleton skeleton-text"></div>',
      stat: '<div class="skeleton skeleton-stat"></div>',
      product: `
        <div class="bg-surface-container-lowest rounded-2xl p-4 border border-surface-variant/50">
          <div class="skeleton w-full aspect-square rounded-xl mb-4"></div>
          <div class="skeleton skeleton-text mb-2"></div>
          <div class="skeleton skeleton-text" style="width:40%"></div>
        </div>`,
      tableRow: '<tr><td colspan="6" style="padding:8px 20px"><div class="skeleton skeleton-row" style="margin:0"></div></td></tr>'
    };
    return Array(count).fill(variants[type] || variants.row).join('');
  }

  /* ── Contador animado (rAF, ease-out) ──────────── */
  function animateCounter(el, target, opts = {}) {
    if (!el) return;
    const { prefix = '', suffix = '', decimals = 0, duration = 900 } = opts;
    const format = v => prefix + v.toFixed(decimals) + suffix;
    if (reducedMotion || !isFinite(target)) {
      el.textContent = format(Number(target) || 0);
      return;
    }
    const start = performance.now();
    let done = false;
    function tick(now) {
      if (done) return;
      const t = Math.min((now - start) / duration, 1);
      const eased = 1 - Math.pow(1 - t, 3);
      el.textContent = format(target * eased);
      if (t < 1) requestAnimationFrame(tick);
      else done = true;
    }
    requestAnimationFrame(tick);
    // Garantía: rAF se congela en pestañas en segundo plano
    setTimeout(() => {
      if (!done) { done = true; el.textContent = format(Number(target)); }
    }, duration + 150);
  }

  /* ── Estado vacío ──────────────────────────────── */
  function emptyState({ icon = 'inbox', title = 'Sin datos', hint = '', action = '' } = {}) {
    return `
      <div class="empty-state">
        <div class="empty-icon"><span class="material-symbols-outlined">${icon}</span></div>
        <div class="empty-title">${title}</div>
        ${hint ? `<div class="empty-hint">${hint}</div>` : ''}
        ${action || ''}
      </div>`;
  }

  /* ── Toasts apilados ───────────────────────────── */
  const TOAST_ICONS = { success: 'check_circle', error: 'error', warn: 'warning' };

  function toast(msg, type = 'success', duration = 3200) {
    let stack = document.getElementById('toastStack') || document.getElementById('toast');
    if (!stack) {
      stack = document.createElement('div');
      stack.id = 'toastStack';
      document.body.appendChild(stack);
    }
    const item = document.createElement('div');
    item.className = `toast-item toast-${type}`;
    item.style.setProperty('--toast-dur', duration + 'ms');
    item.innerHTML = `
      <span class="material-symbols-outlined toast-icon" style="font-variation-settings:'FILL' 1">${TOAST_ICONS[type] || TOAST_ICONS.success}</span>
      <span style="flex:1;min-width:0">${msg}</span>
      <div class="toast-progress"></div>`;
    item.addEventListener('click', () => dismiss(item));
    stack.appendChild(item);
    const timer = setTimeout(() => dismiss(item), duration);

    function dismiss(el) {
      clearTimeout(timer);
      if (!el.isConnected) return;
      el.classList.add('toast-leaving');
      el.addEventListener('animationend', () => el.remove(), { once: true });
      // Fallback por si las animaciones están desactivadas
      setTimeout(() => el.remove(), 350);
    }
  }

  window.UI = { skeleton, animateCounter, emptyState, toast };
})();
