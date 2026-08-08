[CmdletBinding()]
param(
    [string]$GodotExe = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$manifestPath = Join-Path $PSScriptRoot 'gate_manifest.json'
$gateResults = New-Object System.Collections.Generic.List[object]
$gateWarnings = New-Object System.Collections.Generic.List[string]
$gateWarningCounts = @{}

if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot executable not found: $GodotExe"
}
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "V2 gate manifest not found: $manifestPath"
}

function Register-Result {
    param(
        [string]$Kind,
        [string]$Path,
        [int]$ExitCode,
        [string[]]$Output
    )

    $passedAssertions = -1
    $failedAssertions = -1
    foreach ($line in $Output) {
        if ($line -match '^\s*Passed:\s*(\d+)\s*$') {
            $passedAssertions = [int]$Matches[1]
        }
        if ($line -match '^\s*Failed:\s*(\d+)\s*$') {
            $failedAssertions = [int]$Matches[1]
        }
        if ($line -match '^\s*WARNING:' -or $line -match '^\s*ERROR:.*(leaked|resources still in use)') {
            $warning = "$Kind $Path :: $line"
            $gateWarnings.Add($warning)
            $message = $line.Trim()
            if ($gateWarningCounts.ContainsKey($message)) {
                $gateWarningCounts[$message]++
            } else {
                $gateWarningCounts[$message] = 1
            }
        }
    }

    $passed = $ExitCode -eq 0 -and ($failedAssertions -lt 0 -or $failedAssertions -eq 0)
    $gateResults.Add([pscustomobject]@{
        Kind = $Kind
        Path = $Path
        ExitCode = $ExitCode
        PassedAssertions = $passedAssertions
        FailedAssertions = $failedAssertions
        Passed = $passed
    })

    $passedText = if ($passedAssertions -ge 0) { $passedAssertions } else { 'n/a' }
    $failedText = if ($failedAssertions -ge 0) { $failedAssertions } else { 'n/a' }
    $status = if ($passed) { 'PASS' } else { 'FAIL' }
    Write-Host ("[V2] RESULT {0}: {1} {2} (exit={3}; Passed={4}; Failed={5})" -f $status, $Kind, $Path, $ExitCode, $passedText, $failedText)
}

function Invoke-GodotItem {
    param([string]$ScriptPath)

    Write-Host "[V2] Godot script: $ScriptPath"
    $output = @(& $GodotExe --headless --path $projectRoot --script $ScriptPath 2>&1 | ForEach-Object { [string]$_ })
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    Register-Result -Kind 'Godot script' -Path $ScriptPath -ExitCode $exitCode -Output $output
}

function Invoke-SceneItem {
    param([string]$ScenePath)

    Write-Host "[V2] Godot scene: $ScenePath"
    $output = @(& $GodotExe --headless --path $projectRoot $ScenePath 2>&1 | ForEach-Object { [string]$_ })
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    Register-Result -Kind 'Godot scene' -Path $ScenePath -ExitCode $exitCode -Output $output
}

function Invoke-PowerShellItem {
    param([string]$RelativePath)

    $scriptPath = Join-Path $projectRoot $RelativePath
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        Write-Host "[V2] PowerShell test missing: $RelativePath"
        Register-Result -Kind 'PowerShell test' -Path $RelativePath -ExitCode 1 -Output @("Test not found: $scriptPath")
        return
    }

    Write-Host "[V2] PowerShell test: $RelativePath"
    if ($RelativePath -eq 'tests/run_release_gate.ps1' -or $RelativePath -eq 'tests/v2/run_m1_visual_matrix.ps1') {
        $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -GodotExe $GodotExe 2>&1 | ForEach-Object { [string]$_ })
    } else {
        $output = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath 2>&1 | ForEach-Object { [string]$_ })
    }
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    Register-Result -Kind 'PowerShell test' -Path $RelativePath -ExitCode $exitCode -Output $output
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
foreach ($scriptPath in @($manifest.script_tests)) {
    Invoke-GodotItem -ScriptPath $scriptPath
}
foreach ($scenePath in @($manifest.scene_tests)) {
    Invoke-SceneItem -ScenePath $scenePath
}
foreach ($relativePath in @($manifest.powershell_tests)) {
    Invoke-PowerShellItem -RelativePath $relativePath
}

$failedResults = @($gateResults | Where-Object { -not $_.Passed })
$passedResults = @($gateResults | Where-Object { $_.Passed })
$totalPassedAssertions = 0
$totalFailedAssertions = 0
$assertionResultCount = 0
foreach ($result in $gateResults) {
    if ($result.PassedAssertions -ge 0) {
        $assertionResultCount++
        $totalPassedAssertions += $result.PassedAssertions
    }
    if ($result.FailedAssertions -ge 0) {
        $totalFailedAssertions += $result.FailedAssertions
    }
}

Write-Host 'V2 GATE SUMMARY'
Write-Host ("Items: {0}; Passed items: {1}; Failed items: {2}" -f $gateResults.Count, $passedResults.Count, $failedResults.Count)
Write-Host ("Assertions: {0} result lines; Passed: {1}; Failed: {2}" -f $assertionResultCount, $totalPassedAssertions, $totalFailedAssertions)
if ($gateWarnings.Count -eq 0) {
    Write-Host 'Warnings: 0'
} else {
    Write-Host ("Warnings (non-fatal): {0} occurrences across {1} unique messages" -f $gateWarnings.Count, $gateWarningCounts.Count)
    foreach ($message in @($gateWarningCounts.Keys | Sort-Object)) {
        Write-Host ("  {0} x{1}" -f $message, $gateWarningCounts[$message])
    }
}

if ($failedResults.Count -gt 0) {
    Write-Host 'Failed items:'
    foreach ($result in $failedResults) {
        Write-Host ("  {0} {1} (exit={2}; Passed={3}; Failed={4})" -f $result.Kind, $result.Path, $result.ExitCode, $result.PassedAssertions, $result.FailedAssertions)
    }
    exit 1
}

Write-Host 'V2 RELEASE GATE PASSED'
exit 0
