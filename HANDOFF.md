---
tags: [handoff, state]
---

# Handoff

Snapshot of project state as of 2026-07-29. Point-in-time document — delete or rewrite when it stops matching reality. Everything durable lives in the other files; this one exists so the next session does not re-derive decisions or re-litigate settled trade-offs.

---

## What this project is

A modern CLI environment for Sergey: tool selection, runnable shell config, and learning material. Started as a research document (`modern-cli-tools.md`), then absorbed his old dotfiles and turned into a deployable setup.

⚠️ **Correction, 2026-07-30.** An earlier version of this section said the absorbed dotfiles were "Ubuntu" dotfiles. They were not. His only tracked dotfiles repo, [vinterbris/dotfiles](https://github.com/vinterbris/dotfiles), is **Windows-only** — a PowerShell profile plus four starship TOMLs, one of which (`starship_pure.toml`) is the stock Pure preset. He had no Linux dotfiles. This matters because the decision "starship, not Pure — his old config ran *stock* Pure with zero customisation" was reasoning about that Windows file, not a zsh setup. The conclusion still holds; the provenance was mislabelled.

**Target machines:** Ubuntu 24.04 under WSL2 (primary, already deployed), Windows 11 with PowerShell 7 (config written 2026-07-30, not yet run), Pop!\_OS 22.04 (laptop, planned), Debian 12 (home server, planned).

## Current state

**Deployed and working on WSL.** zsh + starship (Pure preset) + zsh-autosuggestions + zsh-syntax-highlighting + atuin + fzf + zoxide. Config symlinked from `~/cli_tools/dotfiles` into `$HOME`. `Ctrl-R` / `Ctrl-T` / `Alt-C` confirmed working by the user.

**Not yet deployed:** laptop, server. `bootstrap/install.sh` is written and dry-run-tested but has never executed a real `sudo apt-get install` — only `--dry-run` and the dotfiles half.

**Repo layout** is described in [README.md](README.md). Do not add files without checking the one-file-one-purpose split there.

## The working copy problem

⚠️ **Two copies exist and they drift.**

- `C:\Users\Vinterbris\_CLAUDE_DESKTOP_PROJECTS\cli_tools` — the repo, edited by Claude
- `~/cli_tools` inside WSL — the live copy, symlinked into `$HOME`

Sync is manual:

```bash
cp -r /mnt/c/Users/Vinterbris/_CLAUDE_DESKTOP_PROJECTS/cli_tools/. ~/cli_tools/
```

The Linux copy is deliberate — `/mnt/c` is slow enough to lag every shell start, so symlinking rc files across the boundary was rejected. Not under git yet; that is the obvious fix and would make the drift visible.

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
| **Put the repo under git** | ✅ Done 2026-07-30, local only. Remote is `https://github.com/vinterbris/cli_tools.git`; **push has not happened** — no credentials available to the agent. The WSL copy is still a `cp -r`, not yet re-established as a clone |
| **Run the PowerShell config** | Written 2026-07-30 (`dotfiles/profile.ps1`, `dotfiles/functions.ps1`, `bootstrap/install.ps1`), **never executed** — no PowerShell available in the agent's sandbox. Unverified items are listed in `prd-powershell.md` §8 |
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

## How he works — worth knowing

- Wants a plan and sign-off before building. Interrogates vague proposals
- Wants pushback, not agreement. Flagging a contradiction is expected, not rude
- Wants provenance tags on claims: `[WEB]` `[REPO]` `[RUN]` `[INF]` `[MEM]` `[?]`
- Extremely concise output. Telegraph style in discussion; normal prose in files
- Converses in Russian when he asks for it; all written artifacts stay English
- Asked for adversarial review via subagent once and it found a critical bug — worth repeating for anything non-trivial

## Continuing

```bash
cd ~/cli_tools
cs -l                      # confirm the cheatsheet search works
bootstrap/install.sh --dry-run
```

Read [README.md](README.md) for the file layout, then [learning-plan.md](learning-plan.md) Phase 0 for the verification block.
