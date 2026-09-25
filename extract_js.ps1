$c = [System.IO.File]::ReadAllText("index.html")
$s = $c.LastIndexOf("<script>")
$e = $c.LastIndexOf("</script>") + 9
$js = $c.Substring($s, $e - $s)
[System.IO.File]::WriteAllText("script_section.txt", $js)
Write-Host "Done, length: $($e - $s)"
