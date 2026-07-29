<# Generates the original Mag-Rail Transit Hub runtime environment kit. #>
[CmdletBinding()]
param([string]$OutputRoot = (Join-Path $PSScriptRoot '..\assets\generated\chapter1\runtime\environment\transit_hub'))

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-Canvas([int]$Width = 64, [int]$Height = 64, [bool]$Opaque = $false) {
    $bitmap = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear($(if ($Opaque) { [System.Drawing.Color]::FromArgb(255, 29, 36, 42) } else { [System.Drawing.Color]::Transparent }))
    return @($bitmap, $graphics)
}
function Brush([string]$Hex, [int]$Alpha = 255) { $c = [System.Drawing.ColorTranslator]::FromHtml($Hex); return [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb($Alpha, $c.R, $c.G, $c.B)) }
function Pen([string]$Hex, [single]$Width = 1, [int]$Alpha = 255) { $c = [System.Drawing.ColorTranslator]::FromHtml($Hex); return [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb($Alpha, $c.R, $c.G, $c.B), $Width) }
function Save-Canvas($Canvas, [string]$Relative) { $path = Join-Path $OutputRoot $Relative; New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null; $Canvas[1].Dispose(); $Canvas[0].Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $Canvas[0].Dispose() }
function Line($G, [string]$Hex, [single]$Width, [int]$X1, [int]$Y1, [int]$X2, [int]$Y2, [int]$Alpha = 255) { $p = Pen $Hex $Width $Alpha; $G.DrawLine($p, $X1, $Y1, $X2, $Y2); $p.Dispose() }

for ($i = 0; $i -lt 8; $i++) {
    $c = New-Canvas 64 64 $true; $g = $c[1]
    $fill = Brush @('#3c474c','#454f53','#1f4d50','#5b4a25','#465155','#26363d','#34383b','#35494a')[$i]
    $g.FillRectangle($fill, 2, 2, 60, 60); $fill.Dispose()
    Line $g '#9aa8a7' 1 2 2 62 2 100; Line $g '#9aa8a7' 1 2 62 62 62 100
    if ($i -eq 1 -or $i -eq 5) { for ($x = 8; $x -lt 64; $x += 12) { Line $g '#172126' 2 $x 4 $x 60 190 } }
    if ($i -eq 2) { $b = Brush '#3de0ae' 180; $g.FillRectangle($b, 4, 27, 56, 10); $b.Dispose(); Line $g '#b7fff1' 1 8 32 56 32 220 }
    if ($i -eq 3) { $b = Brush '#e5ae3e' 185; $g.FillRectangle($b, 4, 27, 56, 10); $b.Dispose(); for ($x = 10; $x -lt 55; $x += 12) { Line $g '#302614' 3 $x 28 ($x + 8) 36 220 } }
    if ($i -eq 4) { for ($y = 10; $y -lt 60; $y += 12) { Line $g '#a9b7b4' 2 5 $y 59 $y 150 } }
    if ($i -eq 6) { for ($x = 10; $x -lt 60; $x += 16) { Line $g '#12181c' 2 $x 4 ($x - 12) 60 120 } }
    if ($i -eq 7) { $b = Brush '#fae28a' 145; $g.FillEllipse($b, 10, 20, 44, 22); $b.Dispose() }
    Save-Canvas $c ("floor/floor_{0:d2}.png" -f $i)
}

$edges = @('north','east','south','west','corner_nw','corner_ne','corner_se','corner_sw')
for ($i = 0; $i -lt $edges.Count; $i++) {
    $c = New-Canvas; $g = $c[1]; $p = Pen '#45dcae' 4 220
    switch ($i) { 0 { $g.DrawLine($p,0,4,64,4) } 1 { $g.DrawLine($p,60,0,60,64) } 2 { $g.DrawLine($p,0,60,64,60) } 3 { $g.DrawLine($p,4,0,4,64) } 4 { $g.DrawArc($p,2,2,56,56,180,90) } 5 { $g.DrawArc($p,6,2,56,56,270,90) } 6 { $g.DrawArc($p,6,6,56,56,0,90) } 7 { $g.DrawArc($p,2,6,56,56,90,90) } }
    $p.Dispose(); Save-Canvas $c ("edge/edge_{0}.png" -f $edges[$i])
}

for ($i = 0; $i -lt 6; $i++) {
    $c = New-Canvas; $g = $c[1]; $frame = Brush '#23343a'; $accent = Brush @('#64d2b0','#e0b451','#57c0d7','#cf7251','#aebdc1','#6e8b8b')[$i]
    switch ($i) { 0 { $g.FillRectangle($frame,10,16,44,36); $g.FillRectangle($accent,14,20,36,26) } 1 { $g.FillRectangle($frame,7,34,50,16); $g.FillRectangle($accent,12,28,40,12) } 2 { $g.FillRectangle($frame,16,10,32,44); $g.FillRectangle($accent,21,16,22,16) } 3 { $g.FillRectangle($frame,4,42,56,12); $g.FillRectangle($accent,8,44,48,5) } 4 { $g.FillRectangle($frame,8,24,48,26); $g.FillEllipse($accent,14,28,16,16); $g.FillEllipse($accent,34,28,16,16) } 5 { $g.FillRectangle($frame,24,8,16,48); $g.FillEllipse($accent,19,14,26,16) } }
    $frame.Dispose(); $accent.Dispose(); Save-Canvas $c ("prop/prop_{0:d2}.png" -f $i)
}

for ($i = 0; $i -lt 3; $i++) { $c = New-Canvas; $g = $c[1]; if ($i -eq 0) { Line $g '#d9ac45' 3 8 32 56 32 190; Line $g '#d9ac45' 3 32 8 32 56 190 } elseif ($i -eq 1) { Line $g '#27343a' 5 8 54 56 12 180 } else { Line $g '#59e5bb' 2 8 8 56 56 170 }; Save-Canvas $c ("decal/decal_{0:d2}.png" -f $i) }

$c = New-Canvas 192 128; $g = $c[1]; $body = Brush '#e5eeee'; $glass = Brush '#59dbd0'; $g.FillRectangle($body,16,40,160,64); $g.FillEllipse($body,24,12,144,80); $g.FillEllipse($glass,46,25,100,45); $body.Dispose(); $glass.Dispose(); Line $g '#28363c' 3 16 104 176 104; Save-Canvas $c 'landmark/suspended_train_nose_192x128.png'
$c = New-Canvas 128 128; $g = $c[1]; Line $g '#35474d' 7 20 116 20; Line $g '#35474d' 6 30 20 115; Line $g '#35474d' 6 98 116 115; $lamp = Brush '#4ce1ae'; $g.FillEllipse($lamp,15,12,14,14); $g.FillEllipse($lamp,99,12,14,14); $lamp.Dispose(); Save-Canvas $c 'landmark/signal_gantry_128.png'
