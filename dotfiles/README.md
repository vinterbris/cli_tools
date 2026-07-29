# dotfiles

Runnable shell config. This directory is the config itself, not documentation of it — rationale is in [`../modern-cli-tools.md`](../modern-cli-tools.md), commands in [`../cheatsheet.md`](../cheatsheet.md), automated install in [`../bootstrap/`](../bootstrap/INSTALL.md).

| File | Goes to | Purpose |
|---|---|---|
| `shell_common` | `~/.shell_common` | Aliases, exports, functions. POSIX-shaped, sourced by both shells |
| `zshrc` | `~/.zshrc` | zsh-only: setopts, compinit, plugins, tool init |
| `bashrc` | `~/.bashrc` | bash-only: shopts, completion, tool init |
| `starship.toml` | `~/.config/starship.toml` | Prompt. Pure emulation, verbatim from the official preset |

Files are dotless here so they stay visible in file browsers. The dot is added at install time.

## Install

Automated: [`../bootstrap/install.sh`](../bootstrap/install.sh) does everything below plus tool installation. The manual path follows.

Back up first — Debian ships a default `~/.bashrc`:

```bash
mkdir -p ~/.dotfiles-backup
for f in .bashrc .zshrc .shell_common; do
  [ -e ~/$f ] && cp -a ~/$f ~/.dotfiles-backup/
done
```

Symlink, so edits in the repo take effect with no re-copy:

```bash
REPO=~/path/to/cli_tools/dotfiles
ln -sf "$REPO/shell_common" ~/.shell_common
ln -sf "$REPO/zshrc"        ~/.zshrc
ln -sf "$REPO/bashrc"       ~/.bashrc
mkdir -p ~/.config
ln -sf "$REPO/starship.toml" ~/.config/starship.toml
```

Copy instead of symlink if the repo lives on `/mnt/c` — WSL reads the Windows filesystem slowly, and rc files are read on every shell start.

## Machine-local additions

Never edit the tracked files for one-machine settings. Both rc files source an untracked override at the end:

- `~/.zshrc.local`
- `~/.bashrc.local`

Put machine-specific `PATH` entries, work credentials, and per-host toolchain exports there.

## Dependencies

Neither rc file hard-fails on a missing tool — every line is guarded by `command -v`. Install order and per-tool install commands are in [`../modern-cli-tools.md`](../modern-cli-tools.md#installation).

Zsh plugins are not vendored:

```bash
mkdir -p ~/.zsh
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions     ~/.zsh/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting
```

`starship.toml` is the official [Pure preset](https://starship.rs/presets/pure-preset), copied verbatim so it can be regenerated with `starship preset pure-preset -o -` and diffed against upstream. Edit freely — the header comment records where it came from.

One-time git config for `delta`:

```bash
git config --global core.pager delta
git config --global interactive.diffFilter 'delta --color-only'
git config --global delta.navigate true
git config --global delta.line-numbers true
git config --global delta.side-by-side true
git config --global merge.conflictStyle zdiff3
```

## Load order — the rules that actually bite

1. `zoxide init` after any `cd` alias, or the alias wins.
2. `atuin init` after `fzf --bash`/`--zsh`, or fzf keeps `Ctrl-R`.
3. `starship init` after both.
4. `zsh-syntax-highlighting` sourced **last of everything** — it wraps the line editor; anything loaded after it goes unhighlighted.
5. `compinit` before any plugin that registers completions.

## Design rules

- **Core commands keep core behaviour.** `grep`, `find`, `cat`, `sed`, `ls`(-ish) do what a pasted script or `man` example expects. New tools get new names.
- Three sanctioned exceptions: `rm -I` (same binary, added flag), `df`→`duf` (read-only), `grep`→`ug` (flag-compatible with GNU grep, and a no-op until ugrep is installed).
- **Startup forks are budgeted, not banned.** `brew --prefix` is replaced by a directory probe that sets `$HOMEBREW_PREFIX`. Two forks are kept deliberately: `dircolors` (its `LS_COLORS` drives zsh completion colouring) and `lesspipe`. Everything else is pure shell.
- **No framework.** oh-my-zsh was removed: ~60 files sourced at startup, and its plugin layer obscures what is actually loaded.
- **Aliases are invisible to anything that shells out.** fzf runs `FZF_DEFAULT_COMMAND` through `sh`, where `fd`→`fdfind` doesn't exist. `shell_common` resolves real paths into `$FD_BIN` / `$BAT_BIN` before defining aliases, and every subshell-bound setting uses those.
- Aliases do **not** expand under `sudo` or inside scripts. `rm -I` is a prompt-level convenience, not a safety guarantee.

## Scaling up later

Three symlinks need no tooling. If this grows to many files or several machines:

- **GNU stow** — `stow -t ~ dotfiles` symlinks a whole directory tree by mirroring its structure. Zero config, packaged everywhere, no templating. The right next step if the only thing that changes is file count.
- **chezmoi** — adds templating (per-host values in one file), encrypted secrets, and a `chezmoi apply` bootstrap on a new machine. Worth it only once machines genuinely differ; otherwise it is a state layer over a problem you do not have.

Both are avoidable today. The `.local` override pattern above already covers per-machine divergence.
