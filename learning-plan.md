---
tags: [cli, learning, plan]
---

# Learning Plan

Phases, not weeks. Move on when the exit criterion is met, not when time passes. If a phase feels like homework, you've hit one you don't need yet — skip it and come back when a real task demands it.

Commands live in [cheatsheet.md](cheatsheet.md); task-shaped recipes in [usecases.md](usecases.md).

**The only rule that matters:** a tool you have to remember to use is a tool you won't use. Each phase below is designed around replacing one existing reflex, not around learning features.

---

## Phase 0 — Verify the setup

Before learning anything, confirm it works. Ten minutes.

```bash
for t in eza bat fd rg fzf zoxide starship btop duf procs delta gdu \
         dust lazygit tldr micro yazi xh sd hyperfine trash-put atuin jless; do
  command -v $t >/dev/null && echo "ok   $t" || echo "MISS $t"
done
```

Then check each keybinding fires: `Ctrl-R`, `Ctrl-T`, `Alt-C`.

**Exit criterion:** no MISS lines, three keybindings respond.

---

## Phase 1 — History and navigation

The highest-leverage phase by a wide margin. These two replace hundreds of keystrokes a day and require no new vocabulary.

**Replace:** pressing `↑` repeatedly → `Ctrl-R`
**Replace:** typing full paths → `z`

### Do this

```bash
atuin import auto      # once: pull your existing history in
```

Then, for the next few days, force two habits:

1. Any command you've run before — find it with `Ctrl-R` instead of retyping or arrow-scrolling.
2. Any directory you've visited before — `z partial-name` instead of `cd full/path`.

zoxide is deliberately useless at first. Its database only fills as you navigate. Keep using `cd` for new places; it records those too.

### Drills

- `Ctrl-R`, type two letters from a command you ran yesterday. Find it.
- `z` into your three most-used directories without typing a full path.
- `atuin stats` — look at what you actually run. It's usually surprising.

**Exit criterion:** you reach for `Ctrl-R` before `↑` without deciding to.

---

## Phase 2 — Search

**Replace:** `grep -r` → `rg`
**Replace:** `find . -name` → `fd`

Two commands, three flags each, and the one trap that will otherwise waste an afternoon.

### Learn exactly this

```bash
rg pattern          rg -i pattern        rg -tpy pattern
fd name             fd -e md             fd -td name
```

### Then learn the trap

Both skip gitignored and hidden files. When a search comes back empty and you know the file exists:

```bash
rgh pattern         # rg -uuu
fda name            # fd -HI
```

Practise this deliberately: create a file, add it to `.gitignore`, search for it, watch it not appear, escalate. Doing it once on purpose beats discovering it under pressure.

### Drills

- Find every `TODO` in a project.
- Find all `.md` files modified today.
- Find a string inside a `.env` file (hidden — requires the escape hatch).

**Exit criterion:** you type `rg` reflexively, and empty results make you think "gitignore" rather than "not there".

---

## Phase 3 — Reading and listing

Low effort, immediate payoff. Mostly muscle memory for four aliases.

**Replace:** `ls -la` → `ll` / `la`
**Add:** `b` for reading files with highlighting

```bash
ll        la        lt        lnew        lsize
b file    bp file
```

Note the git status column in `ll`. It tells you what's modified without running `git status`.

### Drills

- Use `lt` instead of `ls -R` once.
- Use `lsize` to find the biggest file in a directory.
- Read a JSON or Python file with `b` and notice the line numbers and highlighting.

**Exit criterion:** `ll` is automatic. That's the whole phase.

---

## Phase 4 — fzf

The compounding one. Everything after this gets easier because fzf composes with all of it.

**Add:** `Ctrl-T`, `Alt-C`, `**<Tab>`

### Learn the three entry points

```bash
micro <Ctrl-T>      # insert a file path into the command you're typing
<Alt-C>             # cd into a fuzzy-picked directory
cd **<Tab>          # fuzzy-complete any path argument
```

Then the wrappers already in your config:

```bash
fe                  # pick a file, open it
fif pattern         # search contents, jump to the matching line
fkill               # pick processes, kill them
fbr                 # pick a git branch, switch
```

### How fzf matching works

Type letters in order, gaps allowed. `shcom` matches `shell_common`. `sc` matches it too, but so does everything else — add letters until the list is short.

### Drills

- Open three files in a row using only `Ctrl-T`.
- Use `Alt-C` to reach a directory four levels deep.
- Run `fif` on a word you know appears in several files.

**Exit criterion:** you use `Ctrl-T` mid-command without pausing to remember it.

