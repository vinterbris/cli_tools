---
tags: [cli, install, bootstrap]
---

# Bootstrap

Raise a working environment on a fresh Debian-family box.

Verified against Ubuntu 22.04 and 24.04. Written for Pop!\_OS 22.04 and Debian 12 as well — both are apt-based, and every version-sensitive decision is made at runtime rather than hardcoded per release.

---

## Fast path

```bash
git clone <this-repo> ~/cli_tools
cd ~/cli_tools/bootstrap
./install.sh --dry-run          # read what it intends to do
./install.sh --install-managers # do it
exec zsh
atuin import auto               # once, pulls existing history
```

On a machine that already has cargo and brew, drop `--install-managers`.

---

## What it does

1. Detects the distribution and confirms apt is present
2. Installs each missing tool from the best available source
3. Backs up any real config file it is about to replace, then symlinks `dotfiles/*` into `$HOME`
4. Clones the two zsh plugins
5. Wires `delta` into git
6. Offers to make zsh the login shell
7. Verifies the result and prints a summary

Nothing is removed. Anything already present is left untouched.

## Install priority

**apt → cargo → brew**, with a version gate on apt.

The gate matters. Pop!\_OS 22.04 ships fzf 0.29; the config needs ≥ 0.48 for `fzf --zsh`. Rather than hardcode "use brew on 22.04", the script asks `apt-cache policy` for the candidate version and compares it with `dpkg --compare-versions`. On 24.04 apt wins; on 22.04 the same tool falls through to cargo or brew automatically.

Only `fzf` currently carries a minimum. Others take whatever apt has, on the grounds that an older `bat` is still a working `bat`.

## Options

| Flag | Effect |
|---|---|
| `--dry-run` | Print every action, change nothing. Run this first |
| `--skip-tools` | Config only — no packages |
| `--skip-dotfiles` | Packages only — no config touched |
| `--skip-shell` | Leave the login shell alone |
| `--install-managers` | Install rustup and Homebrew if absent |
| `-h`, `--help` | Usage |

## Re-running

Safe and expected. The script distinguishes "already correct" from "needs doing":

- A symlink already pointing at the right target is reported and skipped
- A real file in the way is copied to `~/.dotfiles-backup/<timestamp>/` before being replaced
- A tool whose binary is on `PATH` is never reinstalled
- Plugin directories that are already git checkouts are left alone

Use it after editing `dotfiles/` on one machine to bring another into line.

---

## Manual sequence

If the script doesn't fit your case.

### 1. Base

```bash
sudo apt update
sudo apt install -y zsh git curl jq ripgrep fd-find bat fzf btop duf micro trash-cli
```

Debian/Ubuntu ship `fd` as `fdfind` and `bat` as `batcat`. `dotfiles/shell_common` detects this and resolves the real paths — nothing to do by hand.

### 2. Package managers

```bash
# rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 3. Rust tools

```bash
cargo install --locked eza zoxide starship atuin git-delta du-dust procs \
                       tealdeer yazi-fm xh sd hyperfine jless
```

### 4. Go tools

```bash
brew install lazygit gdu
```

Not on crates.io. If brew is unavailable, both publish release binaries on GitHub.

### 5. Newer fzf, if apt's is old

```bash
fzf --version                 # need >= 0.48 for `fzf --zsh`
brew install fzf              # or: cargo install --locked fzf-make is NOT this
```

The config falls back to sourcing `/usr/share/doc/fzf/examples/key-bindings.zsh` on older versions, so this is optional — you lose nothing but the newer interface.

### 6. Config

```bash
mkdir -p ~/.dotfiles-backup
for f in .bashrc .zshrc .shell_common; do
  [ -e ~/$f ] && cp -a ~/$f ~/.dotfiles-backup/
done

REPO=~/cli_tools/dotfiles
ln -sfn "$REPO/shell_common"  ~/.shell_common
ln -sfn "$REPO/zshrc"         ~/.zshrc
ln -sfn "$REPO/bashrc"        ~/.bashrc
mkdir -p ~/.config && ln -sfn "$REPO/starship.toml" ~/.config/starship.toml
```

### 7. Plugins and git

```bash
mkdir -p ~/.zsh
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions     ~/.zsh/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting

