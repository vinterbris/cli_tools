---
tags: [cli, powershell, windows]
---

# PowerShell 7

The same tool set and the same `starship.toml` as the Linux config, driven from
`dotfiles/profile.ps1`. This page is the *why*: the constraints that make the Windows
half look different from the Unix half. For what to type, see
[cheatsheet.md](cheatsheet.md#powershell--start-here). For installation, see
[../bootstrap/INSTALL.md](../bootstrap/INSTALL.md#windows--powershell-7).

## Scope

PowerShell 7 (`pwsh`) only — 5.1 is not supported. Packages come from Scoop: no admin
rights, current versions, one `scoop update *`. Windows Terminal is assumed.

## Five constraints that shape the port

1. **`Set-Alias` cannot carry arguments.** `alias ll='eza -lh --git'` has no alias form
   on Windows. Every flag-bearing alias becomes a function.

2. **PowerShell resolves Alias before Function.** A function named after a built-in
   cmdlet alias — `gc`, `gcm`, `gl`, `gp`, `h`, `ls` — never runs and never errors. It
   is defined, it is shadowed, and nothing tells you. This is the single nastiest trap
   in the port; `Test-CliToolsSetup` exists to catch it.

3. **Overriding `ls` breaks the object pipeline.** `ls | Where-Object Length -gt 1MB`
   works today. An `eza` function returns strings and silently breaks it. The repo's
   "core commands keep core behaviour" rule has sharper teeth here, which is why there
   are **zero** aliasing exceptions on Windows against three on Linux — `grep`→`ug`,
   `df`→`duf`, `top`→`btop` and `h`→`tldr` were all dropped.

4. **fzf has no `--powershell` init.** Bindings come from the `PSFzf` module, not from
   `FZF_CTRL_T_COMMAND` / `FZF_ALT_C_COMMAND`. `Ctrl-R` is not bound by PSFzf unless
   asked for — and it is not, because atuin claims it, mirroring the Linux load-order
   rule.

5. **fzf on Windows runs `--preview` and `FZF_*_COMMAND` through `cmd.exe`** and ignores
   `$SHELL` ([fzf#1018](https://github.com/junegunn/fzf/issues/1018)). This is the
   Windows form of the Linux `$FD_BIN` trap: anything that shells out cannot see a
   PowerShell function.

## No symlinks

`$PROFILE` is a one-line stub that dot-sources `dotfiles/profile.ps1` from the repo.
Symlinks on Windows need Developer Mode or admin, and the `/mnt/c` slowness that forced
copies inside WSL does not apply to a repo on native `C:`.

Never hardcode the `$PROFILE` path — it moves if OneDrive backs up `Documents`. Always
resolve `$PROFILE`.

## Two chords are deliberately unbound

`Ctrl+T` and `Alt+C` both corrupted the terminal display: an empty picker, then garbled
output on the first keystroke. Removed rather than fixed.

| Was | Use instead |
|---|---|
| `Ctrl+T` | `fe` — pick a file, open in `$EDITOR` |
| `Alt+C` | `zi` — zoxide's interactive picker |

`Alt+A` works and is kept. `FZF_CTRL_T_COMMAND` and `FZF_ALT_C_COMMAND` stay exported —
`fe` and any direct fzf call consume them.

The lead, if anyone returns to this: **plain fzf is fine.** `cs` invokes `fzf.exe`
directly and works. The fault is in PSFzf's PSReadLine handlers redrawing the prompt,
plausibly `InvokePromptHack` against Windows Terminal and a two-line prompt. Not fzf,
not the environment.

## Startup cost

Every `<tool> init` spawns a process. Four of them at once pushed a new tab past a
second, so the init output is cached on disk and re-read; `Test-CliToolsCache` reports
whether the cache is actually being used. Profile load is ~380 ms, down from 847 ms at
the first working build.

Measured, not assumed — and the one finding worth carrying: Steve Lee's
[`Initialize-Profile`](https://devblogs.microsoft.com/powershell/optimizing-your-profile/)
technique does **not** speed up interactive startup, because `prompt` runs before the
first prompt is drawn. See also Microsoft's [startup performance
guide](https://learn.microsoft.com/en-us/powershell/scripting/dev-cross-plat/performance/startup-performance).
Use `PSProfiler` / `Measure-Script` for per-line attribution; hand-rolled stage timers
are too coarse to explain what they find.

## Config policy

**The repo is the single source of truth; tools are pointed at it with environment
variables.** Nothing is copied into a tool's conventional location. Today that means
`$STARSHIP_CONFIG` and `$CLI_DOCS`; the same shape applies to `$BAT_CONFIG_PATH` as
configs appear.

Rejected: having `install.ps1` distribute files into each tool's native directory. It
would make a config findable when a tool launches from outside pwsh, but it reintroduces
a sync step — the exact drift this project keeps paying for elsewhere. Revisit at three
or four config files.

## Verify

```powershell
Test-CliToolsSetup    # name collisions + missing tools
Test-CliToolsCache    # is the init cache being used
cs -List              # cheatsheet sections
```

## Not verified

`install.ps1` has been run for real, and `-DryRun` twice. Two paths through it never
executed and should be treated as untested:

- **The replace-and-backup branch.** `$PROFILE` did not exist on the machine, so the
  installer took the create branch. What happens to an existing `$PROFILE` is
  review-level only.
- **Every rollback step** in [../bootstrap/INSTALL.md](../bootstrap/INSTALL.md).
