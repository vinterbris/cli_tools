#Requires -Version 7.0
# ─────────────────────────────────────────────────────────────
#  profile.ps1 — PowerShell 7 counterpart of zshrc + shell_common
#
#  Install: $PROFILE holds ONE line, written by bootstrap/install.ps1:
#      . "<repo>\dotfiles\profile.ps1"
#  The file in the repo is the loaded config; there is no copy to sync.
#
#  Design rules:
#    - Core commands keep core behaviour. On Windows "core" includes the
#      cmdlet aliases: ls, cat, gc, gcm, gl, gp, h are not touched.
#    - Every tool reference is guarded, so this works on a bare machine and
#      lights up as tools are installed.
#    - The repo is the single source of truth for config; tools are pointed
#      at it with environment variables, never by copying files.
#    - Machine-local settings go in profile.local.ps1, untracked, loaded last.
#
#  Load order and the constraints behind it: dotfiles/README.md
#  Design history, constraints and rejected options: ../docs/powershell.md
# ─────────────────────────────────────────────────────────────

# --- startup timing ---------------------------------------------
# CLI_TOOLS_TIMING=1 prints cumulative milliseconds at each stage.
# Write-CliTiming stays in the session after load — dot-sourcing offers no
# private scope, so there is nowhere else for it to live.
$CliSw = if ($env:CLI_TOOLS_TIMING) { [System.Diagnostics.Stopwatch]::StartNew() } else { $null }
function Write-CliTiming {
    param([string]$Label)
    if ($CliSw) { Write-Host ('{0,6} ms  {1}' -f $CliSw.ElapsedMilliseconds, $Label) -ForegroundColor DarkGray }
}

# --- locate the docs --------------------------------------------
# $PSScriptRoot is <repo>\dotfiles, so the repo can be cloned anywhere.
# CLI_DOCS points at <repo>\docs — the same override name shell_common uses.
$env:CLI_DOCS = Join-Path (Split-Path -Parent $PSScriptRoot) 'docs'

# --- resolve real executable paths ------------------------------
# Full paths, not bare names: fzf on Windows runs --preview and
# FZF_*_COMMAND through cmd.exe and ignores $SHELL (junegunn/fzf#1018), and
# PowerShell functions and aliases do not exist there. This is the Windows
# form of the shell_common rule that aliases are invisible to anything that
# shells out.
#
# Get-CliBin and the $*Bin variables land in the session scope because this
# file is dot-sourced; functions.ps1 depends on that. Dot-source this file,
# do not run it as a script.
# Plain Get-Command, deliberately, after a measured detour.
#
# A PATH index was built to replace ~21 of these probes and then reverted. It
# worked — 380 ms against 386 — but the gain was ~25 ms, roughly 6%, in
# exchange for 35 lines, its own verification function, and a correctness
# limitation Get-Command does not have: a `.cmd` earlier on PATH would be
# shadowed by a same-named `.exe`. Machinery must not exceed the problem, and a
# construct needing its own test to police a limitation it introduced is on the
# wrong side of that.
#
# Cost of what remains, for anyone tempted to try again: ~15 ms per probe on
# this machine, so about 60 ms here and 45 ms in functions.ps1. Known and
# accepted, not overlooked.
#
# Applications only, by design. functions.ps1 deliberately uses Get-Command
# without -CommandType for `scoop`, whose entry point may be a .ps1.
function Get-CliBin {
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$Name)
    $cmd = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue |
           Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return $null
}

$FdBin       = Get-CliBin fd
$BatBin      = Get-CliBin bat
$FzfBin      = Get-CliBin fzf
$EzaBin      = Get-CliBin eza
$StarshipBin = Get-CliBin starship
$ZoxideBin   = Get-CliBin zoxide
$CarapaceBin = Get-CliBin carapace
$AtuinBin    = Get-CliBin atuin
Write-CliTiming 'resolve binaries'

