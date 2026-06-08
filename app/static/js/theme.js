/* theme.js — Dark/light mode toggle for VentaIA
 * Must load BEFORE Tailwind CDN to prevent FOUC */
(function () {
  var STORAGE_KEY = 'ventaia-theme';
  var HTML = document.documentElement;

  function getPreferredTheme() {
    var stored = localStorage.getItem(STORAGE_KEY);
    if (stored === 'dark' || stored === 'light') return stored;
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  function updateToggleIcons(theme) {
    var icons = document.querySelectorAll('[data-theme-icon]');
    for (var i = 0; i < icons.length; i++) {
      icons[i].textContent = theme === 'dark' ? 'light_mode' : 'dark_mode';
    }
  }

  function applyTheme(theme) {
    if (theme === 'dark') {
      HTML.classList.add('dark');
    } else {
      HTML.classList.remove('dark');
    }
    updateToggleIcons(theme);
    updateChartColors(theme === 'dark');
  }

  function updateChartColors(isDark) {
    if (typeof Chart === 'undefined') return;
    var textColor = isDark ? '#e5e1df' : '#1b1c1c';
    var gridColor = isDark ? '#342f2c' : '#e4e2e1';
    var instances = Object.values(Chart.instances || {});
    for (var i = 0; i < instances.length; i++) {
      var chart = instances[i];
      if (!chart.options || !chart.options.scales) continue;
      var scales = Object.values(chart.options.scales);
      for (var j = 0; j < scales.length; j++) {
        if (scales[j].ticks) scales[j].ticks.color = textColor;
        if (scales[j].grid) scales[j].grid.color = gridColor;
      }
      chart.update('none');
    }
  }

  window.toggleTheme = function () {
    var current = HTML.classList.contains('dark') ? 'dark' : 'light';
    var next = current === 'dark' ? 'light' : 'dark';
    localStorage.setItem(STORAGE_KEY, next);
    HTML.classList.add('theme-transitioning');
    applyTheme(next);
    setTimeout(function () { HTML.classList.remove('theme-transitioning'); }, 320);
  };

  /* Apply immediately to prevent flash */
  applyTheme(getPreferredTheme());

  /* Re-update icons after DOM ready (IIFE runs before DOM) */
  document.addEventListener('DOMContentLoaded', function () {
    var theme = HTML.classList.contains('dark') ? 'dark' : 'light';
    updateToggleIcons(theme);
  });

  /* Follow system preference when no stored choice */
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function (e) {
    if (!localStorage.getItem(STORAGE_KEY)) {
      applyTheme(e.matches ? 'dark' : 'light');
    }
  });
})();
