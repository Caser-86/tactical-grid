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

# --- 1. Godot 无头导入（验证资源完整性） ---
Write-Host "[1/3] Godot headless import..."
try {
    $importResult = Invoke-GodotHeadless -Exe $GodotExe -Path $projectPath -ArgumentList @('--headless', '--import', '--path', $projectPath)
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

# 解析总结（从 stdout）
$passMatch = [regex]::Match($testStr, '通过:\s*(\d+)')
$failMatch = [regex]::Match($testStr, '失败:\s*(\d+)')
$passed = if ($passMatch.Success) { [int]$passMatch.Groups[1].Value } else { -1 }
$failed = if ($failMatch.Success) { [int]$failMatch.Groups[1].Value } else { -1 }

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

# --- 3. 日志门：检查非预期 ERROR/WARNING ---
Write-Host "[3/3] Checking log gate..."

# 合并 stdout + stderr 用于日志门检查（Godot 的 push_warning/push_error 可能走 stderr）
$combinedOut = $testOut + ($testErrStr -split "`r?`n")

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
Write-Host "  Failures: $failed"
Write-Host "  Expected warnings: $($expectedWarnings.Count)"
Write-Host "  Unexpected warnings: $($unexpectedWarnings.Count)"
Write-Host "  Unexpected errors: $($unexpectedErrors.Count)"
exit 0
