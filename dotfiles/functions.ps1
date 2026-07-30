# ─────────────────────────────────────────────────────────────
#  functions.ps1 — the shell_common alias/function layer, ported
#
#  Dot-sourced from profile.ps1, which must run first: it sets $FdBin,
#  $BatBin, $EzaBin and Get-CliBin, all used below.
#
#  Two structural facts shape this whole file:
#
#  1. Set-Alias cannot carry arguments. Everything with a flag is a
#     function, not an alias.
#  2. PowerShell's command precedence is Alias > Function > Cmdlet >
#     Application. A built-in cmdlet alias therefore BEATS a function of
#     the same name, silently. So none of the names below may collide with
#     one — `Test-CliToolsSetup` at the bottom enforces that.
#
#  Deliberately NOT ported (see ../docs/powershell.md):
#    git aliases  — git is used from WSL; `g` passthrough is enough
#    grep→ug      — Windows has no grep to improve on; use rg or sls
#    df→duf       — no df to override; duf keeps its own name
#    top→btop     — btop is not built for Windows; bottom (btm) is
#    py           — py.exe is the official Python launcher, do not shadow
#    MANPAGER     — no man pages
#    h→tldr       — h is Get-History; call tldr by name
#    rm -I / mv -i / cp -i — no -I equivalent, see `tp` below
# ─────────────────────────────────────────────────────────────

# Fail immediately and clearly if this file is dot-sourced on its own.
# Without the guard the failure is confusing rather than absent: the
# `if ($EzaBin)` blocks quietly evaluate false, then the first Get-CliBin
# call throws "term not recognized" and everything after it — tp, cs, the
# dot-directory functions, Test-CliToolsSetup — is never defined.
if (-not (Get-Command Get-CliBin -ErrorAction SilentlyContinue)) {
    throw 'functions.ps1 requires profile.ps1: dot-source that instead, it loads this file itself.'
}

# --- ls / eza ---------------------------------------------------
# `ls` stays Get-ChildItem. This is stricter than the Linux config, and
# deliberately so: `ls | Where-Object Length -gt 1MB` works today, and an
# eza wrapper would return strings and break every such pipeline. eza gets
# a new name, `e`, per the "new tools get new names" rule.
#
# The base flags are repeated rather than held in a shared variable: a
# dot-sourced file has no private script scope, so a `$script:` variable
# here is just a session variable that anything could clobber, and an eza
# call with silently-missing flags is worse than eight repeated lines.
if ($EzaBin) {
    function e     { & $EzaBin --group-directories-first --icons=auto @args }
    function ll    { & $EzaBin -lh  --git --group-directories-first --icons=auto @args }
    function la    { & $EzaBin -lah --git --group-directories-first --icons=auto @args }
    function lt    { & $EzaBin --tree --level=2 --group-directories-first --icons=auto @args }
    function ltt   { & $EzaBin --tree --level=4 --group-directories-first --icons=auto @args }
    function ltg   { & $EzaBin --tree --level=3 --git-ignore --group-directories-first --icons=auto @args }
    function lsize { & $EzaBin -lah --icons=auto --sort=size     --reverse @args }
    function lnew  { & $EzaBin -lah --icons=auto --sort=modified --reverse @args }
}

# --- cat / bat --------------------------------------------------
# `cat` stays Get-Content. `b` reads, `bp` is plain (safe to copy from).
if ($BatBin) {
    function b  { & $BatBin @args }
    function bp { & $BatBin -p @args }
}

# --- search -----------------------------------------------------
if (Get-CliBin rg) {
    function rgh { rg -uuu @args }    # everything: no ignore, hidden, binary
    function rgf { rg --files @args } # list the files rg would search
}

# --- find -------------------------------------------------------
if ($FdBin) {
    function ff  { & $FdBin -tf @args }   # files only
    function fdd { & $FdBin -td @args }   # dirs only
    function fda { & $FdBin -HI @args }   # hidden + gitignored
}

# --- disk -------------------------------------------------------
if (Get-CliBin dust) { function dsz { dust -d 2 @args } }

