/* ══════════════════  theme  ══════════════════ */
const store = {
  get(k, d) { try { const v = localStorage.getItem(k); return v === null ? d : v; } catch (e) { return d; } },
  set(k, v) { try { localStorage.setItem(k, v); } catch (e) {} }
};
const html = document.documentElement;
function setTheme(t) {
  html.dataset.theme = t;
  store.set('cli-theme', t);
  document.getElementById('theme-i').textContent = t === 'dark' ? '◐' : '◑';
  document.getElementById('theme-t').textContent = t === 'dark' ? 'Dark' : 'Light';
}
setTheme(store.get('cli-theme', window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark'));
document.getElementById('theme-btn').onclick = () => setTheme(html.dataset.theme === 'dark' ? 'light' : 'dark');

/* ══════════════════  router  ══════════════════ */
const DEFAULT_PAGE = Object.keys(PAGES)[0];
let current = null;

function show(pid, anchor, push) {
  if (!PAGES[pid]) pid = DEFAULT_PAGE;
  if (anchor && anchor.charAt(0) === '/') anchor = null;   // page-level search hit
  if (pid !== current) {
    document.querySelectorAll('.page').forEach(e => e.classList.toggle('on', e.id === 'pg-' + pid));
    document.querySelectorAll('.toc-l').forEach(e => e.classList.toggle('on', e.id === 'toc-' + pid));
    document.querySelectorAll('.nav-a').forEach(e => e.classList.toggle('on', e.dataset.p === pid));
    document.getElementById('crumb-p').textContent = PAGES[pid].title;
    document.getElementById('crumb-f').textContent = PAGES[pid].src;
    document.title = PAGES[pid].title + ' · cli_tools';
    current = pid;
  }
  if (push) {
    const h = anchor ? '#' + anchor : '#/' + pid;
    if (location.hash !== h) history.pushState(null, '', h);
  }
  const el = anchor ? document.getElementById(anchor) : null;
  // No manual offset here: html has scroll-behavior:smooth, so a scrollBy() on the next
  // line becomes a second scroll request that retargets the in-flight animation to
  // current-position minus 8 — i.e. the jump never happens. The gap under the sticky bar
  // comes from scroll-margin-top on the headings instead.
  if (el) { el.scrollIntoView({ block: 'start' }); }
  else { window.scrollTo(0, 0); }   // stale or lifted anchor: land at the top of the page
  spy();
}

function route(push) {
  const h = decodeURIComponent(location.hash.replace(/^#/, ''));
  if (!h) return show(DEFAULT_PAGE, null, false);
  if (h.startsWith('/')) return show(h.slice(1), null, false);
  const pid = ANCHOR2PAGE[h];
  if (pid) return show(pid, h, false);
  show(DEFAULT_PAGE, null, false);
}
window.addEventListener('hashchange', () => route(false));

/* intercept internal links so page switches happen without reload */
document.addEventListener('click', e => {
  const a = e.target.closest('a');
  if (!a) return;
  const href = a.getAttribute('href') || '';
  if (!href.startsWith('#')) return;
  const t = decodeURIComponent(href.slice(1));
  if (!t) return;
  e.preventDefault();
  if (t.startsWith('/')) show(t.slice(1), null, true);
  else if (ANCHOR2PAGE[t]) show(ANCHOR2PAGE[t], t, true);
  closeSearch();
  closeNav();
});

/* ══════════════════  scrollspy  ══════════════════ */
let spyT = null;
function spy() {
  const list = document.getElementById('toc-' + current);
  if (!list) return;
  const links = [...list.querySelectorAll('a')];
  let best = null;
  for (const l of links) {
    const el = document.getElementById(decodeURIComponent(l.getAttribute('href').slice(1)));
    if (el && el.getBoundingClientRect().top <= 96) best = l; else break;
  }
  links.forEach(l => l.classList.toggle('on', l === best));
  if (best) {
    const r = best.getBoundingClientRect(), c = list.parentElement.getBoundingClientRect();
    if (r.top < c.top || r.bottom > c.bottom) best.scrollIntoView({ block: 'nearest' });
  }
}
window.addEventListener('scroll', () => { if (spyT) return; spyT = setTimeout(() => { spyT = null; spy(); }, 90); }, { passive: true });

/* ══════════════════  copy buttons  ══════════════════ */
document.querySelectorAll('.codewrap').forEach(w => {
  const b = document.createElement('button');
  b.className = 'copy'; b.textContent = 'copy'; b.type = 'button';
  b.onclick = () => {
    const txt = w.querySelector('pre').innerText;
    const done = () => { b.textContent = 'copied'; b.classList.add('done'); setTimeout(() => { b.textContent = 'copy'; b.classList.remove('done'); }, 1300); };
    if (navigator.clipboard) navigator.clipboard.writeText(txt).then(done, fallback);
    else fallback();
    function fallback() {
      const ta = document.createElement('textarea');
      ta.value = txt; ta.style.position = 'fixed'; ta.style.opacity = '0';
      document.body.appendChild(ta); ta.select();
      try { document.execCommand('copy'); done(); } catch (e) { b.textContent = 'failed'; }
      ta.remove();
    }
  };
  w.appendChild(b);
});

/* ══════════════════  search  ══════════════════ */
const ov = document.getElementById('ov'), q = document.getElementById('q'), hitsEl = document.getElementById('hits');
let hits = [], sel = 0;

function openSearch() { ov.classList.add('on'); q.value = ''; q.focus(); render(''); }
function closeSearch() { ov.classList.remove('on'); }
document.getElementById('search-btn').onclick = openSearch;
ov.onclick = e => { if (e.target === ov) closeSearch(); };

function esc(s) { return s.replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])); }
function hl(s, terms) {
  let out = esc(s);
  for (const t of terms) {
    if (!t) continue;
    out = out.replace(new RegExp('(' + t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'gi'), '<mark>$1</mark>');
  }
  return out;
}

function render(query) {
  const terms = query.toLowerCase().split(/\s+/).filter(Boolean);
  if (!terms.length) {
    hits = SIDX.filter(s => s.d === 2).slice(0, 12);
  } else {
    const scored = [];
    for (const s of SIDX) {
      const t = s.t.toLowerCase(), x = s.x.toLowerCase();
      let score = 0, ok = true;
      for (const term of terms) {
        const it = t.indexOf(term), ix = x.indexOf(term);
        if (it < 0 && ix < 0) { ok = false; break; }
        if (it === 0) score += 60; else if (it > 0) score += 34;
        if (ix >= 0) score += 8;
        if (s.d === 2) score += 4;
      }
      if (ok) scored.push([score, s]);
    }
    scored.sort((a, b) => b[0] - a[0]);
    hits = scored.slice(0, 40).map(p => p[1]);
  }
  sel = 0;
  if (!hits.length) { hitsEl.innerHTML = '<div class="empty">No matches</div>'; return; }
  hitsEl.innerHTML = hits.map((h, i) => {
    let x = h.x;
    if (terms.length) {
      const k = x.toLowerCase().indexOf(terms[0]);
      if (k > 70) x = '…' + x.slice(k - 50);
    }
    const where = PAGES[h.p].nav + (h.s ? ' / ' + h.s : '');
    return '<a class="hit' + (i === 0 ? ' sel' : '') + '" data-i="' + i + '" href="#' + h.a + '">' +
      '<div class="hit-t"><span class="hit-p">' + esc(where) + '</span>' + hl(h.t, terms) + '</div>' +
      '<div class="hit-x">' + hl(x.slice(0, 190), terms) + '</div></a>';
  }).join('');
  hitsEl.querySelectorAll('.hit').forEach(el => {
    el.addEventListener('mouseenter', () => { sel = +el.dataset.i; mark(); });
  });
}
function mark() {
  hitsEl.querySelectorAll('.hit').forEach((e, i) => e.classList.toggle('sel', i === sel));
  const e = hitsEl.querySelectorAll('.hit')[sel];
  if (e) e.scrollIntoView({ block: 'nearest' });
}
q.addEventListener('input', () => render(q.value.trim()));

document.addEventListener('keydown', e => {
  const open = ov.classList.contains('on');
  // e.code, not e.key: on a Cyrillic layout Ctrl+K reports key 'л' and the browser's
  // own Ctrl+K would win instead.
  if ((e.ctrlKey || e.metaKey) && (e.code === 'KeyK' || e.key.toLowerCase() === 'k')) {
    e.preventDefault(); open ? closeSearch() : openSearch(); return;
  }
  if (e.key === '/' && !open && !e.ctrlKey && !e.altKey && !e.metaKey && !e.shiftKey
      && !/^(INPUT|TEXTAREA)$/.test(document.activeElement.tagName)) { e.preventDefault(); openSearch(); return; }
  if (!open) return;
  if (e.key === 'Escape') { closeSearch(); }
  else if (e.key === 'ArrowDown') { e.preventDefault(); sel = Math.min(sel + 1, hits.length - 1); mark(); }
  else if (e.key === 'ArrowUp') { e.preventDefault(); sel = Math.max(sel - 1, 0); mark(); }
  else if (e.key === 'Enter') {
    e.preventDefault();
    const h = hits[sel];
    if (h) { show(h.p, h.a, true); closeSearch(); }
  }
});

/* ══════════════════  mobile nav  ══════════════════ */
const sb = document.querySelector('.sidebar'), scrim = document.getElementById('scrim');
function closeNav() { sb.classList.remove('open'); scrim.classList.remove('on'); }
document.getElementById('menu-btn').onclick = () => { sb.classList.toggle('open'); scrim.classList.toggle('on'); };
scrim.onclick = closeNav;

route(false);
