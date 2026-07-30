---
tags: [cli, dotfiles, config]
---

# Shell config

What the files in [`dotfiles/`](../dotfiles/) do, in what order they load, and the rules they follow. The config itself is those files; this page is the explanation. Tool rationale is in [`modern-cli-tools.md`](modern-cli-tools.md), commands in [`cheatsheet.md`](cheatsheet.md), automated install in [`install.md`](install.md).

| File | Goes to | Purpose |
|---|---|---|
| `shell_common` | `~/.shell_common` | Aliases, exports, functions. POSIX-shaped, sourced by both shells |
| `zshrc` | `~/.zshrc` | zsh-only: setopts, compinit, plugins, tool init |
| `bashrc` | `~/.bashrc` | bash-only: shopts, completion, tool init |
| `starship.toml` | `~/.config/starship.toml` | Prompt. Pure emulation, verbatim from the official preset. Shared with PowerShell |
| `profile.ps1` | sourced by `$PROFILE` | PowerShell 7 init: tool resolution, fzf env, PSReadLine, starship/zoxide/PSFzf |
| `functions.ps1` | dot-sourced by `profile.ps1` | The `shell_common` alias/function layer, ported |

Files are dotless here so they stay visible in file browsers. The dot is added at install time. The `.ps1` files keep their extension — PowerShell will not dot-source a file without it.

## Install

