## 存档解析错误检查（Release Gate 子集）
## 验证存档损坏恢复测试不会产生 Godot 引擎级 JSON 解析错误
param(
    [string]$GodotExe = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'
)

$projectPath = Split-Path -Parent $PSScriptRoot
$output = & $GodotExe --headless --path $projectPath res://tests/battle_smoke_test.tscn 2>&1

if ($LASTEXITCODE -ne 0) {
    throw "Godot smoke test failed with exit code $LASTEXITCODE"
}

# 存档损坏恢复测试会产生 2 条预期的 push_warning，但不应该产生引擎级 ERROR
$fullOutput = ($output | Out-String)

# 预期的 WARNING（存档损坏恢复）
$expectedWarnings = ($fullOutput -split "`n" | Where-Object { $_ -match 'Save file corrupted or missing, trying backup' }).Count
if ($expectedWarnings -ne 2) {
    throw "Expected 2 corruption recovery warnings, got $expectedWarnings"
}

# 非预期的 JSON 解析引擎错误
if ($fullOutput -match 'ERROR: Parse JSON failed') {
    throw 'Corrupted-save recovery emitted a Godot JSON parse error.'
}

# 非预期的 SCRIPT ERROR 或 Parse Error
if ($fullOutput -match 'SCRIPT ERROR' -or $fullOutput -match 'Parse Error') {
    throw 'Unexpected script/parse error in smoke test output.'
}

Write-Host "Save parse error check: PASSED (2 expected warnings, 0 unexpected errors)"
