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
- **oh-my-posh is redundant, not heavy** — and, it turns out, not installed. It is a prompt binary in the same category as starship, not a framework like oh-my-zsh, so the ~60-files-at-startup objection never applied to it; the objection that does apply is two prompt engines and two configs. Moot here: `oh-my-posh` is absent from this machine `[RUN]`, so its `init` line in the old profile would have errored on every shell start.
- **The old repo is a stale artefact, not a source of truth.** Three of its references point at software that is not installed: `nvim`, `oh-my-posh`, and hardcoded `tig`/`less` paths under `C:\Program Files\Git`. Nothing further should be inferred from it without checking the machine.
- **`$PROFILE` does not currently exist** on this machine — the dry run printed no backup line, which only happens when the existing profile is absent or empty. So the old profile is not installed here at all, and `install.ps1` will create rather than replace. `[RUN]`

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
- **`Set-Item -Path 'Function:..'`.** Chosen over `function ..` precisely because the
  latter's parsing is not worth betting a profile load on. `[INF]`
- **`Add-Type -AssemblyName Microsoft.VisualBasic` under PowerShell 7.** Used by `tp`.
  `[MEM]` If it is unavailable, `tp` reports and deletes nothing.
- **`tl`'s `GetDetailsOf` column indices** (1 = original path, 2 = date deleted).
  `[MEM]` Cosmetic if wrong.
- **Scoop availability of the non-core tools**: `bat`, `fd`, `ripgrep`, `eza`, `jq`,
  `delta`, `dust`, `duf`, `procs`, `bottom`, `xh`, `lazygit`, `yazi`, `micro`,
  `tealdeer`. `[?]` `install.ps1` attempts each and reports failures rather than
  pre-checking, so a missing manifest is visible but not fatal.
- ~~Scoop's `bucket list` / `list` output shape.~~ **Resolved by the dry run, which
  found the defect.** `scoop list` prints its `Installed apps:` header on the host
  stream and the table on the output stream, so the text match found nothing and every
  tool was reported as "would install" — a check that fails by silently answering
  "no". Replaced with `Test-Path $SCOOP\apps\<name>` and `$SCOOP\buckets\<name>`: the
  directories Scoop actually keys on, and `Test-Path` cannot half-succeed. `[RUN]`
- **Startup time under 400 ms** with starship + zoxide + PSFzf + PSReadLine
  prediction. `[?]` Success criterion 1, unmeasured.
- **Windows Terminal font.** The Pure prompt needs `❯` (U+276F), which Cascadia Mono
  covers. The old profile's oh-my-posh takuya theme implies a Nerd Font is already
  configured, so `eza --icons` should work too. `[INF]`

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
| 🔴 | `bootstrap/INSTALL.md` has no Windows section yet; `cheatsheet.md` has no PowerShell column (M4 partially done) |
