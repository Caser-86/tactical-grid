$files = Get-ChildItem -Path ".\tactical-grid\client\data\*.json"
$results = @()
foreach ($f in $files) {
    try {
        $content = Get-Content $f.FullName -Raw -Encoding UTF8
        $j = $content | ConvertFrom-Json
        $line = "OK: $($f.Name) ($($j.PSObject.Properties.Count) top-level props)"
    } catch {
        $line = "ERROR: $($f.Name) - $($_.Exception.Message)"
    }
    $results += $line
}
$results | Out-File -FilePath ".\check_json_results.txt" -Encoding utf8
Get-Content ".\check_json_results.txt"
