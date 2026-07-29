<#
Generates the original Echo Freight Yard runtime environment kit.
No third-party textures, samples or fonts are used.
#>
[CmdletBinding()]
param(
    [string]$OutputRoot = (Join-Path $PSScriptRoot '..\assets\generated\chapter1\runtime\environment\echo_yard')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$baseFloorPath = Join-Path $PSScriptRoot '..\assets\generated\chapter1\runtime\tiles\data_floor_64.png'
$script:baseFloorTexture = [System.Drawing.Bitmap]::FromFile($baseFloorPath)

function New-Canvas {
    param([int]$Width = 64, [int]$Height = 64, [bool]$Opaque = $false)
    $bitmap = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    if ($Opaque) { $graphics.Clear([System.Drawing.Color]::FromArgb(255, 24, 34, 40)) }
    else { $graphics.Clear([System.Drawing.Color]::Transparent) }
    return @($bitmap, $graphics)
}

function Save-Canvas {
    param($Canvas, [string]$RelativePath)
    $path = Join-Path $OutputRoot $RelativePath
    $directory = Split-Path -Parent $path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $Canvas[1].Dispose()
    $Canvas[0].Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $Canvas[0].Dispose()
}

function New-Brush([string]$Hex, [int]$Alpha = 255) {
    $color = [System.Drawing.ColorTranslator]::FromHtml($Hex)
    return [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb($Alpha, $color.R, $color.G, $color.B))
}

function New-Pen([string]$Hex, [single]$Width = 1.0, [int]$Alpha = 255) {
    $color = [System.Drawing.ColorTranslator]::FromHtml($Hex)
    return [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb($Alpha, $color.R, $color.G, $color.B), $Width)
}

function Add-PlateBase($Graphics, [int]$Variant) {
    $base = New-Brush '#1a262d'
    $Graphics.FillRectangle($base, 0, 0, 64, 64)
    $base.Dispose()
    $Graphics.DrawImage($script:baseFloorTexture, 0, 0, 64, 64)
    $innerHex = @('#26343b', '#223139', '#24383e', '#2b3337')[$Variant % 4]
    $inner = New-Brush $innerHex 72
    $Graphics.FillRectangle($inner, 2, 2, 60, 60)
    $inner.Dispose()
    $seam = New-Pen '#52646b' 1 105
    $Graphics.DrawRectangle($seam, 1, 1, 61, 61)
    $Graphics.DrawLine($seam, 32, 2, 32, 62)
    $Graphics.DrawLine($seam, 2, 32, 62, 32)
    $seam.Dispose()
    $bolt = New-Brush '#829096' 170
    foreach ($point in @(@(5,5), @(57,5), @(5,57), @(57,57))) {
        $Graphics.FillEllipse($bolt, $point[0], $point[1], 2, 2)
    }
    $bolt.Dispose()
}

for ($variant = 0; $variant -lt 8; $variant++) {
    $canvas = New-Canvas 64 64 $true
    $g = $canvas[1]
    Add-PlateBase $g $variant
    switch ($variant) {
        1 {
            $pen = New-Pen '#80939a' 1 100
            $g.DrawLine($pen, 8, 16, 56, 16); $g.DrawLine($pen, 8, 48, 56, 48)
            $pen.Dispose()
        }
        2 {
            $cyan = New-Brush '#23d9eb' 205
            $g.FillRectangle($cyan, 29, 4, 6, 56)
            $cyan.Dispose()
        }
        3 {
            $amber = New-Pen '#e5a632' 3 190
            for ($x = -8; $x -lt 64; $x += 14) { $g.DrawLine($amber, $x, 60, $x + 18, 42) }
            $amber.Dispose()
        }
        4 {
            $dark = New-Brush '#10191e'
            $g.FillRectangle($dark, 10, 8, 44, 48)
            $dark.Dispose()
            $grate = New-Pen '#607078' 1 170
            for ($x = 13; $x -le 51; $x += 4) { $g.DrawLine($grate, $x, 10, $x, 54) }
            $g.DrawRectangle($grate, 10, 8, 44, 48)
            $grate.Dispose()
        }
        5 {
            $drain = New-Brush '#111a1f'
            $g.FillRectangle($drain, 5, 27, 54, 10)
            $drain.Dispose()
            $slots = New-Pen '#718188' 1 170
            for ($x = 8; $x -le 56; $x += 4) { $g.DrawLine($slots, $x, 29, $x, 35) }
            $slots.Dispose()
        }
        6 {
            $wear = New-Pen '#8d7660' 2 80
            $g.DrawArc($wear, 6, 8, 52, 40, 18, 138)
            $g.DrawLine($wear, 12, 52, 46, 39)
            $wear.Dispose()
        }
        7 {
            $wet = New-Brush '#3b6472' 65
            $g.FillEllipse($wet, 8, 36, 42, 15)
            $g.FillEllipse($wet, 30, 13, 25, 10)
            $wet.Dispose()
            $shine = New-Pen '#8fd9e6' 1 75
            $g.DrawArc($shine, 11, 38, 34, 9, 190, 135)
            $shine.Dispose()
        }
    }
    Save-Canvas $canvas ("floor/floor_{0:00}.png" -f $variant)
}

$edgeSpecs = @(
    @{Name='north'; X=0; Y=0; W=64; H=7}, @{Name='east'; X=57; Y=0; W=7; H=64},
    @{Name='south'; X=0; Y=57; W=64; H=7}, @{Name='west'; X=0; Y=0; W=7; H=64}
)
foreach ($spec in $edgeSpecs) {
    $canvas = New-Canvas
    $g = $canvas[1]
    $shadow = New-Brush '#071014' 190
    $g.FillRectangle($shadow, $spec.X, $spec.Y, $spec.W, $spec.H)
    $shadow.Dispose()
    $rim = New-Pen '#d0922c' 1 210
    if ($spec.Name -in @('north','south')) { $g.DrawLine($rim, 0, $(if($spec.Name -eq 'north'){6}else{57}), 64, $(if($spec.Name -eq 'north'){6}else{57})) }
    else { $g.DrawLine($rim, $(if($spec.Name -eq 'west'){6}else{57}), 0, $(if($spec.Name -eq 'west'){6}else{57}), 64) }
    $rim.Dispose()
    Save-Canvas $canvas ("edge/edge_{0}.png" -f $spec.Name)
}

foreach ($corner in @('nw','ne','se','sw')) {
    $canvas = New-Canvas
    $g = $canvas[1]
    $shadow = New-Pen '#071014' 7 205
    $rim = New-Pen '#d0922c' 1 220
    switch ($corner) {
        'nw' { $g.DrawLine($shadow, 3, 0, 3, 28); $g.DrawLine($shadow, 0, 3, 28, 3); $g.DrawArc($rim, 3, 3, 18, 18, 180, 90) }
        'ne' { $g.DrawLine($shadow, 61, 0, 61, 28); $g.DrawLine($shadow, 36, 3, 64, 3); $g.DrawArc($rim, 43, 3, 18, 18, 270, 90) }
        'se' { $g.DrawLine($shadow, 61, 36, 61, 64); $g.DrawLine($shadow, 36, 61, 64, 61); $g.DrawArc($rim, 43, 43, 18, 18, 0, 90) }
        'sw' { $g.DrawLine($shadow, 3, 36, 3, 64); $g.DrawLine($shadow, 0, 61, 28, 61); $g.DrawArc($rim, 3, 43, 18, 18, 90, 90) }
    }
    $shadow.Dispose(); $rim.Dispose()
    Save-Canvas $canvas ("edge/edge_corner_{0}.png" -f $corner)
}

function Add-Cargo($Graphics, [string]$FillHex, [string]$RimHex) {
    $shadow = New-Brush '#020608' 125; $Graphics.FillRectangle($shadow, 10, 18, 46, 36); $shadow.Dispose()
    $fill = New-Brush $FillHex; $Graphics.FillRectangle($fill, 8, 13, 46, 36); $fill.Dispose()
    $rim = New-Pen $RimHex 2 230; $Graphics.DrawRectangle($rim, 8, 13, 46, 36)
    for ($x = 14; $x -lt 54; $x += 8) { $Graphics.DrawLine($rim, $x, 15, $x, 47) }
    $rim.Dispose()
}

for ($prop = 0; $prop -lt 6 -and -not (Test-Path -LiteralPath (Join-Path $OutputRoot 'prop\prop_00.png')); $prop++) {
    $canvas = New-Canvas
    $g = $canvas[1]
    switch ($prop) {
        0 { Add-Cargo $g '#24475b' '#51a6c5' }
        1 { Add-Cargo $g '#65391f' '#d78237' }
        2 {
            $fill = New-Brush '#273239'; $g.FillRectangle($fill, 6, 22, 52, 24); $fill.Dispose()
            $rim = New-Pen '#a7b7bb' 2 220; $g.DrawRectangle($rim, 6, 22, 52, 24); $g.DrawLine($rim, 10, 42, 54, 26); $rim.Dispose()
            $amber = New-Pen '#e4a62f' 2 220; $g.DrawLine($amber, 10, 38, 50, 25); $amber.Dispose()
        }
        3 {
            $pipe = New-Brush '#39464c'; $rim = New-Pen '#96a5aa' 1 200
            for ($y = 19; $y -le 39; $y += 10) { $g.FillRectangle($pipe, 9, $y, 46, 8); $g.DrawEllipse($rim, 7, $y, 10, 8); $g.DrawEllipse($rim, 47, $y, 10, 8) }
            $pipe.Dispose(); $rim.Dispose()
        }
        4 {
            $spool = New-Brush '#4b3523'; $g.FillEllipse($spool, 8, 12, 48, 40); $spool.Dispose()
            $hub = New-Brush '#151d21'; $g.FillEllipse($hub, 18, 19, 28, 26); $hub.Dispose()
            $cable = New-Pen '#7e8b8e' 3 220; $g.DrawArc($cable, 21, 22, 22, 20, 0, 340); $cable.Dispose()
        }
        5 {
            $fill = New-Brush '#182e35'; $g.FillRectangle($fill, 13, 11, 38, 44); $fill.Dispose()
            $rim = New-Pen '#3fd6e5' 2 220; $g.DrawRectangle($rim, 13, 11, 38, 44); $g.DrawRectangle($rim, 20, 18, 24, 13); $rim.Dispose()
            $light = New-Brush '#e9b54a'; $g.FillEllipse($light, 22, 40, 5, 5); $g.FillEllipse($light, 32, 40, 5, 5); $light.Dispose()
        }
    }
    Save-Canvas $canvas ("prop/prop_{0:00}.png" -f $prop)
}

for ($decal = 0; $decal -lt 3; $decal++) {
    $canvas = New-Canvas
    $g = $canvas[1]
    switch ($decal) {
        0 {
            $amber = New-Pen '#e5a632' 4 150
            for ($x = -8; $x -lt 64; $x += 14) { $g.DrawLine($amber, $x, 54, $x + 18, 36) }
            $amber.Dispose()
        }
        1 {
            $oil = New-Brush '#05080a' 125; $g.FillEllipse($oil, 9, 31, 45, 19); $g.FillEllipse($oil, 28, 17, 24, 20); $oil.Dispose()
            $rim = New-Pen '#58737c' 1 75; $g.DrawArc($rim, 12, 34, 37, 10, 175, 160); $rim.Dispose()
        }
        2 {
            $wear = New-Pen '#9d8568' 3 90; $g.DrawArc($wear, 5, 4, 54, 46, 20, 135); $g.DrawArc($wear, 8, 13, 50, 42, 180, 130); $wear.Dispose()
        }
    }
    Save-Canvas $canvas ("decal/decal_{0:00}.png" -f $decal)
}

if (-not (Test-Path -LiteralPath (Join-Path $OutputRoot 'landmark\gantry_crane_192x128.png'))) {
    $crane = New-Canvas 192 128
    $g = $crane[1]
    $steel = New-Brush '#1e2a31'; $rim = New-Pen '#d4912d' 4 235; $cyan = New-Brush '#2ed8e8'
    $g.FillRectangle($steel, 5, 8, 18, 112); $g.FillRectangle($steel, 169, 8, 18, 112); $g.FillRectangle($steel, 5, 8, 182, 18)
    $g.DrawRectangle($rim, 5, 8, 18, 112); $g.DrawRectangle($rim, 169, 8, 18, 112); $g.DrawRectangle($rim, 5, 8, 182, 18)
    for ($x = 32; $x -lt 164; $x += 24) { $g.DrawLine($rim, $x, 10, $x + 18, 24) }
    $g.FillRectangle($cyan, 12, 108, 5, 5); $g.FillRectangle($cyan, 176, 108, 5, 5)
    $steel.Dispose(); $rim.Dispose(); $cyan.Dispose()
    Save-Canvas $crane 'landmark/gantry_crane_192x128.png'
}

if (-not (Test-Path -LiteralPath (Join-Path $OutputRoot 'landmark\floodlight_tower_128.png'))) {
    $tower = New-Canvas 128 128
    $g = $tower[1]
    $steel = New-Pen '#586970' 5 240; $amber = New-Brush '#ffd27a'; $glow = New-Brush '#ffc04c' 55
    $g.DrawLine($steel, 64, 32, 64, 122); $g.DrawLine($steel, 64, 82, 42, 122); $g.DrawLine($steel, 64, 82, 86, 122)
    $g.FillEllipse($glow, 12, 4, 104, 56); $g.FillRectangle($amber, 30, 16, 26, 16); $g.FillRectangle($amber, 72, 16, 26, 16)
    $steel.Dispose(); $amber.Dispose(); $glow.Dispose()
    Save-Canvas $tower 'landmark/floodlight_tower_128.png'
}

Write-Host "Generated Echo Freight Yard environment kit at $OutputRoot"
$script:baseFloorTexture.Dispose()
