[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Path
)

$skillsRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$linter = Join-Path $skillsRoot 'skill-linter\scripts\skill-lint.ps1'
if (-not (Test-Path -LiteralPath $linter)) {
  Write-Error "skill-linter not found at $linter"
  exit 2
}

& $linter -Path $Path
exit $LASTEXITCODE
