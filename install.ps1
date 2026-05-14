# sim-buddy one-shot installer for WorkBuddy / CodeBuddy on Windows.
#
# Usage from WorkBuddy / CodeBuddy chat, or any PowerShell:
#   irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1 | iex
#
# What it does:
#   1. Installs uv (Astral Python toolchain manager) if not present.
#   2. Installs the global sim CLI command with the COMSOL plugin available.
#   3. Clones / refreshes sim-buddy into ~/.workbuddy/plugins/marketplaces/sim-buddy.
#   4. Registers the marketplace in ~/.workbuddy/plugins/known_marketplaces.json (type=local).
#   5. Asks the user to restart WorkBuddy / CodeBuddy so the marketplace is picked up.
#
# Safe to re-run: detects existing junctions / directories and refreshes them
# without touching the upstream source.

# Do not use $ErrorActionPreference = "Stop" globally.
# PowerShell 5.1 treats every stderr line from native commands (uv, sim, git)
# as a terminating error under Stop, which kills the script mid-flight.
# Instead, check $LASTEXITCODE after each native command.
$ErrorActionPreference = "Continue"

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Info($msg) { Write-Host "    $msg" -ForegroundColor Gray }
function Ok($msg) { Write-Host "    OK: $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "    WARN: $msg" -ForegroundColor Yellow }
function Die($msg) { Write-Host "    FAIL: $msg" -ForegroundColor Red; exit 1 }
function NativeOrDie($what) { if ($LASTEXITCODE -ne 0) { Die "$what (exit $LASTEXITCODE)" } }

# ----- 1. uv ------------------------------------------------------------
Step "1/4  uv (Astral)"
if (Get-Command uv -ErrorAction SilentlyContinue) {
    Ok ("already on PATH (" + (& uv --version 2>&1 | Out-String).Trim() + ")")
} else {
    Info "installing uv..."
    irm https://astral.sh/uv/install.ps1 | iex
    $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Die "uv installer ran but uv was not found on PATH. Open a new PowerShell window and re-run this script."
    }
    Ok ("uv installed: " + (& uv --version 2>&1 | Out-String).Trim())
}

# ----- 2. sim CLI + COMSOL plugin --------------------------------------
Step "2/4  sim CLI + COMSOL plugin"
Info "installing/updating sim-cli-core with sim-plugin-comsol..."
& uv tool install sim-cli-core --with sim-plugin-comsol --upgrade --force *>&1 | Out-String | Write-Host
NativeOrDie "uv tool install sim-cli-core --with sim-plugin-comsol"
$env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"

Info "checking sim CLI ..."
& sim --version *>&1 | Out-String | Write-Host
NativeOrDie "sim --version"

Info "checking registered sim plugins ..."
& sim plugin list *>&1 | Out-String | Write-Host
NativeOrDie "sim plugin list"

Info "checking COMSOL plugin wiring ..."
& sim plugin doctor comsol *>&1 | Out-String | Write-Host
NativeOrDie "sim plugin doctor comsol"

Info "checking COMSOL detection ..."
& sim check comsol *>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Ok "sim check comsol passed (COMSOL installation detected)"
} else {
    Warn "sim check comsol returned $LASTEXITCODE. The plugin is installed, but COMSOL Multiphysics itself may be missing or unavailable. Saved .mph inspection can still be useful."
}

# ----- 3. clone sim-buddy into WorkBuddy marketplaces ------------------
Step "3/4  sim-buddy marketplace"
$mpDir = Join-Path $env:USERPROFILE ".workbuddy\plugins\marketplaces"
if (-not (Test-Path $mpDir)) {
    throw "WorkBuddy is not installed (no $mpDir). Install WorkBuddy from https://copilot.tencent.com/work/ first, launch it once, then re-run this script."
}

$dst = Join-Path $mpDir "sim-buddy"

# Stop WorkBuddy so the marketplace can be replaced cleanly.
$wb = Get-Process -Name "WorkBuddy" -ErrorAction SilentlyContinue
if ($wb) {
    Info "stopping WorkBuddy so the marketplace can be refreshed..."
    $wb | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# Remove an existing install. Be careful with junctions and do not follow them.
if (Test-Path $dst) {
    $item = Get-Item $dst -Force
    if ($item.LinkType -eq "Junction" -or $item.LinkType -eq "SymbolicLink") {
        Info "removing existing junction (source dir is preserved)..."
        cmd /c rmdir "$dst" 2>&1 | Out-Null
    } else {
        Info "removing existing install ..."
        Remove-Item $dst -Recurse -Force
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Die "git is required but not on PATH. Install Git for Windows: https://git-scm.com/download/win"
}

Info "git clone https://github.com/svd-ai-lab/sim-buddy.git --> $dst"
& git clone --depth 1 https://github.com/svd-ai-lab/sim-buddy.git $dst *>&1 | Out-String | Write-Host
NativeOrDie "git clone"
Ok "cloned"

# ----- 4. register in known_marketplaces.json --------------------------
Step "4/4  register marketplace with WorkBuddy"
$kmPath = Join-Path $env:USERPROFILE ".workbuddy\plugins\known_marketplaces.json"
$existing = if (Test-Path $kmPath) {
    [System.IO.File]::ReadAllText($kmPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
} else {
    [pscustomobject]@{}
}

$manifestPath = Join-Path $dst ".codebuddy-plugin\marketplace.json"
$mf = [System.IO.File]::ReadAllText($manifestPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json

$entry = [ordered]@{
    type = "local"
    source = [ordered]@{ source = "local"; path = $dst }
    installLocation = $dst
    isBuiltIn = $false
    autoUpdate = $false
    description = $mf.description
    lastUpdated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
    manifest = $mf
}

if ($existing.PSObject.Properties.Name -contains "sim-buddy") {
    $existing.PSObject.Properties.Remove("sim-buddy")
}
$existing | Add-Member -NotePropertyName "sim-buddy" -NotePropertyValue $entry -Force

$json = $existing | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($kmPath, $json, (New-Object System.Text.UTF8Encoding $false))
Ok "registered in known_marketplaces.json"

# ----- done ------------------------------------------------------------
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host " sim-buddy installed." -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next:"
Write-Host "  1. Start WorkBuddy from the Start Menu."
Write-Host "  2. In chat, try: 'Inspect this .mph file and summarize its physics and parameters.'"
Write-Host "     WorkBuddy / CodeBuddy will load the sim-comsol skill and call sim CLI."
Write-Host ""
Write-Host "Re-run this script any time to refresh sim-buddy from GitHub."
Write-Host ""

# Force exit 0 even if upstream native commands wrote benign progress to
# stderr. PowerShell 5.1 can otherwise propagate a non-zero exit code to
# "irm | iex" callers and confuse them.
exit 0
