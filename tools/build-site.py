#!/usr/bin/env python3
"""Generate docs/index.html — one self-contained HTML site from the cli_tools markdown docs.

Usage:  python3 tools/build-site.py [output.html]
Deps:   pip install 'markdown>=3.4' 'pygments>=2.11'
Sources of truth stay the .md files; this file only renders them.
"""
import hashlib, json, os, re, sys, posixpath
import markdown
from markdown.extensions.toc import slugify as md_slugify
from pygments.formatters import HtmlFormatter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.environ.get("CLI_TOOLS_REPO") or os.path.dirname(HERE)
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "docs", "index.html")
GH = "https://github.com/vinterbris/cli_tools"

# One geometry for every icon: 24-unit grid, stroke only, no fill, round joins.
# Mixing unicode glyphs here was inconsistent — different blocks carry different
# weights, widths and baselines. These share a single drawing rule instead.
ICONS = {
    "home":     '<path d="M3.5 10.6 12 3.8l8.5 6.8V20a.8.8 0 0 1-.8.8H4.3a.8.8 0 0 1-.8-.8Z"/><path d="M9.6 20.8v-6.2h4.8v6.2"/>',
    "download": '<path d="M12 3.6v10.8"/><path d="M7.6 10.4 12 14.8l4.4-4.4"/><path d="M4.2 20.4h15.6"/>',
    "rows":     '<path d="M4 7.4h4"/><path d="M11 7.4h9"/><path d="M4 12h4"/><path d="M11 12h9"/><path d="M4 16.6h4"/><path d="M11 16.6h9"/>',
    "terminal": '<rect x="3.4" y="4.4" width="17.2" height="15.2" rx="1.4"/><path d="M7.4 10 10 12.6 7.4 15.2"/><path d="M12.6 15.2h4"/>',
    "sliders":  '<path d="M4 8.4h4.4"/><path d="M13.6 8.4H20"/><path d="M4 15.6h6.4"/><path d="M15.6 15.6H20"/><circle cx="11" cy="8.4" r="2.2"/><circle cx="13" cy="15.6" r="2.2"/>',
    "window":   '<rect x="3.4" y="4.4" width="17.2" height="15.2" rx="1.4"/><path d="M3.4 8.8h17.2"/><path d="M6.5 6.6h.01"/><path d="M9.1 6.6h.01"/>',
    "file":     '<path d="M13.4 3.6H6.6a1.2 1.2 0 0 0-1.2 1.2v14.4a1.2 1.2 0 0 0 1.2 1.2h10.8a1.2 1.2 0 0 0 1.2-1.2V8.6Z"/><path d="M13.4 3.6v5h5.2"/><path d="M8.6 13h6.8"/><path d="M8.6 16.6h4.4"/>',
    "trend":    '<path d="M3.6 17.4l5.2-5.2 3.4 3.4 6.6-6.6"/><path d="M14.6 8.6h4.6v4.6"/>',
}

# id, source path, nav label, group, icon.
# Groups name what a document *is*, not which OS it targets: every page except
# powershell.md is cross-platform, so an OS-based grouping would misfile most of them.
# "" is the ungrouped slot at the top — README is the index, not a category.
PAGES = [
    ("home",          "README.md",              "Overview",       "",          "home"),
    ("install",       "bootstrap/INSTALL.md",   "Installation",   "Setup",     "download"),
    ("dotfiles",      "dotfiles/README.md",     "Dotfiles",       "Setup",     "file"),
    ("cheatsheet",    "docs/cheatsheet.md",     "Cheatsheet",     "Reference", "rows"),
    ("usecases",      "docs/usecases.md",       "Use cases",      "Reference", "terminal"),
    ("tools",         "docs/modern-cli-tools.md","Tool selection","Reference", "sliders"),
    ("powershell",    "docs/powershell.md",     "PowerShell 7",   "Reference", "window"),
    ("learning-plan", "docs/learning-plan.md",  "Learning plan",  "Practice",  "trend"),
]
FILE2PAGE = {p[1]: p[0] for p in PAGES}
GROUPS = ["", "Setup", "Reference", "Practice"]