# `du -sh * | sort -h` equivalent. Get-ChildItem rather than a shelled-out
# tool, so it works on a machine with nothing installed.
#
# Unreadable subdirectories are counted and reported. Suppressing the errors
# without saying so would produce a total that looks complete and is not;
# `du` at least writes to stderr while totalling what it can.
function dus {
    [CmdletBinding()]
    param()
    $denied = 0
    $rows = Get-ChildItem -Force | ForEach-Object {
        $bytes = if ($_.PSIsContainer) {
            $errs = @()
            $sum = (Get-ChildItem $_.FullName -Recurse -Force -File -ErrorAction SilentlyContinue -ErrorVariable +errs |
                    Measure-Object Length -Sum).Sum
            $denied += $errs.Count
            $sum
        } else { $_.Length }
        [pscustomobject]@{
            Size = [int64]($bytes ?? 0)
            MB   = [math]::Round(($bytes ?? 0) / 1MB, 1)
            Name = $_.Name
        }
    } | Sort-Object Size -Descending

    $rows | Format-Table MB, Name -AutoSize | Out-String | Write-Host
    if ($denied) { Write-Warning "$denied item(s) could not be read — totals are partial. Use -Verbose on Get-ChildItem to see which." }
}

# --- process ----------------------------------------------------
# `ps` and `kill` stay as they are. procs gets its own names.
# fkill comes from PSFzf, aliased in profile.ps1.
if (Get-CliBin procs) {
    function pg    { procs @args }              # "process grep"
    function ptree { procs --tree @args }
    function pcpu  { procs --sortd cpu @args }
    function pmem  { procs --sortd mem @args }
}

# --- git --------------------------------------------------------
# No git alias set here on purpose: git is driven from WSL, where
# shell_common already provides gs/gd/gl/gc/... Four of those names are
# built-in cmdlet aliases on Windows (gc=Get-Content, gcm=Get-Command,
# gl=Get-Location, gp=Get-ItemProperty) and overriding them would break any
# script run in this session. `g` is free and composes: `g status -sb`.
if (Get-CliBin git)     { Set-Alias g  git     -Force }
if (Get-CliBin lazygit) { Set-Alias lg lazygit -Force }

# --- json / http ------------------------------------------------
if (Get-CliBin jq) {
    function jqc { jq -c @args }
    function jqr { jq -r @args }
}
if (Get-CliBin xh) { Set-Alias http xh -Force }

# --- package manager (scoop) ------------------------------------
# Translation of the apt block. `scoop update` refreshes the manifests;
# `scoop update *` upgrades installed apps — two different things, hence
# two names. `*` is passed through literally: PowerShell does not glob for
# native commands.
#
# Get-Command, not Get-CliBin: scoop's entry point is a shim, and depending
# on how it was installed the resolvable one may be scoop.ps1 rather than an
# Application. Get-CliBin filters to Application and would miss it.
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    function scoopupd { scoop update }
    function scoopupg { scoop update * }
    function scoopup  { scoop update; scoop update * }
    function scoopin  { scoop install @args }
    function scooprm  { scoop uninstall @args }
    function scoopse  { scoop search @args }
    function scoopst  { scoop status }
}

