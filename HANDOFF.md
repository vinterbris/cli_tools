---
tags: [handoff, state]
---

# Handoff

Snapshot of project state as of 2026-07-30. Point-in-time document — delete or rewrite when it stops matching reality. Everything durable lives in the other files; this one exists so the next session does not re-derive decisions or re-litigate settled trade-offs.

---

## What this project is

A modern CLI environment for Sergey: tool selection, runnable shell config, and learning material. Started as a research document (`modern-cli-tools.md`), then absorbed his old dotfiles and turned into a deployable setup.

⚠️ **Correction, 2026-07-30.** An earlier version of this section said the absorbed dotfiles were "Ubuntu" dotfiles. They were not. His only tracked dotfiles repo, [vinterbris/dotfiles](https://github.com/vinterbris/dotfiles), is **Windows-only** — a PowerShell profile plus four starship TOMLs, one of which (`starship_pure.toml`) is the stock Pure preset. He had no Linux dotfiles. This matters because the decision "starship, not Pure — his old config ran *stock* Pure with zero customisation" was reasoning about that Windows file, not a zsh setup. The conclusion still holds; the provenance was mislabelled.

**Target machines:** Ubuntu 24.04 under WSL2 (primary, already deployed), Windows 11 with PowerShell 7 (config written 2026-07-30, not yet run), Pop!\_OS 22.04 (laptop, planned), Debian 12 (home server, planned).

## Current state

**Deployed and working on WSL.** zsh + starship (Pure preset) + zsh-autosuggestions + zsh-syntax-highlighting + atuin + fzf + zoxide. Config symlinked from `~/cli_tools/dotfiles` into `$HOME`. `Ctrl-R` / `Ctrl-T` / `Alt-C` confirmed working by the user.

**Deployed and working on Windows 11 / PowerShell 7.6.4** as of 2026-07-30. starship (same `starship.toml` as WSL) + zoxide + carapace + atuin + PSFzf + PSReadLine prediction, 23 tools from Scoop. `$PROFILE` is a one-line stub dot-sourcing `dotfiles/profile.ps1` from `C:\Users\Vinterbris\cli_tools`. Profile load ~380 ms, down from 847 ms at first working build. `Test-CliToolsSetup` reports OK.

Two Windows chords are **deliberately unbound**: `Ctrl+T` and `Alt+C` corrupted the terminal display. Use `fe` and `zi` instead. Diagnosis in `prd-powershell.md`.

**Not yet deployed:** laptop, server. `bootstrap/install.sh` is written and dry-run-tested but has never executed a real `sudo apt-get install` — only `--dry-run` and the dotfiles half.

**Repo layout** is described in [README.md](README.md). Do not add files without checking the one-file-one-purpose split there.

## The working copies

Three copies, and as of 2026-07-30 two of them are git clones of
`https://github.com/vinterbris/cli_tools.git`.

| Copy | Role | Synced by |
|---|---|---|
| `C:\Users\Vinterbris\cli_tools` | what PowerShell loads; `$PROFILE` points here | git |
| `C:\Users\Vinterbris\_CLAUDE_DESKTOP_PROJECTS\cli_tools` | the agent's working copy | git |
| `~/cli_tools` inside WSL | the live copy, symlinked into `$HOME` | ⚠️ still a manual `cp -r` |

The agent's copy is registered as a local remote in the Windows clone, so changes travel
without a GitHub round-trip:

```powershell
cd $HOME\cli_tools
git pull agent main      # remote 'agent' → the _CLAUDE_DESKTOP_PROJECTS path
```

🔴 **The WSL copy is the last remaining drift.** Replacing it with a clone is now trivial
and is the highest-value cleanup left:

```bash
# destructive — back up ~/cli_tools first if anything local lives there
git clone https://github.com/vinterbris/cli_tools.git ~/cli_tools
```

A separate Linux copy is deliberate: `/mnt/c` is slow enough to lag every shell start, so
symlinking rc files across the boundary was rejected.

---

## Decisions already made — do not reopen without new information

| Decision | Reason |
|---|---|
| **No oh-my-zsh** | ~60 files at startup, plugin layer hides what is sourced. Two `source` lines replace it |
| **starship, not Pure** | Cross-shell, one TOML. His old config ran *stock* Pure with zero customisation — nothing was lost. Official `pure-preset` reproduces the look |
| **Core commands keep core behaviour** | Never alias a core command to something with different flags. Three sanctioned exceptions only: `rm -I` (same binary), `df`→`duf` (read-only), `grep`→`ug` (flag-compatible) |
| **`rm -I`, not `rm -i`** | `-i` prompts on every deletion and trains reflex-`y`, which then fires on the prompt that mattered. `-I` prompts once for >3 files or `-r`. `trash-cli` covers "changed my mind" under its own names (`tp`/`tl`/`tre`/`tempty`) |
| **`gl` = log, not `git pull`** | Deliberate break from oh-my-zsh. `git pull` has no alias — he should see what it does |
| **Dotless filenames in `dotfiles/`** | He browses this folder in Explorer; dot-prefixed files are hidden there. The dot is added at install |
| **Symlinks, not copies** | Edit in repo, effect is immediate. Exception: copy if the repo lives on `/mnt/c` |
| **Version gate, not "apt first"** | Pop!\_OS 22.04 ships fzf 0.29; the config wants ≥ 0.48. The script asks `apt-cache policy` and compares with `dpkg --compare-versions` rather than hardcoding per-release rules |
| **Install priority apt > cargo > brew** | His call. cargo above brew |
| **`edir` dropped entirely** | He decided against it |
| **Phases, not weeks, in the learning plan** | His call — the pace is variable |
| **English for all documents** | His call, despite conversing in Russian |

### Rejected, with reasons

- **`alias rm=trash-put`** — breaks the design rule; `rm` would stop meaning "gone" and disk would never free
- **`navi`** for cheatsheet search — its own `.cheat` format duplicates `cheatsheet.md`. Replaced by the `cs` function, ~30 lines, single source of truth
- **GNU stow / chezmoi** — machinery exceeds the problem at four files. Noted in `dotfiles/README.md` as the escalation path
- **`alias cat=bat`** — core command. `b` / `bp` instead

---

## Traps discovered the hard way

Each of these cost real debugging time. They are the reason certain code looks the way it does.

1. **Aliases are invisible to anything that shells out.** fzf runs `FZF_DEFAULT_COMMAND` through `sh`, where `fd`→`fdfind` does not exist. Result: empty `Ctrl-T`, broken preview. Fixed by resolving real paths into `$FD_BIN` / `$BAT_BIN` *before* aliases are defined, using a `case /*` test that rejects alias definitions.

2. **`rg --color=always` puts ANSI escapes inside colon-delimited fields.** `awk -F:` then yields a filename full of escape bytes that no editor can open. `fif` was broken on every invocation until this was found by adversarial review. Fixed with `--color=never` plus shell parameter expansion instead of awk.

3. **`REPO=$PWD/dotfiles` executed from inside `dotfiles/`** produced four dangling symlinks (`dotfiles/dotfiles/...`), which made zsh run `zsh-newuser-install`. `ln -sf` creates dangling links silently. The install script now uses absolute paths and verifies the source exists first.

4. **fzf < 0.48 has no `--zsh`/`--bash`.** Ubuntu 24.04 ships 0.44. Both rc files fall back to sourcing `/usr/share/doc/fzf/examples/key-bindings.*`.

5. **Ubuntu's stock `.bashrc` contains things worth keeping** — `dircolors` (its `LS_COLORS` drives zsh completion colouring — without it a `zstyle list-colors` line is silently inert) and `lesspipe`. These were lost in the first replacement and restored after diffing against `/etc/skel/.bashrc`.

6. **`.zshrc.local` must be sourced BEFORE zsh-syntax-highlighting**, or anything defined there goes unhighlighted.

---

## Open threads

| Thread | Status |
|---|---|
| **Put the repo under git** | ✅ Done and pushed 2026-07-30 to `https://github.com/vinterbris/cli_tools.git`. Commit authorship uses the GitHub noreply address — GitHub rejects pushes that would publish a private email (`GH007`) |
| **Run the PowerShell config** | ✅ Deployed and working 2026-07-30. The agent cannot execute PowerShell, so every verification in this session was Sergey running a command and pasting output. Remaining unverified items: `prd-powershell.md` §8 |
| **Replace the WSL copy with a clone** | 🔴 Not done. The last remaining drift; see "The working copies" above. Requires deleting `~/cli_tools`, so it needs an explicit go-ahead |
| **`Ctrl+T` / `Alt+C` on Windows** | Worked around, not fixed. Both corrupt the terminal display; `fe` and `zi` replace them. Lead if anyone returns to it: `cs` invokes `fzf.exe` directly and works, so the fault is in PSFzf's PSReadLine handlers — look at `InvokePromptHack` |
| **Deploy to Pop!\_OS 22.04 laptop** | Untried. Expect more tools to fall through to cargo (slow, compiles from source). `--install-managers` required unless rustup is present |
| **Deploy to Debian 12 server** | Untried. Consider trimming `TOOLS` in `install.sh` — `yazi`, `micro`, `btop` are interactive and rarely wanted on an ssh-only box |
| **`atuin sync` across machines** | Not set up. Needs an account. Note the privacy implication: every command from the laptop lands in the server's history and back |
| **Print the cheatsheet** | Not done. `cheatsheet.md` is ~8 A4 pages; PDF generation was explicitly deferred to save tokens |
| **Obsidian** | He uses it. Files carry YAML frontmatter with `tags:` and use relative markdown links, which Obsidian resolves. No `[[wikilinks]]` — relative links also work on GitHub and in editors |
| **fzf upgrade** | Still 0.44 from apt on WSL. `brew install fzf` would give ≥ 0.6x and remove the fallback path. He was offered this and did not decide |

## Claims never verified

Carried over from the original research document. Nobody has run these against a real binary:

- `xh` syntax (`key=value`, `:=`, `==`, `Header:value`)
- `zoxide query -l`
- `dust -d`, `procs --sortd`
- `ugrep` / `ug` GNU-grep flag compatibility (the whole justification for the `grep`→`ug` exception)
- `sudo apt-get install` path in `install.sh` — only ever dry-run

Everything else in the docs was checked against `--help` output, upstream source, or official man pages during adversarial review. Findings that were wrong (`sd -s`, `procs --tcp`, `hyperfine` apt availability) have been corrected.

---

## Lessons from the PowerShell session — read before optimising anything

Five wrong conclusions were reached and retracted in one session, all the same shape:
**reading a mechanism from numbers instead of from the thing itself.** Each retraction is
recorded in `prd-powershell.md` rather than quietly edited away.

1. `nvim` assumed installed because an alias referenced it. An alias is evidence someone
   once intended to install something.
2. "The scoop text-parse check is broken" — inferred from all 18 tools reporting "would
   install", when in fact none were installed. Absence of a match is not a broken matcher.
3. "The init cache doesn't work" — inferred from two timing numbers. It worked;
   carapace's 960 ms was a cold first run.
4. "starship's cost is `New-Module`" — its init has a second `Invoke-Native` that was
   never looked for.
5. "`resolve binaries` is irreducible command-discovery warm-up" — held for three rounds;
   it was ~15 ms per probe.

What actually worked: **look at the artefact.** One glance at a 135-byte cache file
settled what two rounds of timing analysis got wrong.

Procedural lessons worth keeping:

- **Search first.** The literature was consulted only when Sergey asked whether it had
  been. It contained a decisive fact — Steve Lee's `Initialize-Profile` technique does not
  speed up *interactive* startup, because `prompt` runs before the first prompt is drawn.
  Without checking, the next step would have been a full profile restructure for zero gain.
- **Use `PSProfiler` / `Measure-Script`** for per-line attribution. Hand-rolled stage
  timings found the big wins but were too coarse to explain them.
- **Adversarial review by subagent earns its cost.** Two passes found two failures of the
  class "a check that reports success without checking" — both in code written *as* a
  check. Both passes also invented API surface that does not exist (`Set-PsFzfOption`
  parameters, twice), so verify what a reviewer asserts before building on it.

## How he works — worth knowing

- Wants a plan and sign-off before building. Interrogates vague proposals
- Wants pushback, not agreement. Flagging a contradiction is expected, not rude
- Wants provenance tags on claims: `[WEB]` `[REPO]` `[RUN]` `[INF]` `[MEM]` `[?]`
- Extremely concise output. Telegraph style in discussion; normal prose in files
- Converses in Russian when he asks for it; all written artifacts stay English
- Asked for adversarial review via subagent once and it found a critical bug — worth repeating for anything non-trivial

## Continuing

Linux / WSL:

```bash
cd ~/cli_tools
cs -l                      # confirm the cheatsheet search works
bootstrap/install.sh --dry-run
```

Windows:

```powershell
cd $HOME\cli_tools
Test-CliToolsSetup         # name collisions + missing tools
Test-CliToolsCache         # is the init cache being used
cs -List                   # cheatsheet sections
```

Read [README.md](README.md) for the file layout, [cheatsheet.md](../cheatsheet.md#powershell--start-here) for the PowerShell differences, then [learning-plan.md](learning-plan.md) Phase 0 for the verification block. The PowerShell port's full audit, measurements and retractions are in [prd-powershell.md](prd-powershell.md).
