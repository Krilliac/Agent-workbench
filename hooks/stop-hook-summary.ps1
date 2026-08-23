# stop-hook-summary.ps1 -- append a session-index entry on session end
$ErrorActionPreference = 'SilentlyContinue'
try {
    $sid = $env:CLAUDE_SESSION_ID
    if (-not $sid) { exit 0 }
    $dir = Join-Path $env:USERPROFILE '.claude\sessions-index'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $file = Join-Path $dir "$sid.md"
    $now = Get-Date -Format 'o'
    $cwd = (Get-Location).Path
    $lines = @(
        "# Session $sid"
        ""
        "- Ended: $now"
        "- CWD: $cwd"
        ""
        "## Notes"
        ""
        "_(auto-generated stop-hook summary)_"
    )
    $lines | Set-Content -Path $file -Encoding UTF8
} catch { }
exit 0