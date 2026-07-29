---
tags: [cli, reference, cheatsheet]
---

# CLI Cheatsheet

Dense reference. What to type, not why — the reasoning is in [modern-cli-tools.md](modern-cli-tools.md), task-shaped recipes are in [usecases.md](usecases.md).

Aliases below come from [`dotfiles/shell_common`](dotfiles/shell_common). Search this file from the shell with `cs <term>`.

---

## Aliases — listing & viewing

| Alias | Runs | Notes |
|---|---|---|
| `ls` | `eza --group-directories-first --icons=auto` | |
| `ll` | `eza -lh --git ...` | long + git status column |
| `la` | `eza -lah --git ...` | + hidden |
| `lt` | `eza --tree --level=2` | replaces `tree` |
| `ltt` | `eza --tree --level=4` | deeper |
| `ltg` | `eza --tree --level=3 --git-ignore` | skips ignored files |
| `lsize` | `eza -lah --sort=size --reverse` | biggest first |
| `lnew` | `eza -lah --sort=modified --reverse` | newest first |
| `b` | `bat` | syntax-highlighted read |
| `bp` | `bat -p` | plain — safe to copy from |

## Aliases — search & find

| Alias | Runs |
|---|---|
| `rgh` | `rg -uuu` — no ignore, hidden, binary |
| `rgf` | `rg --files` — list what rg would search |
| `ff` | `fd -tf` — files only |
| `fdd` | `fd -td` — dirs only |
| `fda` | `fd -HI` — hidden + gitignored |
| `grep` | `grep --color=auto` (or `ug` if installed) |
| `egrep` / `fgrep` | `grep -E` / `grep -F`, coloured |
| `fd` / `bat` | → `fdfind` / `batcat` on Debian & Ubuntu, only if the real binary is absent |

## Aliases — disk, process, system

| Alias | Runs |
|---|---|
| `df` | `duf` — mounted filesystems |
| `dus` | `du -sh * \| sort -h` — coreutils fallback |
| `dsz` | `dust -d 2` — tree by size, depth 2 |
| `ncdu` | `gdu` — interactive, delete inside |
| `top` | `btop` |
| `pg` | `procs` — process grep |
| `ptree` / `pcpu` / `pmem` | `procs --tree` / `--sortd cpu` / `--sortd mem` |

## Aliases — git

| Alias | Runs |
|---|---|
| `gs` | `git status -sb` |
| `gd` / `gds` | `git diff` / `--staged` |
| `gl` | `git log --oneline --graph --decorate -20` |
| `ga` / `gc` / `gcm` | `git add` / `commit` / `commit -m` |
| `gco` / `gcb` | `git switch` / `git switch -c` |
| `gp` | `git push` |
| `lg` | `lazygit` |

> `gl` is **log**, not `git pull` — oh-my-zsh used the other meaning. `git pull` has no alias by design.

## Aliases — files, apt, misc

| Alias | Runs |
|---|---|
| `rm` | `rm -I` — one prompt for >3 files or `-r` |
| `mv` / `cp` / `ln` | `-i` — prompt before overwrite |
| `tp` / `tl` / `tre` / `tempty` | `trash-put` / `-list` / `-restore` / `-empty` |
| `md` | `mkdir -pv` |
| `jqc` / `jqr` | `jq -c` (compact) / `jq -r` (raw strings) |
| `http` | `xh` |
| `aptup` | `sudo apt update && sudo apt upgrade` |
| `aptupd` / `aptupg` | update only / upgrade only |
| `aptin` / `aptrm` | `sudo apt install` / `remove` |
| `h` | `tldr` |
| `fm` | `yazi` |
| `py` | `python3` |
| `path` | print `$PATH` one entry per line |
| `..` / `...` / `....` | up 1 / 2 / 3 levels |

> Aliases do **not** expand under `sudo` or inside scripts. `rm -I` is convenience, not a guarantee.

## Functions

| Function | Does |
|---|---|
| `fe` | fuzzy-pick a file, open in `$EDITOR` |
| `fif <pat>` | search contents, preview match, open at that line |
| `fkill [sig]` | pick processes interactively, kill (default TERM) |
| `fbr` | fuzzy-pick a git branch, switch to it |
| `cs [term]` | search this cheatsheet by section |

---

## Keybindings

