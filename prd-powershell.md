---
tags: [prd, powershell, windows]
---

# PRD — PowerShell 7 port

Planning document, awaiting sign-off. Not yet implemented. Delete or fold into
[README.md](README.md) + [HANDOFF.md](HANDOFF.md) once the work lands.

Provenance tags: `[WEB]` searched · `[REPO]` read in this repo · `[RUN]` executed ·
`[INF]` derived · `[MEM]` recalled, unverified · `[?]` unrecorded.

---

## 1. Problem

The environment described in this repo exists only inside WSL. Native Windows work
(Explorer-adjacent paths, `winget`, .NET tooling, anything touching `C:` at speed)
happens in PowerShell, where none of it is available: no fuzzy history, no `z`,
default prompt, no fast file navigation.

Secondary problem: the repo is still not under git ([HANDOFF.md](HANDOFF.md), open
thread #1). Adding a third config surface without version control multiplies the
existing Windows↔WSL drift.

## 2. Success criteria

Binary, checkable on the machine:

1. `pwsh` starts in **< 400 ms** with the full profile loaded (`Measure-Command`).
2. `Ctrl-T` inserts a fuzzy-picked path; `Ctrl-R` fuzzy-searches PSReadLine history;
   `Alt-C` changes directory. All three with a `bat`/`eza` preview pane.
3. `z <partial>` jumps; `zi` opens the interactive picker.
4. Prompt is visually identical to the WSL Pure prompt, driven by the **same**
   `dotfiles/starship.toml` — no Windows-specific fork of that file.
5. `cs <term>` finds a section of `cheatsheet.md` from PowerShell.
6. A fresh Windows box reaches this state by running one documented script.
7. Repo is a git repository with a clean README; WSL copy is a clone, not a `cp -r`.

## 3. Decisions taken (from the answered questions)

| Decision | Value |
|---|---|
| Shell | PowerShell 7 (`pwsh`) only. `powershell.exe` 5.1 not supported |
| Package manager | Scoop (no admin, current versions, `scoop update *`) |
| Terminal | Windows Terminal — assumed present |
| Scope | 3 core tools **+** ported alias/function layer **+** git repo & README |

## 4. Non-goals

- PowerShell 5.1 compatibility. One profile, one shell version.
- Rewriting the Linux config. The port adapts; it does not drive changes upstream.
- `docs`/PDF generation, `atuin sync`, laptop/server deploys — untouched open threads.

---

## 5. Portability audit — `dotfiles/shell_common` → PowerShell

`[REPO]` for what the current config does; `[INF]`/`[MEM]` for the PowerShell
behaviour, flagged per row. **Verify column = what Phase 0 must check on the machine.**

### 5.1 Structural constraints that shape everything below

1. **`Set-Alias` cannot carry arguments.** `alias ll='eza -lh --git'` has no alias
   form. Every flag-bearing alias becomes a function. `[MEM] high confidence`
2. **PowerShell ships its own aliases that collide.** `gc`=Get-Content,
   `gcm`=Get-Command, `gl`=Get-Location, `gp`=Get-ItemProperty, `h`=Get-History,
   `ls`=Get-ChildItem, `cat`=Get-Content, `rm`=Remove-Item, `cp`, `mv`, `ps`, `kill`.
   Four of the eleven git aliases collide with core cmdlet aliases. `[MEM] high`
3. **Overriding `ls` breaks the object pipeline.** `ls | Where-Object Length -gt 1MB`
   works today; an `eza` function returns strings and silently breaks it. This is the
   repo's own "core commands keep core behaviour" rule with sharper teeth on Windows.
4. **PSFzf, not fzf's own key bindings.** fzf has no `--powershell` init. Bindings come
   from the `PSFzf` module and are configured through `Set-PsFzfOption`, not
   `FZF_CTRL_T_COMMAND` / `FZF_ALT_C_COMMAND`. `[WEB]` confirms the three chords and
   that `Ctrl-R` is **not** bound unless explicitly requested via
   `-PSReadlineChordReverseHistory 'Ctrl+r'`. Which `FZF_*` env vars PSFzf honours is
   `[?]` — Phase 0 must test.
5. **No process substitution, `awk`, `sed`, `readlink`.** Every function in
   `shell_common` is a rewrite, not a copy.
6. **Symlinks need Developer Mode or admin.** Avoided entirely: `$PROFILE` becomes a
   one-line stub that dot-sources the repo file. The repo is on native `C:`, so the
   `/mnt/c` slowness argument that forced copies inside WSL does not apply here.
7. **`$PROFILE` moves if OneDrive backs up `Documents`.** Never hardcode the path;
   always resolve `$PROFILE`. `[MEM] high`

### 5.2 Verdict per block

| Block (`shell_common`) | Ports? | Plan |
|---|---|---|
| PATH / brew / cargo | ✅ trivial | Replaced by Scoop shims; `~/.cargo/bin` if rustup present |
| `fdfind`/`batcat` name fixes | 🟢 not needed | Scoop ships real `fd.exe` / `bat.exe`. Whole `FD_BIN`/`BAT_BIN` dance disappears — but the *lesson* stays: PSFzf commands run in a child process where functions do not exist, so use resolved `.exe` paths |
| `dircolors` / `lesspipe` | ⛔ N/A | Linux-only |
| eza block (`ls ll la lt ltt ltg lsize lnew`) | 🟡 renamed | All become functions. **`ls` stays Get-ChildItem** (§5.1.3). New name for the eza default listing — proposal: `e` |
| bat (`b`, `bp`) | ✅ | Functions. `MANPAGER` dropped — no `man` |
| grep→`ug`, `rgh`, `rgf` | 🟡 partial | `rgh`/`rgf` port as functions. **No `grep` alias**: PowerShell has no `grep`; `sls`(Select-String) is the native idiom. Aliasing `grep`→`ug` on Windows adds a name that no pasted script expects — recommend dropping, keeping plain `rg` |
| `ff`, `fdd`, `fda` | ✅ | Functions over `fd.exe` |
| duf / gdu / dust / `dus` | 🟡 | `duf`, `dust` exist on Windows `[?]` scoop availability. **`df` alias dropped** — no `df` on Windows to shadow |
| btop / procs (`top pg ptree pcpu pmem`) | 🟡 | `btop` is Linux-only; Windows analog is `btop4win` `[?]`. `procs` has Windows builds `[MEM]`. `top` alias dropped |
| git aliases (11) | 🔴 **conflict** | `gc` `gcm` `gl` `gp` collide with core cmdlet aliases. Three options in §7 Q1 — needs your call |
| `jqc` `jqr` `http`→`xh` | ✅ | Functions |
| apt aliases | 🔄 translated | → `scoopup` / `scoopin` / `scooprm` / `scoopsearch` |
| `rm -I` / `mv -i` / `cp -i` / `ln -i` | 🔴 **does not port** | `Remove-Item -Confirm` prompts per item — exactly the habituation trap [HANDOFF.md] rejected `-i` for. No `-I` analog. Proposal: leave `rm` alone, add a `tp` Recycle-Bin delete function (the `trash-put` analog, via `Microsoft.VisualBasic.FileIO`) so "changed my mind" is covered under its own name |
| `md` `h` `fm` `py` `path` `..` `...` | 🟡 mostly | `md` already a PS function (`mkdir`) — keep. `h` collides with Get-History → use `tldr` directly or pick another letter. `py` unnecessary (`py.exe` launcher exists). `path` → function splitting on `;`. `..`/`...` → functions, valid names |
| `FZF_*` exports | 🟡 rework | `FZF_DEFAULT_OPTS` + `FZF_DEFAULT_COMMAND` are read by `fzf.exe` itself and port directly. `FZF_CTRL_T_*` / `FZF_ALT_C_*` are fzf-shell-integration variables — PSFzf has its own mechanism. Preview panes configured through `Set-PsFzfOption`/`FZF_DEFAULT_OPTS` instead |
| `EDITOR` / `VISUAL` | ✅ | `$env:EDITOR = 'micro'` |
| `fe` | ✅ rewrite | ~6 lines |
| `fif` | ✅ rewrite, **easier** | PowerShell splits on `:` without ANSI hazard. Keep `--color=never` anyway — the reason is documented in [HANDOFF.md] trap #2 |
| `fkill` | ✅ rewrite | `Get-Process \| fzf \| Stop-Process`. Note: Windows PIDs, no signal argument — the `kill -9` parameter drops |
| `_cli_docs` | 🟡 rewrite | No `readlink`. Resolve from the profile's own location (`$PSCommandPath`) or `$env:CLI_DOCS` |
| `cs` | ✅ rewrite | `awk` section index → regex over `Get-Content`; `sed -n a,bp` → array slice |
| `fbr` | ✅ rewrite | Straightforward |

### 5.3 Parity additions with no Linux counterpart in this repo

| Linux piece | Windows equivalent |
|---|---|
| zsh-autosuggestions | `Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView` |
| zsh-syntax-highlighting | PSReadLine's built-in `-Colors` — no module needed |
| atuin | `[WEB]` atuin ≥ 18.11.0 ships PowerShell support (Windows + Linux). Optional, deferred — pulls in the unresolved `atuin sync` privacy question |
| `.zshrc.local` | `profile.local.ps1`, dot-sourced last, untracked |

---

## 6. Milestones

**M0 — git, before anything else.**
`git init` in the Windows repo, `.gitignore`, first commit of the current state, push
to GitHub. WSL copy re-established as a clone. Rewrite `README.md` (badges, layout,
quick install per-platform). Without this, everything below is unversioned.
*Verification:* `git status` clean in both copies; a change committed on Windows
appears in WSL after `git pull`.

**M1 — bootstrap for Windows.**
`bootstrap/install.ps1`: install Scoop if absent → add `main`/`extras` buckets →
install the tool list → link `$PROFILE` stub → report what was skipped. `-DryRun`
mandatory, mirroring `install.sh`. Version gates where a tool needs a minimum.
*Verification:* `-DryRun` output reviewed line by line before the first real run.

**M2 — the three core tools.**
`dotfiles/profile.ps1`: starship init pointing at the existing `starship.toml`,
zoxide init, PSFzf with the three chords + previews, PSReadLine parity options.
*Verification:* success criteria 1–4.

**M3 — ported alias/function layer.**
`dotfiles/functions.ps1` per §5.2, with the git-alias question resolved.
*Verification:* success criteria 5; every function invoked once against a real repo.

**M4 — docs.**
`bootstrap/INSTALL.md` gets a Windows section; `cheatsheet.md` gets a
"differs on PowerShell" column or block; `dotfiles/README.md` documents load order
for the third shell. `usecases.md` left alone unless a recipe is Linux-only.
*Verification:* adversarial-review subagent over the whole diff — this found a
critical bug last time and is cheap.

## 7. Open questions — blocking

**Q1. Git aliases `gc` / `gcm` / `gl` / `gp` collide with core PowerShell cmdlet
aliases (Get-Content, Get-Command, Get-Location, Get-ItemProperty).** Three options:

- **(a) Override with `-Force`** — muscle memory transfers from WSL unchanged, but it
  breaks the repo's own core-behaviour rule and will bite when pasting PowerShell
  snippets from the internet.
- **(b) Keep the non-colliding seven, rename the four** (e.g. `gco`-style: `gcmt`,
  `gcmm`, `glg`, `gpu`) — rule intact, two dialects to remember.
- **(c) One prefix for all git shortcuts on Windows** (`g` function with subcommands,
  or `posh-git`'s own set) — consistent, furthest from the WSL habit.

**Q2. `rm` safety.** Confirm: leave `rm`/`Remove-Item` untouched, add `tp` for
Recycle-Bin deletion? Or do you want the `-Confirm` behaviour despite the
habituation argument?

**Q3. Scope check on the drop list.** `grep`→`ug`, `df`→`duf`, `top`→`btop`, `py`,
`MANPAGER`, `h`→`tldr` are all proposed for removal on Windows for reasons in §5.2.
Objections?

## 8. Unverified, must be checked in Phase 0

- Scoop availability and current version of: `fzf`, `zoxide`, `starship`, `bat`, `fd`,
  `ripgrep`, `eza`, `jq`, `xh`, `lazygit`, `yazi`, `micro`, `procs`, `dust`, `duf`,
  `gdu`, `tldr`/`tealdeer`, `delta`. `[?]` — `scoop search` on the machine settles it
  faster than guessing from bucket manifests.
- Which `FZF_*` environment variables PSFzf actually honours. `[?]`
- Whether `pwsh` 7 is already installed, and whether Scoop or winget is already
  present. `[?]`
- `$PROFILE` resolved path — OneDrive redirection. `[?]`
- Windows Terminal font: the Pure prompt needs `❯` (U+276F). Cascadia Mono covers it;
  a Nerd Font is only needed if eza icons are wanted. `[MEM]`
