# sim-buddy Windows 一键安装脚本,用于 WorkBuddy / CodeBuddy。
#
# 在 WorkBuddy / CodeBuddy 聊天框,或任意 PowerShell 里运行:
#   irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1 | iex
#
# 装多一个 Tier 2 solver (Fluent / MATLAB / Abaqus / HFSS / Mechanical / Simscale / Workbench):
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1))) -AddSolvers fluent
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1))) -AddSolvers fluent,matlab
#
# 这个脚本会:
#   1. 如果本机没有 uv,安装 uv (Astral Python toolchain manager)。
#   2. 装带 Tier 1 plugin (COMSOL + OpenFOAM + LTspice) 的全局 sim CLI 命令。
#      如果传了 -AddSolvers 或之前装过其他 Tier 2,一起装上 (matlab 等装包失败会软 fail)。
#   3. clone / refresh sim-buddy 到 ~/.workbuddy/plugins/marketplaces/sim-buddy。
#   4. 对每个装上的 sim-plugin-X (Tier 1 + Tier 2),junction
#      plugins/sim-X/skill/ 到包内的 _skills/X/ 目录;Tier 2 还会追加到 marketplace.json。
#   5. 注册到 ~/.workbuddy/plugins/known_marketplaces.json (type=local) 并提示重启 WorkBuddy。
#
# 可以重复运行:状态由 uv tool list 自动反推,不需要 state file。

param(
    [string[]] $AddSolvers = @()
)

# 不要全局设置 $ErrorActionPreference = "Stop"。
# PowerShell 5.1 会把 native command (uv, sim, git) 写到 stderr 的进度信息当成
# terminating error,导致脚本中途退出。这里改为每次 native command 后检查 $LASTEXITCODE。
$ErrorActionPreference = "Continue"

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Info($msg) { Write-Host "    $msg" -ForegroundColor Gray }
function Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "    WARN: $msg" -ForegroundColor Yellow }
function Die($msg)  { Write-Host "    FAIL: $msg" -ForegroundColor Red; exit 1 }
function NativeOrDie($what) { if ($LASTEXITCODE -ne 0) { Die "$what (exit $LASTEXITCODE)" } }

# Tier 1: 默认装,装包成功率高,即使没本机软件也有 fallback 用途
$TIER1 = @("comsol", "openfoam", "ltspice")

# Tier 2: 用户按需 enable,装包可能依赖本机商业软件 (matlab) 或拉重 SDK (ansys-*)
$TIER2_KNOWN = @("matlab", "abaqus", "fluent", "hfss", "mechanical", "simscale", "workbench")

# 规整化 -AddSolvers (支持逗号字符串和数组)
$requested = @()
foreach ($s in $AddSolvers) {
    foreach ($x in ($s -split ",")) {
        $x = $x.Trim().ToLower()
        if ($x) { $requested += $x }
    }
}
$requested = $requested | Sort-Object -Unique
$unknown = $requested | Where-Object { $_ -notin $TIER1 -and $_ -notin $TIER2_KNOWN }
if ($unknown) {
    Die ("-AddSolvers 里有未知 solver: " + ($unknown -join ",") +
         ". 已知 PyPI 上有的 plugin: " + (($TIER1 + $TIER2_KNOWN) -join ","))
}

# ----- 1. uv ------------------------------------------------------------
Step "1/5  uv (Astral)"
if (Get-Command uv -ErrorAction SilentlyContinue) {
    Ok ("uv 已在 PATH 上 (" + (& uv --version 2>&1 | Out-String).Trim() + ")")
} else {
    Info "正在安装 uv..."
    irm https://astral.sh/uv/install.ps1 | iex
    $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Die "uv installer 已运行,但 PATH 上找不到 uv。请打开新的 PowerShell 窗口后重新运行本脚本。"
    }
    Ok ("uv installed: " + (& uv --version 2>&1 | Out-String).Trim())
}

