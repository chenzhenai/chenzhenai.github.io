$ErrorActionPreference = "Stop"
hugo --minify --cleanDestinationDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$dirs = @("about", "agent", "archives", "infra", "papers", "posts", "roadmap", "search", "tags")
foreach ($dir in $dirs) {
    robocopy (Join-Path "docs" $dir) $dir /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy $dir failed: $LASTEXITCODE" }
}

Copy-Item docs\index.html, docs\404.html, docs\favicon.svg, docs\robots.txt, docs\sitemap.xml, docs\index.xml, docs\index.json, docs\.nojekyll -Destination . -Force
robocopy docs\assets assets /E /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy assets failed: $LASTEXITCODE" }