# --- init-script cache ------------------------------------------
# starship, zoxide, carapace and atuin each generate their PowerShell init by
# running the binary. Four process spawns per shell start; measured at 666 ms
# for the config before this existed. The generated script is cached and
# dot-sourced instead.
#
# Staleness compares timestamps against the binary, so a Scoop update — which
# rewrites the shim — invalidates the cache. CLI_TOOLS_NO_CACHE=1 bypasses it;
# Clear-CliToolsCache removes it; Test-CliToolsCache reports on it.
$CliCacheDir = Join-Path $env:LOCALAPPDATA 'cli_tools\cache'

function Use-CachedInit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Exe,
        [Parameter(Mandatory)][string[]]$InitArgs
    )

    # Empty output means a broken install or wrong arguments. Without this
    # check the integration would simply be absent, with nothing said.
    $generate = {
        $text = (& $Exe @InitArgs | Out-String)
        if (-not $text.Trim()) { throw "'$Exe $($InitArgs -join ' ')' produced no output" }
        $text
    }

    if ($env:CLI_TOOLS_NO_CACHE) {
        try {
            # Invoke-Expression is unavoidable here: the input is a local
            # binary's own stdout, which is how these tools ship their init.
            # PSScriptAnalyzer flags the call; the trust boundary is the
            # binary, not user input.
            Invoke-Expression (& $generate)
        } catch {
            Write-Warning "cli_tools: '$Name' init failed — $($_.Exception.Message)"
        }
        return
    }

    # The cache is keyed on $Name alone, so a change to $InitArgs would not
    # invalidate it. The invocation is therefore recorded as the first line
    # and compared: a different command line counts as stale.
    # [IO.File] rather than cmdlets: same three checks, but four cmdlet
    # invocations per tool — one of them opening a pipeline — becomes three
    # static calls. Exists() must stay first: GetLastWriteTimeUtc returns
    # 1601-01-01 for a missing file instead of throwing.
    $cache  = Join-Path $CliCacheDir "$Name.ps1"
    $header = "# cli_tools: $Exe $($InitArgs -join ' ')"
    $fresh  = [IO.File]::Exists($cache) -and
              ([IO.File]::GetLastWriteTimeUtc($cache) -ge [IO.File]::GetLastWriteTimeUtc($Exe)) -and
              ((& { $r = [IO.StreamReader]::new($cache); try { $r.ReadLine() } finally { $r.Dispose() } }) -eq $header)

    if (-not $fresh) {
        $generated = $null
        try {
            $generated = & $generate
            if (-not (Test-Path -LiteralPath $CliCacheDir)) {
                New-Item -ItemType Directory -Path $CliCacheDir -Force -ErrorAction Stop | Out-Null
            }
            Set-Content -LiteralPath $cache -Value "$header`n$generated" -Encoding utf8 -ErrorAction Stop
            Write-CliTiming "  (regenerated cache: $Name)"
        } catch {
            # A write failure must not become a permanent silent slowdown:
            # without this warning the binary would be re-run on every start
            # forever, and nothing would say so.
            Write-Warning "cli_tools: cache for '$Name' not written, falling back to running the binary every start. $($_.Exception.Message)"
            if ($generated) { Invoke-Expression $generated }
            return
        }
    }
    . $cache
}

function Clear-CliToolsCache {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    if (-not (Test-Path -LiteralPath $CliCacheDir)) { Write-Host 'nothing cached' -ForegroundColor DarkGray; return }
    if ($PSCmdlet.ShouldProcess($CliCacheDir, 'Remove init cache')) {
        Remove-Item -LiteralPath $CliCacheDir -Recurse -Force
        Write-Host "cleared $CliCacheDir — restart the shell" -ForegroundColor Green
    }
}