unresolved = []
seen_slugs = set()


def strip_fm(text):
    tags = []
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            fm = text[3:end]
            m = re.search(r"tags:\s*\[(.*?)\]", fm)
            if m:
                tags = [t.strip() for t in m.group(1).split(",") if t.strip()]
            text = text[end + 4:].lstrip("\n")
    return text, tags


def gh_slug(text):
    """GitHub's heading slug: punctuation dropped, spaces -> '-'. The docs' hand-written
    anchors (e.g. #powershell--start-here) follow this, not python-markdown's."""
    s = re.sub(r"<[^>]+>", "", text).strip().lower()
    s = re.sub(r"[^\w\- ]", "", s, flags=re.UNICODE)
    return s.replace(" ", "-")


def make_slugifier(mapping, pid):
    """Element ids are '<page>--<slug>'. All 8 documents share one DOM, so ids must be
    unique across pages; prefixing by page makes that structural instead of relying on a
    global counter, whose '-2' suffixes depended on the order pages happened to be built.
    `mapping` keeps every author-visible spelling (python-markdown's slug and GitHub's)
    pointing at the final id, so hand-written anchors in the .md files keep working."""
    def slug(value, sep):
        base = md_slugify(value, sep)
        final = "%s--%s" % (pid, base)
        n = 1
        while final in seen_slugs:
            n += 1
            final = "%s--%s-%d" % (pid, base, n)
        seen_slugs.add(final)
        for alias in (base, gh_slug(value)):
            if alias:
                mapping.setdefault(alias, final)
        return final
    return slug


def render_md(text, mapping, pid):
    # NOTE: pymdownx.superfences silently parses zero fences in these files (measured);
    # the stdlib fenced_code + codehilite pair handles all 15+ blocks per file correctly.
    md = markdown.Markdown(
        extensions=["tables", "attr_list", "def_list", "sane_lists",
                    "fenced_code", "codehilite", "toc"],
        extension_configs={
            "codehilite": {"guess_lang": False, "css_class": "highlight",
                           "linenums": False},
            "toc": {"permalink": "#", "permalink_class": "headerlink",
                    "permalink_title": "Link to this section",
                    "slugify": make_slugifier(mapping, pid)},
        },
    )
    return md.convert(text)


def strip_tags(s):
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", s)).strip()


def split_hero(html):
    """Pull the leading <h1> out of the body; return (title, its id, rest).
    The id no longer exists in the DOM afterwards, so it is routed to the page top."""
    m = re.search(r'<h1(?:\s+id="([^"]+)")?[^>]*>(.*?)</h1>', html, re.S)
    if not m:
        return None, None, html
    title = strip_tags(m.group(2)).replace("#", "").strip()
    return title, m.group(1), (html[:m.start()] + html[m.end():]).lstrip()


def fix_table_escapes(html):
    """GitHub strips the backslash from a `\\|` escaped pipe inside a table cell;
    python-markdown leaves it in the text. Unescape, cells only."""
    return re.sub(r"<t[dh][^>]*>.*?</t[dh]>",
                  lambda m: m.group(0).replace("\\|", "|"), html, flags=re.S)


def wrap_blocks(html):
    """Wrap code blocks in .codewrap and tables in .tablewrap."""
    tokens = []

    def stash(m):
        tokens.append(m.group(0))
        return "\x00%d\x00" % (len(tokens) - 1)

    html = re.sub(r'<div class="highlight">.*?</div>', stash, html, flags=re.S)
    html = re.sub(r"<pre[^>]*>.*?</pre>", lambda m: '<div class="codewrap">%s</div>' % m.group(0),
                  html, flags=re.S)
    html = re.sub(r"\x00(\d+)\x00", lambda m: '<div class="codewrap">%s</div>' % tokens[int(m.group(1))], html)
    html = re.sub(r"<table>.*?</table>", lambda m: '<div class="tablewrap">%s</div>' % m.group(0),
                  html, flags=re.S)
    return html


