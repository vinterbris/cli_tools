#Requires -Version 7.0
<#
.SYNOPSIS
    Sets up the cli_tools environment for PowerShell 7 on Windows.

.DESCRIPTION
    Counterpart of bootstrap/install.sh. Installs the tool set with Scoop,
    installs the PSFzf module, and points $PROFILE at dotfiles/profile.ps1.

    Idempotent: Scoop skips what is already installed, and the profile stub
    is only rewritten when its content differs.

    Nothing is ever deleted. An existing $PROFILE is copied to
    <profile>.bak-<timestamp> before being replaced.

.PARAMETER DryRun
    Print every action without performing it. Run this first.

.PARAMETER SkipTools
    Only wire up the profile; install no packages.

.PARAMETER SkipProfile
    Only install packages; leave $PROFILE alone.

.EXAMPLE
    .\bootstrap\install.ps1 -DryRun
    .\bootstrap\install.ps1

.NOTES
    Scoop is required and is NOT installed automatically — bootstrapping a
    package manager by piping a remote script is a decision to make
    deliberately, not a side effect of running an installer. The command is
    printed if Scoop is missing.
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipTools,
    [switch]$SkipProfile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot    = Split-Path -Parent $PSScriptRoot
$DotfilesDir = Join-Path $RepoRoot 'dotfiles'
$ProfileSrc  = Join-Path $DotfilesDir 'profile.ps1'

$script:Failures = [System.Collections.Generic.List[string]]::new()

function Say  { param($m) Write-Host $m }
function Step { param($m) Write-Host "==> $m" -ForegroundColor Cyan }
function Warn { param($m) Write-Host "  ! $m" -ForegroundColor Yellow }
function Ok   { param($m) Write-Host "  + $m" -ForegroundColor Green }
function Act  { param($m) if ($DryRun) { Write-Host "  [dry-run] $m" -ForegroundColor DarkGray } }

# ── preflight ───────────────────────────────────────────────────
Step "Preflight"

if (-not (Test-Path $ProfileSrc)) {
    throw "profile.ps1 not found at $ProfileSrc — run this script from inside the repo."
}
Ok "repo: $RepoRoot"
Ok "PowerShell $($PSVersionTable.PSVersion)"

$scoop = Get-Command scoop -ErrorAction SilentlyContinue
if (-not $scoop -and -not $SkipTools) {
    Warn "Scoop not found. Install it first, then re-run:"
    Say  ""
    Say  "    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
    Say  "    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression"
    Say  ""
    throw "Scoop is required (or pass -SkipTools)."
}

# ── tools ───────────────────────────────────────────────────────
# Grouped by why they are here, not alphabetically. `main` and `extras` are
# the only buckets used.
#
# Version floor worth knowing: the config wants fzf >= 0.48 for the modern
# flags. Scoop main carries 0.74+, so unlike Pop!_OS there is no fallback
# path to maintain here.
$Buckets = @('main', 'extras')

$Tools = [ordered]@{
    # the three this port exists for
    'fzf'      = 'core'
    'zoxide'   = 'core'
    'starship' = 'core'
    # everything the profile lights up when present
    'bat'      = 'quality'
    'fd'       = 'quality'
    'ripgrep'  = 'quality'
    'eza'      = 'quality'
    'jq'       = 'quality'
    'dust'     = 'quality'
    'duf'      = 'quality'
    'procs'    = 'quality'
    'bottom'   = 'quality'   # btm — the cross-platform btop replacement
    'xh'       = 'quality'
    'lazygit'  = 'quality'
    'yazi'     = 'quality'
    'micro'    = 'quality'
    'tealdeer' = 'quality'   # tldr
}
# NOT in the list, and why:
#   delta  — it is a git pager, configured through .gitconfig. git runs from
#            WSL on this machine, where install.sh already handles it. On
#            Windows it would be an installed binary nothing ever calls.
#   git    — same reason. Its absence here is intentional, not a gap.