# Answers "is the cache actually being used", instead of leaving it to be
# inferred from timing numbers.
function Test-CliToolsCache {
    [CmdletBinding()]
    param()
    if ($env:CLI_TOOLS_NO_CACHE) {
        Write-Host 'CLI_TOOLS_NO_CACHE is set — caching disabled' -ForegroundColor DarkYellow
        return
    }
    if (-not (Test-Path -LiteralPath $CliCacheDir)) {
        Write-Warning "cache directory does not exist: $CliCacheDir"
        Write-Host 'Every init is being regenerated on every shell start.' -ForegroundColor DarkYellow
        return
    }
    Write-Host "cache: $CliCacheDir" -ForegroundColor DarkGray
    foreach ($n in 'starship', 'zoxide', 'carapace', 'atuin') {
        $f = Join-Path $CliCacheDir "$n.ps1"
        if (-not (Test-Path -LiteralPath $f)) { Write-Host ('{0,-10} absent' -f $n) -ForegroundColor DarkYellow; continue }
        $exe   = Get-CliBin $n
        $item  = Get-Item -LiteralPath $f
        $state = if (-not $exe) { 'no binary' }
                 elseif ($item.LastWriteTimeUtc -ge (Get-Item -LiteralPath $exe).LastWriteTimeUtc) { 'fresh' }
                 else { 'STALE — regenerates every start' }
        Write-Host ('{0,-10} {1,7} bytes  {2}' -f $n, $item.Length, $state)
    }
}

# --- editor -----------------------------------------------------
# micro, same as the Linux config: Ctrl+S saves, Ctrl+Q quits, nothing modal.
# notepad last so $env:EDITOR is never empty on a bare machine.
#
# A bare name here rather than a resolved path, unlike everything else in
# this file: EDITOR is consumed by programs that hand it to a POSIX-ish shell
# — git's editor invocation being the obvious one — where a Windows path full
# of backslashes is mangled and a PATH-resolved name is not. The full-path
# rule applies to strings that reach cmd.exe; this is not one.
foreach ($e in 'micro', 'notepad') {
    if (Get-CliBin $e) { $env:EDITOR = $e; break }
}
$env:VISUAL = $env:EDITOR

# --- bat --------------------------------------------------------
# ansi theme follows the terminal's own colours. No MANPAGER: Windows has no
# man pages, help is Get-Help.
if ($BatBin -and -not $env:BAT_THEME) { $env:BAT_THEME = 'ansi' }

# --- fzf environment --------------------------------------------
# PSFzf honours FZF_DEFAULT_COMMAND, FZF_CTRL_T_COMMAND and
# FZF_ALT_C_COMMAND. It does not read FZF_CTRL_T_OPTS / FZF_ALT_C_OPTS —
# those are fzf's shell-integration variables and have no PowerShell
# equivalent, so preview options go into _PSFZF_FZF_DEFAULT_OPTS, assigned at
# the end of this file.
$FzfPreviewCmd = $null
if ($FzfBin) {
    $env:FZF_DEFAULT_OPTS = '--height 60% --layout=reverse --border --info=inline'

    # -I dropped and AppData excluded relative to the Linux config: in $HOME,
    # `fd -tf -HI` measured 3305 ms against 235 ms with these exclusions,
    # because -HI means walking AppData. FZF_CTRL_T_COMMAND and
    # FZF_ALT_C_COMMAND are still exported even though those chords are
    # unbound — `fe` and any future direct fzf use pick them up.
    $FdExcludes = '--exclude .git --exclude AppData --exclude node_modules --exclude $Recycle.Bin'
    if ($FdBin) {
        $env:FZF_DEFAULT_COMMAND = "`"$FdBin`" -tf -H $FdExcludes"
        $env:FZF_CTRL_T_COMMAND  = $env:FZF_DEFAULT_COMMAND
        $env:FZF_ALT_C_COMMAND   = "`"$FdBin`" -td -H $FdExcludes"
    }

    # Ctrl+T yields files and Alt+C directories, but they share one set of
    # options, so the preview command branches. `if exist "X\"` is the
    # cmd.exe directory test; the trailing backslash is what makes it
    # directory-only.
    #
    # Quoting, outside in:
    #   1. fzf splits FZF_DEFAULT_OPTS into words honouring quotes, so the
    #      command is wrapped in SINGLE quotes — double quotes would be
    #      closed by the first inner quote.
    #   2. fzf does not quote the {} substitution on Windows (fzf#1018), so
    #      each {} is quoted here by hand.
    #
    # If the preview pane shows a cmd error, drop the branch and use
    # $filePrev alone.
    if ($BatBin) {
        $filePrev = """$BatBin"" --color=always --style=numbers --line-range :200 ""{}"""
        $dirPrev  = if ($EzaBin) {
            """$EzaBin"" --tree --level=2 --icons=auto --color=always ""{}"""
        } else {
            'dir /b "{}"'
        }
        $FzfPreviewCmd = "if exist ""{}\"" ($dirPrev) else ($filePrev)"
    }
}
Write-CliTiming 'fzf env'

