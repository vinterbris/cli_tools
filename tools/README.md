# tools

Build machinery. Nothing here is loaded by a shell — it only renders the docs.

## build-site.py

Renders every published markdown file into a single self-contained
`docs/index.html`: sidebar navigation, per-page table of contents, full-text
search, copy buttons on code blocks, dark/light themes, print stylesheet. No
network requests at runtime, no external assets.

```bash
pip install 'markdown>=3.4' 'pygments>=2.11'
python3 tools/build-site.py            # -> docs/index.html
python3 tools/build-site.py /tmp/x.html
```

`CLI_TOOLS_REPO` overrides repository-root detection (default: this file's parent).

`site.css` and `site.js` are inlined into the output verbatim — edit them, not
the generated HTML. The page list, navigation groups and icons live in the
`PAGES` / `ICONS` tables at the top of `build-site.py`.

**The HTML is generated. Edit the `.md` files and re-run the build.** Adding a
document means adding one row to `PAGES`; anything not listed is not rendered.

## Notes

- Heading anchors are hand-written in some docs using GitHub's slug rules
  (`#powershell--start-here`), which differ from python-markdown's. The build
  registers both spellings and fails loudly — `UNRESOLVED LINKS` on stdout — if
  a link points at a heading that no longer exists.
- `pymdownx.superfences` parses zero fences in these files (measured, cause
  undiagnosed); the build uses stdlib `fenced_code` + `codehilite` instead.
