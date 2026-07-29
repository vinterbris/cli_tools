#Requires -Version 7.0
# ─────────────────────────────────────────────────────────────
#  profile.ps1 — PowerShell 7 counterpart of zshrc + shell_common
#
#  Install: $PROFILE holds ONE line, written by bootstrap/install.ps1:
#      . "<repo>\dotfiles\profile.ps1"
#  No symlink — those need Developer Mode or admin on Windows, and the
#  repo lives on native C:, so the /mnt/c slowness that forced copies
#  inside WSL does not apply here.
#
#  Design rules carried over from shell_common:
#    - Core commands keep core behaviour. On Windows "core" includes the
#      cmdlet aliases: ls, cat, gc, gcm, gl, gp, h are NOT touched.
#    - Guarded everywhere. Every tool is wrapped in a resolve-or-skip, so
#      this file works on a bare machine and lights up as you install.
#    - Machine-local settings live in profile.local.ps1, untracked.
#
#  See dotfiles/README.md for load order and ../prd-powershell.md for the
#  full Linux→PowerShell portability audit.
# ─────────────────────────────────────────────────────────────

# --- startup timing ---------------------------------------------
# Set CLI_TOOLS_TIMING=1 to print cumulative milliseconds at each stage.
# Exists because "the profile feels slow" is not actionable and guessing at
# the cause is how you optimise the wrong line. Costs one Stopwatch when
# off, and Mark is a no-op.
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
# Get-CliBin and the $*Bin variables land in the session scope because this
# file is dot-sourced. functions.ps1 relies on that. Do not run this file as
# a script (`& profile.ps1`) — dot-source it.
function Get-CliBin {
    param([Parameter(Mandatory)][string]$Name)
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
Mark 'resolve binaries'

# --- editor -----------------------------------------------------
# micro, same as the Linux config: modern keybindings (Ctrl+S saves,
# Ctrl+Q quits), nothing modal to learn. notepad is the last resort so
# $env:EDITOR is never empty on a machine with no tools installed.
#
# nvim is deliberately NOT in this chain. The old profile aliased vim→nvim,
# but nvim is not installed and he does not use it — the alias was stale.
foreach ($e in 'micro', 'notepad') {
    if (Get-CliBin $e) { $env:EDITOR = $e; break }
}
$env:VISUAL = $env:EDITOR

# --- bat --------------------------------------------------------
# ansi theme = follow the terminal's own colours, same as Linux.
# No MANPAGER: Windows has no man pages, help is Get-Help.
if ($BatBin) {
    if (-not $env:BAT_THEME) { $env:BAT_THEME = 'ansi' }
}

# --- fzf environment --------------------------------------------
# PSFzf honours FZF_DEFAULT_COMMAND, FZF_CTRL_T_COMMAND and
# FZF_ALT_C_COMMAND (confirmed in the PSFzf README). It does NOT read
# FZF_CTRL_T_OPTS / FZF_ALT_C_OPTS — those are fzf's shell-integration
# variables and have no PowerShell equivalent. Per-widget preview options
# therefore go into _PSFZF_FZF_DEFAULT_OPTS, which PSFzf swaps in for the
# duration of its own calls, leaving a bare `fzf` invocation clean.
if ($FzfBin) {
    $env:FZF_DEFAULT_OPTS = '--height 60% --layout=reverse --border --info=inline'

    if ($FdBin) {
        $env:FZF_DEFAULT_COMMAND = "`"$FdBin`" -tf -HI --exclude .git"
        $env:FZF_CTRL_T_COMMAND  = $env:FZF_DEFAULT_COMMAND
        $env:FZF_ALT_C_COMMAND   = "`"$FdBin`" -td -H --exclude .git"
    }

    # Preview pane. Ctrl+T yields files and Alt+C yields directories, but the
    # options are shared between them, so the command has to branch.
    # `if exist "X\"` is the cmd.exe directory test — the trailing backslash
    # inside the quotes is what makes it directory-only.
    #
    # Quoting, in order from outside in:
    #   1. fzf splits FZF_DEFAULT_OPTS into words honouring quotes, so the
    #      whole preview command is wrapped in SINGLE quotes. Double quotes
    #      there would be closed by the first inner quote and the rest of the
    #      line would be parsed as separate options.
    #   2. On Windows fzf does NOT quote the {} substitution (fzf#1018), so
    #      each {} is wrapped in double quotes here by hand — otherwise any
    #      path containing a space breaks.
    #
    # UNVERIFIED end to end. If the preview pane shows a cmd error, drop the
    # branch and use $filePrev alone — one less thing to go wrong:
    #     $env:_PSFZF_FZF_DEFAULT_OPTS =
    #         "$($env:FZF_DEFAULT_OPTS) --preview '$filePrev'"
    if ($BatBin) {
        $filePrev = """$BatBin"" --color=always --style=numbers --line-range :200 ""{}"""
        $dirPrev  = if ($EzaBin) {
            """$EzaBin"" --tree --level=2 --icons=auto --color=always ""{}"""
        } else {
            'dir /b "{}"'
        }
        $preview = "if exist ""{}\"" ($dirPrev) else ($filePrev)"
        $env:_PSFZF_FZF_DEFAULT_OPTS = "$($env:FZF_DEFAULT_OPTS) --preview '$preview'"
    }
}

Mark 'fzf env'

# --- the alias / function layer ---------------------------------
. (Join-Path $PSScriptRoot 'functions.ps1')
Mark 'functions.ps1'

# --- PSReadLine -------------------------------------------------
# Parity with zsh-autosuggestions (inline prediction) and
# zsh-syntax-highlighting (PSReadLine colours it natively — no module).
# Imported explicitly BEFORE PSFzf, which registers key handlers on it.
Import-Module PSReadLine -ErrorAction SilentlyContinue
if (Get-Module PSReadLine) {
    $psrl = (Get-Module PSReadLine).Version

    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -BellStyle None

    # PredictionSource/View need PSReadLine 2.2+. PS 7.6 ships newer, but
    # a machine with an older module in PSModulePath would throw.
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

# --- prompt: starship, Pure preset ------------------------------
# Same starship.toml as WSL — one file, no Windows fork. STARSHIP_CONFIG is
# set explicitly rather than relying on ~/.config, so the repo stays the
# single source of truth.
#
# NOTE: the old profile initialised oh-my-posh (takuya theme). install.ps1
# backs that file up; oh-my-posh itself is left installed but uninitialised.
if ($StarshipBin) {
    $env:STARSHIP_CONFIG = Join-Path $PSScriptRoot 'starship.toml'
    Invoke-Expression (& $StarshipBin init powershell)
}
Mark 'starship init'

# --- zoxide -----------------------------------------------------
# Provides `z` and `zi`. Must come after the prompt init: zoxide hooks the
# prompt function to record directories, and starship replaces it.
if ($ZoxideBin) {
    Invoke-Expression (& { (& $ZoxideBin init powershell | Out-String) })
}
Mark 'zoxide init'

# --- PSFzf: Ctrl+T / Ctrl+R / Alt+C ------------------------------
# Alt+C is bound by default. Ctrl+R is NOT — PSFzf refuses to take it from
# PSReadLine unless asked explicitly (PSFzf README).
#
# -EnableAlias* is deliberately NOT used. PSFzf's optional aliases include
# `fd` (Invoke-FuzzySetLocation), which would shadow the fd binary, and
# `ff`, `fe`, `fkill`, which collide with the names below.
if ($FzfBin) {
    Import-Module PSFzf -ErrorAction SilentlyContinue
    if (Get-Module PSFzf) {
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' `
                        -PSReadlineChordReverseHistory 'Ctrl+r'

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

# --- machine-local overrides ------------------------------------
# Loaded LAST so it can override anything above. This is the opposite of
# the zsh order, where .zshrc.local must precede syntax highlighting;
# PSReadLine colours are applied dynamically, so no such constraint exists.
Mark 'PSFzf'

$localProfile = Join-Path $PSScriptRoot 'profile.local.ps1'
if (Test-Path $localProfile) { . $localProfile }
Mark 'total'

# --- self-check --------------------------------------------------
# Structural control, not a reminder: a function silently loses to an alias
# of the same name in PowerShell's command precedence (Alias > Function >
# Cmdlet > Application). Without this, adding a colliding name later fails
# invisibly. Runs only when CLI_TOOLS_SELFCHECK is set, so shell start stays
# fast; bootstrap/install.ps1 sets it for one verification run.
if ($env:CLI_TOOLS_SELFCHECK) { Test-CliToolsSetup }