# --- the alias / function layer ---------------------------------
. (Join-Path $PSScriptRoot 'functions.ps1')
Write-CliTiming 'functions.ps1'

# --- PSReadLine -------------------------------------------------
# Parity with zsh-autosuggestions (inline prediction) and
# zsh-syntax-highlighting (PSReadLine colours natively — no module).
# Imported before PSFzf and carapace, both of which register handlers on it.
Import-Module PSReadLine -ErrorAction SilentlyContinue
if (Get-Module PSReadLine) {
    # One call, not four. -EditMode Windows is already the Windows default;
    # it is stated because it resets key bindings, which is what forces
    # carapace's Tab handler to be set after this point.
    Set-PSReadLineOption -EditMode Windows -HistoryNoDuplicates `
                         -HistorySearchCursorMovesToEnd -BellStyle None

    # Kept separate on purpose: merged in, an older PSReadLine rejecting these
    # two would discard every option above as well.
    if ((Get-Module PSReadLine).Version -ge [version]'2.2.0') {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        Set-PSReadLineOption -PredictionViewStyle ListView
    }

    # Search history by the prefix already typed — zsh's
    # history-substring-search behaviour.
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}
Write-CliTiming 'PSReadLine'

# --- Terminal-Icons: opt-in only --------------------------------
# Measured at 348 ms of shell startup, the largest single cost in this file.
# Set CLI_TOOLS_ICONS=1 in profile.local.ps1 to accept that price.
if ($env:CLI_TOOLS_ICONS) {
    Import-Module Terminal-Icons -ErrorAction SilentlyContinue
    Write-CliTiming 'Terminal-Icons'
}

# --- prompt: starship, Pure preset ------------------------------
# The same starship.toml as WSL. STARSHIP_CONFIG is set explicitly rather
# than relying on ~/.config, so the repo stays the single source of truth.
# --print-full-init, because plain `starship init powershell` emits a
# 135-byte stub that re-invokes starship at load time — caching the stub
# still spawned the process on every start.
#
# This stage still costs ~80 ms. Per-line profiling attributes it to parsing
# and executing the cached script rather than to a spawn: `. $cache` across
# all four tools is 97 ms, while the one spawn inside starship's init
# (`prompt --continuation`) measures 26 ms. Not reducible without dropping
# the tool.
if ($StarshipBin) {
    $env:STARSHIP_CONFIG = Join-Path $PSScriptRoot 'starship.toml'
    Use-CachedInit -Name starship -Exe $StarshipBin -InitArgs @('init', 'powershell', '--print-full-init')
}
Write-CliTiming 'starship init'

# --- zoxide -----------------------------------------------------
# Provides `z` and `zi`. After the prompt init: zoxide hooks the prompt
# function to record directories, and starship replaces it.
if ($ZoxideBin) {
    Use-CachedInit -Name zoxide -Exe $ZoxideBin -InitArgs @('init', 'powershell')
}
Write-CliTiming 'zoxide init'

# --- carapace: argument completion ------------------------------
# Completions for 1000+ commands. MenuComplete on Tab is required, not a
# preference: the default Complete function renders raw ANSI escapes. It is
# set after Set-PSReadLineOption -EditMode above, which resets key bindings.
if ($CarapaceBin) {
    $env:CARAPACE_BRIDGES = 'zsh,fish,bash'
    Set-PSReadLineOption -Colors @{ 'Selection' = "`e[7m" }
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Use-CachedInit -Name carapace -Exe $CarapaceBin -InitArgs @('_carapace')
}
Write-CliTiming 'carapace'

# --- atuin: shell history ---------------------------------------
# Takes Ctrl+R, mirroring the Linux load-order rule, which is why PSFzf
# below is told not to claim it. Local only until `atuin login`.
#
# If the prompt jumps when the search UI opens, set
# $env:ATUIN_POWERSHELL_PROMPT_OFFSET = 1 in profile.local.ps1 — the UI is
# drawn relative to the prompt and the Pure preset is two lines.
if ($AtuinBin) {
    Use-CachedInit -Name atuin -Exe $AtuinBin -InitArgs @('init', 'powershell')
}
Write-CliTiming 'atuin'

# --- PSFzf, deferred, and Ctrl+T / Alt+C deliberately unbound ----
# Importing PSFzf costs ~150 ms — PSFzf.dll, a PSModulePath walk, a wildcard
# PATH scan for fzf, and a `fzf --version` spawn — none of which is needed
# until something actually uses it. So stubs pay it on first use.
#
# CTRL+T AND ALT+C ARE NOT BOUND. Both corrupted the terminal display on this
# machine: Ctrl+T drew an empty picker and typing into it garbled the screen,
# Alt+C did the same. Plain fzf is fine — `cs` runs it directly and works — so
# the fault is in PSFzf's PSReadLine handlers redrawing the prompt, not fzf.
# Rather than ship two keys that break the shell, they are left alone.
#
# The functionality is available without them:
#   Alt+C  → `zi`   zoxide's interactive directory picker
#   Ctrl+T → `fe`   pick a file and open it in $EDITOR
#
# Alt+A works correctly and is kept. It is bound by PSFzf's own import, so it
# would have disappeared silently without a stub of its own.
#
# The stubs call PSFzf's exported handlers directly and stay bound rather than
# handing the chord over after import: PSFzf skips any chord already bound, so
# a handover would need -Override, and Set-PsFzfOption has no parameter for
# the Alt+A chord at all.
#
# -EnableAlias* remains unused: PSFzf's optional aliases include `fd`
# (Invoke-FuzzySetLocation), which would shadow the fd binary, plus `ff`,
# `fe` and `fkill`, which collide with names in functions.ps1.
if ($FzfBin) {
    function Import-PsFzfNow {
        if (Get-Module PSFzf) { return $true }
        Import-Module PSFzf -ErrorAction SilentlyContinue
        if (Get-Module PSFzf) { return $true }
        # Loud: the alternative is a dead key with no explanation.
        Write-Host 'cli_tools: PSFzf failed to import — Alt+A, fe, fkill and fif are unavailable' -ForegroundColor Red
        return $false
    }

    Set-PSReadLineKeyHandler -Key 'Alt+a' -BriefDescription 'PSFzf history args (deferred)' `
        -ScriptBlock { if (Import-PsFzfNow) { Invoke-FzfPsReadlineHandlerHistoryArgs } }

    # Functions, not aliases: an alias cannot trigger the import, and these
    # names must work the first time they are typed.
    function fe    { if (Import-PsFzfNow) { Invoke-FuzzyEdit        @args } }
    function fkill { if (Import-PsFzfNow) { Invoke-FuzzyKillProcess @args } }
    function fif   { if (Import-PsFzfNow) { Invoke-PsFzfRipgrep     @args } }
}
Write-CliTiming 'PSFzf (deferred)'

# --- machine-local overrides ------------------------------------
# Last, so it can override anything above. The opposite of the zsh order,
# where .zshrc.local must precede syntax highlighting; PSReadLine applies
# colours dynamically and has no such constraint.
$localProfile = Join-Path $PSScriptRoot 'profile.local.ps1'
if (Test-Path $localProfile) { . $localProfile }

# --- derived from the final FZF_DEFAULT_OPTS ---------------------
# After profile.local.ps1 on purpose: this embeds a copy of
# FZF_DEFAULT_OPTS, and PSFzf reads the variable when a chord fires rather
# than now, so a local override still reaches the preview.
if ($FzfPreviewCmd) {
    $env:_PSFZF_FZF_DEFAULT_OPTS = "$($env:FZF_DEFAULT_OPTS) --preview '$FzfPreviewCmd'"
}
Write-CliTiming 'total'

# --- self-check --------------------------------------------------
# A function silently loses to an alias of the same name in PowerShell's
# command precedence, so a collision introduced later would fail invisibly.
# CLI_TOOLS_SELFCHECK=1 runs the check at shell start.
if ($env:CLI_TOOLS_SELFCHECK) { Test-CliToolsSetup }
