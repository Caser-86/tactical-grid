param(
    [string]$GodotExe = "godot"
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\.." )).Path
$scene = "res://tests/v2/v2_m1_e2e_test.tscn"
$routes = @("main_direct", "optional_record", "checkpoint_retry")
$totalAssertions = 0

foreach ($route in $routes) {
    Write-Host "=== M112 isolated process: $route ==="
    # Godot emits non-fatal leak diagnostics on stderr. Treat them as captured
    # test output, then explicitly validate the route result below.
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = @(& $GodotExe --headless --path $projectRoot $scene -- "--v2-m1-e2e-route=$route" 2>&1 | ForEach-Object { [string]$_ })
    $ErrorActionPreference = $previousErrorAction
    $exitCode = $LASTEXITCODE
    $routeHeaders = @($output | Where-Object { $_ -match '^--- M112 route:' })
    $requestedHeaders = @($output | Where-Object { $_ -eq "--- M112 route: $route ---" })
    $passedLines = @($output | Where-Object { $_ -match '^Passed:\s*(\d+)' })
    $failedLines = @($output | Where-Object { $_ -match '^Failed:\s*(\d+)' })

    if ($exitCode -ne 0 -or $routeHeaders.Count -ne 1 -or $requestedHeaders.Count -ne 1 -or $failedLines.Count -ne 1 -or $failedLines[-1] -notmatch '^Failed:\s*0') {
        $output | Select-Object -Last 40 | ForEach-Object { Write-Host $_ }
        throw "M112 route '$route' did not run as one independent passing Godot process. exit=$exitCode routes=$($routeHeaders.Count) requested=$($requestedHeaders.Count)"
    }

    if ($passedLines[-1] -match '^Passed:\s*(\d+)') {
        $totalAssertions += [int]$Matches[1]
    }
    $output | Where-Object { $_ -match '^WARNING:' -or $_ -match '^ERROR:.*(leaked|resources still in use)' } | ForEach-Object { Write-Host $_ }
}

Write-Host "Passed: $totalAssertions"
Write-Host "Failed: 0"
