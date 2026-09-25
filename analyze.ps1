# Script to replace localStorage with Firebase in index.html
$content = [System.IO.File]::ReadAllText("index.html")

# Find the script tag position
$scriptStart = $content.LastIndexOf("<script>")
$scriptEnd = $content.LastIndexOf("</script>") + 9

# Write the original JS for inspection
$jsContent = $content.Substring($scriptStart, $scriptEnd - $scriptStart)
[System.IO.File]::WriteAllText("original_js.txt", $jsContent)

Write-Host "Script section: chars $scriptStart to $scriptEnd"
Write-Host "Script length: $($jsContent.Length) chars"

# Find specific localStorage patterns
$patterns = @("localStorage", "STORAGE_KEY", "loadSaved", "saveSaved", "addSavedToData", "admin-note")
foreach ($p in $patterns) {
    $idx = $jsContent.IndexOf($p)
    Write-Host "Pattern '$p' at position $idx in script"
}
