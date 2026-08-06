[CmdletBinding()]
param(
    [string]$GodotExe = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$outputRoot = Join-Path $projectRoot '..\artifacts\v2\verification\m1-graybox\screenshots'
$null = New-Item -ItemType Directory -Force -Path $outputRoot
$sizes = @('1280x720', '1920x1080')
$modes = @('normal', 'grayscale', 'deuteranopia_assist')
$stages = @('start', 'selected', 'attack_preview', 'rescue', 'evac', 'dialogue', 'result')

if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot executable not found: $GodotExe"
}

Add-Type -AssemblyName System.Drawing
$expected = 0
$verified = 0

foreach ($size in $sizes) {
    $parts = $size.Split('x')
    $expectedWidth = [int]$parts[0]
    $expectedHeight = [int]$parts[1]
    foreach ($mode in $modes) {
        foreach ($stage in $stages) {
            $expected++
            $filename = "${size}_${mode}_${stage}.png"
            $outputPath = Join-Path $outputRoot $filename
            Write-Host "[M112] $filename"
            $arguments = @(
                '--path', $projectRoot,
                '--display-driver', 'windows',
                '--rendering-method', 'gl_compatibility',
                '--scene', 'res://tests/v2/v2_m1_visual_snapshot.tscn',
                '--',
                "--qa-size=$size",
                "--qa-mode=$mode",
                "--qa-stage=$stage",
                "--qa-output=$outputPath"
            )
            & $GodotExe @arguments
            if ($LASTEXITCODE -ne 0) {
                throw "M112 visual scene failed with exit code ${LASTEXITCODE}: $filename"
            }
            if (-not (Test-Path -LiteralPath $outputPath)) {
                throw "M112 visual snapshot missing: $outputPath"
            }
            $fileInfo = Get-Item -LiteralPath $outputPath
            if ($fileInfo.Length -le 0) {
                throw "M112 visual snapshot is empty: $outputPath"
            }
            $image = [System.Drawing.Image]::FromFile($outputPath)
            try {
                if ($image.Width -ne $expectedWidth -or $image.Height -ne $expectedHeight) {
                    throw "M112 visual snapshot has wrong dimensions: $filename ($($image.Width)x$($image.Height))"
                }
            }
            finally {
                $image.Dispose()
            }
            $verified++
        }
    }
}

Write-Host "M112 VISUAL MATRIX PASSED ($verified/$expected snapshots, 2 resolutions x 3 modes x 7 stages)"
exit 0
