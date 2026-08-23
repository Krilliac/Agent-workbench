# new-agent.ps1 -- scaffold a new global agent
param(
    [Parameter(Mandatory)][string]$Name,
    [string]$Description = '',
    [string]$Tools = '"*"'
)
$claudeRoot = Join-Path $env:USERPROFILE '.claude'
$dir = Join-Path $claudeRoot 'agents'
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$file = Join-Path $dir "$Name.md"
if (Test-Path $file) { Write-Host "Exists: $file" -ForegroundColor Yellow; exit 1 }
$desc = if ($Description) { $Description } else { "TODO: agent's specialty in one sentence." }
$content = @"
---
name: $Name
description: $desc
tools: $Tools
---

You are $Name.

TODO: role in 2-3 sentences.

## What you do
1. TODO.
2. TODO.

## Output
TODO.

## Rules
- TODO.
"@
$content | Set-Content -Path $file -Encoding UTF8 -NoNewline
Write-Host "Created: $file" -ForegroundColor Green