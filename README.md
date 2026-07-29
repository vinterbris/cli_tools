---
tags: [cli, index]
---

# CLI Tools

Modern command-line environment: tool selection, runnable config, and the material to actually learn it.

Targets Debian-family Linux — Ubuntu 24.04 (WSL), Pop!\_OS 22.04, Debian 12.

## Start here

| If you want to | Read |
|---|---|
| Set up a new machine | [bootstrap/INSTALL.md](bootstrap/INSTALL.md) |
| Look up a command or flag | [cheatsheet.md](cheatsheet.md) — or type `cs <term>` |
| Solve a specific task | [usecases.md](usecases.md) |
| Learn this systematically | [learning-plan.md](learning-plan.md) |
| Know why these tools | [modern-cli-tools.md](modern-cli-tools.md) |
| Change the config | [dotfiles/README.md](dotfiles/README.md) |

## Layout

```
cli_tools/
├── README.md              this index
├── modern-cli-tools.md    why this set — rationale, tier list, counter-arguments
├── cheatsheet.md          what to type — dense, print-oriented
├── usecases.md            how to solve a task — ordered by frequency
├── learning-plan.md       how to absorb it — phases, not weeks
├── dotfiles/              runnable config, symlinked into $HOME
│   ├── shell_common       aliases, exports, functions (bash + zsh)
│   ├── zshrc              zsh init
│   ├── bashrc             bash init
│   ├── starship.toml      prompt (Pure emulation)
│   └── README.md          install, load order, design rules
├── bootstrap/
│   ├── install.sh         idempotent installer, --dry-run
│   └── INSTALL.md         manual sequence, per-machine notes, troubleshooting
└── archive/               superseded PDF/HTML/PNG renders
```

Each document answers one question and links to the others rather than repeating them. If two files start saying the same thing, one of them is wrong.

## Quick install

```bash
git clone <repo> ~/cli_tools
~/cli_tools/bootstrap/install.sh --dry-run
~/cli_tools/bootstrap/install.sh --install-managers
exec zsh
```

## Design rules

Applied throughout, and the reason the config looks the way it does:

- **Core commands keep core behaviour.** `grep`, `find`, `cat`, `sed` do what a pasted script or `man` example expects. New tools get new names. Three sanctioned exceptions: `rm -I`, `df`→`duf`, `grep`→`ug`.
- **No framework.** oh-my-zsh replaced by two `source` lines. Nothing is loaded that you cannot point at.
- **Guarded everywhere.** Every tool reference is wrapped in `command -v`, so the config works on a bare machine and lights up as you install.
- **Machine-local settings never touch tracked files** — `~/.zshrc.local` and `~/.bashrc.local` are sourced at the end.
