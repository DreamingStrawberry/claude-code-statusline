# cc-statusbar - Claude Code Status Bar (PowerShell)
# https://github.com/DreamingStrawberry/claude-code-statusline

$input = $input | Out-String
if (-not $input) { $input = [Console]::In.ReadToEnd() }

# ===================================================
# Config
# ===================================================
$SHOW_MODEL=$true; $SHOW_PATH=$true; $SHOW_GIT_BRANCH=$true; $SHOW_CONTEXT=$true
$SHOW_5H_LIMIT=$true; $SHOW_7D_LIMIT=$true; $SHOW_COST=$false; $SHOW_COMMANDS=$true
$LANGUAGE="en"; $BAR_STYLE="blocks"; $BAR_WIDTH=10; $BAR_FILL="▓"; $BAR_EMPTY="░"

$confPath = Join-Path $env:USERPROFILE ".claude\statusline.conf"
if (-not (Test-Path $confPath)) { $confPath = Join-Path $HOME ".claude\statusline.conf" }
if (Test-Path $confPath) {
    foreach ($line in Get-Content $confPath) {
        if ($line -match '^(\w+)=(.*)$') {
            $k = $Matches[1]; $v = $Matches[2].Trim('"', "'")
            switch ($k) {
                'SHOW_MODEL'      { $SHOW_MODEL = $v -eq 'true' }
                'SHOW_PATH'       { $SHOW_PATH = $v -eq 'true' }
                'SHOW_GIT_BRANCH' { $SHOW_GIT_BRANCH = $v -eq 'true' }
                'SHOW_CONTEXT'    { $SHOW_CONTEXT = $v -eq 'true' }
                'SHOW_5H_LIMIT'   { $SHOW_5H_LIMIT = $v -eq 'true' }
                'SHOW_7D_LIMIT'   { $SHOW_7D_LIMIT = $v -eq 'true' }
                'SHOW_COST'       { $SHOW_COST = $v -eq 'true' }
                'SHOW_COMMANDS'   { $SHOW_COMMANDS = $v -eq 'true' }
                'LANGUAGE'        { $LANGUAGE = $v }
                'BAR_STYLE'       { $BAR_STYLE = $v }
                'BAR_WIDTH'       { $BAR_WIDTH = [int]$v }
                'BAR_FILL'        { $BAR_FILL = $v }
                'BAR_EMPTY'       { $BAR_EMPTY = $v }
            }
        }
    }
}

# ===================================================
# Parse JSON
# ===================================================
try { $json = $input | ConvertFrom-Json } catch { $json = $null }
if (-not $json) { exit }

$model = $json.model.display_name
$cwd = $json.workspace.current_dir; if (-not $cwd) { $cwd = $json.cwd }
$exceeds200k = $json.exceeds_200k_tokens
$usedPct = [int]($json.context_window.used_percentage)
$ctxSize = [int]($json.context_window.context_window_size)
$fiveHPct = [int]($json.rate_limits.five_hour.used_percentage)
$fiveHReset = [int]($json.rate_limits.five_hour.resets_at)
$sevenDPct = [int]($json.rate_limits.seven_day.used_percentage)
$sevenDReset = [int]($json.rate_limits.seven_day.resets_at)
$totalCost = $json.cost.total_cost_usd

# ===================================================
# ANSI colors
# ===================================================
$R = "`e[0m"; $B = "`e[1m"; $D = "`e[2m"; $BK = "`e[5m"
$CY = "`e[36m"; $GN = "`e[32m"; $YL = "`e[33m"; $RD = "`e[31m"
$GR = "`e[90m"; $MG = "`e[35m"; $BL = "`e[34m"; $OR = "`e[38;5;208m"

function Get-PctColor([int]$p) {
    if ($p -ge 80) { return $RD }
    if ($p -ge 50) { return $YL }
    return $GN
}

# ===================================================
# Bar
# ===================================================
$STYLES = @{
    blocks    = @{ fill = $BAR_FILL; empty = $BAR_EMPTY }
    dots      = @{ fill = "●"; empty = "○" }
    squares   = @{ fill = "■"; empty = "□" }
    lines     = @{ fill = "━"; empty = "─" }
    triangles = @{ fill = "▰"; empty = "▱" }
    ascii     = @{ fill = "#"; empty = "." }
}

function Make-Bar([int]$pct) {
    $s = $STYLES[$BAR_STYLE]; if (-not $s) { $s = $STYLES['blocks'] }
    $n = [Math]::Round($pct * $BAR_WIDTH / 100); if ($n -gt $BAR_WIDTH) { $n = $BAR_WIDTH }
    $m = $BAR_WIDTH - $n
    return ($s.fill * $n) + ($s.empty * $m)
}

function Format-Time([int]$sec, [string]$fmt) {
    if ($sec -le 0) { return "now" }
    if ($fmt -eq "hm") { return "{0}h {1}m" -f [Math]::Floor($sec/3600), [Math]::Floor($sec%3600/60) }
    return "{0}d {1}h {2}m" -f [Math]::Floor($sec/86400), [Math]::Floor($sec%86400/3600), [Math]::Floor($sec%3600/60)
}

# ===================================================
# Language
# ===================================================
switch ($LANGUAGE) {
    'ko' { $L = @{ ctx="컨텍스트"; h5="5시간"; d7="7일"; svc="서비스"; set="설정" } }
    'ja' { $L = @{ ctx="ctx"; h5="5h"; d7="7d"; svc="svc"; set="設定" } }
    'zh' { $L = @{ ctx="上下文"; h5="5小时"; d7="7天"; svc="服务"; set="设置" } }
    default { $L = @{ ctx="ctx"; h5="5h"; d7="7d"; svc="svc"; set="settings" } }
}

