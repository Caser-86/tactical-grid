## Release Gate：第一章正式版测试入口
## 退出码 0 代表 Godot 导入、烟雾测试和日志门全部通过
## 用法: pwsh -ExecutionPolicy Bypass -File tests/run_release_gate.ps1
##       powershell -ExecutionPolicy Bypass -File tests/run_release_gate.ps1
param(
    [string]$GodotExe = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'
)

$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { (Get-Location).Path }
$projectPath = Split-Path -Parent $scriptRoot

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
    & (Join-Path $scriptRoot '..\tools\test_audio_assets.ps1')
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

# --- 2.91. Chapter-one objectives contract ---
Write-Host "[2.91/3] Running chapter-one objectives contract..."
try {
    $objResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/chapter_one_objectives_test.tscn')
} catch {
    Write-Host "CHAPTER-ONE OBJECTIVES TEST FAILED: $_" -ForegroundColor Red
    exit 1
}
$objSummary = Get-LocalizedTestSummary -Output $objResult.Stdout
$objPassed = [int]$objSummary[0]
$objFailed = [int]$objSummary[1]
Write-Host "  Passed: $objPassed"
Write-Host "  Failed: $objFailed"
if ($objResult.ExitCode -ne 0 -or $objFailed -ne 0) {
    Write-Host "CHAPTER-ONE OBJECTIVES TEST FAILED (exit=$($objResult.ExitCode), failed=$objFailed)" -ForegroundColor Red
    ($objResult.Stdout -split "`r?`n") | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
    ($objResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- 2.92. Targeting controller contract ---
Write-Host "[2.92/3] Running targeting controller contract..."
try {
    $targetingResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/targeting_controller_test.tscn')
} catch {
    Write-Host "TARGETING CONTROLLER TEST FAILED: $_" -ForegroundColor Red
    exit 1
}
$targetingSummary = Get-LocalizedTestSummary -Output $targetingResult.Stdout
$targetingPassed = [int]$targetingSummary[0]
$targetingFailed = [int]$targetingSummary[1]
Write-Host "  Passed: $targetingPassed"
Write-Host "  Failed: $targetingFailed"
if ($targetingResult.ExitCode -ne 0 -or $targetingFailed -ne 0) {
    Write-Host "TARGETING CONTROLLER TEST FAILED (exit=$($targetingResult.ExitCode), failed=$targetingFailed)" -ForegroundColor Red
    ($targetingResult.Stdout -split "`r?`n") | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
    ($targetingResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- 2.93. Save recovery contract ---
Write-Host "[2.93/3] Running save recovery contract..."
try {
    $saveRecoveryResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/save_recovery_test.tscn')
} catch {
    Write-Host "SAVE RECOVERY TEST FAILED: $_" -ForegroundColor Red
    exit 1
}
$saveRecoverySummary = Get-LocalizedTestSummary -Output $saveRecoveryResult.Stdout
$saveRecoveryPassed = [int]$saveRecoverySummary[0]
$saveRecoveryFailed = [int]$saveRecoverySummary[1]
Write-Host "  Passed: $saveRecoveryPassed"
Write-Host "  Failed: $saveRecoveryFailed"
if ($saveRecoveryResult.ExitCode -ne 0 -or $saveRecoveryFailed -ne 0) {
    Write-Host "SAVE RECOVERY TEST FAILED (exit=$($saveRecoveryResult.ExitCode), failed=$saveRecoveryFailed)" -ForegroundColor Red
    ($saveRecoveryResult.Stdout -split "`r?`n") | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
    ($saveRecoveryResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- 2.94. Action system contract ---
Write-Host "[2.94/3] Running action system contract..."
try {
    $actionResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/action_system_test.tscn')
} catch {
    Write-Host "ACTION SYSTEM TEST FAILED: $_" -ForegroundColor Red
    exit 1
}
$actionSummary = Get-LocalizedTestSummary -Output $actionResult.Stdout
$actionPassed = [int]$actionSummary[0]
$actionFailed = [int]$actionSummary[1]
Write-Host "  Passed: $actionPassed"
Write-Host "  Failed: $actionFailed"
if ($actionResult.ExitCode -ne 0 -or $actionFailed -ne 0) {
    Write-Host "ACTION SYSTEM TEST FAILED (exit=$($actionResult.ExitCode), failed=$actionFailed)" -ForegroundColor Red
    ($actionResult.Stdout -split "`r?`n") | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
    ($actionResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}
# --- 2.95. Locked map validator contract ---
Write-Host "[2.95/3] Running locked map validator contract..."
try {
    $validatorResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/locked_map_validator_test.tscn')
} catch {
    Write-Host "LOCKED MAP VALIDATOR TEST FAILED: $_" -ForegroundColor Red
    exit 1
}
$validatorSummary = Get-LocalizedTestSummary -Output $validatorResult.Stdout
$validatorPassed = [int]$validatorSummary[0]
$validatorFailed = [int]$validatorSummary[1]
Write-Host "  Passed: $validatorPassed"
Write-Host "  Failed: $validatorFailed"
if ($validatorResult.ExitCode -ne 0 -or $validatorFailed -ne 0) {
    Write-Host "LOCKED MAP VALIDATOR TEST FAILED (exit=$($validatorResult.ExitCode), failed=$validatorFailed)" -ForegroundColor Red
    ($validatorResult.Stdout -split "`r?`n") | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
    ($validatorResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- 2.96. Visibility state contract ---
Write-Host "[2.96/3] Running visibility state contract..."
try {
    $visibilityResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/visibility_state_test.tscn')
} catch {
    Write-Host "VISIBILITY STATE TEST FAILED: $_" -ForegroundColor Red
    exit 1
}
$visibilitySummary = Get-LocalizedTestSummary -Output $visibilityResult.Stdout
$visibilityPassed = [int]$visibilitySummary[0]
$visibilityFailed = [int]$visibilitySummary[1]
Write-Host "  Passed: $visibilityPassed"
Write-Host "  Failed: $visibilityFailed"
if ($visibilityResult.ExitCode -ne 0 -or $visibilityFailed -ne 0) {
    Write-Host "VISIBILITY STATE TEST FAILED (exit=$($visibilityResult.ExitCode), failed=$visibilityFailed)" -ForegroundColor Red
    ($visibilityResult.Stdout -split "`r?`n") | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
    ($visibilityResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- 2.97. Enemy intent state contract ---
Write-Host "[2.97/3] Running enemy intent state contract..."
try {
    $intentResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/enemy_intent_state_test.tscn')
} catch {
    Write-Host "ENEMY INTENT STATE TEST FAILED: $_" -ForegroundColor Red
    exit 1
}
$intentSummary = Get-LocalizedTestSummary -Output $intentResult.Stdout
$intentPassed = [int]$intentSummary[0]
$intentFailed = [int]$intentSummary[1]
Write-Host "  Passed: $intentPassed"
Write-Host "  Failed: $intentFailed"
if ($intentResult.ExitCode -ne 0 -or $intentFailed -ne 0) {
    Write-Host "ENEMY INTENT STATE TEST FAILED (exit=$($intentResult.ExitCode), failed=$intentFailed)" -ForegroundColor Red
    ($intentResult.Stdout -split "`r?`n") | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
    ($intentResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- 2.98. Tactical network state contract ---
Write-Host "[2.98/3] Running tactical network state contract..."
try {
    $tnsResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/tactical_network_state_test.tscn')
} catch {
    Write-Host "TACTICAL NETWORK STATE TEST FAILED: $_" -ForegroundColor Red
    exit 1
}
$tnsSummary = Get-LocalizedTestSummary -Output $tnsResult.Stdout
$tnsPassed = [int]$tnsSummary[0]
$tnsFailed = [int]$tnsSummary[1]
Write-Host "  Passed: $tnsPassed"
Write-Host "  Failed: $tnsFailed"
if ($tnsResult.ExitCode -ne 0 -or $tnsFailed -ne 0) {
    Write-Host "TACTICAL NETWORK STATE TEST FAILED (exit=$($tnsResult.ExitCode), failed=$tnsFailed)" -ForegroundColor Red
    ($tnsResult.Stdout -split "`r?`n") | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
    ($tnsResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- 2.99. Alert state contract ---
Write-Host "[2.99/3] Running alert state contract..."
try {
    $alertResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/alert_state_test.tscn')
} catch {
    Write-Host "ALERT STATE TEST FAILED: $_" -ForegroundColor Red
    exit 1
}
$alertSummary = Get-LocalizedTestSummary -Output $alertResult.Stdout
$alertPassed = [int]$alertSummary[0]
$alertFailed = [int]$alertSummary[1]
Write-Host "  Passed: $alertPassed"
Write-Host "  Failed: $alertFailed"
if ($alertResult.ExitCode -ne 0 -or $alertFailed -ne 0) {
    Write-Host "ALERT STATE TEST FAILED (exit=$($alertResult.ExitCode), failed=$alertFailed)" -ForegroundColor Red
    ($alertResult.Stdout -split "`r?`n") | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
    ($alertResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- 2.991. Encounter checkpoint state contract ---
Write-Host "[2.991/3] Running encounter checkpoint state contract..."
try {
    $checkpointResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/encounter_checkpoint_state_test.tscn')
} catch {
    Write-Host "ENCOUNTER CHECKPOINT STATE TEST FAILED: $_" -ForegroundColor Red
    exit 1
}
$checkpointSummary = Get-LocalizedTestSummary -Output $checkpointResult.Stdout
$checkpointPassed = [int]$checkpointSummary[0]
$checkpointFailed = [int]$checkpointSummary[1]
Write-Host "  Passed: $checkpointPassed"
Write-Host "  Failed: $checkpointFailed"
if ($checkpointResult.ExitCode -ne 0 -or $checkpointFailed -ne 0) {
    Write-Host "ENCOUNTER CHECKPOINT STATE TEST FAILED (exit=$($checkpointResult.ExitCode), failed=$checkpointFailed)" -ForegroundColor Red
    ($checkpointResult.Stdout -split "`r?`n") | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
    ($checkpointResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- 2.992. Visibility renderer contract ---
Write-Host "[2.992/3] Running visibility renderer contract..."
try {
    $visRendererResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/visibility_renderer_test.tscn')
} catch {
    Write-Host "VISIBILITY RENDERER TEST FAILED: $_" -ForegroundColor Red
    exit 1
}
$visRendererSummary = Get-LocalizedTestSummary -Output $visRendererResult.Stdout
$visRendererPassed = [int]$visRendererSummary[0]
$visRendererFailed = [int]$visRendererSummary[1]
Write-Host "  Passed: $visRendererPassed"
Write-Host "  Failed: $visRendererFailed"
if ($visRendererResult.ExitCode -ne 0 -or $visRendererFailed -ne 0) {
    Write-Host "VISIBILITY RENDERER TEST FAILED (exit=$($visRendererResult.ExitCode), failed=$visRendererFailed)" -ForegroundColor Red
    ($visRendererResult.Stdout -split "`r?`n") | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
    ($visRendererResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- 2.993. Enemy intent renderer contract ---
Write-Host "[2.993/3] Running enemy intent renderer contract..."
try {
    $intentRendererResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--path', $projectPath, 'res://tests/enemy_intent_renderer_test.tscn')
} catch {
    Write-Host "ENEMY INTENT RENDERER TEST FAILED: $_" -ForegroundColor Red
    exit 1
}
$intentRendererSummary = Get-LocalizedTestSummary -Output $intentRendererResult.Stdout
$intentRendererPassed = [int]$intentRendererSummary[0]
$intentRendererFailed = [int]$intentRendererSummary[1]
Write-Host "  Passed: $intentRendererPassed"
Write-Host "  Failed: $intentRendererFailed"
if ($intentRendererResult.ExitCode -ne 0 -or $intentRendererFailed -ne 0) {
    Write-Host "ENEMY INTENT RENDERER TEST FAILED (exit=$($intentRendererResult.ExitCode), failed=$intentRendererFailed)" -ForegroundColor Red
    ($intentRendererResult.Stdout -split "`r?`n") | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" }
    ($intentRendererResult.Stderr -split "`r?`n") | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" }
    exit 1
}

# --- 3. 日志门：检查预期 ERROR/WARNING ---
Write-Host "[3/3] Checking log gate..."

# Merge stdout and stderr for the log gate.
$combinedOut = $testOut + ($testErrStr -split "`r?`n") + `
    ($unitResult.Stdout -split "`r?`n") + ($unitResult.Stderr -split "`r?`n") + `
    ($baseResult.Stdout -split "`r?`n") + ($baseResult.Stderr -split "`r?`n") + `
    ($hudResult.Stdout -split "`r?`n") + ($hudResult.Stderr -split "`r?`n") + `
    ($bossResult.Stdout -split "`r?`n") + ($bossResult.Stderr -split "`r?`n") + `
    ($balanceResult.Stdout -split "`r?`n") + ($balanceResult.Stderr -split "`r?`n") + `
    ($e2eResult.Stdout -split "`r?`n") + ($e2eResult.Stderr -split "`r?`n") + `
    ($objResult.Stdout -split "`r?`n") + ($objResult.Stderr -split "`r?`n") + `
    ($targetingResult.Stdout -split "`r?`n") + ($targetingResult.Stderr -split "`r?`n") + `
    ($saveRecoveryResult.Stdout -split "`r?`n") + ($saveRecoveryResult.Stderr -split "`r?`n") + `
    ($actionResult.Stdout -split "`r?`n") + ($actionResult.Stderr -split "`r?`n") + `
    ($validatorResult.Stdout -split "`r?`n") + ($validatorResult.Stderr -split "`r?`n") + `
    ($visibilityResult.Stdout -split "`r?`n") + ($visibilityResult.Stderr -split "`r?`n") + `
    ($intentResult.Stdout -split "`r?`n") + ($intentResult.Stderr -split "`r?`n") + `
    ($tnsResult.Stdout -split "`r?`n") + ($tnsResult.Stderr -split "`r?`n") + `
    ($alertResult.Stdout -split "`r?`n") + ($alertResult.Stderr -split "`r?`n") + `
    ($checkpointResult.Stdout -split "`r?`n") + ($checkpointResult.Stderr -split "`r?`n") + `
    ($visRendererResult.Stdout -split "`r?`n") + ($visRendererResult.Stderr -split "`r?`n") + `
    ($intentRendererResult.Stdout -split "`r?`n") + ($intentRendererResult.Stderr -split "`r?`n")

# 预期的 WARNING（存档损坏恢复测试产生，共 3 条：2 来自 smoke test，1 来自 save_recovery_test）
$expectedWarningPattern = 'Save file corrupted or missing, trying backup'

# 收集所有 WARNING 行（区分大小写：Godot 输出 "WARNING:"，避免匹配测试输出中的 "BossWarning:" 等）
$warningLines = $combinedOut | Where-Object { $_ -cmatch 'WARNING:' }
$expectedWarnings = $warningLines | Where-Object { $_ -cmatch $expectedWarningPattern }
$unexpectedWarnings = $warningLines | Where-Object {
    $_ -cnotmatch $expectedWarningPattern -and
    $_ -cnotmatch 'RIDs of type.*were leaked' -and
    $_ -cnotmatch 'ObjectDB instances were leaked at exit'
}

Write-Host "  Expected warnings (corruption recovery): $($expectedWarnings.Count)"
Write-Host "  Unexpected warnings: $($unexpectedWarnings.Count)"

# 收集所有 ERROR 行（非预期）
$errorLines = $combinedOut | Where-Object {
    $_ -match 'ERROR:' -or $_ -match 'SCRIPT ERROR' -or $_ -match 'Parse Error'
}
# 过滤掉 JSON 解析的预期错误（来自存档损坏测试）、日志文件写入错误，
# 以及未来版本存档拒绝错误（来自 save_recovery_test 的 _test_future_version_refusal）
$unexpectedErrors = $errorLines | Where-Object {
    $_ -notmatch 'JSON parse error' -and `
    $_ -notmatch 'Parse JSON failed' -and `
    $_ -notmatch "Failed to open 'user://logs/" -and `
    $_ -notmatch 'resources still in use at exit' -and `
    $_ -notmatch 'Save version .* is newer than supported'
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

if ($expectedWarnings.Count -ne 3) {
    Write-Host "Expected exactly 3 corruption recovery warnings, got $($expectedWarnings.Count)" -ForegroundColor Yellow
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
Write-Host "  Chapter-one objectives assertions: $objPassed"
Write-Host "  Targeting controller assertions: $targetingPassed"
Write-Host "  Save recovery assertions: $saveRecoveryPassed"
Write-Host "  Action system assertions: $actionPassed"
Write-Host "  Locked map validator assertions: $validatorPassed"
Write-Host "  Visibility state assertions: $visibilityPassed"
Write-Host "  Enemy intent state assertions: $intentPassed"
Write-Host "  Tactical network state assertions: $tnsPassed"
Write-Host "  Alert state assertions: $alertPassed"
Write-Host "  Encounter checkpoint state assertions: $checkpointPassed"
Write-Host "  Visibility renderer assertions: $visRendererPassed"
Write-Host "  Enemy intent renderer assertions: $intentRendererPassed"
Write-Host "  Failures: $failed"
Write-Host "  Expected warnings: $($expectedWarnings.Count)"
Write-Host "  Unexpected warnings: $($unexpectedWarnings.Count)"
Write-Host "  Unexpected errors: $($unexpectedErrors.Count)"
exit 0
