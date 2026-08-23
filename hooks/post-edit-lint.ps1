# post-edit-lint.ps1 -- lint edited SKILL.md via skill-linter if present
$ErrorActionPreference = 'SilentlyContinue'
try {
    $edited = $env:CLAUDE_EDITED_FILE
    if (-not $edited) { exit 0 }
    if ($edited -notmatch '\.md$') { exit 0 }
    $skillsRoot = Join-Path $env:USERPROFILE '.claude\skills'
    if ($edited -notlike "$skillsRoot*") { exit 0 }
    $linter = Join-Path $env:USERPROFILE '.claude\skills\skill-linter\scripts\skill-lint.ps1'
    if (Test-Path $linter) {
        $result = & $linter $edited 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[post-edit-lint] Warning: $edited" -ForegroundColor Yellow
            $result | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
        }
    }
} catch { }
exit 0
