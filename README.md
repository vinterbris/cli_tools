---
tags: [cli, index]
---

# CLI Tools

Modern command-line environment: tool selection, runnable config, and the material to actually learn it.

One prompt, one tool set, one cheatsheet across three shells: **zsh**, **bash**, and **PowerShell 7**.

| Platform | Status | Shell | Prompt |
|---|---|---|---|
| Ubuntu 24.04 (WSL2) | deployed | zsh | starship, Pure preset |
| Windows 11 | deployed | PowerShell 7 | the same `starship.toml` |
| Pop!\_OS 22.04 (laptop) | planned | zsh | — |
| Debian 12 (server) | planned | bash | — |

## Start here

| If you want to | Read |
|---|---|
| Set up a new Linux machine | [bootstrap/INSTALL.md](bootstrap/INSTALL.md) |
| Set up Windows / PowerShell | [docs/powershell.md](docs/powershell.md), then `bootstrap/install.ps1 -DryRun` |
| Look up a command or flag | [docs/cheatsheet.md](docs/cheatsheet.md) — or type `cs <term>` |
| Solve a specific task | [docs/usecases.md](docs/usecases.md) |
| Learn this systematically | [docs/learning-plan.md](docs/learning-plan.md) |
| Know why these tools | [docs/modern-cli-tools.md](docs/modern-cli-tools.md) |
| Change the config | [dotfiles/README.md](dotfiles/README.md) |

## Layout

```
cli_tools/
├── README.md              this index
├── docs/
│   ├── modern-cli-tools.md  why this set — rationale, tier list, counter-arguments
│   ├── cheatsheet.md        what to type — dense, print-oriented
│   ├── usecases.md          how to solve a task — ordered by frequency
│   ├── learning-plan.md     how to absorb it — phases, not weeks
│   └── powershell.md        the Windows half: constraints, decisions, startup cost
├── dotfiles/              runnable config
│   ├── shell_common       aliases, exports, functions (bash + zsh)
│   ├── zshrc              zsh init
│   ├── bashrc             bash init
│   ├── profile.ps1        PowerShell 7 init
│   ├── functions.ps1      the alias/function layer, ported to PowerShell
│   ├── starship.toml      prompt (Pure emulation) — shared by all three shells
│   └── README.md          install, load order, design rules
└── bootstrap/
    ├── install.sh         idempotent Linux installer, --dry-run
    ├── install.ps1        idempotent Windows installer, -DryRun
    └── INSTALL.md         manual sequence, per-machine notes, troubleshooting
```

Each document answers one question and links to the others rather than repeating them. If two files start saying the same thing, one of them is wrong.

## Quick install

Linux:

```bash
git clone https://github.com/vinterbris/cli_tools.git ~/cli_tools
~/cli_tools/bootstrap/install.sh --dry-run
~/cli_tools/bootstrap/install.sh --install-managers
exec zsh
```

Windows (PowerShell 7 + Scoop):

```powershell
git clone https://github.com/vinterbris/cli_tools.git $HOME\cli_tools
& $HOME\cli_tools\bootstrap\install.ps1 -DryRun
& $HOME\cli_tools\bootstrap\install.ps1
```

## Design rules

Applied throughout, and the reason the config looks the way it does:

- **Core commands keep core behaviour.** `grep`, `find`, `cat`, `sed` do what a pasted script or `man` example expects. New tools get new names. Three sanctioned exceptions on Linux: `rm -I`, `df`→`duf`, and `grep`→`ug` — which accepts GNU grep's flags but not its output ordering or path prefixes, so scripts should call `\grep`. **Zero on Windows** — see [dotfiles/README.md](dotfiles/README.md#powershell-specific) for why each one loses its justification there.
- **No framework.** oh-my-zsh replaced by two `source` lines. Nothing is loaded that you cannot point at.
- **Guarded everywhere.** Every tool reference is wrapped in `command -v`, so the config works on a bare machine and lights up as you install.
- **Machine-local settings never touch tracked files** — `~/.zshrc.local` and `~/.bashrc.local` are sourced at the end.
