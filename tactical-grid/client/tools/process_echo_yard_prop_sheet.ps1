<#
Crops the reviewed 3x2 transparent Echo Yard prop sheet into six 64x64 runtime sprites.
The source sheet must already have its chroma key converted to alpha.
#>
[CmdletBinding()]
param(
    [string]$SourcePath = (Join-Path $PSScriptRoot '..\assets\generated\chapter1\source\echo_yard_props_sheet_alpha_v1.png'),
    [string]$OutputRoot = (Join-Path $PSScriptRoot '..\assets\generated\chapter1\runtime\environment\echo_yard\prop')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$source = [System.Drawing.Bitmap]::FromFile($SourcePath)
try {
    if ($source.Width -ne 1536 -or $source.Height -ne 1024) {
        throw "Expected a 1536x1024 3x2 sheet, received $($source.Width)x$($source.Height)"
    }
    for ($index = 0; $index -lt 6; $index++) {
        $column = $index % 3
        $row = [Math]::Floor($index / 3)
        $sourceRect = [System.Drawing.Rectangle]::new($column * 512, $row * 512, 512, 512)
        $target = [System.Drawing.Bitmap]::new(64, 64, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($target)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $graphics.DrawImage($source, [System.Drawing.Rectangle]::new(0, 0, 64, 64), $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
        } finally {
            $graphics.Dispose()
        }
        $outputPath = Join-Path $OutputRoot ("prop_{0:00}.png" -f $index)
        $target.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $target.Dispose()
    }
} finally {
    $source.Dispose()
}

Write-Host "Processed six Echo Freight Yard prop sprites into $OutputRoot"
