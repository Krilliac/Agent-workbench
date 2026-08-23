<#
.SYNOPSIS
  Lint Claude Code SKILL.md files against the Fable-5 authoring discipline.
.DESCRIPTION
  Walks a directory looking for SKILL.md, or lints a single file if -Path points at one.
  Exit codes: 0 clean, 1 warnings only, 2 errors present.
.PARAMETER Path
  Directory to walk, or a single SKILL.md file. Defaults to $HOME\.claude\skills.
.PARAMETER Strict
  Treat warnings as errors.
#>
[CmdletBinding()]
param(
  [string]$Path = (Join-Path $env:USERPROFILE '.claude\skills'),
  [switch]$Strict
)

$ErrorActionPreference = 'Continue'

if (-not (Test-Path $Path)) {
  Write-Host "skill-lint: path not found: $Path" -ForegroundColor Red
  exit 2
}

$files = if ((Get-Item $Path).PSIsContainer) {
  Get-ChildItem -Path $Path -Recurse -Filter 'SKILL.md' -File
} else {
  @(Get-Item $Path)
}

if (-not $files -or $files.Count -eq 0) {
  Write-Host "skill-lint: no SKILL.md files found under $Path" -ForegroundColor Yellow
  exit 1
}

$totalErr = 0
$totalWarn = 0

foreach ($f in $files) {
  $rel = $f.FullName
  $lines = Get-Content -Path $f.FullName -Encoding UTF8
  $folder = Split-Path -Parent $f.FullName | Split-Path -Leaf

  $errs = @()
  $warns = @()

  # 1. YAML frontmatter present
  if ($lines.Count -lt 3 -or $lines[0] -ne '---') {
    $errs += "no YAML frontmatter (first line is not '---')"
  } else {
    # find closing ---
    $close = -1
    for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i] -eq '---') { $close = $i; break } }
    if ($close -lt 0) {
      $errs += "YAML frontmatter never closes"
    } else {
      $fm = $lines[1..($close - 1)]
      # collapse multi-line values into a joined string per key
      $joined = @{}
      $currentKey = $null
      $currentVal = New-Object System.Text.StringBuilder
      foreach ($ln in $fm) {
        if ($ln -match '^([a-zA-Z_][a-zA-Z0-9_-]*):\s*(.*)$') {
          if ($currentKey) { $joined[$currentKey] = $currentVal.ToString().Trim() }
          $currentKey = $matches[1]
          $currentVal = New-Object System.Text.StringBuilder
          [void]$currentVal.Append($matches[2])
        } elseif ($currentKey) {
          [void]$currentVal.Append(' ')
          [void]$currentVal.Append($ln.Trim())
        }
      }
      if ($currentKey) { $joined[$currentKey] = $currentVal.ToString().Trim() }

      # 2. name matches folder
      if (-not $joined.ContainsKey('name')) {
        $errs += "no 'name' key in frontmatter"
      } elseif ($joined['name'] -ne $folder) {
        $warns += "name '$($joined['name'])' does not match folder '$folder'"
      }

      # 3. description checks
      if (-not $joined.ContainsKey('description')) {
        $errs += "no 'description' key in frontmatter"
      } else {
        $desc = $joined['description']
        if ($desc.Length -lt 120) {
          $errs += "description too short ($($desc.Length) chars, need >= 120)"
        }
        $hasTrigger = ($desc -match '(?i)(TRIGGER when|Use when|Trigger with)')
        $hasDoNot   = ($desc -match '(?i)(DO NOT TRIGGER|Do not use for|Do NOT use|NOT for)')
        if (-not $hasTrigger) { $errs += "description missing TRIGGER cue" }
        if (-not $hasDoNot)   { $warns += "description missing DO-NOT cue (recommended for undertrigger prevention)" }

        # 4. generic opener
        if ($desc -match '^(?i)(a skill for|this skill|skill that helps|helps you|allows you to)\s') {
          $warns += "description starts with a generic opener"
        }
      }
    }
  }

  $body = ($lines -join "`n")

  # 5. provenance / date-stamp
  $hasProv = ($body -match '(?i)##\s+Provenance')
  $hasDate = ($body -match '20\d{2}-\d{2}-\d{2}')
  if (-not $hasProv -and -not $hasDate) {
    $warns += "no 'Provenance' section and no date-stamp - volatile facts will drift silently"
  }

  # 6. placeholder tokens
  $ph = @('<your project>','PLACEHOLDER','TBD','xxx','TODO','FIXME')
  foreach ($tok in $ph) {
    if ($body -match [regex]::Escape($tok)) {
      $warns += "placeholder token '$tok' still in body"
    }
  }

  # 7. referenced scripts exist
  $skillDir = Split-Path -Parent $f.FullName
  $refs = [regex]::Matches($body, 'scripts/([A-Za-z0-9_.-]+\.(ps1|py|sh))')
  foreach ($m in $refs) {
    $ref = Join-Path $skillDir $m.Value
    if (-not (Test-Path $ref)) {
      $errs += "references missing script $($m.Value)"
    }
  }

  # report
  $totalErr += $errs.Count
  $totalWarn += $warns.Count
  if ($errs.Count -gt 0 -or $warns.Count -gt 0) {
    Write-Host ""
    Write-Host $rel -ForegroundColor Cyan
    foreach ($e in $errs)  { Write-Host "  ERROR: $e" -ForegroundColor Red }
    foreach ($w in $warns) { Write-Host "  WARN:  $w" -ForegroundColor Yellow }
  } else {
    Write-Host "OK    $rel" -ForegroundColor Green
  }
}

Write-Host ""
Write-Host "skill-lint: $($files.Count) file(s), $totalErr error(s), $totalWarn warning(s)"

if ($totalErr -gt 0) { exit 2 }
if ($Strict -and $totalWarn -gt 0) { exit 2 }
if ($totalWarn -gt 0) { exit 1 }
exit 0