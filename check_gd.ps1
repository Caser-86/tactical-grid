$results = @()
$files = Get-ChildItem -Path ".\tactical-grid\client\scripts\**\*.gd" -Recurse
foreach ($f in $files) {
    $content = Get-Content $f.FullName -Raw -Encoding UTF8
    # Check for BOM
    $bom = ""
    if ($content.Length -gt 0 -and $content[0] -eq [char]0xFEFF) {
        $bom = "[BOM]"
    }
    # Check for old GDScript 3 dict syntax
    $g3syntax = ""
    if ($content -match '\{[a-zA-Z_]+\s*=\s*[^:}]') {
        $g3syntax = "[G3-SYNTAX?]"
    }
    # Check for empty files
    $empty = ""
    if ($content.Trim().Length -eq 0) {
        $empty = "[EMPTY]"
    }
    # Count extends / class_name
    $extends = ""
    if ($content -notmatch 'extends|class_name') {
        $extends = "[NO-EXTENDS]"
    }
    $line = "$($f.Name) lines=$($content.Split([char]10).Count) $bom$g3syntax$empty$extends"
    $results += $line
}
$results | Out-File -FilePath ".\check_gd_results.txt" -Encoding utf8
Get-Content ".\check_gd_results.txt" | Select-Object -First 100
