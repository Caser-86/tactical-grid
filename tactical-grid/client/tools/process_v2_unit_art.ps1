<#
.SYNOPSIS
Deterministically normalizes V2 unit direction art.

The source images are generated with true alpha. This tool removes only near-zero
alpha haze, removes only edge-connected near-black/near-white backgrounds when a
generator has baked one into an opaque PNG, crops transparent bounds, and places
every subject on the same 128x128 runtime canvas with a shared bottom-center
anchor. It does not alter the existing V2 directionless art or any V1 asset.
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
$BackgroundTolerance = 54

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;

public static class V2EdgeBackgroundRemoval
{
    private static int RowOffset(int y, int height, int stride)
    {
        int rowStride = Math.Abs(stride);
        return stride >= 0 ? y * rowStride : (height - 1 - y) * rowStride;
    }

    private static bool IsBackground(byte[] bytes, int x, int y, int width, int height, int stride)
    {
        int offset = RowOffset(y, height, stride) + x * 4;
        int r = bytes[offset];
        int g = bytes[offset + 1];
        int b = bytes[offset + 2];
        int max = Math.Max(r, Math.Max(g, b));
        int min = Math.Min(r, Math.Min(g, b));
        return (min >= 220 && max - min <= 24) || (max <= 42 && max - min <= 32);
    }

    private static void Enqueue(Queue<int> queue, bool[] visited, int x, int y, int width, int height)
    {
        if (x < 0 || x >= width || y < 0 || y >= height) return;
        int index = y * width + x;
        if (visited[index]) return;
        visited[index] = true;
        queue.Enqueue(index);
    }

    public static void Remove(byte[] bytes, int width, int height, int stride)
    {
        bool[] visited = new bool[width * height];
        Queue<int> queue = new Queue<int>();
        for (int x = 0; x < width; x++)
        {
            Enqueue(queue, visited, x, 0, width, height);
            Enqueue(queue, visited, x, height - 1, width, height);
        }
        for (int y = 1; y < height - 1; y++)
        {
            Enqueue(queue, visited, 0, y, width, height);
            Enqueue(queue, visited, width - 1, y, width, height);
        }

        while (queue.Count > 0)
        {
            int index = queue.Dequeue();
            int x = index % width;
            int y = index / width;
            if (!IsBackground(bytes, x, y, width, height, stride)) continue;
            int offset = RowOffset(y, height, stride) + x * 4;
            bytes[offset + 3] = 0;
            Enqueue(queue, visited, x - 1, y, width, height);
            Enqueue(queue, visited, x + 1, y, width, height);
            Enqueue(queue, visited, x, y - 1, width, height);
            Enqueue(queue, visited, x, y + 1, width, height);
        }
    }
}
"@

$Jobs = @(
    Get-ChildItem -LiteralPath $SourceRoot -Recurse -Filter '*_source_2026-08-15.png' |
        Sort-Object FullName |
        ForEach-Object {
            $key = $_.BaseName -replace '_source_2026-08-15$', ''
            @{ key = $key; source = $_.FullName; output = "${key}_128.png" }
        }
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

function Test-EdgeBackgroundPixel {
    param(
        [int]$X,
        [int]$Y,
        [byte[]]$Bytes,
        [int]$Width,
        [int]$Height,
        [int]$Stride,
        [int]$Tolerance
    )
    $rowOffset = Get-RowOffset $Y $Height $Stride
    $offset = $rowOffset + $X * 4
    $r = [int]$Bytes[$offset]
    $g = [int]$Bytes[$offset + 1]
    $b = [int]$Bytes[$offset + 2]
    $max = [Math]::Max($r, [Math]::Max($g, $b))
    $min = [Math]::Min($r, [Math]::Min($g, $b))
    if ($min -ge 220 -and ($max - $min) -le 24) { return $true }
    if ($max -le 42 -and ($max - $min) -le 32) { return $true }
    return $false
}

function Remove-EdgeConnectedBackground {
    param(
        [byte[]]$Bytes,
        [int]$Width,
        [int]$Height,
        [int]$Stride,
        [int]$Tolerance
    )
    $visited = New-Object bool[] ($Width * $Height)
    $queue = New-Object 'System.Collections.Generic.Queue[System.Drawing.Point]'

    function Enqueue-BackgroundPoint {
        param([int]$X, [int]$Y)
        if ($X -lt 0 -or $X -ge $Width -or $Y -lt 0 -or $Y -ge $Height) { return }
        $index = $Y * $Width + $X
        if ($visited[$index]) { return }
        $visited[$index] = $true
        $queue.Enqueue([System.Drawing.Point]::new($X, $Y))
    }

    for ($x = 0; $x -lt $Width; $x++) {
        Enqueue-BackgroundPoint $x 0
        Enqueue-BackgroundPoint $x ($Height - 1)
    }
    for ($y = 1; $y -lt ($Height - 1); $y++) {
        Enqueue-BackgroundPoint 0 $y
        Enqueue-BackgroundPoint ($Width - 1) $y
    }

    while ($queue.Count -gt 0) {
        $point = $queue.Dequeue()
        $index = $point.Y * $Width + $point.X
        if (-not (Test-EdgeBackgroundPixel $point.X $point.Y $Bytes $Width $Height $Stride $Tolerance)) { continue }

        $rowOffset = Get-RowOffset $point.Y $Height $Stride
        $offset = $rowOffset + $point.X * 4
        $Bytes[$offset + 3] = 0
        Enqueue-BackgroundPoint ($point.X - 1) $point.Y
        Enqueue-BackgroundPoint ($point.X + 1) $point.Y
        Enqueue-BackgroundPoint $point.X ($point.Y - 1)
        Enqueue-BackgroundPoint $point.X ($point.Y + 1)
    }
}

foreach ($job in $Jobs) {
    $sourcePath = $job.source
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

    $hasTransparency = $false
    $minX = $width
    $minY = $height
    $maxX = -1
    $maxY = -1
    for ($y = 0; $y -lt $height; $y++) {
        $rowOffset = Get-RowOffset $y $height $data.Stride
        for ($x = 0; $x -lt $width; $x++) {
            $offset = $rowOffset + $x * 4
            $alpha = [int]$bytes[$offset + 3]
            if ($alpha -lt 255) { $hasTransparency = $true }
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
    if (-not $hasTransparency) {
        [V2EdgeBackgroundRemoval]::Remove($bytes, $width, $height, $data.Stride)
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

Write-Host "V2 direction art written to $OutputRoot"
