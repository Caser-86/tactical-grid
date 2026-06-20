$results = @()
$files = Get-ChildItem -Path ".\tactical-grid\client\scripts\**\*.gd" -Recurse
foreach ($f in $files) {
    $content = Get-Content $f.FullName -Raw -Encoding UTF8
    $hasClassName = $content -match '^class_name\s+\w+'
    $hasExtends = $content -match '^extends\s+'
    if ($hasClassName -and -not $hasExtends) {
        $results += "MISSING_EXTENDS: $($f.Name)"
    }
}
$results | Out-File -FilePath ".\extends_check.txt" -Encoding utf8
"Files with class_name without extends: $($results.Count)"
$results
