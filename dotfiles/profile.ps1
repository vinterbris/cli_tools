#Requires -Version 7.0
# ─────────────────────────────────────────────────────────────
#  profile.ps1 — PowerShell 7 counterpart of zshrc + shell_common
#
#  Install: $PROFILE holds ONE line, written by bootstrap/install.ps1:
#      . "<repo>\dotfiles\profile.ps1"
#  No symlink, no copy. Symlinks need Developer Mode or admin on Windows,
#  and PowerShell — unlike zsh, which insists on ~/.zshrc — lets the stub
#  point anywhere. So the file in the repo IS the loaded config, and there
#  is no sync step to forget.
#
#  Design rules carried over from shell_common:
#    - Core commands keep core behaviour. On Windows "core" includes the
#      cmdlet aliases: ls, cat, gc, gcm, gl, gp, h are NOT touched.
#    - Guarded everywhere. Every tool is wrapped in a resolve-or-skip, so
#      this file works on a bare machine and lights up as you install.
#    - Machine-local settings live in profile.local.ps1, untracked.
#    - Config policy: the repo is the single source of truth, and tools are
#      pointed at it with environment variables ($STARSHIP_CONFIG and
#      friends). Nothing is copied into a tool's conventional location.
#
#  See dotfiles/README.md for load order and ../prd-powershell.md for the
#  full Linux→PowerShell portability audit.
# ─────────────────────────────────────────────────────────────

# --- startup timing ---------------------------------------------
# CLI_TOOLS_TIMING=1 prints cumulative milliseconds at each stage.
# Exists because "the profile feels slow" is not actionable and guessing at
# the cause is how you optimise the wrong line.
$CliSw = if ($env:CLI_TOOLS_TIMING) { [System.Diagnostics.Stopwatch]::StartNew() } else { $null }
function Mark {
    param([string]$Label)
    if ($CliSw) { Write-Host ('{0,6} ms  {1}' -f $CliSw.ElapsedMilliseconds, $Label) -ForegroundColor DarkGray }
}

# --- locate the repo --------------------------------------------
# $PSScriptRoot is <repo>\dotfiles. Nothing is hardcoded, so the repo can
# be cloned anywhere. CLI_DOCS is the same override name shell_common uses.
$env:CLI_DOCS = Split-Path -Parent $PSScriptRoot

# --- resolve real executable paths ------------------------------
# WHY full paths and not bare names: fzf on Windows runs --preview and
# FZF_*_COMMAND through cmd.exe (it ignores $SHELL — junegunn/fzf#1018,
# #2638). PowerShell functions and aliases do not exist inside cmd.exe.
# This is the Windows form of the shell_common trap: "aliases are invisible
# to anything that shells out".
#
# The Scoop shims directory is tried first. Everything here comes from
# Scoop, all its shims live in one folder, and a Test-Path against a known
# location is far cheaper than Get-Command walking the whole PATH — six
# probes cost 66 ms that way. No cache and no invalidation logic: the file
# is either there or it is not.
#
# Get-CliBin and the $*Bin variables land in the session scope because this
# file is dot-sourced. functions.ps1 relies on that. Do not run this file as
# a script (`& profile.ps1`) — dot-source it.
$ScoopRoot  = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $HOME 'scoop' }
$ScoopShims = Join-Path $ScoopRoot 'shims'

