# claude-search.ps1 -- grep the config
param([Parameter(Mandatory)][string]$Keyword)
$claudeRoot = Join-Path $env:USERPROFILE '.claude'
$targets = @(
    (Join-Path $claudeRoot 'skills'),
    (Join-Path $claudeRoot 'agents'),
    (Join-Path $claudeRoot 'CLAUDE.md'),
    (Join-Path $claudeRoot 'memory'),
    (Join-Path $claudeRoot 'sessions-index')
) | Where-Object { Test-Path $_ }

$totalHits = 0
foreach ($t in $targets) {
    if (Test-Path $t -PathType Container) {
        $files = Get-ChildItem -Recurse -File $t -Include '*.md','*.json','*.ps1','*.py','*.bat' -ErrorAction SilentlyContinue
    } else {
        $files = @(Get-Item $t)
    }
    foreach ($f in $files) {
        $matches = Select-String -Path $f.FullName -Pattern $Keyword -SimpleMatch -ErrorAction SilentlyContinue
        if ($matches) {
            $totalHits += $matches.Count
            $rel = $f.FullName.Replace($claudeRoot, '~')
            Write-Host ""
            Write-Host "== $rel  ($($matches.Count) matches)" -ForegroundColor Cyan
            foreach ($m in $matches | Select-Object -First 5) {
                Write-Host "  $($m.LineNumber): $($m.Line.Trim())" -ForegroundColor Gray
            }
            if ($matches.Count -gt 5) { Write-Host "  ..." -ForegroundColor DarkGray }
        }
    }
}
Write-Host ""
Write-Host "Total: $totalHits matches" -ForegroundColor Green