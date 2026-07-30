---
tags: [prd, powershell, windows]
---

# PRD — PowerShell 7 port

Signed off 2026-07-30. Code written, **never executed** — see §8 and §9.
Delete or fold into [README.md](README.md) + [HANDOFF.md](HANDOFF.md) once it has
actually run on the machine.

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
| **Git aliases** | **None on Windows.** git is driven from WSL, where `shell_common` already has them. `g`→`git` passthrough only. Q1 below is therefore closed without renaming anything |
| **`rm`** | Untouched. Recoverable deletion is `tp` → Recycle Bin. Option (a) |
| **Drop list** | `grep`→`ug`, `df`→`duf`, `top`→`btop`, `py`, `MANPAGER`, `h`→`tldr` all dropped. `bottom` (`btm`) installed instead of btop |
| **Remote** | `https://github.com/vinterbris/cli_tools.git` — new repo. The old `vinterbris/dotfiles` is left as-is |

### Phase 0 results — measured on the machine, 2026-07-30 `[RUN]`

| Check | Result | Consequence |
|---|---|---|
| `$PSVersionTable.PSVersion` | **7.6.4** | PSReadLine ≥ 2.3, all prediction options available |
| `$PROFILE` | `C:\Users\Vinterbris\Documents\PowerShell\Microsoft.PowerShell_profile.ps1` | **Not** OneDrive-redirected. The `$PROFILE` trap did not fire |
| `Get-Alias gc,gcm,gl,gp,h,ls` | all six exist | Collision prediction confirmed exactly |
| `Get-Alias gs,gd,ga,gco,gcb,tp` | none exist | Those names are free |
| `scoop search` | fzf **0.74.1**, zoxide **0.10.0**, starship **1.26.0**, all in `main` | fzf ≫ 0.48 — the Pop!\_OS fallback path has no Windows counterpart to maintain |
| `winget` | absent | Scoop only. atuin would come from Scoop, not winget |

### Resolved from the PSFzf README `[WEB]`

- `Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'` — exact form. `Ctrl+R` is **not** taken by default.
- `Alt+C` **is** bound by default; there is no chord parameter for it, only `-AltCCommand` to change what it runs. An earlier guess at `-PSReadlineChordSetLocation` was wrong.
- PSFzf **does** honour `FZF_DEFAULT_COMMAND`, `FZF_CTRL_T_COMMAND`, `FZF_ALT_C_COMMAND` — closes the `[?]` in §5.2. It does **not** honour `FZF_CTRL_T_OPTS`/`FZF_ALT_C_OPTS`; `_PSFZF_FZF_DEFAULT_OPTS` is the replacement mechanism.
- PSFzf already ships `Invoke-FuzzyEdit`, `Invoke-FuzzyKillProcess` and `Invoke-PsFzfRipgrep`, so `fe`, `fkill` and `fif` are aliases rather than rewrites. Three of the five Linux functions did not need porting at all.
- Its optional aliases include `fd` (→`Invoke-FuzzySetLocation`), which would shadow the `fd` binary. `-EnableAlias*` must stay off.

### From the old `vinterbris/dotfiles` profile `[REPO]`

- Active prompt was **oh-my-posh** (`takuya` theme); the starship lines were commented out. starship replaces it; `install.ps1` backs up the old profile and warns. oh-my-posh stays installed, just uninitialised.
- A takuya-theme prompt implies a Nerd Font is already configured in Windows Terminal — so `eza --icons` should render.
- `starship_pure.toml` in that repo is the stock Pure preset but uses the **deprecated** `vicmd_symbol` key; `dotfiles/starship.toml` has the current `vimcmd_symbol`. Nothing to salvage.
- Worth keeping from it: `g`→`git`. Dropped: `Set-Alias grep findstr` (superseded by `rg`), `ll`→`ls` (superseded by eza), hardcoded `tig`/`less` paths from Git for Windows (unguarded absolute paths), `vim`→`nvim`.
- ⚠️ **Corrected 2026-07-30.** An earlier revision of this section claimed "`nvim` is present, so `$env:EDITOR` prefers it". That was inferred from the presence of the `vim`→`nvim` alias and is **wrong** — nvim is not installed and he does not use it. The alias was stale. `$env:EDITOR` is `micro`, then `notepad`. Recorded because the failure mode is worth remembering: an alias in a config file is evidence that someone once intended to install something, not that they did.
- **oh-my-posh is redundant, not heavy** — and not installed here. It is a prompt binary in the same category as starship, not a framework like oh-my-zsh, so the ~60-files-at-startup objection never applied to it; the objection that does apply is two prompt engines and two configs. Moot in practice.
- **The old repo describes a previous Windows installation that no longer exists.** This is a *different machine* — not a machine that drifted from the repo. `nvim`, `oh-my-posh` and the `C:\Program Files\Git\usr\bin` paths were all real there. So the repo is a historical record, not a stale config, and the correct way to use it is as a list of things he once chose, each to be re-decided against the current machine. Do not infer installed software from it; that mistake was already made once, with `nvim`.
- **`$PROFILE` does not exist** on this machine — the dry run printed no backup line, which only happens when the file is absent or empty. `install.ps1` will create rather than replace, so the replace-and-backup path stays untested. `[RUN]`
- **A Nerd Font is already installed**: `Maple-Mono-NF` `[RUN]`. Closes the font question — both `❯` and `eza --icons` will render, provided Windows Terminal is set to it.

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

