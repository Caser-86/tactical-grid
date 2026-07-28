param(
    [string]$GodotExe = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'
)

$projectPath = Split-Path -Parent $PSScriptRoot
$output = & $GodotExe --headless --path $projectPath res://tests/battle_smoke_test.tscn 2>&1
$output | ForEach-Object { $_ }

if ($LASTEXITCODE -ne 0) {
    throw "Godot smoke test failed with exit code $LASTEXITCODE"
}

if (($output -join "`n") -match 'ERROR: Parse JSON failed') {
    throw 'Corrupted-save recovery emitted a Godot JSON parse error.'
}