def build_toc(html, pid):
    """h1 is included: INSTALL.md uses in-body h1s as Linux/Windows dividers, and without
    them the TOC shows five pairs of identically-labelled entries."""
    out = []
    for m in re.finditer(r"<h([123])\s+id=\"([^\"]+)\"[^>]*>(.*?)</h\1>", html, re.S):
        lvl, hid, raw = m.group(1), m.group(2), m.group(3)
        label = strip_tags(re.sub(r'<a class="headerlink".*?</a>', "", raw, flags=re.S))
        if not label:
            continue
        out.append((int(lvl), hid, label))
    return out


def clean_text(s):
    s = re.sub(r"`{1,3}", "", s)
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s)
    s = re.sub(r"^\s*[-*+]\s+", "", s, flags=re.M)
    s = re.sub(r"^\s*\|?[-:\s|]+\|\s*$", "", s, flags=re.M)
    s = s.replace("|", " ").replace("*", "").replace("#", "")
    return re.sub(r"\s+", " ", s).strip()


def build_index(md_text, pid, mapping, page_title):
    """Section-level search index straight from the markdown source. `s` carries the
    nearest in-body h1 so that repeated section names (INSTALL.md has five) stay
    distinguishable in the results list."""
    entries = []
    cur = {"d": 0, "t": page_title, "a": "/" + pid, "s": None, "buf": []}
    fence = False
    hero_seen = False
    section = None
    for line in md_text.split("\n"):
        if line.lstrip().startswith("```"):
            fence = not fence
        if not fence:
            m = re.match(r"^(#{1,3})\s+(.*)$", line)
            if m:
                depth = len(m.group(1))
                if depth == 1 and not hero_seen:
                    hero_seen = True        # page title: already the hero, not a section
                    continue
                title = clean_text(m.group(2))
                base = md_slugify(re.sub(r"<[^>]+>", "", m.group(2)).replace("`", ""), "-")
                if depth == 1:
                    section = title
                entries.append(cur)
                cur = {"d": depth, "t": title, "a": mapping.get(base, "/" + pid),
                       "s": section if depth > 1 else None, "buf": []}
                continue
        cur["buf"].append(line)
    entries.append(cur)
    out = []
    for e in entries:
        if not e["t"]:
            continue
        body = clean_text("\n".join(e["buf"]))
        row = {"p": pid, "d": e["d"], "t": e["t"], "a": e["a"], "x": body[:340]}
        if e["s"]:
            row["s"] = e["s"]
        out.append(row)
    return out


# ── pass 1: render every page ────────────────────────────────────────────────
rendered, maps, tocs, index, titles, hero_ids = {}, {}, {}, [], {}, {}
digest = hashlib.sha256()
for pid, path, nav, group, icon in PAGES:
    with open(os.path.join(REPO, path), "rb") as f:
        blob = f.read()
    digest.update(blob)
    body_md, tags = strip_fm(blob.decode("utf-8"))
    mapping = {}
    html = render_md(body_md, mapping, pid)
    title, hero_id, html = split_hero(html)
    titles[pid] = title or nav
    hero_ids[pid] = hero_id
    maps[pid] = mapping
    tocs[pid] = build_toc(html, pid)
    rendered[pid] = {"html": wrap_blocks(fix_table_escapes(html)), "tags": tags,
                     "src": path, "title": titles[pid]}
    index.extend(build_index(body_md, pid, mapping, titles[pid]))