# --- file safety ------------------------------------------------
# `rm` / Remove-Item are left alone. Two reasons, and they compound:
#   - Remove-Item's only prompt is -Confirm, which asks per item. That is
#     exactly the habituation trap `rm -i` was rejected for on Linux; the
#     good variant, `rm -I` (one prompt for >3 files or -r), has no
#     PowerShell equivalent.
#   - Remove-Item does NOT use the Recycle Bin. It deletes permanently.
# So "gone" and "recoverable" get different words, mirroring rm +
# trash-put on Linux. Here the Recycle Bin is built in, so nothing extra
# needs installing.
#
# UNVERIFIED: Microsoft.VisualBasic ships with the PowerShell 7 runtime on
# Windows. If Add-Type fails, tp reports it rather than deleting anything.
#
# ValueFromRemainingArguments is what makes `tp a.txt b.txt` work. Without it
# a [string[]] parameter has a single positional slot, so the second argument
# is rejected — the same trap as `Get-ChildItem a b`. Since tp stands in for
# rm, space-separated arguments are the expected form, not a nicety.
function tp {
    [CmdletBinding()]
    param([Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromRemainingArguments)]
          [string[]]$Path)
    begin {
        $ok = $true
        try { Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop }
        catch {
            $ok = $false
            Write-Error 'tp: Microsoft.VisualBasic unavailable — nothing deleted. Use Remove-Item or Explorer.'
        }
        if ($ok) {
            $ui = [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs
            $rb = [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
        }
    }
    process {
        if (-not $ok) { return }
        foreach ($p in $Path) {
            # Resolve-Path yielding nothing must not pass silently. `tp fiel.txt`
            # would otherwise print nothing, delete nothing, and look like it
            # worked — the worst outcome for a delete command.
            $resolved = Resolve-Path -LiteralPath $p -ErrorAction SilentlyContinue
            if (-not $resolved) { Write-Warning "tp: not found: $p"; continue }
            foreach ($item in $resolved) {
                $full = $item.Path
                if (Test-Path -LiteralPath $full -PathType Container) {
                    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($full, $ui, $rb)
                } else {
                    [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($full, $ui, $rb)
                }
                Write-Verbose "recycled: $full"
            }
        }
    }
}

# List the Recycle Bin. 0xA is the ssfBITBUCKET special folder.
function tl {
    $shell = New-Object -ComObject Shell.Application
    $bin   = $shell.NameSpace(0xA)      # resolved once, not per property
    $bin.Items() |
        Select-Object @{n='Name';e={$_.Name}},
                      @{n='Deleted';e={$bin.GetDetailsOf($_, 2)}},
                      @{n='OriginalPath';e={$bin.GetDetailsOf($_, 1)}}
}

# No `tre` (restore): the Shell verb for undelete is display-name based and
# therefore locale-dependent. Restoring from Explorer is the reliable path.
Set-Alias tempty Clear-RecycleBin -Force

# --- elevation --------------------------------------------------
# gsudo runs a command elevated in the SAME console, no second window.
# `sudo` is the muscle-memory name and PowerShell has nothing called that.
if (Get-CliBin gsudo) { Set-Alias sudo gsudo -Force }

# --- Everything (voidtools) -------------------------------------
# Instant filename search over the NTFS index — the one thing here with no
# Linux counterpart in this repo. `es.exe` is a SEPARATE download from
# voidtools; the GUI being installed does not provide it. Guarded, so this
# is a no-op until es.exe is on the PATH.
if (Get-CliBin es) {
    function esf { es -n 50 @args }              # first 50 matches
    function esr { es -regex @args }             # regex mode
}

# --- misc -------------------------------------------------------
# `md` already exists as a PowerShell function (mkdir). Left alone.
if (Get-CliBin yazi) { Set-Alias fm yazi -Force }
# No -p: glow's pager is `less`, which does not exist on Windows, so -p fails
# with "executable file not found in %PATH%". Rendering straight to stdout
# lets the terminal's own scrollback do the paging.
if (Get-CliBin glow) { function mdv { glow @args } }

function path { $env:PATH -split ';' | Where-Object { $_ } }

# Plain declarations are required here: `Set-Item -Path 'Function:..'`
# resolves `..` as a relative path inside the Function: drive and fails with
# a null-name error.
function ..   { Set-Location .. }
function ...  { Set-Location ../.. }
function .... { Set-Location ../../.. }

# ─────────────────────────────────────────────────────────────
#  cs — fuzzy-search cheatsheet.md by section
#
#  `cs -List` prints the section titles without the picker.
#
#  The Linux version used awk to build a section index and sed to print the
#  chosen range. Here the index is built in PowerShell and the range is
#  printed by `bat --line-range`, which also makes the fzf preview a single
#  cmd.exe-safe command — no sed, no process substitution.
# ─────────────────────────────────────────────────────────────
function cs {
    [CmdletBinding()]
    param([string]$Query, [switch]$List)

    $root = $env:CLI_DOCS
    if (-not $root) { Write-Error 'cs: CLI_DOCS is not set (profile.ps1 sets it)'; return }
    $doc = Join-Path $root 'cheatsheet.md'
    if (-not (Test-Path $doc)) { Write-Error "cs: not found: $doc"; return }

    # Section = an H2/H3 heading through to the line before the next one.
    $lines = Get-Content -LiteralPath $doc
    $heads = for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^#{2,3}\s+(.+)$') {
            [pscustomobject]@{ Line = $i + 1; Title = $Matches[1] }
        }
    }
    if (-not $heads) { Write-Error 'cs: no H2/H3 headings found'; return }

    $sections = for ($i = 0; $i -lt $heads.Count; $i++) {
        $end = if ($i + 1 -lt $heads.Count) { $heads[$i + 1].Line - 1 } else { $lines.Count }
        [pscustomobject]@{ Start = $heads[$i].Line; End = $end; Title = $heads[$i].Title }
    }

    if ($List) { return $sections.Title }

    if (-not $FzfBin) { Write-Error 'cs: fzf not found'; return }

    $index = $sections | ForEach-Object { '{0}:{1}:{2}' -f $_.Start, $_.End, $_.Title }

    # The preview command goes through FZF_DEFAULT_OPTS, not through argv.
    # Reason: it must contain quoted paths, and passing an argument that
    # itself contains double quotes to a native executable depends on
    # PowerShell's native-argument-passing mode and on how the receiving
    # program parses the Windows command line — two variables, neither
    # pinned. fzf's own parsing of FZF_DEFAULT_OPTS is well defined: outer
    # single quotes group the command, inner double quotes survive to
    # cmd.exe. Same mechanism profile.ps1 already relies on.
    #
    # Only --query goes through argv, because it never contains quotes.
    $fzfArgs = @()
    if ($Query) { $fzfArgs += @('--query', $Query) }

    $prevOpts = $env:FZF_DEFAULT_OPTS
    try {
        $opts = "$prevOpts --delimiter : --with-nth 3.. --select-1" +
                ' --preview-window right:65%:wrap'
        if ($BatBin) {
            $opts += " --preview '""$BatBin"" --style=plain --color=always" +
                     " --language md --line-range {1}:{2} ""$doc""'"
        }
        $env:FZF_DEFAULT_OPTS = $opts
        $sel = $index | & $FzfBin @fzfArgs
    } finally {
        $env:FZF_DEFAULT_OPTS = $prevOpts
    }
    if (-not $sel) { return }

    $parts = $sel -split ':', 3
    $body  = $lines[([int]$parts[0] - 1)..([int]$parts[1] - 1)]
    if ($BatBin) { $body | & $BatBin -l md -p --color=always } else { $body }
}

