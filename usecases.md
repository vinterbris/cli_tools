---
tags: [cli, usecases, howto]
---

# Use Cases

Ordered by how often the task actually comes up. Each entry: what you want → what to type → what you get → what will bite you.

Flag reference is in [cheatsheet.md](cheatsheet.md). Tool selection rationale is in [modern-cli-tools.md](modern-cli-tools.md).

---

## 1. Find something

### Find text inside files

```bash
rg TODO                     # everywhere below cwd
rg -i todo                  # ignoring case
rg TODO src/                # scoped to a directory
rg -tpy TODO                # only Python files
rg -C3 TODO                 # with 3 lines of context around each hit
rg -l TODO                  # just the filenames
```

You get results grouped by file, with line numbers, coloured. `.gitignore` is respected and hidden files are skipped.

⚠️ **The single most common confusion.** `rg` "finding nothing" almost always means the file is gitignored or hidden — not absent. Escalate:

```bash
rgh TODO                    # rg -uuu : ignore nothing, include hidden and binary
```

Make that reflex now, it saves hours later.

### Find files by name

```bash
fd config                   # anything with "config" in the name
fd -e md                    # all markdown files
fd -e md -e txt             # several extensions
fd -td node_modules         # directories only
fd config ~/projects        # scoped
fd -d 2 config              # don't descend deeper than 2
fda secret                  # include hidden and gitignored
```

`fd` matches substrings by default — no `*` needed. Same gitignore trap as `rg`.

### Find a file when you only half-remember the name

```bash
fe                          # fuzzy picker with preview, opens in $EDITOR
```

Or `Ctrl-T` mid-command: type `micro `, press `Ctrl-T`, filter, `Enter`.

### Find text and jump straight to it

```bash
fif TODO                    # pick a match interactively, opens at that line
```

### Find a file you edited recently

```bash
lnew | head -20             # newest first in cwd
fd -t f --changed-within 1d # changed in the last day
```

---

## 2. Move around

### Jump to a directory you've been to before

```bash
z cli                       # best match for "cli"
z dot files                 # narrowed by two keywords
zi conf                     # interactive pick when ambiguous
z -                         # back to previous directory
```

zoxide learns from your `cd` history. It is useless on day one and excellent after two weeks — keep using `cd` normally and it fills up.

### Jump to a directory you haven't

```bash
Alt-C                       # fuzzy-pick a directory below cwd, cd there
cd ~/some/path              # still works, unchanged
foo                         # AUTO_CD: bare directory name == cd foo
```

### Move up

```bash
..    ...    ....           # 1, 2, 3 levels
cd -<Tab>                   # pick from the directory stack
```

### Re-run something from history

```bash
Ctrl-R                      # atuin: search everything you've ever run
!!                          # previous command
sudo !!                     # rerun previous with sudo
!$                          # last argument of previous command
```

`Alt-.` cycles through last arguments of earlier commands — faster than it sounds.

---

## 3. Look at things

### Read a file

```bash
b file.py                   # syntax highlighting, line numbers, git gutter
bp file.py                  # plain — no decorations, safe to copy from
b -r 100:150 big.log        # just those lines
cat file.py                 # unchanged, still there
```

### List a directory

```bash
ll                          # long, human sizes, git status column
la                          # + hidden
lt                          # tree, 2 levels
lsize                       # biggest first
lnew                        # newest first
```

### Explore an unfamiliar directory tree

```bash
ltg                         # tree, 3 levels, skipping gitignored noise
fm                          # yazi: browse with previews, q exits into that dir
```

`fm` then `q` leaves you in whatever directory you navigated to. `Q` quits without moving.

### Read a man page

```bash
h tar                       # tldr: practical examples, one screen
man tar                     # full manual, rendered through bat
```

Reach for `h` first. `man` when `h` isn't enough.

---

## 4. Git

### See what's going on

```bash
gs                          # short status with branch
gd                          # unstaged diff, through delta
gds                         # staged diff
gl                          # last 20 commits as a graph
```

### Commit

```bash
ga file.py                  # stage one
ga -p                       # stage interactively, hunk by hunk
gcm "fix the thing"
gp                          # push
```

### Anything more complicated

```bash
lg                          # lazygit
```

Interactive rebase, cherry-pick, stash management, partial staging — all of it without memorising porcelain flags. `Space` stages, `c` commits, `?` shows help.

### Switch branches

```bash
gco main                    # git switch
gcb feature/thing           # create and switch
fbr                         # fuzzy-pick from all branches, with log preview
```

### Find when something changed

```bash
git log -S 'functionName'   # commits that added/removed that string
git log -p file.py          # full history of one file
git blame file.py           # who last touched each line
```

⚠️ `gl` here is **log**, not `git pull`. If you came from oh-my-zsh, unlearn that.

---

## 5. Disk filling up

### Which directory is eating space

```bash
gdu ~                       # interactive: arrows to navigate, d to delete
gdu /                       # whole system (needs sudo for some paths)
```