# ── pass 2: rewrite links ────────────────────────────────────────────────────
def rewrite(pid, src, html):
    finals = set(maps[pid].values())

    def sub(m):
        pre, href = m.group(1), m.group(2)
        if "headerlink" in pre:                         # generated permalink, already final
            return m.group(0)
        if re.match(r"^(https?:|mailto:|data:)", href):
            return '%s"%s" target="_blank" rel="noopener" class="ext"' % (pre, href)
        path, _, anchor = href.partition("#")
        if not path:                                    # same-page anchor
            if anchor in finals:
                return m.group(0)
            final = maps[pid].get(anchor)
            if not final:
                unresolved.append("%s: #%s" % (src, anchor))
                return m.group(0)
            return '%s"#%s"' % (pre, final)
        target = posixpath.normpath(posixpath.join(posixpath.dirname(src), path))
        if target in FILE2PAGE:
            tp = FILE2PAGE[target]
            if anchor:
                final = maps[tp].get(anchor)
                if final:
                    return '%s"#%s"' % (pre, final)
                unresolved.append("%s: %s#%s" % (src, target, anchor))
            return '%s"#/%s"' % (pre, tp)
        kind = "tree" if href.endswith("/") else "blob"
        return '%s"%s/%s/main/%s" target="_blank" rel="noopener" class="ext"' % (pre, GH, kind, target)
    return re.sub(r'(<a\s+(?:[^>]*?\s)?href=)"([^"]+)"', sub, html)

for pid in rendered:
    rendered[pid]["html"] = rewrite(pid, rendered[pid]["src"], rendered[pid]["html"])

# ── assemble ─────────────────────────────────────────────────────────────────
css = open(os.path.join(HERE, "site.css"), encoding="utf-8").read()
js = open(os.path.join(HERE, "site.js"), encoding="utf-8").read()
pyg = "\n".join([
    HtmlFormatter(style="one-dark").get_style_defs('html[data-theme="dark"] .highlight'),
    HtmlFormatter(style="friendly").get_style_defs('html[data-theme="light"] .highlight'),
    ".highlight{background:transparent!important}",
    ".highlight pre{margin:0}",
])

nav_html = []
for g in GROUPS:
    items = [p for p in PAGES if p[3] == g]
    if not items:
        continue
    nav_html.append('<div class="nav-group">%s'
                    % (('<div class="nav-label">%s</div>' % g) if g else ""))
    for pid, path, nav, group, icon in items:
        svg = ('<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" '
               'stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">%s</svg>' % ICONS[icon])
        nav_html.append('<a class="nav-a" data-p="%s" href="#/%s"><span class="nav-i">%s</span>%s</a>'
                        % (pid, pid, svg, nav))
    nav_html.append("</div>")

pages_html, toc_html = [], []
for pid, path, nav, group, glyph in PAGES:
    r = rendered[pid]
    tags = "".join('<span class="tag">%s</span>' % t for t in r["tags"])
    pages_html.append(
        '<article class="page" id="pg-%s">\n<header class="hero">%s<h1>%s</h1>'
        '<div class="src">source · <a href="%s/blob/main/%s" target="_blank" rel="noopener" class="ext">%s</a></div>'
        '</header>\n<div class="body">\n%s\n</div>\n</article>'
        % (pid, ('<div class="hero-tags">%s</div>' % tags) if tags else "", r["title"], GH, path, path, r["html"])
    )
    links = "".join('<a class="d%d" href="#%s">%s</a>' % (lvl, hid, lbl)
                    for lvl, hid, lbl in tocs[pid])
    toc_html.append('<div class="toc-l" id="toc-%s">%s</div>' % (pid, links))

meta = {pid: {"title": titles[pid], "nav": nav, "src": path} for pid, path, nav, g, gl in PAGES}
anchor2page = {}
for pid in rendered:
    for lvl, hid, lbl in tocs[pid]:
        anchor2page[hid] = pid
    for final in maps[pid].values():
        anchor2page.setdefault(final, pid)
    if hero_ids[pid]:            # h1 lifted into the hero: keep the anchor routable
        anchor2page[hero_ids[pid]] = pid