function Get-CliBin {
    param([Parameter(Mandatory)][string]$Name)
    $shim = Join-Path $ScoopShims "$Name.exe"
    if (Test-Path -LiteralPath $shim) { return $shim }
    $c = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue |
         Select-Object -First 1
    if ($c) { return $c.Source }
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
Mark 'resolve binaries'

# --- init-script cache ------------------------------------------
# starship, zoxide, carapace and atuin each generate their PowerShell init
# by running the binary. Four process spawns per shell start, and measured
# on this machine the config already costs 666 ms of the 847 ms total —
# adding four more spawns would push a new tab past a second.
#
# So the generated script is cached and dot-sourced instead. Staleness is
# decided by comparing timestamps against the binary itself, so `scoop
# update` invalidates it automatically. Set CLI_TOOLS_NO_CACHE=1 to bypass,
# or run Clear-CliToolsCache.
#
# This is real machinery and it earns its place only because of the
# measurement above. If the numbers had said 200 ms, it should not be here.
$CliCacheDir = Join-Path $env:LOCALAPPDATA 'cli_tools\cache'

function Use-CachedInit {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Exe,
        [Parameter(Mandatory)][string[]]$InitArgs
    )
    if ($env:CLI_TOOLS_NO_CACHE) {
        Invoke-Expression ((& $Exe @InitArgs | Out-String)); return
    }
    $cache = Join-Path $CliCacheDir "$Name.ps1"
    $fresh = (Test-Path -LiteralPath $cache) -and
             ((Get-Item -LiteralPath $cache).LastWriteTimeUtc -ge (Get-Item -LiteralPath $Exe).LastWriteTimeUtc)
    if (-not $fresh) {
        if (-not (Test-Path -LiteralPath $CliCacheDir)) {
            New-Item -ItemType Directory -Path $CliCacheDir -Force | Out-Null
        }
        (& $Exe @InitArgs | Out-String) | Set-Content -LiteralPath $cache -Encoding utf8
    }
    . $cache
}

function Clear-CliToolsCache {
    if (Test-Path -LiteralPath $CliCacheDir) {
        Remove-Item -LiteralPath $CliCacheDir -Recurse -Force
        Write-Host "cleared $CliCacheDir — restart the shell" -ForegroundColor Green
    } else {
        Write-Host 'nothing cached' -ForegroundColor DarkGray
    }
}

# --- editor -----------------------------------------------------
# micro, same as the Linux config: modern keybindings (Ctrl+S saves,
# Ctrl+Q quits), nothing modal to learn. notepad is the last resort so
# $env:EDITOR is never empty on a machine with no tools installed.
#
# nvim is deliberately NOT in this chain. The old profile aliased vim→nvim,
# but nvim is not installed and he does not use it — the alias was stale.
#
# A BARE NAME here, not the resolved path, unlike everywhere else in this
# file. Reviewed and kept deliberately: EDITOR is consumed by programs that
# hand it to a POSIX-ish shell — git's editor invocation being the obvious
# one — where a Windows path full of backslashes gets mangled and a bare
# name resolved through PATH does not. The full-path rule exists for strings
# that reach cmd.exe, which this one does not.
foreach ($e in 'micro', 'notepad') {
    if (Get-CliBin $e) { $env:EDITOR = $e; break }
}
$env:VISUAL = $env:EDITOR

# --- bat --------------------------------------------------------
# ansi theme = follow the terminal's own colours, same as Linux.
# No MANPAGER: Windows has no man pages, help is Get-Help.
if ($BatBin -and -not $env:BAT_THEME) { $env:BAT_THEME = 'ansi' }