---

## Phase 5 — Git

**Replace:** `git status`/`diff`/`log` → `gs` / `gd` / `gl`
**Replace:** everything complicated → `lg`

The alias set is small on purpose. Anything beyond stage-commit-push is better done in lazygit than remembered as flags.

### Sequence

1. Use `gs`, `gd`, `gl` for a few days. Notice delta's side-by-side diffs.
2. Open `lg`. Press `?`. Read the help screen once.
3. Do one interactive stage in lazygit — `Space` on individual hunks.
4. Do one interactive rebase in lazygit, on a branch you don't care about.

⚠️ `gl` is **log** here, not `git pull`. If you have oh-my-zsh reflexes, this will bite once.

### Drills

- Stage half the changes in a file using lazygit hunks.
- Find which commit introduced a string: `git log -S 'string'`.
- Switch branches with `fbr`.

**Exit criterion:** you open `lg` instead of searching for the right git flag.

---

## Phase 6 — Disk and processes

Situational. Learn when you first need it, not before — but know these exist so you know what to reach for.

| Question | Tool |
|---|---|
| What's eating my disk | `gdu ~` |
| How full are my disks | `df` (duf) |
| Quick size answer, no TUI | `dsz` |
| What's running | `top` (btop) |
| Find one process | `pg name` |
| Kill something | `fkill` |

### Drills

- Run `gdu ~` once and navigate three levels. Don't delete anything yet.
- Run `pg` on a process you know is running.
- Open `btop`, press `t` for tree view, `f` to filter.

**Exit criterion:** you know which of `duf` / `dust` / `gdu` answers which question. That distinction is the actual content of this phase.

---

## Phase 7 — Text and data manipulation

Only if your work involves it. Skip freely.

```bash
jq -r '.items[].name' f.json      # extract
jless data.json                   # explore first, then jq
xh POST url key=value             # API calls
sd 'old' 'new' file               # substitution
```

### Sequence

1. `jless` on a large unfamiliar JSON. Navigate, find the path you want.
2. Write the `jq` expression for that path.
3. Replace one `curl` call with `xh`.
4. Replace one `sed s///` with `sd`.

### Drills

- Extract one field from an API response: `xh -b GET url | jq -r '.field'`.
- Preview a mass substitution with `sd -p` before running it.

**Exit criterion:** you reach for `jless` when handed unfamiliar JSON.

---

## Phase 8 — zsh itself

The part most people skip, and the part with the longest tail of payoff. Nothing here is a new tool — it's the shell you already run.

### Globbing

```bash
ls **/*.md              # recursive
ls *(.)                 # files only
ls *(/)                 # dirs only
ls *(.om[1,5])          # 5 most recently modified
ls *(Lm+10)             # larger than 10 MB
```

This replaces a large share of `find` invocations, and it's faster to type.

### History expansion

```bash
!!        sudo !!        !$        !rg        ^old^new
```

### Options already enabled for you

`AUTO_CD` · `AUTO_PUSHD` · `SHARE_HISTORY` · `HIST_VERIFY` · `INTERACTIVE_COMMENTS`

Read what each does in [cheatsheet.md](cheatsheet.md#options-active-in-this-config) — you're already using them without knowing.

### Drills

- List the 5 newest files in a directory using a glob qualifier, not `ls -t | head`.
- Use `!$` three times in a session.
- Use `sudo !!` after a permission error.

**Exit criterion:** you've used a glob qualifier by choice at least once.

---

## Phase 9 — Optional extras

Learn only when a specific need appears.

| Tool | When |
|---|---|
| `yazi` (`fm`) | you want to browse visually with previews |
| `hyperfine` | you're about to argue about performance |
| `dust` | you want disk sizes in a script |
| `micro` | you need a terminal editor with normal Ctrl-S/Ctrl-C |
| `delta` config | side-by-side diffs annoy you and you want to tune them |
| `atuin sync` | you want history shared across the laptop and the server |

---

## Keeping it

Three mechanisms, in order of how well they work:

1. **`cs <term>`** — search the cheatsheet from the shell. Fastest path from "what was that flag" back to work.
2. **`h <tool>`** — tldr. When you need the tool's own examples rather than your notes.
3. **`atuin stats`** — periodically look at what you actually run. If a phase-1 or phase-2 tool isn't showing up, that habit didn't take, and rereading the doc won't fix it. Pick one task and force it.

The failure mode isn't forgetting the commands. It's never breaking the old reflex. Everything above is structured around one substitution at a time for exactly that reason.