# ----- 2. sim CLI + plugins --------------------------------------------
# 探测 sim-cli-core 的 uv tool env 里装了哪些 sim-plugin-* (持久化 state = uv tool env)。
# 注意: `uv tool list` 不显示 --with 装的 extras,必须 Python 探测真正能 import 的包。
function Get-InstalledSimPlugins {
    param([string[]] $Candidates)
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) { return @() }
    # 首次安装时 sim-cli-core 还没装,跳过探测 (避免触发 uv ephemeral install ~30s)
    $list = (& uv tool list 2>&1 | Out-String)
    if ($list -notlike "*sim-cli-core*") { return @() }
    $probe = "import importlib.util,sys`nfor n in sys.argv[1].split(','):`n  if importlib.util.find_spec('sim_plugin_'+n): print(n)"
    $out = (& uv tool run --from sim-cli-core python -c $probe ($Candidates -join ",") 2>$null | Out-String).Trim()
    if (-not $out) { return @() }
    return ($out -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
$existing = Get-InstalledSimPlugins -Candidates ($TIER1 + $TIER2_KNOWN)
$tier2_target = (@() + $existing + $requested) | Sort-Object -Unique | Where-Object { $_ -in $TIER2_KNOWN }
$all_target = $TIER1 + $tier2_target | Sort-Object -Unique

Step ("2/5  sim CLI + plugins  [Tier1: $($TIER1 -join ',') | Tier2: " +
      ($(if ($tier2_target) { $tier2_target -join ',' } else { '(none)' })) + "]")

function Invoke-UvToolInstall {
    param([string[]] $Plugins)
    $withArgs = @()
    foreach ($p in $Plugins) { $withArgs += @("--with", "sim-plugin-$p") }
    Info ("uv tool install sim-cli-core " + ($withArgs -join " ") + " --upgrade --force")
    & uv tool install sim-cli-core @withArgs --upgrade --force *>&1 | Out-String | Write-Host
    return $LASTEXITCODE
}

# Try-all-at-once first (快路径)
$rc = Invoke-UvToolInstall -Plugins $all_target
if ($rc -ne 0) {
    Warn "全量装失败 (exit $rc),降级:先保证 Tier 1 atomic,再逐个加 Tier 2..."
    $rc = Invoke-UvToolInstall -Plugins $TIER1
    if ($rc -ne 0) { Die "Tier 1 装包失败 (exit $rc) — 网络问题?" }
    $installed_ok = @() + $TIER1
    foreach ($p in $tier2_target) {
        Info "试装 sim-plugin-$p ..."
        $rc = Invoke-UvToolInstall -Plugins ($installed_ok + @($p))
        if ($rc -eq 0) {
            $installed_ok += $p
            Ok "sim-plugin-$p 装上了"
        } else {
            Warn "sim-plugin-$p 装包失败 (exit $rc) — 常见原因: matlab 需本机装 MATLAB / ansys-* 网络拉包失败。跳过此 plugin。"
        }
    }
    $all_target = $installed_ok
}
$env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"

Info "检查 sim CLI ..."
& sim --version *>&1 | Out-String | Write-Host
NativeOrDie "sim --version"

Info "检查已注册的 sim plugins ..."
& sim plugin list *>&1 | Out-String | Write-Host
NativeOrDie "sim plugin list"

# ----- 3. clone sim-buddy into WorkBuddy marketplaces ------------------
Step "3/5  sim-buddy marketplace"
$mpDir = Join-Path $env:USERPROFILE ".workbuddy\plugins\marketplaces"
if (-not (Test-Path $mpDir)) {
    throw "未找到 WorkBuddy marketplace 目录 ($mpDir)。请先安装 WorkBuddy: https://copilot.tencent.com/work/ ,启动一次后再重新运行本脚本。"
}

$dst = Join-Path $mpDir "sim-buddy"

# 先停止 WorkBuddy,避免替换 marketplace 时文件被占用。
$wb = Get-Process -Name "WorkBuddy" -ErrorAction SilentlyContinue
if ($wb) {
    Info "正在停止 WorkBuddy,以便刷新 marketplace..."
    $wb | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# 移除已有安装。注意 junction / symlink,不要跟随到源目录。
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

# ----- 4. junction + marketplace 追加 ----------------------------------
# 对每个装上的 sim-plugin-X (Tier 1 + Tier 2),如果 sim-buddy 仓里有 plugin.json
# 壳子,就 junction plugins/sim-X/skill -> 包里的 _skills/X/。
# Tier 2 plugin 还会追加到 marketplace.json (Tier 1 + sim-installer 已在 baseline)。
Step "4/5  junction SKILL bundle + 注册 plugin"

# 一次 python call 探测全部装上的 plugin 路径
$probeScript = @'
import importlib, pathlib, sys
names = sys.argv[1].split(',') if len(sys.argv) > 1 else []
for n in names:
    try:
        m = importlib.import_module('sim_plugin_' + n)
        p = pathlib.Path(m.__file__).parent / '_skills' / n
        if p.exists():
            print(n + '|' + str(p))
    except Exception:
        pass
'@
$probePath = Join-Path $env:TEMP "sim-buddy-probe.py"
Set-Content -Path $probePath -Value $probeScript -Encoding UTF8
$probeArgs = ($TIER1 + $TIER2_KNOWN) -join ","
$probeResult = (& uv tool run --from sim-cli-core python $probePath $probeArgs 2>&1 | Out-String).Trim()
Remove-Item $probePath -ErrorAction SilentlyContinue

$pluginMap = @{}  # name -> _skills/<name> path
foreach ($line in ($probeResult -split "`n")) {
    $line = $line.Trim()
    if ($line -match '^([a-z]+)\|(.+)$') {
        $pluginMap[$matches[1]] = $matches[2]
    }
}
Info ("uv tool env 里检测到 sim-plugin-* 的 _skills: " + ($pluginMap.Keys -join ","))

# 读 baseline marketplace.json (刚 git clone 下来的)
$mpJsonPath = Join-Path $dst ".codebuddy-plugin\marketplace.json"
$mpJson = [System.IO.File]::ReadAllText($mpJsonPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$baselineNames = @($mpJson.plugins | ForEach-Object { $_.name })

$junctioned = @()
foreach ($p in $pluginMap.Keys) {
    $skillSrc = $pluginMap[$p]
    $shellDir = Join-Path $dst "plugins\sim-$p"
    $shellPluginJson = Join-Path $shellDir ".codebuddy-plugin\plugin.json"
    if (-not (Test-Path $shellPluginJson)) {
        Warn "sim-plugin-$p 已装,但 sim-buddy 仓里没 plugin.json 壳。跳过 (新 plugin 需要 PR 加壳到 sim-buddy)。"
        continue
    }
    $skillDst = Join-Path $shellDir "skill"
    # 清理已有 junction / 目录
    if (Test-Path $skillDst) {
        $sItem = Get-Item $skillDst -Force
        if ($sItem.LinkType -eq "Junction" -or $sItem.LinkType -eq "SymbolicLink") {
            cmd /c rmdir "$skillDst" 2>&1 | Out-Null
        } else {
            Remove-Item $skillDst -Recurse -Force
        }
    }
    cmd /c mklink /J "$skillDst" "$skillSrc" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Warn "mklink /J 给 sim-$p 失败,跳过"
        continue
    }

    # 校验 plugin.json skills 字段指向的 SKILL.md 真的存在
    $pjShell = Get-Content $shellPluginJson -Raw -Encoding UTF8 | ConvertFrom-Json
    $skillFile = Join-Path $shellDir ($pjShell.skills[0] -replace '^\./','' -replace '/','\')
    if (-not (Test-Path $skillFile)) {
        Warn "sim-$p junction 完成但 $skillFile 不存在(包里没那个 SKILL 文件?)。跳过该 plugin 的 marketplace 注册。"
        cmd /c rmdir "$skillDst" 2>&1 | Out-Null
        continue
    }
    $junctioned += "sim-$p"

    # 追加到 marketplace.json (如果不在 baseline)
    if ("sim-$p" -notin $baselineNames) {
        $entry = [ordered]@{
            name        = "sim-$p"
            description = $pjShell.description
            source      = "./plugins/sim-$p"
            version     = $pjShell.version
            category    = "engineering"
            author      = @{ name = "SVD AI Lab" }
            homepage    = "https://github.com/svd-ai-lab/sim-buddy"
            license     = "Apache-2.0"
            skills      = @("./plugins/sim-$p")
        }
        $mpJson.plugins = @($mpJson.plugins) + $entry
        Info "marketplace.json 追加: sim-$p"
    }
}

# 写回 marketplace.json
$mpOut = $mpJson | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($mpJsonPath, $mpOut, (New-Object System.Text.UTF8Encoding $false))
Ok ("junction 了 " + $junctioned.Count + " 个 plugin: " + ($junctioned -join ","))

# ----- 5. register in known_marketplaces.json --------------------------
Step "5/5  注册 marketplace 到 WorkBuddy"
$kmPath = Join-Path $env:USERPROFILE ".workbuddy\plugins\known_marketplaces.json"
$existing_km = if (Test-Path $kmPath) {
    [System.IO.File]::ReadAllText($kmPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
} else {
    [pscustomobject]@{}
}

# 重读 marketplace.json (已经被 step 4 mutate)
$mf = [System.IO.File]::ReadAllText($mpJsonPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json

$entry = [ordered]@{
    type            = "local"
    source          = [ordered]@{ source = "local"; path = $dst }
    installLocation = $dst
    isBuiltIn       = $false
    autoUpdate      = $false
    description     = $mf.description
    lastUpdated     = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
    manifest        = $mf
}

if ($existing_km.PSObject.Properties.Name -contains "sim-buddy") {
    $existing_km.PSObject.Properties.Remove("sim-buddy")
}
$existing_km | Add-Member -NotePropertyName "sim-buddy" -NotePropertyValue $entry -Force

$kmOut = $existing_km | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($kmPath, $kmOut, (New-Object System.Text.UTF8Encoding $false))
Ok "已注册到 known_marketplaces.json"

# ----- done ------------------------------------------------------------
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host (" sim-buddy installed. (" + $junctioned.Count + " plugin(s) loaded)") -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "下一步:"
Write-Host "  1. 从 Start Menu 启动 WorkBuddy。"
Write-Host "  2. 在聊天框试试: 'Inspect this .mph file and summarize its physics and parameters.'"
Write-Host "     WorkBuddy / CodeBuddy 会加载对应 plugin 的 SKILL 并调用 sim CLI。"
Write-Host ""
Write-Host "扩展更多 solver (装 Fluent / MATLAB / Abaqus / 等):"
Write-Host "  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/svd-ai-lab/sim-buddy/main/install.ps1))) -AddSolvers fluent"
Write-Host ""

# 即使上游 native command 往 stderr 写了无害进度,也强制 exit 0,避免
# PowerShell 5.1 的 "irm | iex" 调用者被误导。
exit 0