git config --global core.pager delta
git config --global interactive.diffFilter 'delta --color-only'
git config --global delta.navigate true
git config --global delta.line-numbers true
git config --global delta.side-by-side true
git config --global merge.conflictStyle zdiff3
```

### 8. Shell

```bash
chsh -s "$(which zsh)" "$USER"
exec zsh
```

---

## Per-machine notes

### WSL

- `chsh` often doesn't stick. Set the Windows Terminal profile command to `wsl.exe ~ -d <Distro> -e zsh`
- Keep repos in `~`, never `/mnt/c` — Windows filesystem access is slow enough to lag every shell start
- Set the Nerd Font in the terminal profile, not inside WSL. Fonts are a terminal-emulator property
- `wsl --shutdown` from PowerShell after editing `/etc/wsl.conf`
- If tab-completion feels sluggish: `[interop] appendWindowsPath=false` in `/etc/wsl.conf`

### Headless server

```bash
./install.sh --skip-shell
```

Consider trimming the tool list before running — `yazi`, `micro`, and `btop` are interactive and rarely wanted on a box you only ssh into. Edit the `TOOLS` array in `install.sh`.

`atuin` sync across machines needs an account:

```bash
atuin register -u <user> -e <email>   # or: atuin login
atuin sync
```

⚠️ History sync means every command you run on the laptop lands in the server's history and back. If you paste secrets into commands, think before enabling it.

### Pop!_OS 22.04

Older base, so more tools fall through to cargo. Expect the first run to take a while — `cargo install` compiles from source. `--install-managers` is required unless rustup is already there.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `zsh-newuser-install` prompt on first zsh | `~/.zshrc` doesn't resolve — usually a dangling symlink | `q` to quit, then `ls -l ~/.zshrc` and re-link |
| `unknown option: --zsh` | fzf < 0.48 | Harmless — the fallback loads. Upgrade fzf to remove it |
| `compinit: no such file _<tool>` | Stale completion from an uninstalled package | `sudo rm /usr/share/zsh/vendor-completions/_<tool>; rm -f ~/.zcompdump*` |
| `Ctrl-T` shows an empty list | `$FD_BIN` unset or wrong | `echo $FZF_CTRL_T_COMMAND`, then `exec zsh` |
| Icons render as boxes | Terminal font isn't a Nerd Font | Set it in the terminal, not the shell |
| Tools installed but "not found" | `PATH` missing `~/.cargo/bin` | They're added by `shell_common` — you're in a shell that predates it. `exec zsh` |
| Prompt is plain | starship absent or not initialised | `command -v starship`, then `exec zsh` |

## Rollback

```bash
ls ~/.dotfiles-backup/                 # timestamped directories
cp -a ~/.dotfiles-backup/<ts>/. ~/     # restore
chsh -s /bin/bash "$USER"              # if you want bash back
```

Removing the symlinks alone is enough to disable everything — the installed tools are inert without the config.

---

# Windows / PowerShell 7

Separate installer: [`install.ps1`](install.ps1). Same idea, different mechanics — no symlinks, no copies, and Scoop instead of apt.

## Fast path

```powershell
git clone https://github.com/vinterbris/cli_tools.git $HOME\cli_tools
& $HOME\cli_tools\bootstrap\install.ps1 -DryRun    # read this before the real run
& $HOME\cli_tools\bootstrap\install.ps1
```

Then open a new `pwsh` and run `Test-CliToolsSetup`. It should say `cli_tools: OK`.

## Prerequisites

| Needs | Why | Check |
|---|---|---|
| PowerShell **7+** | 5.1 is out of scope: one profile, one version | `$PSVersionTable.PSVersion` |
| **Scoop** | The package manager. Not installed automatically — bootstrapping a package manager by piping a remote script is a decision, not a side effect | `Get-Command scoop` |
| A **Nerd Font** in the terminal | Only for `eza --icons`. The Pure prompt's `❯` needs nothing special | Terminal settings, not the shell |

If Scoop is missing, `install.ps1` prints the two commands and stops.

## What it does

1. Adds the `main` and `extras` Scoop buckets.
2. Installs the tool list. Success is judged by `Test-Path <scoop>\apps\<name>` **after** the attempt — a native command that fails sets `$LASTEXITCODE` rather than throwing, so a `try/catch` alone would report unearned successes.
3. Installs the `PSFzf` module from the PowerShell Gallery.
4. Writes `$PROFILE` as a one-line stub that dot-sources `dotfiles\profile.ps1`.

Nothing is deleted. An existing `$PROFILE` is copied to `<profile>.bak-<timestamp>` first. ⚠️ **That branch has never executed** — `$PROFILE` did not exist on the reference machine, so the installer took the create path. Back up by hand before the first run on a machine that already has a profile.

## Options

| Flag | Effect |
|---|---|
| `-DryRun` | Print every action, change nothing. Run this first |
| `-SkipTools` | Only rewrite the `$PROFILE` stub — use this after moving the repo |
| `-SkipProfile` | Only install packages |

## Why there is no symlink

`$PROFILE` holds one line pointing at the repo, so the file in the repo *is* the loaded config and there is no sync step. Two reasons it works out this way:

- `New-Item -ItemType SymbolicLink` needs Developer Mode or an elevated shell on Windows.
- zsh insists on `~/.zshrc` at a fixed path and so needs a link; PowerShell lets the stub point anywhere.

Consequence: **moving the repo breaks the shell**, because the stub holds an absolute path. Re-run `install.ps1 -SkipTools` after any move.

## Config policy

The repo is the single source of truth; tools are pointed at it with environment variables rather than by copying files. Rationale and the rejected alternative are in [../docs/powershell.md](../docs/powershell.md#config-policy).

Trade-off worth knowing: a tool launched from *outside* pwsh — from Explorer, or another shell — will not see those variables and falls back to its own default location.

## Startup cost

The generated init scripts for starship, zoxide, carapace and atuin are cached in `%LOCALAPPDATA%\cli_tools\cache` and dot-sourced, instead of running four binaries on every shell start. Staleness compares timestamps against the binary, so `scoop update` invalidates the cache by itself.

```powershell
$env:CLI_TOOLS_TIMING=1; pwsh -NoLogo -Command exit   # per-stage cost
Test-CliToolsCache                                    # is the cache being used
Clear-CliToolsCache                                   # wipe it
```

Measured on the reference machine: 181 ms for a bare `pwsh -NoProfile`, ~386 ms inside the profile. The largest remaining items are the `PSFzf` and `PSReadLine` module loads. Full breakdown in [../docs/powershell.md](../docs/powershell.md#startup-cost).

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Ctrl-T` hangs for seconds in `$HOME` | `fd` is walking `AppData` | Already fixed — `-I` dropped and `AppData`/`node_modules` excluded. Check `$env:FZF_CTRL_T_COMMAND` |
| A shortcut of yours "does nothing and gives no error" | A built-in cmdlet alias beats a function of the same name, silently | `Test-CliToolsSetup`, and `Get-Command <name>` to see what it resolved to |
| `Ctrl-R` opens the wrong picker | atuin owns `Ctrl-R` when installed, PSFzf when not | `Get-PSReadLineKeyHandler -Bound` |
| Preview pane in `Ctrl-T` shows a cmd error | The dual file/directory preview is quoting-sensitive | `dotfiles\profile.ps1` has a one-line file-only fallback in a comment |
| `Tab` prints raw escape codes | carapace needs `MenuComplete`, and `-EditMode` resets key bindings | Order matters — `EditMode` first, then the Tab handler |
| `glow -p` → `"less" not found` | glow's pager is `less`, which Windows lacks | `mdv` already drops `-p`. Don't add it back |
| `scoop install X` reported `failed` | Wrong package name or wrong bucket | `scoop search X`. Note `carapace` is `carapace-bin` in `extras` |
| Icons are boxes | Terminal font is not a Nerd Font | Terminal settings |
| Prompt is plain | starship missing, or a stale cache | `Get-Command starship`, then `Clear-CliToolsCache` |

## Rollback

```powershell
Get-ChildItem "$PROFILE.bak-*"        # backups, timestamped
Copy-Item "$PROFILE.bak-<ts>" $PROFILE -Force
Remove-Item $PROFILE                  # or just delete it — pwsh starts bare
Clear-CliToolsCache
scoop uninstall <name>                # per tool
Uninstall-Module PSFzf
```

Deleting the one-line `$PROFILE` stub disables everything at once. The installed tools are inert without the config.
