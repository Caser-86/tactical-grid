<#
.SYNOPSIS
Deterministic alpha cleanup, crop, and resize for the seven Chapter 1 unit source illustrations.

Loads each source PNG, keys green-dominant background pixels to alpha with a soft edge,
crops to non-transparent bounds with 12px padding, resizes to fit inside a 90x90 box, and
composites onto a transparent 96x96 canvas with a 3px foot margin. Validates dimensions,
corner transparency, and edge clearance. Uses bundled .NET System.Drawing; no new runtime dependency.

The AI-generated sources use a flat green chroma background, but the gradient lighting makes
a single corner sample unreliable. Green-dominant keying (G - max(R,B)) robustly separates the
pure/gradient green background from foreground units, which never have G far above R and B.
#>
[CmdletBinding()]
param(
    [string]$SourceRoot = (Join-Path $PSScriptRoot '..\assets\generated\chapter1\source\ch1_m1_units'),
    [string]$OutputRoot = (Join-Path $PSScriptRoot '..\assets\generated\chapter1\runtime\units')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

# Green-dominant threshold: background pixels have G - max(R,B) >= 50.
# Foreground units (armor, weapons, skin) never approach pure green, so 50 is a safe hard key.
# Soft edge over the next 25 values anti-aliases the green-to-foreground transition.
$GreenThreshold = 50
$SoftEdge = 25
$Pad = 12
$Box = 90
$Canvas = 96
$FootMargin = 3

$Jobs = @(
    @{ key='assault';       source='assault_source_v1.png';       output='assault_96.png' }
    @{ key='sniper';        source='sniper_source_v1.png';        output='sniper_96.png' }
    @{ key='heavy';         source='heavy_source_v1.png';         output='heavy_96.png' }
    @{ key='sentry_basic';  source='sentry_basic_source_v1.png';  output='sentry_basic_96.png' }
    @{ key='drone_scout';   source='drone_scout_source_v1.png';   output='drone_scout_96.png' }
    @{ key='sentry_sniper'; source='sentry_sniper_source_v1.png'; output='sentry_sniper_96.png' }
    @{ key='drone_assault'; source='drone_assault_source_v1.png'; output='drone_assault_96.png' },
    @{ key='scout';              source='scout_source_v1.png';              output='scout_96.png' },
    @{ key='protocol_engineer';  source='protocol_engineer_source_v1.png';  output='protocol_engineer_96.png' },
    @{ key='hunter';             source='hunter_source_v1.png';             output='hunter_96.png' }
)

function Convert-To32bppArgb {
    param([System.Drawing.Image]$Image)
    $bmp = New-Object System.Drawing.Bitmap $Image.Width, $Image.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.DrawImage($Image, 0, 0, $Image.Width, $Image.Height)
    $g.Dispose()
    return $bmp
}

foreach ($job in $Jobs) {
    $sourcePath = Join-Path $SourceRoot $job.source
    $outputPath = Join-Path $OutputRoot $job.output
    if (-not (Test-Path $sourcePath)) { throw "Source not found: $sourcePath" }

    $loaded = [System.Drawing.Image]::FromFile($sourcePath)
    $src = Convert-To32bppArgb $loaded
    $loaded.Dispose()

    $w = $src.Width
    $h = $src.Height

    $rect = [System.Drawing.Rectangle]::new(0, 0, $w, $h)
    $data = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $data.Stride
    $byteCount = $stride * $h
    $bytes = New-Object byte[] $byteCount
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $byteCount)

    $minX = $w; $minY = $h; $maxX = -1; $maxY = -1
    for ($y = 0; $y -lt $h; $y++) {
        $rowOffset = $y * $stride
        for ($x = 0; $x -lt $w; $x++) {
            $offset = $rowOffset + $x * 4
            $b = [int]$bytes[$offset]
            $g = [int]$bytes[$offset + 1]
            $r = [int]$bytes[$offset + 2]
            $a = [int]$bytes[$offset + 3]
            # Green-dominant chroma key: AI green background has G much higher than R and B.
            # Threshold 50 keys out background (greenDominance ~160+); soft edge 25 handles anti-aliasing.
            $greenDom = $g - [Math]::Max($r, $b)
            if ($greenDom -ge $GreenThreshold) {
                $bytes[$offset + 3] = 0
                $a = 0
            } elseif ($greenDom -ge ($GreenThreshold - $SoftEdge)) {
                # Soft edge: fade alpha as green dominance approaches the threshold.
                $newAlpha = [int](($greenDom - ($GreenThreshold - $SoftEdge)) / $SoftEdge * 255)
                $newAlpha = 255 - $newAlpha
                if ($newAlpha -lt $a) { $bytes[$offset + 3] = $newAlpha; $a = $newAlpha }
            }
            if ($a -gt 0) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $data.Scan0, $byteCount)
    $src.UnlockBits($data)

    if ($maxX -lt 0) { $src.Dispose(); throw "No opaque pixels in $($job.key)" }

    # Apply 12px padding clamped to image bounds
    $cropX = [Math]::Max(0, $minX - $Pad)
    $cropY = [Math]::Max(0, $minY - $Pad)
    $cropR = [Math]::Min($w - 1, $maxX + $Pad)
    $cropB = [Math]::Min($h - 1, $maxY + $Pad)
    $cropW = $cropR - $cropX + 1
    $cropH = $cropB - $cropY + 1

    # Resize to fit inside 90x90 box maintaining aspect ratio
    $scale = [Math]::Min([double]$Box / $cropW, [double]$Box / $cropH)
    $resizeW = [int][Math]::Round($cropW * $scale)
    $resizeH = [int][Math]::Round($cropH * $scale)
    if ($resizeW -lt 1) { $resizeW = 1 }
    if ($resizeH -lt 1) { $resizeH = 1 }

    # Composite onto transparent 96x96 canvas, bottom center, 3px foot margin
    $outBmp = New-Object System.Drawing.Bitmap $Canvas, $Canvas, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g2 = [System.Drawing.Graphics]::FromImage($outBmp)
    $g2.Clear([System.Drawing.Color]::Transparent)
    $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g2.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g2.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $destX = [int](($Canvas - $resizeW) / 2)
    $destY = $Canvas - $FootMargin - $resizeH
    if ($destY -lt 0) { $destY = 0 }
    $cropRect = [System.Drawing.Rectangle]::new($cropX, $cropY, $cropW, $cropH)
    $destRect = [System.Drawing.Rectangle]::new($destX, $destY, $resizeW, $resizeH)
    $g2.DrawImage($src, $destRect, $cropRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g2.Dispose()
    $src.Dispose()

    # Validate dimensions
    if ($outBmp.Width -ne $Canvas -or $outBmp.Height -ne $Canvas) {
        $outBmp.Dispose(); throw "Output dimensions wrong for $($job.key)"
    }

    # Validate corner alpha <= 0.02
    $cornerSum = 0
    $cornerSum += [int]$outBmp.GetPixel(0, 0).A
    $cornerSum += [int]$outBmp.GetPixel($Canvas - 1, 0).A
    $cornerSum += [int]$outBmp.GetPixel(0, $Canvas - 1).A
    $cornerSum += [int]$outBmp.GetPixel($Canvas - 1, $Canvas - 1).A
    $cornerAvg = $cornerSum / 4.0 / 255.0
    if ($cornerAvg -gt 0.02) {
        $outBmp.Dispose(); throw "Corner alpha too high for $($job.key): $cornerAvg"
    }

    # Validate opaque bounds do not touch canvas edge
    $edgeOpaque = $false
    for ($x = 0; $x -lt $Canvas; $x++) {
        if ($outBmp.GetPixel($x, 0).A -gt 0 -or $outBmp.GetPixel($x, $Canvas - 1).A -gt 0) { $edgeOpaque = $true; break }
    }
    if (-not $edgeOpaque) {
        for ($y = 0; $y -lt $Canvas; $y++) {
            if ($outBmp.GetPixel(0, $y).A -gt 0 -or $outBmp.GetPixel($Canvas - 1, $y).A -gt 0) { $edgeOpaque = $true; break }
        }
    }
    if ($edgeOpaque) { $outBmp.Dispose(); throw "Opaque bounds touch canvas edge for $($job.key)" }

    # Save via MemoryStream + WriteAllBytes (sandbox-safe write)
    $ms = New-Object System.IO.MemoryStream
    $outBmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    [System.IO.File]::WriteAllBytes($outputPath, $ms.ToArray())
    $ms.Dispose()
    $outBmp.Dispose()

    Write-Host ("Processed {0,-14} art={1,3}x{2,-3} on 96x96 -> {3}" -f $job.key, $resizeW, $resizeH, $job.output)
}

Write-Host "All Chapter 1 unit sprites processed into $OutputRoot"