This is the one to reach for. It navigates and deletes in place.

### Quick non-interactive answer

```bash
dsz                         # dust -d 2 : tree with proportional bars
dust -d 3 /var
dus                         # coreutils fallback, works anywhere
```

### How full are the disks

```bash
df                          # this is duf: mounted filesystems, coloured
duf --only local
```

⚠️ Category confusion worth naming: `duf` answers "how full is the disk", `dust`/`gdu` answer "what is using the space". Different questions.

### Delete recoverably

```bash
tp junk/                    # trash-put, recoverable
tl                          # what's in the trash
tre                         # restore, interactive
tempty 30                   # purge items older than 30 days
```

`rm` still deletes permanently. `rm -I` prompts once for >3 files or `-r`.

---

## 6. Processes and system

### What's running

```bash
top                         # btop: full dashboard
pg firefox                  # procs: search by name, pid, user, or port
ptree                       # process tree
pcpu                        # sorted by CPU
pmem                        # sorted by memory
```

`pg` replaces `ps aux | grep foo` and doesn't match itself in the results.

### What's using a port

```bash
ss -tlnp                    # listening TCP sockets with process
procs --help                # procs exposes ports via --insert, see its help
```

### Kill something

```bash
fkill                       # pick interactively, Tab for multiple, TERM
fkill 9                     # same, but SIGKILL
```

### Live monitoring

```bash
btop                        # f filters, t toggles tree view
procs --watch nginx
```

---

## 7. JSON and HTTP

### Look at a JSON file

```bash
jq . data.json              # pretty-print
jless data.json             # interactive, for large unfamiliar payloads
```

Start with `jless` when you don't yet know the shape. Switch to `jq` once you know the path.

### Extract from JSON

```bash
jq -r '.items[].name' f.json        # raw strings, no quotes
jq '.[] | select(.age > 30)'
jq 'map({id, name})'                # keep only some fields
jq -s 'add' a.json b.json           # merge two files
```

### Call an API

```bash
xh httpbin.org/get
xh POST api.example.com/users name=Sergey age:=30
xh GET api.example.com/search q==linux
xh POST url Authorization:"Bearer $TOKEN"
xh -v POST url a=b                  # print the request too
```

`=` string field · `:=` raw JSON (numbers, bools, arrays) · `==` query param · `:` header

### Chain them

```bash
xh -b GET api.example.com/users | jq -r '.[].email'
```

⚠️ Use `curl` in scripts and Dockerfiles. `curl` exists everywhere; `xh` doesn't.

---

## 8. Bulk file operations

### Rename or edit many files

```bash
fd -e jpeg -x mv {} {.}.jpg         # {} full path, {.} without extension
fd -e md -x sd 'old' 'new'          # substitute inside every match
fd -e log -X rm                     # -X batches into ONE invocation
```

`-x` runs once per file (parallel), `-X` runs once with all files as arguments.

### Preview before you commit to it

```bash
sd -p 'old' 'new' file.md           # print the diff, write nothing
fd -e md -x echo mv {} {.}.txt      # dry-run by echoing
```

Always do this before an in-place mass edit. There is no undo.

### Replace text across a repo

```bash
rg -l 'oldname' | xargs sd 'oldname' 'newname'
```

Check `rg -l 'oldname'` alone first. That list is exactly what will be modified.

### Handle spaces in filenames

```bash
fd -0 pattern | xargs -0 rm
```

`-0` / `-0` pairs null-separated output with null-aware input. Without it, a filename with a space becomes two arguments.

---

## 9. One-offs

### Is A actually faster than B

```bash
hyperfine 'rg pattern' 'grep -r pattern .'
hyperfine --warmup 3 './build.sh'
hyperfine -L n 1,4,8 'make -j{n}'
```

Runs each many times, reports mean and standard deviation. Replaces eyeballing `time`.

### Watch a command's output change

```bash
watch -n2 'procs --sortd cpu | head'
```

### What did I run last week

```bash
atuin search --interactive
atuin search -e 0 --limit 50        # only commands that succeeded
atuin stats
```

### Compare two files

```bash
delta a.py b.py
diff <(sort a.txt) <(sort b.txt)
```

### Edit a file quickly

```bash
micro file.conf             # Ctrl-S save, Ctrl-Q quit, mouse works
```

---

## Cross-cutting traps

| Symptom | Cause | Fix |
|---|---|---|
| Search returns nothing, file exists | gitignore / hidden | `rgh`, `fda` |
| Command behaves oddly in a script | aliases don't apply there | write the real command |
| `sudo cmd` ignores your alias | sudo doesn't expand aliases | `sudo $(which cmd)` |
| fzf preview empty | it shells out; aliases invisible | use `$FD_BIN` / `$BAT_BIN` |
| `/mnt/c` operations crawl | WSL crossing to Windows FS | keep work in `~` |
| Deleted the wrong thing with `rm` | `rm` is permanent | use `tp` next time |
| Prompt lost colours / icons | terminal font isn't a Nerd Font | set it in the terminal profile |