| Key | Does | From |
|---|---|---|
| `Ctrl-R` | search shell history, with cwd + exit code | atuin |
| `Ctrl-T` | insert a file path into the current command | fzf |
| `Alt-C` | cd into a picked directory | fzf |
| `**<Tab>` | fuzzy-complete any path argument | fzf |
| `Ctrl-A` / `Ctrl-E` | start / end of line | zsh |
| `Ctrl-W` | delete word back | zsh |
| `Ctrl-U` / `Ctrl-K` | delete to start / end of line | zsh |
| `Alt-.` | insert last argument of previous command | zsh |
| `Ctrl-L` | clear screen | zsh |
| `→` (end of line) | accept autosuggestion | zsh-autosuggestions |
| `Ctrl-Z` … `fg` | suspend job, resume it | zsh |

Inside fzf: `Tab` multi-select · `Ctrl-J/K` move · `Ctrl-/` toggle preview · `Esc` cancel.

---

## ripgrep — `rg`

```bash
rg pattern                # recursive from cwd
rg -i pattern             # case-insensitive
rg -w pattern             # whole word
rg -F 'literal.string'    # no regex
rg -l pattern             # filenames only
rg -tpy pattern           # only Python (-Tpy excludes Python)
rg -g '*.conf' pattern    # glob filter
rg -C3 pattern            # 3 lines of context
rg -uu pattern            # + gitignored + hidden
rg --files | rg conf      # list files, then filter
rg 'old' -l | xargs sd 'old' 'new'
```

**Trap:** respects `.gitignore` and skips hidden files. "Finds nothing" → `rgh`.

## fd

```bash
fd pattern                # match by name, recursive
fd -e md                  # by extension
fd -tf / -td / -tl        # files / dirs / symlinks
fd -H / -I / -HI          # hidden / ignored / both
fd -g '*.tar.gz'          # glob instead of regex
fd -d 2 pattern           # max depth
fd . /var/log -x gzip     # exec per result (-X = batch)
fd -0 pat | xargs -0 rm   # null-safe piping
```

**Trap:** same gitignore behaviour as rg. `fda` bypasses it.

## fzf

```bash
fzf                                  # filter stdin
vim "$(fzf)"                         # open picked file
fd -tf | fzf --preview 'bat --color=always {}'
git branch | fzf | xargs git switch
```

Env already set in `shell_common`: `FZF_DEFAULT_COMMAND`, `FZF_CTRL_T_OPTS`, `FZF_ALT_C_OPTS`.

**Trap:** fzf runs these through `sh`, where aliases don't exist. Use `$FD_BIN` / `$BAT_BIN`.

## bat

```bash
bat file.py
bat -p file.txt           # plain, no line numbers
bat -A file.txt           # show non-printables
bat -r 20:40 file.log     # line range
bat -l json < payload     # force language for stdin
bat --diff file.py        # only git-modified lines
```

Pipe-safe: detects non-TTY and behaves like `cat`.

## eza

```bash
eza -lh --git --icons
eza -la --group-directories-first
eza --tree --level=2
eza -l --sort=modified --reverse
eza -l --total-size              # dir sizes (slow)
eza -l --no-permissions --no-user # trim noise
```

## zoxide

```bash
z foo            # jump to best match
z foo bar        # multiple keywords narrow it
zi foo           # interactive pick
z -              # previous directory
zoxide query -l  # dump the database
```

`cd` still works unchanged. Database needs a few days of normal `cd` to be useful.

## atuin

```bash
atuin search --interactive
atuin search -e 0 --limit 20   # only successful commands
atuin stats                    # what you actually run
atuin import auto              # one-time, pulls old history
```

Owns `Ctrl-R`. Inside: type to filter, `Ctrl-R` cycles filter mode (global / host / session / directory).

---

## btop

```bash
btop
```

`Esc` menu · `f` filter · `t` tree · `+/-` expand · `1234` toggle boxes · `q` quit

## gdu / dust / duf

```bash
gdu /            # interactive: navigate and delete
gdu -n /var      # non-interactive
dust             # tree of cwd by size
dust -d 2 /var   # limit depth
duf              # mounted filesystems (this is `df`, not `du`)
duf --only local
```

gdu keys: `d` delete · `r` rescan · `n`/`s`/`c` sort by name/size/count

## procs

