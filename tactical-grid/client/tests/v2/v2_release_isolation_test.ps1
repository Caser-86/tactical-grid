[CmdletBinding()]
param(
    [string]$BuildDirectory = 'build\TacticalGrid_V2_Infiltration',
    [string]$GodotPath = 'D:\Program Files\Godot\Godot_v4.7.1-stable_win64_console.exe'
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$buildPath = if ([System.IO.Path]::IsPathRooted($BuildDirectory)) { $BuildDirectory } else { Join-Path $projectRoot $BuildDirectory }
$buildRoot = (Resolve-Path $buildPath -ErrorAction SilentlyContinue).Path
if ([string]::IsNullOrWhiteSpace($buildRoot)) {
	$buildRoot = [System.IO.Path]::GetFullPath($buildPath)
}

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "V2 release isolation failed: $Message" }
}

$projectConfig = Get-Content (Join-Path $projectRoot 'project.godot') -Raw
Assert-Condition ($projectConfig -match 'config/name="Tactical Grid V2: Infiltration"') 'project name is not V2'
Assert-Condition ($projectConfig -match 'run/main_scene="res://scenes/v2_boot\.tscn"') 'main scene is not v2_boot.tscn'
Assert-Condition ($projectConfig -match 'config/custom_user_dir_name="TacticalGrid_V2_Infiltration"') 'custom user directory is not V2'
Assert-Condition ($projectConfig -match 'product_line="v2_infiltration"') 'product line is not V2'

$exePath = Join-Path $buildRoot 'TacticalGrid_V2_Infiltration.exe'
$pckPath = Join-Path $buildRoot 'TacticalGrid_V2_Infiltration.pck'
Assert-Condition (Test-Path -LiteralPath $exePath -PathType Leaf) "missing V2 executable: $exePath"
Assert-Condition (Test-Path -LiteralPath $pckPath -PathType Leaf) "missing V2 resource pack: $pckPath"

foreach ($legacyName in @('TacticalGrid.exe', 'TacticalGrid.pck', 'TacticalGrid.console.exe', 'TacticalGrid_V2_Infiltration.console.exe')) {
    Assert-Condition (-not (Test-Path -LiteralPath (Join-Path $buildRoot $legacyName))) "legacy/development file remains: $legacyName"
}

Assert-Condition (Test-Path -LiteralPath $GodotPath -PathType Leaf) "Godot executable not found: $GodotPath"
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exePath
$psi.Arguments = '--headless --quit-after 5'
$psi.WorkingDirectory = $buildRoot
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$process = [System.Diagnostics.Process]::Start($psi)
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
if (-not $process.WaitForExit(30000)) {
    try { $process.Kill() } catch {}
    throw 'V2 packaged executable did not exit within 30 seconds'
}
$combined = $stdoutTask.Result + "`n" + $stderrTask.Result
Assert-Condition ($process.ExitCode -eq 0) "V2 packaged executable exit code: $($process.ExitCode)"
Assert-Condition ($combined -notmatch 'SCRIPT ERROR|Parse Error|ERROR:') 'V2 packaged executable emitted a startup error'

Write-Host 'V2 release isolation passed'
Write-Host "  Build: $buildRoot"
Write-Host '  Entry: scenes/v2_boot.tscn'
Write-Host '  User directory: TacticalGrid_V2_Infiltration'
