<#
.SYNOPSIS
Process a single AI-generated landmark source image: chroma key, crop, resize to 192x128 transparent PNG.
#>
[CmdletBinding()]
param(
    [string]$SourcePath = (Join-Path $PSScriptRoot '..\assets\generated\chapter1\source\landmarks\echo_yard_gantry_crane_v1.jpg'),
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\assets\generated\chapter1\runtime\environment\echo_yard\landmark\gantry_crane_192x128.png'),
    [int]$TargetWidth = 192,
    [int]$TargetHeight = 128
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$outputDir = Split-Path $OutputPath -Parent
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$GreenThreshold = 50
$SoftEdge = 25
$Pad = 12

$loaded = [System.Drawing.Image]::FromFile($SourcePath)
$bmp = New-Object System.Drawing.Bitmap $loaded.Width, $loaded.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.DrawImage($loaded, 0, 0, $loaded.Width, $loaded.Height)
$g.Dispose()
$loaded.Dispose()

$w = $bmp.Width
$h = $bmp.Height
$rect = [System.Drawing.Rectangle]::new(0, 0, $w, $h)
$data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
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
        $gr = [int]$bytes[$offset + 1]
        $r = [int]$bytes[$offset + 2]
        $a = [int]$bytes[$offset + 3]
        $greenDom = $gr - [Math]::Max($r, $b)
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
$bmp.UnlockBits($data)

if ($maxX -lt 0) { $bmp.Dispose(); throw "No opaque pixels in landmark source" }

$cropX = [Math]::Max(0, $minX - $Pad)
$cropY = [Math]::Max(0, $minY - $Pad)
$cropR = [Math]::Min($w - 1, $maxX + $Pad)
$cropB = [Math]::Min($h - 1, $maxY + $Pad)
$cropW = $cropR - $cropX + 1
$cropH = $cropB - $cropY + 1

$outBmp = New-Object System.Drawing.Bitmap $TargetWidth, $TargetHeight, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g2 = [System.Drawing.Graphics]::FromImage($outBmp)
$g2.Clear([System.Drawing.Color]::Transparent)
$g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g2.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g2.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

$scale = [Math]::Min([double]$TargetWidth / $cropW, [double]$TargetHeight / $cropH)
$resizeW = [int][Math]::Round($cropW * $scale)
$resizeH = [int][Math]::Round($cropH * $scale)
$destX = [int](($TargetWidth - $resizeW) / 2)
$destY = [int](($TargetHeight - $resizeH) / 2)
$cropRect = [System.Drawing.Rectangle]::new($cropX, $cropY, $cropW, $cropH)
$destRect = [System.Drawing.Rectangle]::new($destX, $destY, $resizeW, $resizeH)
$g2.DrawImage($bmp, $destRect, $cropRect, [System.Drawing.GraphicsUnit]::Pixel)
$g2.Dispose()
$bmp.Dispose()

$ms = New-Object System.IO.MemoryStream
$outBmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
[System.IO.File]::WriteAllBytes($OutputPath, $ms.ToArray())
$ms.Dispose()
$outBmp.Dispose()

Write-Host "Processed landmark: art=${resizeW}x${resizeH} on ${TargetWidth}x${TargetHeight} -> $OutputPath"
