## Release Gate：第一章正式版测试入口
## 退出码 0 代表 Godot 导入、烟雾测试和日志门全部通过
## 用法: pwsh -ExecutionPolicy Bypass -File tests/run_release_gate.ps1
##       powershell -ExecutionPolicy Bypass -File tests/run_release_gate.ps1
param(
    [string]$GodotExe = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'
)

$projectPath = Split-Path -Parent $PSScriptRoot

Write-Host "=== Release Gate ==="
Write-Host "Project: $projectPath"
Write-Host "Godot:   $GodotExe"
Write-Host ""

## 使用 [System.Diagnostics.Process] 捕获 Godot 输出，避免 PowerShell *> 重定向对 UTF-8 的处理差异
function Invoke-GodotHeadless {
    param(
        [string]$Exe,
        [string]$Path,
        [string[]]$ArgumentList,
        [int]$TimeoutMs = 300000
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Exe
    $argString = ($ArgumentList | ForEach-Object {
        if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
    }) -join ' '
    $psi.Arguments = $argString
    $psi.WorkingDirectory = $Path
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $p = [System.Diagnostics.Process]::Start($psi)
    # 异步读取避免死锁
    $stdoutTask = $p.StandardOutput.ReadToEndAsync()
    $stderrTask = $p.StandardError.ReadToEndAsync()
    $exited = $p.WaitForExit($TimeoutMs)
    if (-not $exited) {
        try { $p.Kill() } catch {}
        throw "Godot timed out after $($TimeoutMs / 1000)s"
    }
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    return [pscustomobject]@{
        ExitCode = $p.ExitCode
        Stdout = $stdout
        Stderr = $stderr
    }
}

## Parse the final two numeric summary lines without localized keywords.
function Get-LocalizedTestSummary {
    param([string]$Output)
    $matches = [regex]::Matches($Output, '(?m)^\s*[^\[\r\n:]+:\s*(\d+)\s*$')
    if ($matches.Count -lt 2) {
        return @(-1, -1)
    }
    $passedValue = [int]($matches[($matches.Count - 2)].Groups[1].Value)
    $failedValue = [int]($matches[($matches.Count - 1)].Groups[1].Value)
    return @($passedValue, $failedValue)
}

# --- 1. Godot 无头导入（验证资源完整性） ---
Write-Host "[1/3] Godot headless import..."
try {
    # --import keeps a fresh editor process alive in Godot 4.7. Explicit editor mode
    # plus --quit validates imports without leaving the release gate blocked.
    $importResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--editor', '--quit', '--path', $projectPath)
} catch {
    Write-Host "IMPORT FAILED: $_" -ForegroundColor Red
    exit 1
}
if ($importResult.ExitCode -ne 0) {
    Write-Host "IMPORT FAILED (exit $($importResult.ExitCode))" -ForegroundColor Red
    ($importResult.Stdout -split "`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    ($importResult.Stderr -split "`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}
Write-Host "  Import OK" -ForegroundColor Green

# --- 1.5. 音频源文件技术质量 ---
Write-Host "[1.5/3] Audio technical QA..."
try {
    & (Join-Path $PSScriptRoot '..\tools\test_audio_assets.ps1')
    if (-not $?) { throw 'Audio QA returned a failed PowerShell status' }
} catch {
    Write-Host "AUDIO QA FAILED: $_" -ForegroundColor Red
    exit 1
}

# --- 2. 烟雾测试 ---
Write-Host "[2/3] Running smoke tests..."
try {
    $testResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/battle_smoke_test.tscn') -TimeoutMs 600000
} catch {
    Write-Host "TEST EXECUTION FAILED: $_" -ForegroundColor Red
    exit 1
}

$testStr = $testResult.Stdout
$testErrStr = $testResult.Stderr
$testOut = $testStr -split "`r?`n"

Write-Host "  Exit code: $($testResult.ExitCode)"
Write-Host "  Stdout bytes: $($testStr.Length)"
Write-Host "  Stderr bytes: $($testErrStr.Length)"

# Parse test summary from stdout.
$testSummary = Get-LocalizedTestSummary -Output $testStr
$passed = [int]$testSummary[0]
$failed = [int]$testSummary[1]

Write-Host "  Passed: $passed"
Write-Host "  Failed: $failed"

if ($testResult.ExitCode -ne 0 -or $failed -lt 0) {
    Write-Host "TEST EXECUTION FAILED (exit=$($testResult.ExitCode))" -ForegroundColor Red
    $testOut | Select-Object -Last 15 | ForEach-Object { Write-Host "  $_" }
    if ($testErrStr) {
        Write-Host "  --- stderr ---" -ForegroundColor Yellow
        ($testErrStr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    }
    exit 1
}
if ($failed -ne 0) {
    Write-Host "TEST FAILED (failed=$failed)" -ForegroundColor Red
    $testOut | Select-String -Pattern '\[FAIL\]' | ForEach-Object { Write-Host "  $($_.Line)" }
    exit 1
}

# --- 2.5. 单位美术与动态表现合约 ---
Write-Host "[2.5/3] Running unit presentation contract..."
try {
    $unitResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/unit_animation_contract_test.tscn')
} catch {
    Write-Host "UNIT PRESENTATION TEST FAILED: $_" -ForegroundColor Red
    exit 1
}
$unitPassMatch = [regex]::Match($unitResult.Stdout, 'Passed:\s*(\d+)')
$unitFailMatch = [regex]::Match($unitResult.Stdout, 'Failed:\s*(\d+)')
$unitPassed = if ($unitPassMatch.Success) { [int]$unitPassMatch.Groups[1].Value } else { -1 }
$unitFailed = if ($unitFailMatch.Success) { [int]$unitFailMatch.Groups[1].Value } else { -1 }
Write-Host "  Passed: $unitPassed"
Write-Host "  Failed: $unitFailed"
if ($unitResult.ExitCode -ne 0 -or $unitFailed -ne 0) {
    Write-Host "UNIT PRESENTATION TEST FAILED (exit=$($unitResult.ExitCode), failed=$unitFailed)" -ForegroundColor Red
    ($unitResult.Stdout -split "`r?`n") | Select-Object -Last 15 | ForEach-Object { Write-Host "  $_" }
    ($unitResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- 2.6. 基地展示与任务列表合约 ---
Write-Host "[2.6/3] Running base presentation contract..."
try {
    $baseResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/base_mission_list_test.tscn')
} catch {
    Write-Host "BASE PRESENTATION TEST FAILED: $_" -ForegroundColor Red
    exit 1
}
$baseSummary = Get-LocalizedTestSummary -Output $baseResult.Stdout
$basePassed = [int]$baseSummary[0]
$baseFailed = [int]$baseSummary[1]
Write-Host "  Passed: $basePassed"
Write-Host "  Failed: $baseFailed"
if ($baseResult.ExitCode -ne 0 -or $baseFailed -ne 0) {
    Write-Host "BASE PRESENTATION TEST FAILED (exit=$($baseResult.ExitCode), failed=$baseFailed)" -ForegroundColor Red
    ($baseResult.Stdout -split "`r?`n") | Select-Object -Last 15 | ForEach-Object { Write-Host "  $_" }
    ($baseResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- 2.65. Battle HUD and tutorial layout contract ---
Write-Host "[2.65/3] Running battle HUD contract..."
try {
    $hudResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/battle_hud_contract_test.tscn')
} catch {
    Write-Host "BATTLE HUD TEST FAILED: $_" -ForegroundColor Red
    exit 1
}
$hudSummary = Get-LocalizedTestSummary -Output $hudResult.Stdout
$hudPassed = [int]$hudSummary[0]
$hudFailed = [int]$hudSummary[1]
Write-Host "  Passed: $hudPassed"
Write-Host "  Failed: $hudFailed"
if ($hudResult.ExitCode -ne 0 -or $hudFailed -ne 0) {
    Write-Host "BATTLE HUD TEST FAILED (exit=$($hudResult.ExitCode), failed=$hudFailed)" -ForegroundColor Red
    ($hudResult.Stdout -split "`r?`n") | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
    ($hudResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- 2.7. Data Sentinel production contract ---
Write-Host "[2.7/3] Running Data Sentinel production contract..."
try {
    $bossResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/data_sentinel_boss_test.tscn')
} catch {
    Write-Host "DATA SENTINEL TEST FAILED: $_" -ForegroundColor Red
    exit 1
}
$bossSummary = Get-LocalizedTestSummary -Output $bossResult.Stdout
$bossPassed = [int]$bossSummary[0]
$bossFailed = [int]$bossSummary[1]
Write-Host "  Passed: $bossPassed"
Write-Host "  Failed: $bossFailed"
if ($bossResult.ExitCode -ne 0 -or $bossFailed -ne 0) {
    Write-Host "DATA SENTINEL TEST FAILED (exit=$($bossResult.ExitCode), failed=$bossFailed)" -ForegroundColor Red
    ($bossResult.Stdout -split "`r?`n") | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
    ($bossResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- 2.8. Chapter-one balance target contract ---
Write-Host "[2.8/3] Running chapter-one balance contract..."
try {
    $balanceResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/chapter_one_balance_test.tscn')
} catch {
    Write-Host "CHAPTER-ONE BALANCE TEST FAILED: $_" -ForegroundColor Red
    exit 1
}
$balanceSummary = Get-LocalizedTestSummary -Output $balanceResult.Stdout
$balancePassed = [int]$balanceSummary[0]
$balanceFailed = [int]$balanceSummary[1]
Write-Host "  Passed: $balancePassed"
Write-Host "  Failed: $balanceFailed"
if ($balanceResult.ExitCode -ne 0 -or $balanceFailed -ne 0) {
    Write-Host "CHAPTER-ONE BALANCE TEST FAILED (exit=$($balanceResult.ExitCode), failed=$balanceFailed)" -ForegroundColor Red
    ($balanceResult.Stdout -split "`r?`n") | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
    ($balanceResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- 2.9. Chapter-one production E2E ---
Write-Host "[2.9/3] Running chapter-one production E2E..."
try {
    $e2eResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/chapter_one_e2e_test.tscn') -TimeoutMs 600000
} catch {
    Write-Host "CHAPTER-ONE E2E FAILED: $_" -ForegroundColor Red
    exit 1
}
$e2eSummary = Get-LocalizedTestSummary -Output $e2eResult.Stdout
$e2ePassed = [int]$e2eSummary[0]
$e2eFailed = [int]$e2eSummary[1]
Write-Host "  Passed: $e2ePassed"
Write-Host "  Failed: $e2eFailed"
if ($e2eResult.ExitCode -ne 0 -or $e2eFailed -ne 0) {
    Write-Host "CHAPTER-ONE E2E FAILED (exit=$($e2eResult.ExitCode), failed=$e2eFailed)" -ForegroundColor Red
    ($e2eResult.Stdout -split "`r?`n") | Select-Object -Last 25 | ForEach-Object { Write-Host "  $_" }
    ($e2eResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- 3. 日志门：检查非预期 ERROR/WARNING ---
Write-Host "[3/3] Checking log gate..."

# Merge stdout and stderr for the log gate.
$combinedOut = $testOut + ($testErrStr -split "`r?`n") + `
    ($unitResult.Stdout -split "`r?`n") + ($unitResult.Stderr -split "`r?`n") + `
    ($baseResult.Stdout -split "`r?`n") + ($baseResult.Stderr -split "`r?`n") + `
    ($hudResult.Stdout -split "`r?`n") + ($hudResult.Stderr -split "`r?`n") + `
    ($bossResult.Stdout -split "`r?`n") + ($bossResult.Stderr -split "`r?`n") + `
    ($balanceResult.Stdout -split "`r?`n") + ($balanceResult.Stderr -split "`r?`n") + `
    ($e2eResult.Stdout -split "`r?`n") + ($e2eResult.Stderr -split "`r?`n")

# 预期的 WARNING（存档损坏恢复测试产生，共 2 条）
$expectedWarningPattern = 'Save file corrupted or missing, trying backup'

# 收集所有 WARNING 行（区分大小写：Godot 输出 "WARNING:"，避免匹配测试输出中的 "BossWarning:" 等）
$warningLines = $combinedOut | Where-Object { $_ -cmatch 'WARNING:' }
$expectedWarnings = $warningLines | Where-Object { $_ -cmatch $expectedWarningPattern }
$unexpectedWarnings = $warningLines | Where-Object { $_ -cnotmatch $expectedWarningPattern }

Write-Host "  Expected warnings (corruption recovery): $($expectedWarnings.Count)"
Write-Host "  Unexpected warnings: $($unexpectedWarnings.Count)"

# 收集所有 ERROR 行（非预期）
$errorLines = $combinedOut | Where-Object {
    $_ -match 'ERROR:' -or $_ -match 'SCRIPT ERROR' -or $_ -match 'Parse Error'
}
# 过滤掉 JSON 解析的预期错误（来自存档损坏测试）和日志文件写入错误
$unexpectedErrors = $errorLines | Where-Object {
    $_ -notmatch 'JSON parse error' -and `
    $_ -notmatch 'Parse JSON failed' -and `
    $_ -notmatch "Failed to open 'user://logs/"
}

Write-Host "  Unexpected errors: $($unexpectedErrors.Count)"

if ($unexpectedWarnings.Count -gt 0) {
    Write-Host "UNEXPECTED WARNINGS:" -ForegroundColor Yellow
    $unexpectedWarnings | ForEach-Object { Write-Host "  $_" }
    exit 1
}

if ($unexpectedErrors.Count -gt 0) {
    Write-Host "UNEXPECTED ERRORS:" -ForegroundColor Red
    $unexpectedErrors | ForEach-Object { Write-Host "  $_" }
    exit 1
}

if ($expectedWarnings.Count -ne 2) {
    Write-Host "Expected exactly 2 corruption recovery warnings, got $($expectedWarnings.Count)" -ForegroundColor Yellow
    $expectedWarnings | ForEach-Object { Write-Host "  $_" }
    exit 1
}

Write-Host ""
Write-Host "=== Release Gate PASSED ===" -ForegroundColor Green
Write-Host "  Stable assertion count: $passed"
Write-Host "  Unit presentation assertions: $unitPassed"
Write-Host "  Base presentation assertions: $basePassed"
Write-Host "  Battle HUD assertions: $hudPassed"
Write-Host "  Data Sentinel assertions: $bossPassed"
Write-Host "  Balance assertions: $balancePassed"
Write-Host "  Chapter-one E2E assertions: $e2ePassed"
Write-Host "  Failures: $failed"
Write-Host "  Expected warnings: $($expectedWarnings.Count)"
Write-Host "  Unexpected warnings: $($unexpectedWarnings.Count)"
Write-Host "  Unexpected errors: $($unexpectedErrors.Count)"
exit 0
