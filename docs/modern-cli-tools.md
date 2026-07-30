# Modern CLI Tools

Reference for Linux work. Selection rule: **keep coreutils muscle memory intact.** A tool earns a place only if it wins on speed, ergonomics, or output clarity *without* forcing you to relearn flags you still need on a bare remote box.

---

## Selection principles

1. **Never alias a core command to an incompatible tool.** `alias grep=rg` breaks the moment you paste a script or `man` example. Use new names, or alias only tools with grep-compatible flags.
2. **Remote servers are the constraint — when you have them.** No regular remote work right now, so replacement tools are low-risk. Keep enough coreutils fluency as insurance: know `grep -rn`, `find -name -type`, `du -sh`, `ps aux`. That is the entire insurance policy.
3. **Colors and icons are a config burden.** Every tool has its own theme system. Budget for it or turn it off.
4. **Speed only matters at scale.** Below ~10k files, coreutils are fine. `rg` is the exception — it wins even on small trees because of gitignore-aware recursion.

---

## Tier list

| Tier | Tools | Rationale |
|---|---|---|
| **S — install first** | `ripgrep`, `fzf`, `fd`, `zoxide`, `bat`, `eza` | Change how you work, not just how output looks. Payoff is immediate. |
| **A — install the same week** | `btop`, `delta`, `atuin`, `gdu`, `duf`, `procs`, `tealdeer`, `lazygit`, `starship` | Clear wins; comfort and visibility rather than new capability. |
| **B — situational** | `yazi`, `xh`, `dust`, `sd`, `hyperfine`, `jless`, `micro` | Great if the use case is yours; otherwise noise. |
| **C — skip** | `exa` (dead), `lsd` (redundant with eza), `gojq` (jq is maintained again), `fish` (non-POSIX) | No sufficient delta. |

---

## Search & find

### ripgrep (`rg`) — replaces `grep -r`

**Why:** fastest recursive search available; respects `.gitignore` by default; sane output (grouped by file, line numbers, color). This is the single highest-value tool on the list.

**Watch out:** `.gitignore` respect is occasionally *wrong* for you — use `-u` to disable it, `-uu` to also include hidden, `-uuu` to also search binaries.

```bash
rg pattern                # recursive from cwd
rg -i pattern             # case-insensitive
rg -w pattern             # whole word
rg -F 'literal.string'    # fixed string, no regex
rg -l pattern             # filenames only
rg -tpy pattern           # only Python files (-T excludes: rg -Tpy)
rg -g '*.conf' pattern    # glob filter
rg -C3 pattern            # 3 lines of context
rg -uu pattern            # ignore .gitignore + include hidden
rg --files | rg conf      # list files, then filter
rg 'old' -l | xargs sed -i 's/old/new/g'
```

**Alternative — `ugrep` (`ug`):** roughly comparable speed, and it **accepts GNU grep's flags**, which is the one real argument for it. Measured, not assumed: 29 GNU-grep invocations run through both binaries (ugrep 3.7.2 vs GNU grep 3.7) behaved identically on every flag tested — `-i -n -c -l -v -w -x -o -r -E -F -q -A -B -C -e -s -h -H -m -P --include --exclude --color`.

Two differences survive, and they are why `alias grep='ug'` is safe interactively but not in scripts:

- **Output order is not stable.** ugrep searches in parallel; three identical `ug -r` runs gave two different orderings. `grep -r … | head` is therefore not reproducible. `--sort` fixes it, and the alias in `dotfiles/shell_common` sets it.
- **`-r` drops the `./` prefix.** `grep -r x .` prints `./a.txt:x`; `ug -r x .` prints `a.txt:x`. No flag restores it. Anything consuming those paths should call `\grep`.

Minor: `-L` returned a different exit code, and diagnostics read `ugrep: warning: …` rather than `grep: …`.

Benchmarks are contested — ugrep's own numbers favour ugrep, ripgrep's test suite favours ripgrep. Both are fast enough. Pick `ugrep` if flag familiarity matters more than ecosystem; pick `ripgrep` if you want the larger toolchain integration (editors, fzf recipes, `delta`).

### fd — replaces `find`

**Why:** `find . -name '*.log' -type f` becomes `fd -e log -tf`. Regex by default, parallel, gitignore-aware, colorized.