[`../bootstrap/install.sh`](../bootstrap/install.sh) does it, and the manual equivalent — backup, symlinks, plugins, git config, `chsh` — is [`install.md`](install.md#6-config). This page explains what the installed files then do; it does not repeat the steps.

Symlinks, not copies, so an edit in the repo takes effect with no re-install. One exception: if the repo has to live on `/mnt/c`, copy instead. WSL reads the Windows filesystem slowly and rc files are read on every shell start.

## Machine-local additions

Never edit the tracked files for one-machine settings. Both rc files source an untracked override at the end:

- `~/.zshrc.local`
- `~/.bashrc.local`

Put machine-specific `PATH` entries, work credentials, and per-host toolchain exports there.

## Dependencies

Neither rc file hard-fails on a missing tool — every line is guarded by `command -v`. Install order and per-tool install commands are in [`modern-cli-tools.md`](modern-cli-tools.md#installation).

Two things the rc files assume but do not create: the zsh plugins, which are cloned rather than vendored, and `delta`'s one-time global git config. Both are [step 7 of `install.md`](install.md#7-plugins-and-git).

`starship.toml` is the official [Pure preset](https://starship.rs/presets/pure-preset), copied verbatim so it can be regenerated with `starship preset pure-preset -o -` and diffed against upstream. Edit freely — the header comment records where it came from.

## Load order — the rules that actually bite

### bash / zsh

1. `zoxide init` after any `cd` alias, or the alias wins.
2. `atuin init` after `fzf --bash`/`--zsh`, or fzf keeps `Ctrl-R`.
3. `starship init` after both.
4. `zsh-syntax-highlighting` sourced **last of everything** — it wraps the line editor; anything loaded after it goes unhighlighted.
5. `compinit` before any plugin that registers completions.

### PowerShell 7

1. Binary paths resolved **before** anything that shells out. Same reason as `$FD_BIN` on Linux, different mechanism: fzf runs `--preview` and `FZF_*_COMMAND` through `cmd.exe` on Windows and ignores `$SHELL` ([junegunn/fzf#1018](https://github.com/junegunn/fzf/issues/1018)), where PowerShell functions do not exist.
2. `functions.ps1` dot-sourced after those variables are set — it reads them at load time.
3. `Import-Module PSReadLine` **before** PSFzf, which registers key handlers on it.
4. `starship init` before `zoxide init` — zoxide hooks the prompt function to record directories, and starship replaces that function.
5. PSFzf last of the three, so its chords win. `Ctrl+R` is not taken unless requested: `Set-PsFzfOption -PSReadlineChordReverseHistory 'Ctrl+r'`.
6. `profile.local.ps1` **last of everything** — the opposite of the zsh rule, because PSReadLine applies colours dynamically and has no wrap-the-editor constraint.

Do not enable PSFzf's optional aliases (`-EnableAlias*`): one of them is `fd`, which would shadow the `fd` binary, and `fe`/`ff`/`fkill` collide with names this config defines.

## Design rules

- **Core commands keep core behaviour.** `grep`, `find`, `cat`, `sed`, `ls`(-ish) do what a pasted script or `man` example expects. New tools get new names.
- Three sanctioned exceptions: `rm -I` (same binary, added flag), `df`→`duf` (read-only), `grep`→`ug` (a no-op until ugrep is installed).
- **The `grep`→`ug` exception is narrower than "compatible".** ugrep accepts GNU grep's flags — 29 invocations were diffed against GNU grep 3.7 and behaved identically — but two output differences survive. It searches in parallel, so `-r` output order varies between runs; the alias adds `--sort` to pin it. And `ug -r x .` prints `a.txt:x` where grep prints `./a.txt:x`, which no flag fixes. Anything that consumes those paths should call `\grep`.
- **Startup forks are budgeted, not banned.** `brew --prefix` is replaced by a directory probe that sets `$HOMEBREW_PREFIX`. Two forks are kept deliberately: `dircolors` (its `LS_COLORS` drives zsh completion colouring) and `lesspipe`. Everything else is pure shell.
- **No framework.** oh-my-zsh was removed: ~60 files sourced at startup, and its plugin layer obscures what is actually loaded.
- **Aliases are invisible to anything that shells out.** fzf runs `FZF_DEFAULT_COMMAND` through `sh`, where `fd`→`fdfind` doesn't exist. `shell_common` resolves real paths into `$FD_BIN` / `$BAT_BIN` before defining aliases, and every subshell-bound setting uses those.
- Aliases do **not** expand under `sudo` or inside scripts. `rm -I` is a prompt-level convenience, not a safety guarantee.

### PowerShell-specific

- **`Set-Alias` cannot carry arguments.** Every flag-bearing shortcut is a function.
- **Command precedence is Alias > Function > Cmdlet > Application.** A built-in cmdlet alias silently beats a function of the same name — the function never runs and never errors. `Test-CliToolsSetup` in `functions.ps1` is the check; `CLI_TOOLS_SELFCHECK=1` runs it at shell start.
- **`ls` and `cat` stay as they are**, more strictly than on Linux: `ls | Where-Object Length -gt 1MB` works today, and an `eza` wrapper returning strings would break every such pipeline. eza is `e`.
- **No git aliases.** `gc`, `gcm`, `gl`, `gp` are `Get-Content`, `Get-Command`, `Get-Location`, `Get-ItemProperty`. Overriding them breaks any script run in the session. git is driven from WSL; `g` is a plain passthrough.
- **`rm` is untouched, and `Remove-Item` does not use the Recycle Bin** — it deletes permanently. Its only prompt is `-Confirm`, which asks per item: the habituation trap `rm -i` was rejected for. There is no `-I` equivalent. Recoverable deletion is `tp`, under its own name.
- **No symlinks.** `New-Item -ItemType SymbolicLink` needs Developer Mode or elevation. `$PROFILE` is a one-line stub that dot-sources `profile.ps1`, and `cat $PROFILE` shows you exactly that.

## Scaling up later

Three symlinks need no tooling. If this grows to many files or several machines:

- **GNU stow** — `stow -t ~ dotfiles` symlinks a whole directory tree by mirroring its structure. Zero config, packaged everywhere, no templating. The right next step if the only thing that changes is file count.
- **chezmoi** — adds templating (per-host values in one file), encrypted secrets, and a `chezmoi apply` bootstrap on a new machine. Worth it only once machines genuinely differ; otherwise it is a state layer over a problem you do not have.

Both are avoidable today. The `.local` override pattern above already covers per-machine divergence.
