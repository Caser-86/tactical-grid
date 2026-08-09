<#
Builds the Windows x64 release after forcing a Godot asset import pass.
Set GODOT_PATH when Godot is not available through PATH or the default install.
#>

param(
    [string]$GodotPath = $env:GODOT_PATH,
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

$projectConfig = Get-Content (Join-Path $projectRoot 'project.godot') -Raw
if ($projectConfig -notmatch 'run/main_scene="res://scenes/v2_boot\.tscn"' -or
	$projectConfig -notmatch 'config/custom_user_dir_name="TacticalGrid_V2_Infiltration"') {
	throw 'This build script only builds the isolated V2 product line.'
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($godotCommand) {
        $GodotPath = $godotCommand.Source
    } else {
        $defaultPath = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'
        if (Test-Path -LiteralPath $defaultPath) {
            $GodotPath = $defaultPath
        }
    }
}

if ([string]::IsNullOrWhiteSpace($GodotPath) -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Godot executable not found. Set GODOT_PATH or pass -GodotPath.'
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
	$OutputPath = Join-Path $projectRoot 'build\TacticalGrid_V2_Infiltration\TacticalGrid_V2_Infiltration.exe'
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

# A clean checkout can need one pass to create generated font/audio import
# metadata and a second pass to settle dependent theme resources before export.
for ($importPass = 1; $importPass -le 2; $importPass++) {
    Write-Host "Godot asset import pass $importPass/2..."
    & $GodotPath --headless --path $projectRoot --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw "Godot asset import failed on pass $importPass with exit code $LASTEXITCODE." }
}

& $GodotPath --headless --path $projectRoot --export-release 'Windows Desktop x64' $OutputPath
if ($LASTEXITCODE -ne 0) { throw "Godot export failed with exit code $LASTEXITCODE." }
if (-not (Test-Path -LiteralPath $OutputPath)) { throw "Expected export was not created: $OutputPath" }

$artifact = Get-Item -LiteralPath $OutputPath
Write-Host "Windows release created: $($artifact.FullName) ($([Math]::Round($artifact.Length / 1MB, 2)) MB)"
