[CmdletBinding()]
param(
    [string]$GodotExe = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$manifestPath = Join-Path $PSScriptRoot 'gate_manifest.json'

if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot executable not found: $GodotExe"
}
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "V2 gate manifest not found: $manifestPath"
}

function Invoke-GodotItem {
    param([string]$ScriptPath)

    Write-Host "[V2] Godot script: $ScriptPath"
    & $GodotExe --headless --path $projectRoot --script $ScriptPath
    if ($LASTEXITCODE -ne 0) {
        throw "V2 Godot test failed with exit code ${LASTEXITCODE}: $ScriptPath"
    }
}

function Invoke-SceneItem {
    param([string]$ScenePath)

    Write-Host "[V2] Godot scene: $ScenePath"
    & $GodotExe --headless --path $projectRoot $ScenePath
    if ($LASTEXITCODE -ne 0) {
        throw "V2 Godot scene failed with exit code ${LASTEXITCODE}: $ScenePath"
    }
}

function Invoke-PowerShellItem {
    param([string]$RelativePath)

    $scriptPath = Join-Path $projectRoot $RelativePath
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "V2 PowerShell test not found: $scriptPath"
    }

    Write-Host "[V2] PowerShell test: $RelativePath"
    if ($RelativePath -eq 'tests/run_release_gate.ps1') {
        & powershell -ExecutionPolicy Bypass -File $scriptPath -GodotExe $GodotExe
    } else {
        & powershell -ExecutionPolicy Bypass -File $scriptPath
    }
    if ($LASTEXITCODE -ne 0) {
        throw "V2 PowerShell test failed with exit code ${LASTEXITCODE}: $RelativePath"
    }
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

Write-Host 'V2 RELEASE GATE PASSED'
exit 0
