# new-skill.ps1 -- scaffold a new global skill
param(
    [Parameter(Mandatory)][string]$Name,
    [string]$Category = 'general',
    [string]$Description = ''
)
$claudeRoot = Join-Path $env:USERPROFILE '.claude'
$dir = Join-Path $claudeRoot "skills\$Name"
if (Test-Path $dir) { Write-Host "Exists: $dir" -ForegroundColor Yellow; exit 1 }
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$md = Join-Path $dir 'SKILL.md'
$desc = if ($Description) { $Description } else { "TODO: trigger-rich description. TRIGGER when the user says <A>, <B>, <C>. DO NOT TRIGGER for <adjacent concern>. Focused on: TODO." }
$content = @"
---
name: $Name
description: $desc
category: $Category
---

# $Name

TODO: skill body.
- One-sentence mental model.
- 3-8 sections: capture, analyze, fix, gotchas, method.
- Cite exact commands.
- Method section: ordered steps.
"@
$content | Set-Content -Path $md -Encoding UTF8 -NoNewline
Write-Host "Created: $md" -ForegroundColor Green