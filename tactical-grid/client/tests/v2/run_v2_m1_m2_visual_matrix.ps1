[CmdletBinding()]
param(
    [string]$GodotExe = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot executable not found: $GodotExe"
}

$m1Script = Join-Path $PSScriptRoot 'run_m1_visual_matrix.ps1'
$m2Script = Join-Path $PSScriptRoot 'run_m2_visual_matrix.ps1'
foreach ($script in @($m1Script, $m2Script)) {
    if (-not (Test-Path -LiteralPath $script)) {
        throw "Visual matrix script not found: $script"
    }
}

& $m1Script -GodotExe $GodotExe
if ($LASTEXITCODE -ne 0) {
    throw "M1 visual matrix failed with exit code $LASTEXITCODE"
}

& $m2Script -GodotExe $GodotExe
if ($LASTEXITCODE -ne 0) {
    throw "M2 visual matrix failed with exit code $LASTEXITCODE"
}

Write-Host "V2 VISUAL MATRIX PASSED (96 snapshots: M1 42 + M2 54)"
exit 0
