(function() {
  const toggle = document.getElementById('theme-toggle');
  const html = document.documentElement;
  const themeColor = document.querySelector('meta[name="theme-color"]');
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)');

  if (!toggle) return;

  function applyTheme(theme) {
    const isDark = theme === 'dark';

    if (isDark) {
      html.setAttribute('data-theme', 'dark');
    } else {
      html.removeAttribute('data-theme');
    }

    toggle.setAttribute('aria-pressed', String(isDark));
    toggle.setAttribute('aria-label', isDark ? 'Switch to light mode' : 'Switch to dark mode');

    if (themeColor) {
      themeColor.setAttribute('content', isDark ? '#1a1714' : '#b84c00');
    }
  }

  const savedTheme = localStorage.getItem('theme');
  applyTheme(savedTheme || (prefersDark.matches ? 'dark' : 'light'));

  prefersDark.addEventListener('change', function(event) {
    if (!localStorage.getItem('theme')) {
      applyTheme(event.matches ? 'dark' : 'light');
    }
  });

  toggle.addEventListener('click', function() {
    const newTheme = html.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
    localStorage.setItem('theme', newTheme);
    applyTheme(newTheme);
  });
})();
