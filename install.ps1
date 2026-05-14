# sim-buddy Windows 一键安装脚本，用于 WorkBuddy / CodeBuddy。
#
# 在 WorkBuddy / CodeBuddy 聊天框，或任意 PowerShell 里运行：
#   irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1 | iex
#
# 这个脚本会：
#   1. 如果本机没有 uv，安装 uv (Astral Python toolchain manager)。
#   2. 安装带 COMSOL plugin 的全局 sim CLI 命令。
#   3. clone / refresh sim-buddy 到 ~/.workbuddy/plugins/marketplaces/sim-buddy。
#   4. 注册到 ~/.workbuddy/plugins/known_marketplaces.json (type=local)。
#   5. 提示用户重启 WorkBuddy / CodeBuddy，让 marketplace 生效。
#
# 可以重复运行：脚本会处理已有 junction / 目录，并刷新 marketplace。

# 不要全局设置 $ErrorActionPreference = "Stop"。
# PowerShell 5.1 会把 native command (uv, sim, git) 写到 stderr 的进度信息当成
# terminating error，导致脚本中途退出。这里改为每次 native command 后检查
# $LASTEXITCODE。
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
    Ok ("uv 已在 PATH 上 (" + (& uv --version 2>&1 | Out-String).Trim() + ")")
} else {
    Info "正在安装 uv..."
    irm https://astral.sh/uv/install.ps1 | iex
    $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Die "uv installer 已运行，但 PATH 上找不到 uv。请打开新的 PowerShell 窗口后重新运行本脚本。"
    }
    Ok ("uv installed: " + (& uv --version 2>&1 | Out-String).Trim())
}

# ----- 2. sim CLI + COMSOL plugin --------------------------------------
Step "2/4  sim CLI + COMSOL plugin"
Info "正在安装 / 更新带 sim-plugin-comsol 的 sim-cli-core..."
& uv tool install sim-cli-core --with sim-plugin-comsol --upgrade --force *>&1 | Out-String | Write-Host
NativeOrDie "uv tool install sim-cli-core --with sim-plugin-comsol"
$env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"

Info "检查 sim CLI ..."
& sim --version *>&1 | Out-String | Write-Host
NativeOrDie "sim --version"

Info "检查已注册的 sim plugins ..."
& sim plugin list *>&1 | Out-String | Write-Host
NativeOrDie "sim plugin list"

Info "检查 COMSOL plugin wiring ..."
& sim plugin doctor comsol *>&1 | Out-String | Write-Host
NativeOrDie "sim plugin doctor comsol"

Info "检查本机 COMSOL 安装 ..."
& sim check comsol *>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Ok "sim check comsol 通过，已检测到 COMSOL 安装"
} else {
    Warn "sim check comsol 返回 $LASTEXITCODE。plugin 已安装，但 COMSOL Multiphysics 本体可能未安装或当前进程无法访问。已保存 .mph 文件检查仍然可能可用。"
}

# ----- 3. clone sim-buddy into WorkBuddy marketplaces ------------------
Step "3/4  sim-buddy marketplace"
$mpDir = Join-Path $env:USERPROFILE ".workbuddy\plugins\marketplaces"
if (-not (Test-Path $mpDir)) {
    throw "未找到 WorkBuddy marketplace 目录 ($mpDir)。请先安装 WorkBuddy: https://copilot.tencent.com/work/ ，启动一次后再重新运行本脚本。"
}

$dst = Join-Path $mpDir "sim-buddy"

# 先停止 WorkBuddy，避免替换 marketplace 时文件被占用。
$wb = Get-Process -Name "WorkBuddy" -ErrorAction SilentlyContinue
if ($wb) {
    Info "正在停止 WorkBuddy，以便刷新 marketplace..."
    $wb | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# 移除已有安装。注意 junction / symlink，不要跟随到源目录。
if (Test-Path $dst) {
    $item = Get-Item $dst -Force
    if ($item.LinkType -eq "Junction" -or $item.LinkType -eq "SymbolicLink") {
        Info "正在移除已有 junction (保留源目录)..."
        cmd /c rmdir "$dst" 2>&1 | Out-Null
    } else {
        Info "正在移除已有安装 ..."
        Remove-Item $dst -Recurse -Force
    }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Die "PATH 上找不到 git。请安装 Git for Windows: https://git-scm.com/download/win"
}

Info "git clone https://github.com/svd-ai-lab/sim-buddy.git --> $dst"
& git clone --depth 1 https://github.com/svd-ai-lab/sim-buddy.git $dst *>&1 | Out-String | Write-Host
NativeOrDie "git clone"
Ok "已 clone"

# ----- 4. register in known_marketplaces.json --------------------------
Step "4/4  注册 marketplace 到 WorkBuddy"
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
Ok "已注册到 known_marketplaces.json"

# ----- done ------------------------------------------------------------
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host " sim-buddy installed." -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "下一步："
Write-Host "  1. 从 Start Menu 启动 WorkBuddy。"
Write-Host "  2. 在聊天框试试：'Inspect this .mph file and summarize its physics and parameters.'"
Write-Host "     WorkBuddy / CodeBuddy 会加载 sim-comsol skill 并调用 sim CLI。"
Write-Host ""
Write-Host "之后可以重复运行本脚本，从 GitHub 刷新 sim-buddy。"
Write-Host ""

# 即使上游 native command 往 stderr 写了无害进度，也强制 exit 0，避免
# PowerShell 5.1 的 "irm | iex" 调用者被误导。
exit 0
