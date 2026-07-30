---
tags: [cli, powershell, windows]
---

# Windows / PowerShell 7

Start here if you work on Windows. The tool set and the `starship.toml` are the same as
on Linux, driven from `dotfiles/profile.ps1`; a dozen names and five constraints are not.

| Step | Where |
|---|---|
| 1. Install | [install.md#windows--powershell-7](install.md#windows--powershell-7) — Scoop, no admin rights |
| 2. Verify | `Test-CliToolsSetup` — name collisions and missing tools |
| 3. What to type | [cheatsheet.md#powershell--start-here](cheatsheet.md#powershell--start-here) — the dozen names that differ |
| 4. Why it differs | this page, below |
| 5. Change the config | [shell-config.md#powershell-7](shell-config.md#powershell-7) — load order and design rules |

The rest of this page is the *why*: the constraints that make the Windows half look
different from the Unix half.

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
   "core commands keep core behaviour" rule has sharper teeth here: **no core command
   is overridden at all on Windows.** Every Linux name that shadows one — `grep`→`ug`,
   `df`→`duf`, `top`→`btop`, `h`→`tldr`, `rm -I` — was dropped rather than ported.

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

Every `<tool> init` spawns a process. Four of them cost 666 ms on every new tab at the
first working build, and more tools were coming, so the init output is cached on disk
and dot-sourced instead; `Test-CliToolsCache` reports whether the cache is actually
being used.

Measured on the reference machine, warm, averaged over five runs `[RUN]`:

| | ms |
|---|---|
| bare `pwsh -NoProfile` | 181 |
| inside the profile, first working build | 460 |
| inside the profile, current | 386 |

Two numbers circulate for the current figure. **386 is the shipped one.** 380 was a PATH
index that was measured and then reverted — 35 lines and a correctness limitation for
about 6%.

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
`$STARSHIP_CONFIG`; the same shape applies to `$BAT_CONFIG_PATH` as configs appear.
(`$CLI_DOCS` looks similar but is not the same thing — no tool reads it, only this
repo's own `cs` function.)

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
- **Every rollback step** in [install.md](install.md).
