<#
Crops and fits the reviewed two-panel transparent landmark sheet into runtime sprites.
The source sheet must already have its chroma key converted to alpha.
#>
[CmdletBinding()]
param(
    [string]$SourcePath = (Join-Path $PSScriptRoot '..\assets\generated\chapter1\source\echo_yard_landmarks_sheet_alpha_v1.png'),
    [string]$OutputRoot = (Join-Path $PSScriptRoot '..\assets\generated\chapter1\runtime\environment\echo_yard\landmark'),
    [int]$SplitX = 1100
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

function Get-AlphaBounds {
    param([System.Drawing.Bitmap]$Bitmap, [System.Drawing.Rectangle]$SearchArea)
    $minX = $SearchArea.Right
    $minY = $SearchArea.Bottom
    $maxX = $SearchArea.Left
    $maxY = $SearchArea.Top
    for ($y = $SearchArea.Top; $y -lt $SearchArea.Bottom; $y += 2) {
        for ($x = $SearchArea.Left; $x -lt $SearchArea.Right; $x += 2) {
            if ($Bitmap.GetPixel($x, $y).A -gt 16) {
                $minX = [Math]::Min($minX, $x)
                $minY = [Math]::Min($minY, $y)
                $maxX = [Math]::Max($maxX, $x)
                $maxY = [Math]::Max($maxY, $y)
            }
        }
    }
    if ($maxX -le $minX -or $maxY -le $minY) { throw 'No opaque landmark pixels found.' }
    return [System.Drawing.Rectangle]::new($minX, $minY, $maxX - $minX + 2, $maxY - $minY + 2)
}

function Export-FittedSprite {
    param(
        [System.Drawing.Bitmap]$Source,
        [System.Drawing.Rectangle]$Panel,
        [int]$TargetWidth,
        [int]$TargetHeight,
        [string]$Filename
    )
    $bounds = Get-AlphaBounds $Source $Panel
    $scale = [Math]::Min(($TargetWidth - 4) / $bounds.Width, ($TargetHeight - 4) / $bounds.Height)
    $drawWidth = [int]($bounds.Width * $scale)
    $drawHeight = [int]($bounds.Height * $scale)
    $target = [System.Drawing.Bitmap]::new($TargetWidth, $TargetHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($target)
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $destination = [System.Drawing.Rectangle]::new(
            [int](($TargetWidth - $drawWidth) / 2),
            [int](($TargetHeight - $drawHeight) / 2),
            $drawWidth,
            $drawHeight
        )
        $graphics.DrawImage($Source, $destination, $bounds, [System.Drawing.GraphicsUnit]::Pixel)
    } finally {
        $graphics.Dispose()
    }
    $target.Save((Join-Path $OutputRoot $Filename), [System.Drawing.Imaging.ImageFormat]::Png)
    $target.Dispose()
}

$source = [System.Drawing.Bitmap]::FromFile($SourcePath)
try {
    if ($SplitX -le 0 -or $SplitX -ge $source.Width) { throw "Invalid landmark split position: $SplitX" }
    Export-FittedSprite $source ([System.Drawing.Rectangle]::new(0, 0, $SplitX, $source.Height)) 192 128 'gantry_crane_192x128.png'
    Export-FittedSprite $source ([System.Drawing.Rectangle]::new($SplitX, 0, $source.Width - $SplitX, $source.Height)) 128 128 'floodlight_tower_128.png'
} finally {
    $source.Dispose()
}

Write-Host "Processed two Echo Freight Yard landmark sprites into $OutputRoot"
