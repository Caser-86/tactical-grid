<#
Generates the original Cooling Works runtime environment kit.
No third-party textures, samples or fonts are used.
#>
[CmdletBinding()]
param(
    [string]$OutputRoot = (Join-Path $PSScriptRoot '..\assets\generated\chapter1\runtime\environment\cooling_works')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-Canvas {
    param([int]$Width = 64, [int]$Height = 64, [bool]$Opaque = $false)
    $bitmap = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    if ($Opaque) { $graphics.Clear([System.Drawing.Color]::FromArgb(255, 29, 39, 43)) }
    else { $graphics.Clear([System.Drawing.Color]::Transparent) }
    return @($bitmap, $graphics)
}

function Save-Canvas {
    param($Canvas, [string]$RelativePath)
    $path = Join-Path $OutputRoot $RelativePath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
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

function Add-ConcreteBase($Graphics, [int]$Variant) {
    $base = New-Brush '#202c30'
    $Graphics.FillRectangle($base, 0, 0, 64, 64)
    $base.Dispose()
    $tone = @('#354144', '#303d40', '#3a4546', '#2b373b')[$Variant % 4]
    $inner = New-Brush $tone 150
    $Graphics.FillRectangle($inner, 3, 3, 58, 58)
    $inner.Dispose()
    $seam = New-Pen '#819093' 1 95
    $Graphics.DrawRectangle($seam, 2, 2, 60, 60)
    $Graphics.DrawLine($seam, 2, 32, 62, 32)
    $Graphics.DrawLine($seam, 32, 2, 32, 62)
    $seam.Dispose()
    $bolt = New-Brush '#a5b7b5' 145
    foreach ($point in @(@(6, 6), @(56, 6), @(6, 56), @(56, 56))) {
        $Graphics.FillEllipse($bolt, $point[0], $point[1], 3, 3)
    }
    $bolt.Dispose()
}

for ($variant = 0; $variant -lt 8; $variant++) {
    $canvas = New-Canvas 64 64 $true
    $g = $canvas[1]
    Add-ConcreteBase $g $variant
    switch ($variant) {
        1 {
            $wet = New-Brush '#6aaeba' 56
            $g.FillEllipse($wet, 6, 38, 42, 16); $g.FillEllipse($wet, 32, 12, 24, 11)
            $wet.Dispose()
        }
        2 {
            $channel = New-Brush '#126f79' 225
            $g.FillRectangle($channel, 24, 0, 16, 64)
            $channel.Dispose()
            $flow = New-Pen '#71e8e2' 2 205
            for ($y = 7; $y -lt 64; $y += 18) { $g.DrawLine($flow, 28, $y, 36, $y + 7) }
            $flow.Dispose()
        }
        3 {
            $stripe = New-Pen '#e0b33d' 4 205
            for ($x = -12; $x -lt 70; $x += 15) { $g.DrawLine($stripe, $x, 59, $x + 20, 39) }
            $stripe.Dispose()
        }
        4 {
            $deck = New-Brush '#d6ddd7' 130
            $g.FillRectangle($deck, 7, 11, 50, 42)
            $deck.Dispose()
            $rib = New-Pen '#78919a' 1 160
            for ($x = 12; $x -le 52; $x += 6) { $g.DrawLine($rib, $x, 12, $x, 52) }
            $rib.Dispose()
        }
        5 {
            $red = New-Pen '#cd544b' 3 190
            $g.DrawLine($red, 7, 14, 57, 14); $g.DrawLine($red, 7, 50, 57, 50)
            $red.Dispose()
        }
        6 {
            $bloom = New-Brush '#9bb6a2' 62
            $g.FillEllipse($bloom, 8, 9, 32, 22); $g.FillEllipse($bloom, 29, 28, 28, 23)
            $bloom.Dispose()
        }
        7 {
            $grate = New-Brush '#101b1e'
            $g.FillRectangle($grate, 8, 9, 48, 46)
            $grate.Dispose()
            $line = New-Pen '#71898b' 1 170
            for ($y = 13; $y -le 51; $y += 5) { $g.DrawLine($line, 10, $y, 54, $y) }
            $line.Dispose()
        }
    }
    Save-Canvas $canvas ("floor/floor_{0:00}.png" -f $variant)
}

$edgeSpecs = @(
    @{Name = 'north'; X = 0; Y = 0; W = 64; H = 8}, @{Name = 'east'; X = 56; Y = 0; W = 8; H = 64},
    @{Name = 'south'; X = 0; Y = 56; W = 64; H = 8}, @{Name = 'west'; X = 0; Y = 0; W = 8; H = 64}
)
foreach ($spec in $edgeSpecs) {
    $canvas = New-Canvas
    $g = $canvas[1]
    $shadow = New-Brush '#071114' 205
    $g.FillRectangle($shadow, $spec.X, $spec.Y, $spec.W, $spec.H)
    $shadow.Dispose()
    $rim = New-Pen '#62d8d6' 1 220
    if ($spec.Name -in @('north', 'south')) {
        $y = if ($spec.Name -eq 'north') { 7 } else { 56 }
        $g.DrawLine($rim, 0, $y, 64, $y)
    } else {
        $x = if ($spec.Name -eq 'west') { 7 } else { 56 }
        $g.DrawLine($rim, $x, 0, $x, 64)
    }
    $rim.Dispose()
    Save-Canvas $canvas ("edge/edge_{0}.png" -f $spec.Name)
}

foreach ($corner in @('nw', 'ne', 'se', 'sw')) {
    $canvas = New-Canvas
    $g = $canvas[1]
    $shadow = New-Pen '#071114' 8 205
    $rim = New-Pen '#62d8d6' 1 220
    switch ($corner) {
        'nw' { $g.DrawLine($shadow, 3, 0, 3, 29); $g.DrawLine($shadow, 0, 3, 29, 3); $g.DrawArc($rim, 3, 3, 19, 19, 180, 90) }
        'ne' { $g.DrawLine($shadow, 61, 0, 61, 29); $g.DrawLine($shadow, 35, 3, 64, 3); $g.DrawArc($rim, 42, 3, 19, 19, 270, 90) }
        'se' { $g.DrawLine($shadow, 61, 35, 61, 64); $g.DrawLine($shadow, 35, 61, 64, 61); $g.DrawArc($rim, 42, 42, 19, 19, 0, 90) }
        'sw' { $g.DrawLine($shadow, 3, 35, 3, 64); $g.DrawLine($shadow, 0, 61, 29, 61); $g.DrawArc($rim, 3, 42, 19, 19, 90, 90) }
    }
    $shadow.Dispose(); $rim.Dispose()
    Save-Canvas $canvas ("edge/edge_corner_{0}.png" -f $corner)
}

function Add-Pipe($Graphics, [int]$Y, [string]$Fill, [string]$Rim) {
    $body = New-Brush $Fill; $Graphics.FillRectangle($body, 7, $Y, 50, 10); $body.Dispose()
    $outline = New-Pen $Rim 2 225; $Graphics.DrawEllipse($outline, 5, $Y, 12, 10); $Graphics.DrawEllipse($outline, 47, $Y, 12, 10); $outline.Dispose()
}

for ($prop = 0; $prop -lt 6; $prop++) {
    $canvas = New-Canvas
    $g = $canvas[1]
    switch ($prop) {
        0 { Add-Pipe $g 18 '#38565a' '#a7d7d4'; Add-Pipe $g 32 '#31505a' '#6bbec5' }
        1 {
            $pipe = New-Pen '#b8cfca' 11 240; $g.DrawArc($pipe, 10, 8, 40, 40, 180, 180); $g.DrawLine($pipe, 15, 28, 15, 54); $g.DrawLine($pipe, 45, 28, 45, 54); $pipe.Dispose()
        }
        2 {
            $box = New-Brush '#34454a'; $g.FillRectangle($box, 10, 15, 44, 35); $box.Dispose()
            $rim = New-Pen '#d9b441' 2 230; $g.DrawRectangle($rim, 10, 15, 44, 35); $rim.Dispose()
            $valve = New-Pen '#cc594e' 3 230; $g.DrawEllipse($valve, 21, 20, 21, 21); $g.DrawLine($valve, 31, 16, 31, 45); $g.DrawLine($valve, 20, 31, 43, 31); $valve.Dispose()
        }
        3 {
            $pump = New-Brush '#243a41'; $g.FillEllipse($pump, 8, 14, 48, 36); $pump.Dispose()
            $rim = New-Pen '#78d8d4' 2 220; $g.DrawEllipse($rim, 8, 14, 48, 36); $g.DrawEllipse($rim, 22, 23, 20, 18); $rim.Dispose()
        }
        4 {
            $tank = New-Brush '#536c6e'; $g.FillRectangle($tank, 16, 8, 32, 47); $tank.Dispose()
            $rim = New-Pen '#c9dcda' 2 220; $g.DrawRectangle($rim, 16, 8, 32, 47); $rim.Dispose()
            $gauge = New-Brush '#67e2dd'; $g.FillEllipse($gauge, 26, 19, 11, 11); $gauge.Dispose()
        }
        5 {
            $barrier = New-Brush '#29383c'; $g.FillRectangle($barrier, 5, 25, 54, 20); $barrier.Dispose()
            $stripe = New-Pen '#d9b441' 3 230; for ($x = 6; $x -lt 58; $x += 13) { $g.DrawLine($stripe, $x, 44, $x + 11, 26) }; $stripe.Dispose()
        }
    }
    Save-Canvas $canvas ("prop/prop_{0:00}.png" -f $prop)
}

for ($decal = 0; $decal -lt 3; $decal++) {
    $canvas = New-Canvas
    $g = $canvas[1]
    switch ($decal) {
        0 { $mist = New-Brush '#b5f2eb' 48; $g.FillEllipse($mist, 6, 29, 50, 18); $mist.Dispose() }
        1 { $bloom = New-Brush '#c5ddaf' 60; $g.FillEllipse($bloom, 8, 8, 38, 34); $bloom.Dispose() }
        2 { $spill = New-Brush '#1db8b3' 85; $g.FillEllipse($spill, 7, 29, 50, 19); $spill.Dispose(); $rim = New-Pen '#98fff1' 1 115; $g.DrawArc($rim, 11, 32, 40, 11, 175, 170); $rim.Dispose() }
    }
    Save-Canvas $canvas ("decal/decal_{0:00}.png" -f $decal)
}

$tower = New-Canvas 192 128
$g = $tower[1]
$body = New-Brush '#273b3d'; $g.FillRectangle($body, 25, 12, 142, 104); $body.Dispose()
$rim = New-Pen '#b9d8d3' 4 230; $g.DrawRectangle($rim, 25, 12, 142, 104); $g.DrawEllipse($rim, 52, 24, 88, 58); $rim.Dispose()
$fan = New-Pen '#5edbd6' 5 230; $g.DrawEllipse($fan, 70, 34, 52, 40); $g.DrawLine($fan, 96, 38, 96, 70); $g.DrawLine($fan, 75, 53, 117, 53); $fan.Dispose()
Save-Canvas $tower 'landmark/cooling_tower_base_192x128.png'

$manifold = New-Canvas 128 128
$g = $manifold[1]
for ($x = 24; $x -le 100; $x += 25) { $pipe = New-Pen '#94b8b7' 12 245; $g.DrawLine($pipe, $x, 18, $x, 106); $pipe.Dispose() }
$rim = New-Pen '#d9b441' 2 220; $g.DrawRectangle($rim, 15, 16, 98, 94); $rim.Dispose()
$light = New-Brush '#4ee0d9'; $g.FillEllipse($light, 57, 48, 15, 15); $light.Dispose()
Save-Canvas $manifold 'landmark/turbine_manifold_128.png'

Write-Host "Generated Cooling Works environment kit at $OutputRoot"