if (-not $SkipTools) {
    # Scoop's own state is read from its directory layout, not from parsing
    # `scoop list` / `scoop bucket list`.
    #
    # WHY: the first version of this script parsed that output, and the dry
    # run proved it does not work — `scoop list` prints its "Installed apps:"
    # header through the host stream and the table through the output stream,
    # so a text match silently found nothing and every tool was reported as
    # "would install". A check that fails by saying "no" is worse than no
    # check. The apps/ and buckets/ directories are what Scoop actually
    # keys on, and Test-Path cannot half-succeed.
    $ScoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $HOME 'scoop' }
    Ok "scoop root: $ScoopRoot"

    # Success is judged by the POST-CONDITION, not by whether the command
    # threw. A native command that fails writes to stderr and sets
    # $LASTEXITCODE rather than raising a catchable error, and `scoop` may
    # resolve to a .ps1 shim, where even $LASTEXITCODE is unreliable. A
    # try/catch alone would make every "installed" line decorative. The
    # directory either exists afterwards or it does not.
    Step "Scoop buckets"
    foreach ($b in $Buckets) {
        $bucketPath = Join-Path $ScoopRoot "buckets\$b"
        if (Test-Path $bucketPath) { Ok "$b already added"; continue }
        if ($DryRun) { Act "scoop bucket add $b"; continue }
        try { & scoop bucket add $b | Out-Null } catch { Write-Verbose $_.Exception.Message }
        if (Test-Path $bucketPath) { Ok "added $b" }
        else { Warn "bucket $b failed"; $script:Failures.Add("bucket:$b") }
    }

    Step "Tools"
    # No pre-flight `scoop search` either: whether a manifest exists at all is
    # settled by attempting the install and recording the failure, which is
    # simpler and authoritative.
    foreach ($t in $Tools.Keys) {
        $appPath = Join-Path $ScoopRoot "apps\$t"
        if (Test-Path $appPath) { Ok "$t already installed"; continue }
        if ($DryRun) { Act "scoop install $t   ($($Tools[$t]))"; continue }
        try { & scoop install $t | Out-Null } catch { Write-Verbose $_.Exception.Message }
        if (Test-Path $appPath) { Ok "installed $t" }
        else { Warn "$t failed"; $script:Failures.Add("tool:$t") }
    }

    Step "PSFzf module"
    # From the PowerShell Gallery rather than the Scoop extras bucket, so
    # Update-Module works and the module lands in the normal module path.
    if (Get-Module PSFzf -ListAvailable) {
        Ok "PSFzf already available"
    } elseif ($DryRun) {
        Act "Install-Module PSFzf -Scope CurrentUser"
    } else {
        try {
            Install-Module PSFzf -Scope CurrentUser -Force -AllowClobber
            Ok "installed PSFzf"
        } catch {
            Warn "PSFzf failed: $($_.Exception.Message)"
            $script:Failures.Add('module:PSFzf')
        }
    }
}

# ── profile stub ────────────────────────────────────────────────
# One line, not a symlink: New-Item -ItemType SymbolicLink needs Developer
# Mode or an elevated shell, and a stub is inspectable with `cat $PROFILE`.
if (-not $SkipProfile) {
    Step "Profile"

    $stub = @"
# Generated by cli_tools/bootstrap/install.ps1
# Everything lives in the repo; edit there, not here.
. "$ProfileSrc"
"@

    $profileDir = Split-Path -Parent $PROFILE
    Ok "`$PROFILE = $PROFILE"

    if (-not (Test-Path $profileDir)) {
        if ($DryRun) { Act "mkdir $profileDir" }
        else { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null; Ok "created $profileDir" }
    }

    # Get-Content -Raw returns $null for a zero-byte file, and under
    # Set-StrictMode calling .Trim() on $null throws.
    $current = if (Test-Path $PROFILE) { Get-Content -Raw -LiteralPath $PROFILE } else { '' }
    if (-not $current) { $current = '' }

    if ($current.Trim() -eq $stub.Trim()) {
        Ok "already points at the repo — nothing to do"
    } else {
        if ($current.Trim()) {
            $backup = "$PROFILE.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
            Warn "existing profile will be replaced. Backup: $backup"
            if ($current -match 'oh-my-posh') {
                Warn "the old profile initialises oh-my-posh. starship replaces it."
                Warn "oh-my-posh is a prompt binary, not a framework — but two prompt engines means two configs. Consider: scoop uninstall oh-my-posh"
            }
            if ($DryRun) { Act "copy `$PROFILE -> $backup" }
            else { Copy-Item -LiteralPath $PROFILE -Destination $backup; Ok "backed up" }
        }
        if ($DryRun) { Act "write stub to `$PROFILE:`n$stub" }
        else { Set-Content -LiteralPath $PROFILE -Value $stub -Encoding utf8; Ok "wrote stub" }
    }
}

# ── report ──────────────────────────────────────────────────────
Step "Result"
if ($script:Failures.Count) {
    Warn "failed: $($script:Failures -join ', ')"
    Say  "Re-run to retry, or install those by hand."
} else {
    Ok "no failures"
}

if ($DryRun) {
    Say ""
    Say "Dry run only. Nothing was changed. Re-run without -DryRun to apply."
} else {
    Say ""
    Say "Next:"
    Say "  1. Start a new pwsh session."
    Say "  2. `$env:CLI_TOOLS_SELFCHECK=1; pwsh -NoLogo   # reports shadowed names and missing tools"
    Say "  3. Measure-Command { pwsh -NoLogo -Command exit }   # target: under 400 ms"
    Say "  4. Try: Ctrl+T, Ctrl+R, Alt+C, z, cs, ll, tp"
}