```bash
procs nginx        # search by name/pid/user/port
procs --tree
procs --sortd cpu
procs --watch
```

---

## git + delta

```bash
git diff                     # paged through delta
git show HEAD~1
delta a.py b.py
git -c delta.side-by-side=false diff   # override for one command
```

Inside delta: `n` / `N` jump between files.

## lazygit

```bash
lg
```

`Space` stage · `c` commit · `P` push · `p` pull · `b` branches · `x` menu · `?` help · `q` quit

---

## jq

```bash
jq . file.json                       # pretty-print
jq -r '.items[].name' f.json         # raw strings, no quotes
jq '.[] | select(.age > 30)'
jq -c '.[]'                          # compact, one per line
jq 'map({id, name})'
jq -s 'add' a.json b.json            # slurp and merge
jq --arg k "$VAR" '.[$k]'            # safe variable injection
```

`jless file.json` — interactive pager for exploring an unfamiliar payload.

## xh

```bash
xh httpbin.org/get
xh POST api.example.com/users name=Sergey age:=30   # := raw JSON type
xh GET api.example.com/s q==linux                   # == query param
xh POST url X-Token:abc123                          # : header
xh --download https://example.com/f.tar.gz
xh -v POST url a=b                                  # show request too
```

Keep `curl` for scripts and Dockerfiles.

## sd

```bash
sd 'old' 'new' file.txt        # in-place
sd -p 'old' 'new' file.txt     # preview, no write
sd -F 'a.b' 'x' file           # literal, no regex
fd -e md -x sd 'foo' 'bar'
```

Substitution only. `sed` still owns everything else.

## hyperfine

```bash
hyperfine 'rg pattern' 'grep -r pattern .'
hyperfine --warmup 3 './build.sh'
hyperfine -L n 1,4,8 'make -j{n}'
```

## yazi

```bash
fm
```

`hjkl` navigate · `Space` select · `y`/`x` copy/cut · `p` paste · `d` delete · `a` create · `r` rename · `/` search · `F` filter · `Tab` preview · `q` quit (cd's to current dir) · `Q` quit without cd

## trash-cli

```bash
tp file.txt      # trash-put
tl               # list
tre              # restore, interactive
tempty 30        # empty items older than 30 days
```

**Trap:** cross-filesystem trash is a full copy. Outside `$HOME` needs `.Trash-$UID` on that mount.

## tealdeer

```bash
h tar            # tldr
h --update
```

---

## zsh specifics

### Globbing

```bash
ls **/*.md            # recursive
ls **/*.md~*node_modules*   # with exclusion
ls *(.)               # plain files only
ls *(/)               # directories only
ls *(.om[1,5])        # 5 newest files
ls *(Lm+10)           # larger than 10 MB
ls *(.x)              # executable
```

`~` excludes, `(...)` are qualifiers. This replaces most simple `find` calls.

### History

```bash
!!            # previous command
sudo !!       # rerun it with sudo
!$            # last argument of previous command
!*            # all arguments of previous command
!rg           # last command starting with rg
^old^new      # rerun previous, substituting once
```

### Options active in this config

| setopt | Effect |
|---|---|
| `AUTO_CD` | `foo` alone == `cd foo` |
| `AUTO_PUSHD` | `cd -<Tab>` walks the directory stack |
| `SHARE_HISTORY` | history shared live between open shells |
| `HIST_IGNORE_ALL_DUPS` | duplicates removed, not just skipped |
| `HIST_VERIFY` | `!!` expands into the line for review, does not run blind |
| `INTERACTIVE_COMMENTS` | `#` works at the prompt |

### Completion

`Tab` once to complete, again to enter the menu, arrows to pick. Case-insensitive: `dow<Tab>` → `Downloads`.

### Escaping the config

```bash
\rm file          # bypass an alias for one call
command rm file   # same, more explicit
unalias rm        # for the session
```

---

## Escape hatches

| Situation | Reach for |
|---|---|
| Search finds nothing | `rgh` / `fda` — gitignore is hiding it |
| Alias in the way | `\cmd` or `command cmd` |
| Need coreutils on a bare box | `grep -rn` · `find -name -type` · `du -sh` · `ps aux` |
| Config broke the shell | zsh drops to a working prompt; fix and `exec zsh` |
| Forgot a flag | `h <tool>` (tldr) before `man` |
