<#
.SYNOPSIS
Deterministically normalizes the V2 south-facing unit sample art.

The source images are generated with true alpha. This tool removes only near-zero
alpha haze, crops transparent bounds, and places every subject on the same 128x128
runtime canvas with a shared bottom-center anchor. It does not alter the existing V2
directionless art or any V1 asset.
#>
[CmdletBinding()]
param(
    [string]$SourceRoot = '',
    [string]$OutputRoot = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Join-Path $PSScriptRoot '..\assets\v2\source\units'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $PSScriptRoot '..\assets\v2\units'
}
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$Canvas = 128
$SubjectBox = 112
$BottomMargin = 6
$AlphaCutoff = 8
$Padding = 4

$Jobs = @(
    @{ key = 'v2_assault'; source = 'player\v2_assault_south_source_2026-08-15.png'; output = 'v2_assault_south_128.png' },
    @{ key = 'v2_scout'; source = 'player\v2_scout_south_source_2026-08-15.png'; output = 'v2_scout_south_128.png' },
    @{ key = 'v2_sentry'; source = 'enemy\v2_sentry_south_source_2026-08-15.png'; output = 'v2_sentry_south_128.png' },
    @{ key = 'v2_drone'; source = 'enemy\v2_drone_south_source_2026-08-15.png'; output = 'v2_drone_south_128.png' },
    @{ key = 'v2_shield_guard'; source = 'enemy\v2_shield_guard_south_source_2026-08-15.png'; output = 'v2_shield_guard_south_128.png' }
)

function Convert-To32bppArgb {
    param([System.Drawing.Image]$Image)
    $bitmap = New-Object System.Drawing.Bitmap $Image.Width, $Image.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.DrawImage($Image, 0, 0, $Image.Width, $Image.Height)
    $graphics.Dispose()
    return $bitmap
}

function Get-RowOffset {
    param([int]$Y, [int]$Height, [int]$Stride)
    $rowStride = [Math]::Abs($Stride)
    if ($Stride -ge 0) { return $Y * $rowStride }
    return ($Height - 1 - $Y) * $rowStride
}

foreach ($job in $Jobs) {
    $sourcePath = Join-Path $SourceRoot $job.source
    $outputPath = Join-Path $OutputRoot $job.output
    if (-not (Test-Path -LiteralPath $sourcePath)) { throw "Source not found: $sourcePath" }

    $loaded = [System.Drawing.Image]::FromFile($sourcePath)
    $source = Convert-To32bppArgb $loaded
    $loaded.Dispose()

    $width = $source.Width
    $height = $source.Height
    $rect = [System.Drawing.Rectangle]::new(0, 0, $width, $height)
    $data = $source.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $rowStride = [Math]::Abs($data.Stride)
    $byteCount = $rowStride * $height
    $bytes = New-Object byte[] $byteCount
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $byteCount)

    $minX = $width
    $minY = $height
    $maxX = -1
    $maxY = -1
    for ($y = 0; $y -lt $height; $y++) {
        $rowOffset = Get-RowOffset $y $height $data.Stride
        for ($x = 0; $x -lt $width; $x++) {
            $offset = $rowOffset + $x * 4
            $alpha = [int]$bytes[$offset + 3]
            if ($alpha -lt $AlphaCutoff) {
                $bytes[$offset + 3] = 0
                continue
            }
            if ($x -lt $minX) { $minX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
    [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $data.Scan0, $byteCount)
    $source.UnlockBits($data)

    if ($maxX -lt 0) {
        $source.Dispose()
        throw "No visible pixels in $($job.key)"
    }

    $cropX = [Math]::Max(0, $minX - $Padding)
    $cropY = [Math]::Max(0, $minY - $Padding)
    $cropRight = [Math]::Min($width - 1, $maxX + $Padding)
    $cropBottom = [Math]::Min($height - 1, $maxY + $Padding)
    $cropWidth = $cropRight - $cropX + 1
    $cropHeight = $cropBottom - $cropY + 1

    $scale = [Math]::Min([double]$SubjectBox / $cropWidth, [double]$SubjectBox / $cropHeight)
    $drawWidth = [Math]::Max(1, [int][Math]::Round($cropWidth * $scale))
    $drawHeight = [Math]::Max(1, [int][Math]::Round($cropHeight * $scale))

    $output = New-Object System.Drawing.Bitmap $Canvas, $Canvas, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($output)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $destinationX = [int](($Canvas - $drawWidth) / 2)
    $destinationY = $Canvas - $BottomMargin - $drawHeight
    if ($destinationY -lt 0) { $destinationY = 0 }
    $sourceRect = [System.Drawing.Rectangle]::new($cropX, $cropY, $cropWidth, $cropHeight)
    $destinationRect = [System.Drawing.Rectangle]::new($destinationX, $destinationY, $drawWidth, $drawHeight)
    $graphics.DrawImage($source, $destinationRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
    $graphics.Dispose()
    $source.Dispose()

    $cornerAlpha = @(
        $output.GetPixel(0, 0).A,
        $output.GetPixel($Canvas - 1, 0).A,
        $output.GetPixel(0, $Canvas - 1).A,
        $output.GetPixel($Canvas - 1, $Canvas - 1).A
    ) | Measure-Object -Average
    if ($output.Width -ne $Canvas -or $output.Height -ne $Canvas) {
        $output.Dispose()
        throw "Output dimensions wrong for $($job.key)"
    }
    if ($cornerAlpha.Average -gt 0.5) {
        $output.Dispose()
        throw "Transparent corners failed for $($job.key): $($cornerAlpha.Average)"
    }

    $stream = New-Object System.IO.MemoryStream
    $output.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    [System.IO.File]::WriteAllBytes($outputPath, $stream.ToArray())
    $stream.Dispose()
    $output.Dispose()

    Write-Host ("Processed {0,-16} visible={1}x{2} output={3}" -f $job.key, $drawWidth, $drawHeight, $job.output)
}

Write-Host "V2 south-facing sample art written to $OutputRoot"