```bash
fd pattern                # match by name, recursive
fd -e md                  # by extension
fd -tf / -td / -tl        # files / dirs / symlinks
fd -H                     # include hidden
fd -I                     # ignore .gitignore
fd -g '*.tar.gz'          # glob instead of regex
fd . /var/log -x gzip     # exec per result (-X = batch once)
fd -0 pat | xargs -0 rm   # null-safe piping
fd -d 2 pattern           # max depth
```

### fzf — no replacement, pure addition

**Why:** turns any list into an interactive filter. Its value is compounding: it composes with everything else here. Install this second, after `rg`.

```bash
fzf                                  # filter stdin
vim "$(fzf)"                         # open picked file
fd -tf | fzf --preview 'bat --color=always {}'
git branch | fzf | xargs git switch
kill -9 "$(ps -ef | fzf | awk '{print $2}')"
```

Bindings (after sourcing fzf's keybindings — see [`dotfiles/`](../dotfiles/)):

- `Ctrl-R` — fuzzy search shell history
- `Ctrl-T` — insert file path into current command
- `Alt-C` — cd into a picked directory
- `**<Tab>` — fuzzy-complete any path argument

---

## Viewing & listing

### bat — replaces `cat` (for reading, not for piping)

**Why:** syntax highlighting, line numbers, git modification gutter, automatic paging. Detects when output is not a TTY and behaves like `cat`, so it is pipe-safe.

**Honest caveat:** several long-time users report no real day-to-day gain over `cat` + a decent pager. Its strongest use is actually as a **previewer for fzf** and as `MANPAGER`.

```bash
bat file.py
bat -p file.txt           # plain: no line numbers/decorations
bat -A file.txt           # show non-printable chars
bat -r 20:40 file.log     # line range
bat -l json < payload     # force language for stdin
bat --diff file.py        # only modified git lines
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
```

### eza — replaces `ls`

**Why:** git status column, tree mode built in, better defaults for human sizes and grouping. Actively maintained successor to **exa**, which is deprecated and unmaintained — do not install `exa`.

Nerd Font is installed, so `--icons` is on in the [`dotfiles/`](../dotfiles/) aliases. Icons are the fastest gain here — file type is readable before you parse the name.

```bash
eza -lh --git --icons                # long + git status + icons
eza -la --group-directories-first
eza --tree --level=2                 # replaces `tree`
eza -l --sort=modified --reverse
eza -l --total-size                  # dir sizes (slow)
eza -l --no-permissions --no-user    # trim noise
```

A well-configured `ls` alias closes most of the gap (`ls --color=auto -lhH --group-directories-first --time-style=long-iso`). What it cannot give you: the git column, `--tree`, and icons.

**`lsd`** — same category, icon-first, Nerd Font required. Redundant if you have eza. Pick one.

### zoxide — augments `cd`

**Why:** learns your directory frequency. `z proj` jumps to `~/work/clients/project-x`. Keeps `cd` working unchanged, which is why it is safe.

```bash
z foo            # jump to best match for "foo"
z foo bar        # match on multiple keywords
zi foo           # interactive pick via fzf
z -               # previous directory
zoxide query -l  # dump the database
```

---

## Disk & system

### btop — replaces `top` / `htop`

**Why:** CPU, memory, disks, network, and processes in one screen; mouse support; readable graphs.

```bash
btop
# in-app: Esc = menu, f = filter, +/- = tree, t = tree view,
#         1/2/3/4 = toggle boxes, q = quit
```

### gdu — replaces `ncdu`

**Why:** same interactive TUI navigate-and-delete workflow, parallelized for SSDs, noticeably faster on large trees. Keep `ncdu` knowledge for servers where only it is packaged.

```bash
gdu /            # interactive
gdu -n /var      # non-interactive, print and exit
gdu -d /home     # show disk usage of devices
# in-app: d = delete, r = rescan, n/s/c = sort by name/size/count
```

**`dua`** — same niche, Rust, `dua i` for interactive. Equivalent choice; pick by whichever your distro packages.

**`dust`** — different niche: **non-interactive** tree with proportional bars. Use it in scripts or for a one-glance answer. Not a `ncdu` replacement.

```bash
dust                # tree of cwd by size
dust -d 2 /var      # limit depth
dust -r             # upside down: biggest at the top
```

### duf — replaces `df`, **not** `du`

Common confusion: `duf` shows **mounted filesystems**, so it competes with `df -h`. It does not analyze directory sizes.

```bash
duf
duf --only local
duf --hide-fs tmpfs,squashfs
duf --sort size
```

### procs — replaces `ps`

**Why:** human-readable columns, built-in tree, search without `grep`. `ps aux | grep foo` becomes `procs foo`. TCP/UDP port columns exist but are not in the default column set — they need a config entry.

```bash
procs nginx        # search by name/pid/user
procs --tree
procs --sortd cpu  # descending; --sorta = ascending
procs --watch      # live refresh
```

`--sortd` and `--sorta` are declared `conflicts_with` `--tree` upstream, so a
sorted tree is not available — pick one.

---

## Text, data, network

### jq — keep it

`jq` is actively maintained again (1.8.x, security and bugfix releases through 2026). No reason to switch.

```bash
jq . file.json                       # pretty-print
jq -r '.items[].name' f.json         # raw strings, no quotes
jq '.[] | select(.age > 30)'
jq -c '.[]'                          # compact, one object per line
jq 'map({id, name})'
jq -s 'add' a.json b.json            # slurp and merge
jq --arg k "$VAR" '.[$k]'            # safe variable injection
curl -s "$URL" | jq -r '.data[].id'
```

**`gojq`** — worth it only for two specific reasons: arbitrary-precision integers, and reading/writing YAML. Costs you key-order preservation (`--sort-keys` and `keys_unsorted` do not exist). Not a default.

**`jless`** — interactive JSON pager. Genuinely useful for exploring a large unfamiliar payload before you know the jq path.

### delta — replaces the git pager

**Why:** side-by-side diffs, syntax highlighting, word-level highlighting, line numbers. Highest ratio of visual improvement to configuration effort on this whole list.

```bash
git diff                     # via core.pager (set in dotfiles/README.md)
git show HEAD~1
delta a.py b.py
git -c delta.side-by-side=true diff
```

### sd — replaces `sed s///`

**Why:** normal regex syntax (no escaping `\(` `\+`), literal-string mode, no BSD/GNU divergence. Only covers substitution — `sed` still owns everything else.

```bash
sd 'old' 'new' file.txt        # in-place
sd -p 'old' 'new' file.txt     # preview diff, no write
sd -F 'a.b' 'x' file           # literal, no regex
fd -e md -x sd 'foo' 'bar'
```

### xh — replaces `curl` for API work

**Why:** HTTPie syntax and ergonomics (`key=value` → JSON body, `Header:Value`), Rust-fast startup where Python HTTPie adds noticeable per-invocation delay. Keep `curl` for scripts, downloads, and anything you will paste into a Dockerfile — `curl` is everywhere, `xh` is not.

```bash
xh httpbin.org/get
xh POST api.example.com/users name=Sergey age:=30   # := for raw JSON types
xh GET api.example.com/s q==linux                   # == for query params
xh POST url X-Token:abc123
xh --download https://example.com/file.tar.gz
xh -v POST url a=b                                  # show request too
```

### tealdeer (`tldr`) — augments `man`

Community-maintained practical examples instead of full manuals. Answers "what is the flag again" in one screen.

```bash
tldr tar
tldr --update
```

### hyperfine — no equivalent

Statistical command benchmarking with warmup runs. Use it instead of eyeballing `time`.

```bash
hyperfine 'rg pattern' 'grep -r pattern .'
hyperfine --warmup 3 './build.sh'
hyperfine -L n 1,4,8 'make -j{n}'
```

---

## Interactive environments

### yazi — replaces `mc` / `ranger`

Async Rust file manager, image previews, vim keys, plugin system. Best current choice for a *new* setup. If you already have a tuned `nnn` or `ranger` config, the migration is not worth it.

```bash
yazi
# keys: hjkl navigate, Space select, y/x copy/cut, p paste,
#       d delete, a create, r rename, / search, F filter,
#       Tab preview toggle, q quit (Q = quit without cd)
```


### atuin — replaces shell history

SQLite-backed history with context (cwd, exit code, duration, host), full-text search, optional end-to-end encrypted sync across machines. Rebinds `Ctrl-R`.

```bash
atuin search --interactive
atuin stats
atuin import auto     # one-time, pulls existing history
```

**Note:** conflicts with fzf's `Ctrl-R`. Run one or the other, not both — atuin can be bound to `Ctrl-R` and fzf's history widget disabled.

### lazygit — TUI for git

Stage hunks, interactive rebase, cherry-pick, stash — without memorizing porcelain flags.

```bash
lazygit
# keys: Space stage, c commit, P push, p pull, b branches,
#       R refresh, x menu, ? help
```

### Editors

**`micro`** replaces `nano`: real mouse support, Ctrl-C/V/Z/S as you expect, syntax highlighting, plugins. Worth installing since your work is local — `nano` remains as the fallback you already know. Keys: `Ctrl-S` save, `Ctrl-Q` quit, `Ctrl-E` command mode, `Ctrl-G` help.

**`helix`** — modal editor, LSP and tree-sitter built in, zero config. Considered separately from this list; it is a project, not a swap.

### Shell: zsh on WSL

**Recommendation: zsh, plain, with two plugins.** Fish has better out-of-box ergonomics but non-POSIX syntax — every snippet you paste from the internet is a coin flip, and any future remote bash work costs you a context switch. Zsh + `zsh-autosuggestions` + `zsh-syntax-highlighting` gets ~90% of fish's interactive quality while staying bash-shaped.

**Skip oh-my-zsh.** It loads ~60 files at startup for features you will not use, and its plugin abstraction hides what is actually being sourced. Two `source` lines do the job.

```bash
# --- Install on WSL (Debian/Ubuntu) ---
sudo apt update && sudo apt install -y zsh

# plugins — no framework needed
mkdir -p ~/.zsh
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting

# make it the default shell for this WSL distro
chsh -s "$(which zsh)" "$USER"
# then: exit WSL fully (wsl --shutdown from PowerShell) and reopen
```

`chsh` sometimes does not stick in WSL. Fallbacks, in order of preference:

```bash
# 1. Windows Terminal profile: set command line to
wsl.exe ~ -d Ubuntu -e zsh

# 2. /etc/wsl.conf (per-distro default)
[user]
default=<yourname>
# ...combined with chsh above

# 3. last resort, in ~/.bashrc — replaces bash, no nesting
[ -z "$ZSH_VERSION" ] && [ -t 1 ] && exec zsh
```

**Keeping both shells in sync:** put every alias and export in a single POSIX-compatible file and source it from both rc files. Shell-specific lines (`fzf --bash` vs `fzf --zsh`, `zoxide init bash` vs `zsh`) stay in their own rc file. [`dotfiles/`](../dotfiles/) is built that way.

**`starship`** — cross-shell prompt, single TOML config, identical in bash and zsh. With a Nerd Font installed it renders the full icon set. Safe, low-commitment.

---

## What to skip

| Tool | Verdict |
|---|---|
| `exa` | Deprecated and unmaintained. Use `eza`. |
| `lsd` | Redundant with `eza`. Choose one, not both. |
| `gojq` | `jq` is actively maintained; gojq loses key ordering. Install only for bigint or YAML. |
| `duf` as a `du` replacement | Category error — `duf` is a `df` replacement. |
| `fish` | Non-POSIX syntax. zsh + 2 plugins gets you most of it without the tax. |
| `oh-my-zsh` | Heavy startup, hides what is sourced. Two `source` lines replace it. |

---

## Honest counter-argument

A widely-shared position, worth holding in mind: after several years on `bat`/`fd`/`eza`/`sd`, some experienced users revert to coreutils. The reasons are real —

- Per-tool theme configuration multiplies, especially if you switch light/dark during the day.
- `.gitignore` respect helps until it silently hides the file you were looking for.
- Speed is rarely the bottleneck at typical scale; `ripgrep` is the clear exception.
- Remote servers force you to keep coreutils fluency anyway, and switching syntax per-host costs more than the tools save.
- Editor integrations (Emacs, vim) wrap `grep`/`find` by default; coreutils compatibility keeps that path smooth.

The counter-argument does **not** apply to: `fzf`, `zoxide`, `atuin`, `delta`, `btop`, `hyperfine`, `lazygit`. Those are additive — they add capability that has no coreutils equivalent, so there is nothing to un-learn.

**How much of it applies to you:** you have no regular remote work and a Nerd Font installed, so points 1, 4 and 5 are mostly inert. Points 2 and 3 remain live — the `.gitignore` trap is real, so learn `rg -uu` / `fd -HI` as the first thing you reach for when a search "finds nothing."

**Conclusion:** install freely; the only hard rule that survives is never aliasing a core command to something with different flags.

---

## Installation

```bash
# Debian / Ubuntu — WSL default (some packages need a recent release or cargo)
sudo apt update
sudo apt install -y zsh ripgrep fd-find fzf bat jq ncdu btop micro duf
# Note: Debian ships fd as `fdfind` and bat as `batcat` — dotfiles/shell_common fixes both
# Not in apt on older Ubuntu: eza, zoxide, atuin, delta, gdu, dust, procs,
#   yazi, lazygit, xh, sd, hyperfine, starship → use cargo/brew/webi below

# eza (official repo)
sudo mkdir -p /etc/apt/keyrings && \
wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
  | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg && \
echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
  | sudo tee /etc/apt/sources.list.d/gierens.list && \
sudo apt update && sudo apt install -y eza

# one-liners for the rest
curl -sS https://starship.rs/install.sh | sh
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
curl -fsSL https://setup.atuin.sh | sh

# Arch
sudo pacman -S ripgrep fd fzf bat eza jq btop gdu duf procs dust \
               git-delta zoxide yazi lazygit tealdeer hyperfine xh sd

# Fedora
sudo dnf install ripgrep fd-find fzf bat eza jq btop duf procs git-delta zoxide

# Cross-distro fallbacks
cargo install eza procs du-dust sd hyperfine xh tealdeer jless
brew install eza gdu duf procs dust git-delta zoxide yazi lazygit  # linuxbrew
curl -sS https://webi.sh/<tool> | sh                              # single binaries
```

---

## Shell setup

The config is not embedded here — it lives as runnable files in [`dotfiles/`](../dotfiles/), symlinked into `$HOME`. See [`dotfiles/README.md`](../dotfiles/README.md) for install, load-order rules, `delta` git config, and the design rules the aliases follow.

| File | Installed as | Contents |
|---|---|---|
| `dotfiles/shell_common` | `~/.shell_common` | Aliases, exports, fzf functions. Sourced by both shells |
| `dotfiles/zshrc` | `~/.zshrc` | setopts, compinit, plugins, tool init |
| `dotfiles/bashrc` | `~/.bashrc` | shopts, completion, tool init |

Governing rule, applied throughout: **new names for new tools; core commands keep core behaviour.** Three sanctioned exceptions — `rm -I` (same binary, added flag), `df`→`duf` (read-only), `grep`→`ug` (GNU-grep-flag-compatible, and a no-op until ugrep is installed).

Every tool reference is guarded by `command -v`, so the files work on a box with none of this installed and light up as you install.

**WSL-specific notes:**

- `/mnt/c` is slow. Never run `fd`, `rg`, or `gdu` against the Windows filesystem from WSL if you can avoid it — keep repos in the Linux filesystem (`~/`). Add `--exclude /mnt` where a scan might wander.
- Windows `PATH` inheritance makes tab-completion sluggish. If it bothers you, put `[interop] appendWindowsPath=false` in `/etc/wsl.conf` and add back only what you need.
- Set the Nerd Font in the **Windows Terminal profile**, not in WSL — the font is a terminal-emulator property.
- `wsl --shutdown` from PowerShell after changing `/etc/wsl.conf` or the default shell.

---

## Sources

- [eza — GitHub discussion vs lsd](https://github.com/orgs/eza-community/discussions/679)
- [exa is unmaintained](https://forum.endeavouros.com/t/exa-has-been-deprecated/45293)
- [ripgrep](https://github.com/BurntSushi/ripgrep) · [ripgrep vs ugrep benchmark discussion](https://github.com/BurntSushi/ripgrep/discussions/2597) · [ugrep benchmark issue](https://github.com/Genivia/ugrep/issues/517)
- [jq releases](https://github.com/jqlang/jq/releases) · [gojq — differences from jq](https://github.com/itchyny/gojq)
- [xh](https://github.com/ducaale/xh)
- [gdu vs ncdu](https://itsfoss.com/gdu/) · [disk usage analyzer comparison 2026](https://cavecreekcoffee.com/reviews/best-linux-disk-usage-analyzers-2026/)
- [nnn vs yazi 2026](https://mqdir.com/blog/file-management/nnn-vs-yazi)
- [awesome-modern-cli](https://github.com/thegdsks/awesome-modern-cli)
