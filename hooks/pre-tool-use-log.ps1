# pre-tool-use-log.ps1 -- log every tool call to session-logs/YYYY-MM-DD.jsonl
$ErrorActionPreference = 'SilentlyContinue'
try {
    $payload = @{
        ts = (Get-Date -Format 'o')
        session_id = $env:CLAUDE_SESSION_ID
        cwd = (Get-Location).Path
        tool = $env:CLAUDE_TOOL_NAME
        args_hash = $env:CLAUDE_TOOL_ARGS_HASH
    }
    $line = $payload | ConvertTo-Json -Compress
    $logDir = Join-Path $env:USERPROFILE '.claude\session-logs'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $today = Get-Date -Format 'yyyy-MM-dd'
    Add-Content -Path (Join-Path $logDir "$today.jsonl") -Value $line
} catch { }
exit 0