for extra in (css, js):
    digest.update(extra.encode())
build_id = digest.hexdigest()[:8]


def jsdump(obj):
    """`</` cannot appear raw inside an inline <script>; a doc quoting a closing
    script tag would otherwise truncate the whole page."""
    return json.dumps(obj, ensure_ascii=False).replace("</", "<\\/")
doc = f"""<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>cli_tools — modern CLI environment</title>
<meta name="description" content="Modern CLI environment: tool selection, cheatsheet, use cases, dotfiles and bootstrap for zsh, bash and PowerShell 7.">
<style>
{css}
/* ── pygments ── */
{pyg}
</style>
</head>
<body>
<div class="app">
<aside class="sidebar">
  <div class="brand">
    <div class="brand-row">
      <div class="logo">&gt;_</div>
      <div><div class="brand-t">cli_tools</div></div>
    </div>
    <div class="brand-s">Modern CLI environment — one repo for zsh, bash and PowerShell&nbsp;7.</div>
  </div>
  <nav class="nav">
{chr(10).join(nav_html)}
  </nav>
  <div class="sb-foot">
    <div><a href="{GH}" target="_blank" rel="noopener" class="ext">github.com/vinterbris/cli_tools</a></div>
    <div><kbd>Ctrl</kbd>+<kbd>K</kbd> search · <kbd>Ctrl</kbd>+<kbd>P</kbd> print all</div>
    <div>Build {build_id} · {len(PAGES)} documents</div>
  </div>
</aside>
<main>
  <div class="topbar">
    <button class="btn" id="menu-btn" title="Menu">&#9776;</button>
    <div class="crumb"><span>cli_tools</span><span>/</span><b id="crumb-p">…</b><span style="opacity:.5">·</span><b id="crumb-f" style="opacity:.7"></b></div>
    <div class="spacer"></div>
    <button class="btn btn-search" id="search-btn"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><circle cx="11" cy="11" r="7"/><path d="M20 20l-4.2-4.2"/></svg><span>Search docs</span><kbd>Ctrl K</kbd></button>
    <button class="btn" id="theme-btn" title="Toggle theme"><span id="theme-i">◐</span><span id="theme-t">Dark</span></button>
  </div>
  <div class="wrap">
    <div class="content">
{chr(10).join(pages_html)}
    </div>
    <div class="tocbar">
      <div class="toc-h">On this page</div>
{chr(10).join(toc_html)}
    </div>
  </div>
</main>
</div>
<div class="scrim" id="scrim"></div>
<div class="overlay" id="ov">
  <div class="modal">
    <div class="modal-in">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="11" cy="11" r="7"/><path d="M20 20l-4.2-4.2"/></svg>
      <input id="q" placeholder="Search all pages…" autocomplete="off" spellcheck="false">
      <kbd>Esc</kbd>
    </div>
    <div class="hits" id="hits"></div>
    <div class="modal-f"><span><kbd>↑</kbd><kbd>↓</kbd> navigate</span><span><kbd>↵</kbd> open</span><span>{len(index)} sections indexed</span></div>
  </div>
</div>
<script>
const PAGES = {jsdump(meta)};
const ANCHOR2PAGE = {jsdump(anchor2page)};
const SIDX = {jsdump(index)};
{js}
</script>
</body>
</html>
"""

if os.path.dirname(OUT):
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write(doc)

print("wrote %s  (%.1f KB, build %s)" % (OUT, len(doc.encode()) / 1024, build_id))
print("pages: %d | indexed sections: %d | toc entries: %d"
      % (len(PAGES), len(index), sum(len(v) for v in tocs.values())))
if unresolved:
    print("UNRESOLVED LINKS (%d):" % len(set(unresolved)))
    for u in sorted(set(unresolved)):
        print("  -", u)
    sys.exit(1)          # the file is written; the build still reports failure
print("all internal links resolved")
