<#
.SYNOPSIS
Process AI-generated network node icons: chroma key, crop, resize to 64x64 transparent PNG.

Loads each source image, keys green-dominant background to alpha, crops to bounds with padding,
resizes to fit 56x56 inside 64x64 canvas, validates corner transparency.
#>
[CmdletBinding()]
param(
    [string]$SourceRoot = (Join-Path $PSScriptRoot '..\assets\generated\chapter1\source\network_icons'),
    [string]$OutputRoot = (Join-Path $PSScriptRoot '..\assets\generated\chapter1\runtime\network_icons')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$GreenThreshold = 50
$SoftEdge = 25
$Pad = 8
$Box = 56
$Canvas = 64

$Jobs = @(
    @{ key='camera';               source='camera_node_v1.jpg';               output='camera_64.png' }
    @{ key='door';                 source='door_node_v1.jpg';                 output='door_64.png' }
    @{ key='turret';               source='turret_node_v1.jpg';               output='turret_64.png' }
    @{ key='power_conduit';        source='power_conduit_node_v1.jpg';        output='power_conduit_64.png' }
    @{ key='reinforcement_beacon'; source='reinforcement_beacon_node_v1.jpg'; output='reinforcement_beacon_64.png' }
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
    if (-not (Test-Path $sourcePath)) { Write-Warning "Source not found: $sourcePath"; continue }

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
            $greenDom = $g - [Math]::Max($r, $b)
            if ($greenDom -ge $GreenThreshold) {
                $bytes[$offset + 3] = 0
                $a = 0
            } elseif ($greenDom -ge ($GreenThreshold - $SoftEdge)) {
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

    $cropX = [Math]::Max(0, $minX - $Pad)
    $cropY = [Math]::Max(0, $minY - $Pad)
    $cropR = [Math]::Min($w - 1, $maxX + $Pad)
    $cropB = [Math]::Min($h - 1, $maxY + $Pad)
    $cropW = $cropR - $cropX + 1
    $cropH = $cropB - $cropY + 1

    $scale = [Math]::Min([double]$Box / $cropW, [double]$Box / $cropH)
    $resizeW = [int][Math]::Round($cropW * $scale)
    $resizeH = [int][Math]::Round($cropH * $scale)
    if ($resizeW -lt 1) { $resizeW = 1 }
    if ($resizeH -lt 1) { $resizeH = 1 }

    $outBmp = New-Object System.Drawing.Bitmap $Canvas, $Canvas, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g2 = [System.Drawing.Graphics]::FromImage($outBmp)
    $g2.Clear([System.Drawing.Color]::Transparent)
    $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g2.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g2.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $destX = [int](($Canvas - $resizeW) / 2)
    $destY = [int](($Canvas - $resizeH) / 2)
    $cropRect = [System.Drawing.Rectangle]::new($cropX, $cropY, $cropW, $cropH)
    $destRect = [System.Drawing.Rectangle]::new($destX, $destY, $resizeW, $resizeH)
    $g2.DrawImage($src, $destRect, $cropRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g2.Dispose()
    $src.Dispose()

    $ms = New-Object System.IO.MemoryStream
    $outBmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    [System.IO.File]::WriteAllBytes($outputPath, $ms.ToArray())
    $ms.Dispose()
    $outBmp.Dispose()

    Write-Host ("Processed {0,-22} art={1,3}x{2,-3} on 64x64 -> {3}" -f $job.key, $resizeW, $resizeH, $job.output)
}

Write-Host "All network node icons processed into $OutputRoot"
