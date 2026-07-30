# dotfiles

Runnable shell config — the files themselves, no prose. Installed by symlink on Linux
(`shell_common`, `zshrc`, `bashrc`, `starship.toml`) and dot-sourced from `$PROFILE` on
Windows (`profile.ps1`, `functions.ps1`).

| Read this for | There |
|---|---|
| What each file does, load order, design rules | [`../docs/shell-config.md`](../docs/shell-config.md) |
| Installing it | [`../docs/install.md`](../docs/install.md) |
| Commands and aliases | [`../docs/cheatsheet.md`](../docs/cheatsheet.md) |

Machine-local settings never go in these files — use `~/.zshrc.local`, `~/.bashrc.local`
or `profile.local.ps1`, all untracked and sourced last.
