param(
    [string]$BuildDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'build')
)

$exePath = Join-Path $BuildDirectory 'TacticalGrid.exe'
$pckPath = Join-Path $BuildDirectory 'TacticalGrid.pck'
$consoleWrapper = Join-Path $BuildDirectory 'TacticalGrid.console.exe'

if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
    throw "Missing Windows executable: $exePath"
}
if (-not (Test-Path -LiteralPath $pckPath -PathType Leaf)) {
    throw "Missing Godot resource pack: $pckPath"
}
if (Test-Path -LiteralPath $consoleWrapper) {
    throw "Development console wrapper must not ship: $consoleWrapper"
}

$exe = Get-Item -LiteralPath $exePath
$pck = Get-Item -LiteralPath $pckPath
if ($exe.Length -lt 20MB) {
    throw "Windows executable is unexpectedly small: $($exe.Length) bytes"
}
if ($pck.Length -lt 5MB) {
    throw "Godot resource pack is unexpectedly small: $($pck.Length) bytes"
}

$version = $exe.VersionInfo
if ($version.ProductName -ne 'Tactical Grid') {
    throw "Unexpected ProductName: $($version.ProductName)"
}
if ($version.ProductVersion -ne '1.0.0.0') {
    throw "Unexpected ProductVersion: $($version.ProductVersion)"
}
if ($version.FileDescription -ne 'Turn-Based Tactical Strategy') {
    throw "Unexpected FileDescription: $($version.FileDescription)"
}

$manifest = [ordered]@{
    generated_at_utc = [DateTime]::UtcNow.ToString('o')
    product = $version.ProductName
    version = $version.ProductVersion
    files = @(
        [ordered]@{
            name = $exe.Name
            bytes = $exe.Length
            sha256 = (Get-FileHash -LiteralPath $exePath -Algorithm SHA256).Hash.ToLowerInvariant()
        },
        [ordered]@{
            name = $pck.Name
            bytes = $pck.Length
            sha256 = (Get-FileHash -LiteralPath $pckPath -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    )
}

$manifestPath = Join-Path $BuildDirectory 'release_manifest.json'
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exePath
$psi.Arguments = '--headless --quit-after 5'
$psi.WorkingDirectory = $BuildDirectory
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$process = [System.Diagnostics.Process]::Start($psi)
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
if (-not $process.WaitForExit(30000)) {
    try { $process.Kill() } catch {}
    throw 'Packaged executable did not exit within 30 seconds'
}
$stdout = $stdoutTask.Result
$stderr = $stderrTask.Result
if ($process.ExitCode -ne 0) {
    throw "Packaged executable cold start failed with exit code $($process.ExitCode)`n$stdout`n$stderr"
}
$combined = $stdout + "`n" + $stderr
if ($combined -match 'SCRIPT ERROR|Parse Error|ERROR:') {
    throw "Packaged executable emitted an error during cold start:`n$combined"
}

Write-Host 'Windows package verification passed'
Write-Host "  EXE: $($exe.Length) bytes"
Write-Host "  PCK: $($pck.Length) bytes"
Write-Host "  Manifest: $manifestPath"