# ===================================================
# Git branch
# ===================================================
$gitBranch = ""
if ($SHOW_GIT_BRANCH -and $cwd -and (Get-Command git -ErrorAction SilentlyContinue)) {
    $gitBranch = git -C $cwd branch --show-current 2>$null
}
$shortPath = ($cwd -replace '\\','/') -replace '^.*/([^/]+/[^/]+)$','$1'

# ===================================================
# Line 1
# ===================================================
$out = ""
$sep = ""

if ($SHOW_MODEL) {
    $out += "${CY}${B}${model}${R}"
    if ($exceeds200k) { $out += " ${GN}thinking:on${R}" } else { $out += " ${GR}thinking:off${R}" }
    $sep = " ${GR}|${R} "
}
if ($SHOW_PATH) {
    $out += "${sep}${BL}${shortPath}${R}"
    if ($gitBranch) { $out += "${GR}@${R}${MG}${gitBranch}${R}" }
    $sep = " ${GR}|${R} "
}
if ($SHOW_CONTEXT) {
    $cc = Get-PctColor $usedPct
    $ctxLeft = $ctxSize - [Math]::Floor($ctxSize * $usedPct / 100)
    $ctxLeftFmt = if ($ctxLeft -ge 1000000) { "{0}.{1}M" -f [Math]::Floor($ctxLeft/1000000), [Math]::Floor($ctxLeft%1000000/100000) } elseif ($ctxLeft -ge 1000) { "{0}k" -f [Math]::Floor($ctxLeft/1000) } else { "$ctxLeft" }
    $ctxTotalFmt = if ($ctxSize -ge 1000000) { "{0}.{1}M" -f [Math]::Floor($ctxSize/1000000), [Math]::Floor($ctxSize%1000000/100000) } else { "{0}k" -f [Math]::Floor($ctxSize/1000) }
    $out += "${sep}$($L.ctx) ${cc}$(Make-Bar $usedPct)${R} ${cc}${usedPct}%${R} ${GR}${ctxLeftFmt}/${ctxTotalFmt}${R}"
    $sep = " ${GR}|${R} "
}
if ($SHOW_5H_LIMIT) {
    $fc = Get-PctColor $fiveHPct
    $out += "${sep}$($L.h5) ${fc}$(Make-Bar $fiveHPct)${R} ${fc}${fiveHPct}%${R}"
    if ($fiveHReset -gt 0) {
        $d5 = $fiveHReset - [int](Get-Date -UFormat %s)
        $out += " ${GR}$(Format-Time $d5 'hm')${R}"
    }
    $sep = " ${GR}|${R} "
}
if ($SHOW_7D_LIMIT) {
    $sc = Get-PctColor $sevenDPct
    $out += "${sep}$($L.d7) ${sc}$(Make-Bar $sevenDPct)${R} ${sc}${sevenDPct}%${R}"
    if ($sevenDReset -gt 0) {
        $d7 = $sevenDReset - [int](Get-Date -UFormat %s)
        $out += " ${GR}$(Format-Time $d7 'dhm')${R}"
    }
    $sep = " ${GR}|${R} "
}
if ($SHOW_COST -and $totalCost -and $totalCost -ne 0) {
    $out += "${sep}${GR}`$${totalCost:F2}${R}"
    $sep = " ${GR}|${R} "
}
if ($SHOW_COMMANDS) {
    $out += "${sep}${D}${GR}$($L.set): npx cc-statusbar${R}"
}

Write-Host $out

# ===================================================
# Line 2: DevLauncher (native PowerShell, fast)
# ===================================================
$dlPath = Join-Path $env:USERPROFILE "DevLauncher.ps1"
if (-not (Test-Path $dlPath)) { exit }

$cache = Join-Path $env:TEMP ".devlauncher-status-cache"
$now = [int](Get-Date -UFormat %s)
$needRefresh = $true

if (Test-Path $cache) {
    $lines = Get-Content $cache
    if ($lines.Count -gt 0) {
        $cachedAt = [int]$lines[0]
        if (($now - $cachedAt) -lt 10) { $needRefresh = $false }
    }
}

if ($needRefresh) {
    Start-Job -ScriptBlock {
        param($dlp, $cp)
        $r = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $dlp status 2>$null
        @([int](Get-Date -UFormat %s)) + $r | Set-Content $cp
    } -ArgumentList $dlPath, $cache | Out-Null
}

if (Test-Path $cache) {
    $raw = (Get-Content $cache | Select-Object -Skip 1) -join "`n"
    $frames = @("⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠇")
    $spin = $frames[[int](Get-Date -UFormat %s) % 8]
    $parts = ""
    foreach ($line in ($raw -split "`n")) {
        if (-not $line.Trim()) { continue }
        $fields = $line -split '\s+'
        $nm = $fields[1]; $pt = $fields[3]; $st = $fields[4]
        switch ($st) {
            'Running'  { $parts += " ${GN}${B}${nm}${pt}${R}${GN}●${R}" }
            'Starting' { $parts += " ${YL}${B}${nm}${pt}${spin}${R}" }
            'Error'    { $parts += " ${BK}${RD}${B}${nm}${pt}✖${R}" }
            default    { $parts += " ${GR}${nm}${pt}●${R}" }
        }
    }
    if ($parts) { Write-Host "${GR}$($L.svc)${R}$parts" }
}
