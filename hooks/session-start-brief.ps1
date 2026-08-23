# session-start-brief.ps1 -- inject git status + last 5 commits as session context
$ErrorActionPreference = 'SilentlyContinue'
try {
    $isRepo = (git rev-parse --is-inside-work-tree 2>$null)
    if ($isRepo -ne 'true') { exit 0 }
    Write-Host "## Repo brief"
    Write-Host ""
    Write-Host "### branch"
    git rev-parse --abbrev-ref HEAD 2>&1 | ForEach-Object { Write-Host $_ }
    Write-Host ""
    Write-Host "### git status --short"
    git status --short 2>&1 | Select-Object -First 30 | ForEach-Object { Write-Host $_ }
    Write-Host ""
    Write-Host "### git log -5 --oneline"
    git log -5 --oneline 2>&1 | ForEach-Object { Write-Host $_ }
} catch { }
exit 0