## 7. Questions — all closed

**Q1. Git-alias collision — closed by removing the whole block.** git is used from
WSL, so Windows needs no git shortcuts at all. `g`→`git` is a plain passthrough and
`g` is free. None of the three rename schemes was needed, and the Linux config stays
untouched. This is the cheapest resolution available and it was his call, not a
compromise.

**Q2. `rm` — closed as option (a).** `rm`/`Remove-Item` untouched; `tp` deletes to
the Recycle Bin. Two more facts reinforce this: `Remove-Item` never uses the Recycle
Bin, and its only prompt is per-item `-Confirm`.

**Q3. Drop list — closed, no objections.** All six dropped. `bottom` (`btm`) goes in
as the cross-platform stand-in for `btop`.

## 8. Unverified — the code has never been executed

There is no PowerShell in the agent's sandbox (`pwsh` is not installed and the proxy
blocks the release download), so nothing below has been run even once. Everything
here is a review-level claim, not a tested one.

- **The whole of `profile.ps1`, `functions.ps1`, `install.ps1`.** `[INF]` Reviewed, not
  executed. Highest-risk items follow.
- **The dual-branch fzf preview.** `if exist "{}\" (eza …) else (bat …)` relies on fzf
  passing `--preview` to `cmd.exe` — which it does, unconditionally, ignoring `$SHELL`
  (junegunn/fzf#1018, #2638) `[WEB]` — and on the quoting surviving PowerShell →
  fzf → cmd. If the preview pane shows an error, the file-only fallback is in a
  comment beside it.
- ~~`Set-Item -Path 'Function:..'`~~ **— this was the bug, and it was caused by the
  defensive choice.** `Set-Item` resolves `Function:..` as a *relative path* inside the
  Function: drive and derives a null name: *"Cannot process argument because the value
  of argument name is null"*. Thrown on the first real shell start. `function ..`
  parses fine and is now used. `[RUN]`

  Worth keeping as a pattern: the reasoning was "a dot-only function name might not
  parse, so use the provider API instead". The speculative risk was imaginary and the
  mitigation was the actual defect. When a plain declaration is the idiom everyone
  uses, that is evidence; a hypothesis about the parser is not.
- **`Add-Type -AssemblyName Microsoft.VisualBasic` under PowerShell 7.** Used by `tp`.
  `[MEM]` If it is unavailable, `tp` reports and deletes nothing.
- **`tl`'s `GetDetailsOf` column indices** (1 = original path, 2 = date deleted).
  `[MEM]` Cosmetic if wrong.
- **Scoop availability of the non-core tools**: `bat`, `fd`, `ripgrep`, `eza`, `jq`,
  `delta`, `dust`, `duf`, `procs`, `bottom`, `xh`, `lazygit`, `yazi`, `micro`,
  `tealdeer`. `[?]` `install.ps1` attempts each and reports failures rather than
  pre-checking, so a missing manifest is visible but not fatal.
- **Scoop state is read from the directory layout**, `Test-Path $SCOOP\apps\<name>` and
  `$SCOOP\buckets\<name>`, rather than by parsing `scoop list`.

  ⚠️ **Retraction.** An earlier revision of this entry, and the commit message that
  introduced the change, claimed the text-parsing version was *proven broken* by the
  dry run because it reported all 18 tools as "would install". That inference was
  wrong. `Get-ChildItem $HOME\scoop\apps` afterwards showed the machine has only
  `Maple-Mono`, `Maple-Mono-NF`, `pipx` and `scoop` installed `[RUN]` — so "would
  install" was the correct answer for all 18 and the old check was never observed to
  fail. Absence of a match is not evidence of a broken matcher.

  The directory test is still the better mechanism, on grounds that do not depend on
  that false claim: it has no dependency on an output format that upstream is free to
  change, and it cannot throw under `Set-StrictMode`. It is kept for those reasons
  alone. `[INF]`

  Confirmed by the run: `$env:SCOOP` is **unset** on this machine, so the
  `$HOME\scoop` fallback is the path that actually gets used — worth knowing before
  anyone "simplifies" it away. `[RUN]`
- 🟡 **Startup: 460 ms inside the profile, warm** `[RUN]`. First cold load was 1759 ms;
  most of that was JIT and cold Scoop shims, not the config. Attributed, not guessed:

  | Stage | Cumulative | Own cost |
  |---|---|---|
  | resolve binaries | 66 ms | 66 — six `Get-Command -CommandType Application` PATH scans |
  | fzf env | 72 ms | 6 |
  | `functions.ps1` | 102 ms | 30 |
  | PSReadLine | 183 ms | 81 — the module load itself, which pwsh would do anyway |
  | starship init | 285 ms | 102 — spawns `starship.exe`, then `Invoke-Expression` |
  | zoxide init | 329 ms | 44 — spawns `zoxide.exe` |
  | PSFzf | 458 ms | 129 — `Import-Module PSFzf` |
  | total | 460 ms | |

  Measured against a bare shell, averaged over 5 runs each `[RUN]`:

  | | ms |
  |---|---|
  | `pwsh -NoProfile` | 181 |
  | `pwsh` with the config | 847 |
  | **cost of the config** | **666** |

  That settles the earlier "is 460 ms a problem" question with data instead of a
  guessed target: 666 ms on every new tab, and tier S+A was about to add four more
  `init` process spawns plus two module imports on top. So the cache layer stopped
  being optional and was built:

  - `Use-CachedInit` writes each tool's generated init script to
    `%LOCALAPPDATA%\cli_tools\cache` and dot-sources it. Staleness is decided by
    comparing timestamps against the binary, so `scoop update` invalidates it
    automatically. `CLI_TOOLS_NO_CACHE=1` bypasses; `Clear-CliToolsCache` wipes it.
  - `Get-CliBin` now checks `<scoop>\shims\<name>.exe` before falling back to
    `Get-Command`. All these tools come from Scoop and every shim is in one folder, so
    this replaces a PATH walk with a `Test-Path` — **and needs no cache and no
    invalidation**, which is why it is preferred over caching resolved paths.

  **Measured again after the additions, and it got worse: 1324 ms total, 865 ms inside
  the profile** `[RUN]`. Per stage, own cost:

  | Stage | Own cost | Note |
  |---|---|---|
  | resolve binaries | 100 ms | up from 66. A *miss* falls through to a full PATH walk — `carapace` being absent is most of this |
  | functions.ps1 | 48 ms | |
  | PSReadLine | 79 ms | module load, unavoidable |
  | **Terminal-Icons** | **348 ms** | **largest single cost in the file** |
  | starship init | 85 ms | cached, yet barely cheaper than the 102 ms uncached — unexplained, needs a look |
  | zoxide init | 15 ms | was 44 — the cache works here |
  | carapace | 0 ms | not installed |
  | atuin | 43 ms | |
  | PSFzf | 139 ms | module load |

  **Terminal-Icons removed.** 348 ms bought icons in native `ls` output, and eza
  already provides icons under `e`/`ll`/`la` — so it was decoration on the one listing
  command deliberately kept native for pipeline reasons. Recommending it was a bad
  call; the cost was not checked before recommending. Now behind `CLI_TOOLS_ICONS=1`.

  **Third measurement, after installing carapace and dropping Terminal-Icons: 1487 ms
  inside the profile** `[RUN]` — worse again, and the reason is one line:

  | Stage | Own cost |
  |---|---|
  | resolve binaries | 65 ms (down from 100 — the carapace miss is gone, as predicted) |
  | starship init | 110 ms |
  | zoxide init | 15 ms |
  | **carapace** | **960 ms** |
  | atuin | 60 ms |
  | PSFzf | 143 ms |

  **Fourth measurement, and the previous conclusion was wrong: 550 ms** `[RUN]`.
  carapace 38 ms, zoxide 14 ms, atuin 45 ms, no `(regenerated cache: …)` lines. The
  cache works. carapace's 960 ms was its **first, cold** run — building its own
  internal state — not a per-start cost.

  Net: 550 ms now with four more tools than the 847 ms baseline. Remaining costs are
  PSFzf 147 ms and starship 100 ms.

  **starship's 100 ms explained, from `Test-CliToolsCache` output rather than by
  guessing.** Its cache file was **135 bytes**; zoxide's was 4446 `[RUN]`. 135 bytes
  cannot cost 105 ms to dot-source — and `starship init powershell` does not emit the
  init, it emits a small stub that re-invokes
  `starship init powershell --print-full-init` at load time. The cache was caching the
  stub, so the process spawned anyway, which is precisely why starship's cost looked
  identical cached and uncached.

  Fixed by caching `--print-full-init`. That also exposed a flaw in the cache itself: it
  was keyed on `$Name` alone, so a change to `$InitArgs` would not have invalidated it.
  The invocation is now written as the cache file's first line and compared.

  Worth noting as the argument for `Test-CliToolsCache` existing: two rounds of
  reasoning from timing numbers alone got this wrong, and one glance at a file size
  settled it.

  ⚠️ **Retraction of the paragraph below.** It was written from two timing numbers and
  asserted a broken cache. Wrong, and the fourth over-inference of this kind in this
  project — the pattern is reading a mechanism failure into data that only showed a
  cost. The diagnostics added in response are worth keeping regardless; the diagnosis
  was not.

  ~~🔴 **The init cache appears not to work at all.**~~ `starship` costs 110 ms cached
  against 102 ms uncached, and `carapace` costs 960 ms — both consistent with the
  binary being run on every start. And it would have failed *silently*: if
  `New-Item`/`Set-Content` threw, the old code left `$fresh` false forever and simply
  paid full price every time, saying nothing. That is the third time in this project a
  check has failed by quietly doing nothing.

  Now: regeneration is announced under `CLI_TOOLS_TIMING`, a write failure produces a
  warning and an explicit fallback, and `Test-CliToolsCache` reports the cache
  directory, file sizes and per-tool freshness. Diagnosis before more optimisation.

  If carapace turns out to cost ~1 s even when genuinely cached, it does not survive
  the trade — Tab completion for 1000+ commands is not worth a second per shell.

  `carapace` is `carapace-bin` in the **extras** bucket, not `carapace` in `main` — the
  installed app directory is `carapace-bin`, the shim is `carapace.exe`. `[WEB]`
- ~~Windows Terminal font.~~ Resolved: `Maple-Mono-NF` is installed. `[RUN]` Only thing
  left is that Windows Terminal is actually configured to use it.

## 7a. Config-file locations — the policy

**Decision: the repo is the single source of truth, and tools are pointed at it with
environment variables.** Nothing is copied into a tool's conventional location.
Currently that means `$STARSHIP_CONFIG`; the same shape applies to `$BAT_CONFIG_PATH`
and friends as configs appear.

Rejected alternative: `install.ps1` distributing files into each tool's native
directory. It would make a config findable when a tool is launched from outside pwsh
(Explorer, another shell), but it reintroduces a sync step — the exact drift this
project keeps paying for elsewhere. With one config file the trade is not close.
Revisit at three or four.

**Why there is no copy or symlink at all on Windows:** `$PROFILE` is a one-line stub
that dot-sources `<repo>\dotfiles\profile.ps1`. zsh insists on `~/.zshrc` at a fixed
path, so Linux needs a link; PowerShell lets the stub point anywhere. The WSL copy
exists for a different reason — `/mnt/c` is slow and rc files are read on every shell
start.

**Two working copies on Windows, by design.**

- `C:\Users\Vinterbris\cli_tools` — the clone the shell loads. `$PROFILE` points here.
- `C:\Users\Vinterbris\_CLAUDE_DESKTOP_PROJECTS\cli_tools` — the agent's working copy.

The original plan was to move the repo out of the agent's folder and delete it, because
`$PROFILE` holds an absolute path and a folder belonging to another tool is a poor place
for a permanent config. Sergey kept both instead: the agent needs its copy to work in,
and a second clone costs nothing. `$PROFILE` points at `~\cli_tools`, so nothing depends
on the agent's path.

Changes travel by git, not by copying. To avoid a GitHub round-trip, the agent's copy is
usable as a local remote:

```powershell
cd $HOME\cli_tools
git remote add agent 'C:\Users\Vinterbris\_CLAUDE_DESKTOP_PROJECTS\cli_tools'
git pull agent main
```

After any move of either copy, re-run `install.ps1 -SkipTools` to rewrite the stub.

| Thing | Location | Status |
|---|---|---|
| `$PROFILE` | `Documents\PowerShell\Microsoft.PowerShell_profile.ps1` | ✅ `[RUN]` one-line stub |
| our config | `<repo>\dotfiles\profile.ps1` + `functions.ps1` | ✅ loaded directly, no copy |
| starship | `<repo>\dotfiles\starship.toml` via `$STARSHIP_CONFIG` | ✅ points at the repo |
| PS modules | `Documents\PowerShell\Modules` | ✅ `[RUN]` |
| Scoop | `~\scoop`; `$env:SCOOP` unset | ✅ `[RUN]` |
| init cache | `%LOCALAPPDATA%\cli_tools\cache` | ✅ generated, disposable |
| zoxide data | `%LOCALAPPDATA%\zoxide` | `[WEB]` scoop manifest |
| bat | `%APPDATA%\bat\config`, `$BAT_CONFIG_PATH` overrides | `[MEM]` |
| PSReadLine history | `%APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\` | `[MEM]` |
| micro, yazi, procs, tealdeer | not checked | `[?]` |

## 7b. Tools added after the first working build

Startup measurement forced the order here: the config already cost 666 ms, so adding
four more `init` process spawns without caching would have pushed a new tab past a
second.

| Tool | Fills what gap |
|---|---|
| **carapace** | Argument completion for 1000+ commands. Before it, Tab did nothing useful for `rg`, `fd`, `scoop`, `fzf`. Requires `MenuComplete` on Tab — not a preference, the default `Complete` renders raw ANSI escapes `[WEB]` |
| **gsudo** | Elevation in the same console. Aliased to `sudo`, a name PowerShell leaves free |
| **Terminal-Icons** | Icons in `Get-ChildItem`. The counterpart of not aliasing `ls`: native `ls` keeps returning objects so pipelines work, and this makes it readable |
| **atuin** | Shell history, local-only until `atuin login`. **Takes `Ctrl+R`**, mirroring the Linux load-order rule, so PSFzf is told not to claim it |
| **hyperfine** | Benchmarking. Directly relevant to the startup question |
| **ouch** | One command for any archive. A real Windows gap — there is no unified `tar`/`unzip` |
| **glow** | Markdown in the terminal. This repo is nine `.md` files |
| **Everything** | Already installed. Its CLI, `es.exe`, is a separate voidtools download and is not on Scoop, so `esf`/`esr` stay guarded no-ops until it is on PATH |

Context worth keeping in view: Microsoft announced native Rust coreutils for Windows at
Build 2026 — `ls`, `cat`, `grep`, `find`, `xargs` on uutils `[WEB]`. Some of this layer
becomes built-in over time, which is an argument against collecting exotica.

## 8a. Adversarial review, 2026-07-30

Run as a separate reviewing agent over the three `.ps1` files, with the fixed items
listed as out of scope so it could not spend effort on them. Nine findings, eight
accepted.

| Severity | Finding | Resolution |
|---|---|---|
| HIGH | `try/catch` around `& scoop install` cannot reliably catch a failure — a native command sets `$LASTEXITCODE` rather than throwing, and `scoop` may resolve to a `.ps1` shim where even that is unreliable. The whole failure report was potentially decorative | **Fixed.** Success is now judged by post-condition: `Test-Path $SCOOP\apps\<name>` after the attempt. The directory exists or it does not; no error-reporting convention to trust |
| MED-HIGH | `tp` on a typo'd path did nothing and said nothing — `Resolve-Path -ErrorAction SilentlyContinue` yields zero iterations | **Fixed.** Warns per unresolved path. Worst possible failure mode for a delete command |
| MEDIUM | `tp a.txt b.txt` failed: a `[string[]]` parameter has one positional slot | **Fixed** with `ValueFromRemainingArguments`. Space-separated arguments are the expected form for an `rm` stand-in |
| MEDIUM | `Test-CliToolsSetup` never checked `g`, `lg`, `http`, `fm`, `tempty`, `fe`, `fkill`, `fif`. The alias-target whitelist that was supposed to cover them was **dead code**, so those eight names had zero collision protection while the check still printed OK | **Fixed.** Aliases are now a name→expected-target table, checked for pointing at the right thing, rather than whitelisted out of the test |
| MEDIUM | `git` was in the missing-tools list, but its absence on Windows is intentional — so the green OK line was unreachable on a correct setup, training you to ignore the output | **Fixed.** `git` and `delta` removed from the check, with the reason in a comment |
| LOW | `_PSFZF_FZF_DEFAULT_OPTS` embedded a copy of `FZF_DEFAULT_OPTS` at load time, so a `profile.local.ps1` override of the latter silently never reached PSFzf | **Fixed.** Only the preview command is built early; the variable is assigned last, after the local profile |
| LOW | `delta` was installed but referenced nowhere — it is a git pager configured through `.gitconfig`, and git runs from WSL | **Fixed.** Dropped from the Windows tool list, with the reason recorded |
| COSMETIC | `tl` resolved `NameSpace(0xA)` three times | **Fixed.** Resolved once |
| LOW | `$env:EDITOR` is a bare name rather than the resolved path, inconsistent with the rest of the file | **Rejected, with reason.** EDITOR is consumed by programs that pass it to a POSIX-ish shell — git's editor invocation being the obvious one — where a Windows path full of backslashes is mangled and a PATH-resolved bare name is not. The full-path rule exists for strings that reach `cmd.exe`; this one does not. Comment added so it is not "fixed" later |

Checked and confirmed **not** bugs, recorded so they are not re-litigated: variable
visibility inside `cs` and `Mark` (both files dot-source into the same scope, and
functions resolve free variables lexically); `$ok` across `tp`'s `begin`/`process`;
`$Matches` staleness in the `cs` heading scan; and `$sections.Title` / `$heads.Count`
with exactly one heading (PowerShell 7 gives scalars synthetic `Count` and `[0]`).

The reviewer traced both preview strings character by character and found the quoting
correctly paired, while noting — correctly — that static analysis cannot settle fzf's
Windows-side re-quoting. That still needs a live `Ctrl+T`.

## 8b. Second adversarial review, 2026-07-30 — publication readiness

Brief was "judge this as a PowerShell-literate stranger landing on a public repo".
Eight findings, all accepted.

| Severity | Finding | Resolution |
|---|---|---|
| HIGH | The `CLI_TOOLS_NO_CACHE` bypass had no empty-output guard, unlike the cached path — so in the one mode intended for troubleshooting, a broken tool would leave its integration silently absent | **Fixed.** Generation is one scriptblock used by both paths, and it throws on empty output |
| MEDIUM | `Get-CliBin` returned the Scoop shim even when a different binary of the same name came earlier on `PATH` — a function claiming to resolve a name while ignoring `PATH` order | **Fixed by removing the shim fast path entirely.** It was added for speed; comparing measurements, "resolve binaries" was 66 ms before it and 63–65 ms after, with two more probes. It bought ~20 ms and cost correctness. Now plain `Get-Command`. The 60 ms floor is command-discovery warm-up, not the probes |
| MEDIUM | `dus` swallowed access-denied per directory, producing totals that look complete and are not | **Fixed.** Unreadable items are counted and a warning states the totals are partial |
| MEDIUM | `functions.ps1` dot-sourced alone fails confusingly: the `$EzaBin` guards quietly evaluate false, then the first `Get-CliBin` throws and everything after it — `tp`, `cs`, the dot functions, the self-check — is never defined | **Fixed.** An explicit guard at the top throws a message naming the actual requirement |
| LOW-MED | `Mark` broke the file's own `Verb-Noun` convention and sat in the global session as a bare generic verb | **Fixed.** Renamed `Write-CliTiming`, and the comment now states plainly that dot-sourcing offers no private scope, rather than leaving it unaddressed |
| LOW | Dead ternary: `Get-CliBin $(if ($n -eq 'carapace') { 'carapace' } else { $n })` — both branches yield `$n`, a fossil of the `carapace-bin`/`carapace.exe` rename | **Fixed.** Plain `Get-CliBin $n` |
| LOW | The cache-write failure path discarded already-captured output and spawned the binary a second time, in the file whose premise is that spawns are expensive | **Fixed.** Reuses `$generated` |
| LOW | `Invoke-Expression` trips `PSAvoidUsingInvokeExpression` on sight | **Kept, now justified in place.** It is how these tools ship their init; the trust boundary is the local binary, not user input. Reduced to the two non-happy paths — the common path dot-sources the cache file |

**Comments cut**, on the reviewer's argument that narrating fixed bugs is noise in a
public repo rather than rationale: the `Set-Item 'Function:..'` post-mortem, the "an
earlier version omitted this table" paragraph, the "Reviewed and kept deliberately"
code-review artefact in the EDITOR block, and duplicated eza reasoning in the
Terminal-Icons note. History belongs in this document; the code keeps only what a
maintainer needs. Comment-to-code ratio is now ~0.74 in both files, which is still high
but every remaining comment states a constraint rather than a war story.

Verified as accurate by the reviewer, not merely asserted: `Invoke-PsFzfRipgrep` is
genuinely exported by PSFzf; junegunn/fzf#1018 does describe the cmd.exe preview
routing; and Scoop's `shim()` does `Copy-Item … -Force` on every shim creation, which
is what makes the timestamp-based cache invalidation work.

Also added: `[CmdletBinding()]` where missing, `[OutputType([string])]` on `Get-CliBin`,
and `SupportsShouldProcess` on `Clear-CliToolsCache` — it deletes a directory.

## 9. What has actually happened

| | |
|---|---|
| ✅ | Repo is a local git repository, working tree clean, `git fsck` clean |
| ✅ | All three `.ps1` files pass `[Parser]::ParseFile` — syntax valid, logic still untested `[RUN]` |
| ✅ | `install.ps1 -DryRun` executed twice on the machine. It found a real defect: see below |
| ✅ | Commit authorship rewritten to `21102027+vinterbris@users.noreply.github.com` — GitHub rejected the push with `GH007` rather than publish a private address. `refs/original/` holds the pre-rewrite refs |
| ✅ | `.gitattributes` forces LF — CRLF would break `install.sh` on a Linux clone |
| ✅ | `install.sh` marked executable in the index (the Windows mount reports no exec bit) |
| 🔴 | **Not pushed.** No credentials in the agent's sandbox. Remote must be added and pushed by hand |
| 🔴 | **WSL copy is still a `cp -r`**, not a clone. The drift problem is not yet solved, only made solvable |
| 🔴 | **No PowerShell code has been run** |
| ✅ | It loads and works. `Test-CliToolsSetup` reports `cli_tools: OK` — no shadowed names, all 17 tools resolvable. `z`, `ll`, `b`, `..` confirmed working by hand `[RUN]` |
| ✅ | `cheatsheet.md` now has a PowerShell block: what to press, every name that differs from Linux and why, a runnable example for each command he had not used, the diagnostic switches, and the escape hatches. Written with real invocations rather than an alias→command table, because the gap was "I don't know how to use these", not "I forgot the flag" |
| ✅ | `bootstrap/INSTALL.md` has a Windows section: fast path, prerequisites, what the installer does and why success is judged by post-condition, the no-symlink rationale, config policy, startup cost, a troubleshooting table built from the failures actually hit in this project, and rollback |
| ✅ | Repo cloned to `C:\Users\Vinterbris\cli_tools`; `$PROFILE` points there. The agent's copy stays where it is, and changes travel by git — see §7a |
| ✅ | **`Ctrl+T` freeze: diagnosed and fixed, hypothesis confirmed by measurement.** In `$HOME`, `fd -tf -HI --exclude .git` took **3305 ms**; with `-I` dropped and `AppData`/`node_modules` excluded, **235 ms** — 14× `[RUN]`. `Alt+C` was unaffected because it lists directories only, of which there are orders of magnitude fewer. The Linux config's `-HI` is fine on Linux and wrong in a Windows home directory, where `AppData` lives |
| 🔴 | The replace-and-backup path in `install.ps1` is still untested: `$PROFILE` did not exist, so it took the create branch |