# --- fzf environment --------------------------------------------
# PSFzf honours FZF_DEFAULT_COMMAND, FZF_CTRL_T_COMMAND and
# FZF_ALT_C_COMMAND (confirmed in the PSFzf README). It does NOT read
# FZF_CTRL_T_OPTS / FZF_ALT_C_OPTS — those are fzf's shell-integration
# variables and have no PowerShell equivalent. Per-widget preview options
# therefore go into _PSFZF_FZF_DEFAULT_OPTS, assigned at the end of this
# file.
$FzfPreviewCmd = $null
if ($FzfBin) {
    $env:FZF_DEFAULT_OPTS = '--height 60% --layout=reverse --border --info=inline'

    # The Linux config uses `fd -tf -HI`. -I (no-ignore) is dropped here and
    # AppData / node_modules are excluded, because on Windows Ctrl+T is
    # frequently pressed in $HOME, where -HI means walking AppData — tens of
    # thousands of files — before fzf shows anything. That is the reported
    # "terminal froze". Hidden files are still included; only the two
    # directories that are always large are not.
    $FdExcludes = '--exclude .git --exclude AppData --exclude node_modules --exclude $Recycle.Bin'
    if ($FdBin) {
        $env:FZF_DEFAULT_COMMAND = "`"$FdBin`" -tf -H $FdExcludes"
        $env:FZF_CTRL_T_COMMAND  = $env:FZF_DEFAULT_COMMAND
        $env:FZF_ALT_C_COMMAND   = "`"$FdBin`" -td -H $FdExcludes"
    }

    # Preview pane. Ctrl+T yields files and Alt+C yields directories, but the
    # options are shared between them, so the command has to branch.
    # `if exist "X\"` is the cmd.exe directory test — the trailing backslash
    # inside the quotes is what makes it directory-only.
    #
    # Quoting, from outside in:
    #   1. fzf splits FZF_DEFAULT_OPTS into words honouring quotes, so the
    #      whole preview command is wrapped in SINGLE quotes. Double quotes
    #      there would be closed by the first inner quote.
    #   2. On Windows fzf does NOT quote the {} substitution (fzf#1018), so
    #      each {} is wrapped in double quotes here by hand.
    #
    # If the preview pane shows a cmd error, drop the branch and use
    # $filePrev alone — one less thing to go wrong.
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
Mark 'fzf env'

# --- the alias / function layer ---------------------------------
. (Join-Path $PSScriptRoot 'functions.ps1')
Mark 'functions.ps1'

# --- PSReadLine -------------------------------------------------
# Parity with zsh-autosuggestions (inline prediction) and
# zsh-syntax-highlighting (PSReadLine colours it natively — no module).
# Imported explicitly BEFORE PSFzf and carapace, both of which register key
# handlers on it.
Import-Module PSReadLine -ErrorAction SilentlyContinue
if (Get-Module PSReadLine) {
    $psrl = (Get-Module PSReadLine).Version

    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -BellStyle None

    # PredictionSource/View need PSReadLine 2.2+.
    if ($psrl -ge [version]'2.2.0') {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        Set-PSReadLineOption -PredictionViewStyle ListView
    }

    # Up/Down search history by the prefix already typed, which is what
    # zsh's history-substring-search does.
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}
Mark 'PSReadLine'

# --- Terminal-Icons ---------------------------------------------
# Icons in Get-ChildItem output. This is the counterpart of the decision NOT
# to alias ls to eza: native ls keeps returning objects, so pipelines still
# work, and this makes it readable anyway. Needs a Nerd Font, which is
# installed (Maple-Mono-NF).
Import-Module Terminal-Icons -ErrorAction SilentlyContinue
Mark 'Terminal-Icons'

# --- prompt: starship, Pure preset ------------------------------
# Same starship.toml as WSL — one file, no Windows fork. STARSHIP_CONFIG is
# set explicitly rather than relying on ~/.config, so the repo stays the
# single source of truth.
if ($StarshipBin) {
    $env:STARSHIP_CONFIG = Join-Path $PSScriptRoot 'starship.toml'
    Use-CachedInit -Name starship -Exe $StarshipBin -InitArgs @('init', 'powershell')
}
Mark 'starship init'

# --- zoxide -----------------------------------------------------
# Provides `z` and `zi`. Must come after the prompt init: zoxide hooks the
# prompt function to record directories, and starship replaces it.
if ($ZoxideBin) {
    Use-CachedInit -Name zoxide -Exe $ZoxideBin -InitArgs @('init', 'powershell')
}
Mark 'zoxide init'

# --- carapace: argument completion ------------------------------
# Completions for 1000+ commands. Without this, Tab does nothing useful for
# rg, fd, scoop or fzf.
#
# MenuComplete on Tab is required by carapace, not a preference: the default
# Complete function renders raw ANSI escapes instead of styled completions.
# It is set AFTER Set-PSReadLineOption -EditMode above, because EditMode
# resets key bindings and would undo it.
if ($CarapaceBin) {
    $env:CARAPACE_BRIDGES = 'zsh,fish,bash'
    Set-PSReadLineOption -Colors @{ 'Selection' = "`e[7m" }
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Use-CachedInit -Name carapace -Exe $CarapaceBin -InitArgs @('_carapace')
}
Mark 'carapace'

# --- atuin: shell history ---------------------------------------
# Takes Ctrl+R. This mirrors the Linux load order rule — atuin after fzf, so
# atuin keeps Ctrl+R — and it is why PSFzf below is told not to claim it.
# Local-only until `atuin login`; no sync, no account, nothing leaves the
# machine.
#
# ATUIN_POWERSHELL_PROMPT_OFFSET exists because the search UI is drawn
# relative to the prompt, and the Pure preset is two lines. If the prompt
# jumps when Ctrl+R opens, set it to 1 in profile.local.ps1.
if ($AtuinBin) {
    Use-CachedInit -Name atuin -Exe $AtuinBin -InitArgs @('init', 'powershell')
}
Mark 'atuin'

# --- PSFzf: Ctrl+T / Alt+C (and Ctrl+R only without atuin) -------
# Alt+C is bound by default. Ctrl+R is NOT — PSFzf refuses to take it from
# PSReadLine unless asked explicitly.
#
# -EnableAlias* is deliberately NOT used. PSFzf's optional aliases include
# `fd` (Invoke-FuzzySetLocation), which would shadow the fd binary, and
# `ff`, `fe`, `fkill`, which collide with the names in functions.ps1.
if ($FzfBin) {
    Import-Module PSFzf -ErrorAction SilentlyContinue
    if (Get-Module PSFzf) {
        if ($AtuinBin) {
            Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t'
        } else {
            Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' `
                            -PSReadlineChordReverseHistory 'Ctrl+r'
        }

        # PSFzf's own implementations, under the shell_common names.
        # Reusing them beats reimplementing: Invoke-PsFzfRipgrep already
        # handles the rg/fzf plumbing that broke `fif` on Linux.
        Set-Alias fe    Invoke-FuzzyEdit        -Force
        Set-Alias fkill Invoke-FuzzyKillProcess -Force
        if (Get-Command Invoke-PsFzfRipgrep -ErrorAction SilentlyContinue) {
            Set-Alias fif Invoke-PsFzfRipgrep -Force
        }
    }
}
Mark 'PSFzf'

# --- machine-local overrides ------------------------------------
# Loaded LAST so it can override anything above. This is the opposite of
# the zsh order, where .zshrc.local must precede syntax highlighting;
# PSReadLine colours are applied dynamically, so no such constraint exists.
$localProfile = Join-Path $PSScriptRoot 'profile.local.ps1'
if (Test-Path $localProfile) { . $localProfile }

# --- derived from the final FZF_DEFAULT_OPTS ---------------------
# Deliberately last. PSFzf reads this variable when a chord fires, not now,
# so assigning it here means profile.local.ps1 can still change
# FZF_DEFAULT_OPTS and have that reach the Ctrl+T / Alt+C preview.
if ($FzfPreviewCmd) {
    $env:_PSFZF_FZF_DEFAULT_OPTS = "$($env:FZF_DEFAULT_OPTS) --preview '$FzfPreviewCmd'"
}
Mark 'total'

# --- self-check --------------------------------------------------
# Structural control, not a reminder: a function silently loses to an alias
# of the same name in PowerShell's command precedence (Alias > Function >
# Cmdlet > Application). Without this, adding a colliding name later fails
# invisibly. Runs only when CLI_TOOLS_SELFCHECK is set, so shell start stays
# fast.
if ($env:CLI_TOOLS_SELFCHECK) { Test-CliToolsSetup }
