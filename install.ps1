# sim-buddy one-shot installer for WorkBuddy on Windows.
#
# Usage from WorkBuddy chat (or any PowerShell):
#   irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1 | iex
#
# What it does:
#   1. Installs uv (Astral Python toolchain manager) if not present.
#   2. Installs sim CLI core + the COMSOL driver as uv tools.
#   3. Clones / refreshes sim-buddy into ~/.workbuddy/plugins/marketplaces/sim-buddy.
#   4. Registers the marketplace in ~/.workbuddy/plugins/known_marketplaces.json (type=local).
#   5. Asks the user to restart WorkBuddy so the new marketplace is picked up.
#
# Safe to re-run: detects existing junctions / directories and refreshes them
# without touching the upstream source.

$ErrorActionPreference = "Stop"

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Info($msg) { Write-Host "    $msg" -ForegroundColor Gray }
function Ok($msg) { Write-Host "    OK: $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "    WARN: $msg" -ForegroundColor Yellow }

# ----- 1. uv ------------------------------------------------------------
Step "1/4  uv (Astral)"
if (Get-Command uv -ErrorAction SilentlyContinue) {
    Ok "already on PATH ($(uv --version))"
} else {
    Info "installing uv..."
    irm https://astral.sh/uv/install.ps1 | iex
    $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        throw "uv install ran but uv not found on PATH. Open a new PowerShell and re-run this script."
    }
    Ok "uv $(uv --version) installed"
}

# ----- 2. sim CLI + COMSOL driver --------------------------------------
Step "2/4  sim CLI + COMSOL driver"
if (Get-Command sim -ErrorAction SilentlyContinue) {
    Ok "sim already on PATH ($(sim --version 2>&1 | Select-Object -First 1))"
} else {
    Info "uv tool install sim-cli-core ..."
    uv tool install sim-cli-core
    $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
    Ok "sim CLI installed"
}

Info "uv tool install sim-plugin-comsol ..."
uv tool install sim-plugin-comsol --force 2>$null
# sim plugin install delegates to pip; either path works:
& sim plugin install sim-plugin-comsol 2>$null | Out-Null
Ok "sim COMSOL driver installed"

Info "checking COMSOL detection ..."
$check = & sim check comsol 2>&1
if ($LASTEXITCODE -eq 0) {
    Ok "sim check comsol passed"
} else {
    Warn "sim check comsol returned $LASTEXITCODE -- driver is installed, but COMSOL Multiphysics itself may be missing on this host. Offline .mph inspection still works."
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
    Info "stopping WorkBuddy (will restart after install)..."
    $wb | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# Remove existing install -- be careful with junctions, do not follow them.
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
    throw "git is required but not on PATH. Install Git for Windows: https://git-scm.com/download/win"
}

Info "git clone https://github.com/svd-ai-lab/sim-buddy.git --> $dst"
git clone --depth 1 https://github.com/svd-ai-lab/sim-buddy.git $dst | Out-Null
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
Write-Host "  1. Start WorkBuddy:    & 'E:\Program Files\WorkBuddy\WorkBuddy.exe'  (or from Start Menu)"
Write-Host "  2. In the chat, try:   '我有一个 .mph 文件,你帮我看看里面用了什么物理场'"
Write-Host "     WorkBuddy will load the sim-comsol skill and shell out to sim CLI."
Write-Host ""
Write-Host "Re-run this script any time to refresh sim-buddy from GitHub."
Write-Host ""