# ─────────────────────────────────────────────────────────────
#  Test-CliToolsSetup — collision check for the names defined above
#
#  PowerShell resolves an alias before a function, so a function named after
#  a built-in alias never runs and never errors. This reports any such name,
#  plus which expected tools are missing. Run after editing this file, or set
#  CLI_TOOLS_SELFCHECK=1 to have it run at shell start.
# ─────────────────────────────────────────────────────────────
function Test-CliToolsSetup {
    [CmdletBinding()]
    param()
    # Names this config defines as FUNCTIONS. Any of these resolving to an
    # alias means the function is unreachable.
    $ourFunctions = @(
        'e','ll','la','lt','ltt','ltg','lsize','lnew','b','bp','rgh','rgf',
        'ff','fdd','fda','dsz','dus','pg','ptree','pcpu','pmem','jqc','jqr',
        'tp','tl','path','cs','..','...','....','mdv','esf','esr',
        'scoopupd','scoopupg','scoopup','scoopin','scooprm','scoopse','scoopst',
        # defined in profile.ps1 as deferred wrappers around PSFzf
        'fe','fkill','fif'
    )

    # Names this config defines as ALIASES, mapped to what they must resolve
    # to. Checked against the target, not against being an alias: the failure
    # mode here is "aliased to something other than what we set". Names
    # missing from this table get no collision protection at all, so add to
    # it whenever an alias is added above.
    $ourAliases = @{
        g = 'git'; lg = 'lazygit'; http = 'xh'; fm = 'yazi'; sudo = 'gsudo'
        tempty = 'Clear-RecycleBin'
    }

    $problems = @(
        foreach ($n in $ourFunctions) {
            $cmd = Get-Command $n -ErrorAction SilentlyContinue
            if ($cmd -and $cmd.CommandType -eq 'Alias') {
                [pscustomobject]@{ Name = $n; Problem = "shadowed by alias -> $($cmd.Definition)" }
            }
        }
        foreach ($n in $ourAliases.Keys) {
            $cmd = Get-Command $n -ErrorAction SilentlyContinue
            if (-not $cmd) { continue }   # its tool is not installed; fine
            if ($cmd.CommandType -ne 'Alias' -or $cmd.Definition -ne $ourAliases[$n]) {
                [pscustomobject]@{ Name = $n; Problem = "resolves to $($cmd.CommandType) $($cmd.Definition), expected alias -> $($ourAliases[$n])" }
            }
        }
    )
    if ($problems) {
        Write-Warning 'Name collisions — these do not resolve to what this config defines:'
        $problems | Format-Table -AutoSize | Out-String | Write-Host
    }

    # git and delta are deliberately absent on Windows (driven from WSL), so
    # they are not in this list. Including them would make the green "OK" line
    # unreachable on a correct setup, which trains you to ignore the output.
    $tools = 'fzf','zoxide','starship','bat','fd','rg','eza','jq',
             'procs','dust','duf','xh','lazygit','yazi','micro','btm','tldr',
             'carapace','gsudo','atuin','hyperfine','ouch','glow'
    $missing = $tools | Where-Object { -not (Get-CliBin $_) }
    if ($missing) { Write-Host "not installed: $($missing -join ', ')" -ForegroundColor DarkYellow }

    if (-not $problems -and -not $missing) { Write-Host 'cli_tools: OK' -ForegroundColor Green }
}
