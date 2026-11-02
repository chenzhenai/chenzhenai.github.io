$ErrorActionPreference = "Stop"
hugo --minify --cleanDestinationDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Git 会把 Windows 的 CRLF 存成 LF，浏览器会因为 integrity 对不上而丢掉样式。
$utf8 = New-Object System.Text.UTF8Encoding $false
Get-ChildItem docs -Recurse -Filter *.html -File | ForEach-Object {
    $text = [IO.File]::ReadAllText($_.FullName)
    $next = $text -replace ' integrity="[^"]*"', '' -replace ' crossorigin="anonymous"', '' -replace ' crossorigin=anonymous', ''
    if ($next -ne $text) { [IO.File]::WriteAllText($_.FullName, $next, $utf8) }
}

$dirs = @("about", "agent", "archives", "infra", "papers", "posts", "roadmap", "search", "tags")
foreach ($dir in $dirs) {
    robocopy (Join-Path "docs" $dir) $dir /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy $dir failed: $LASTEXITCODE" }
}

Copy-Item docs\index.html, docs\404.html, docs\favicon.svg, docs\robots.txt, docs\sitemap.xml, docs\index.xml, docs\index.json, docs\.nojekyll -Destination . -Force
robocopy docs\assets assets /E /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy assets failed: $LASTEXITCODE" }
