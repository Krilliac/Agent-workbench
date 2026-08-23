# claude-remote.ps1 — launch a Claude Code session with remote-control
# Usage:
#   claude-remote                            current dir, label = dir name
#   claude-remote -Repo "C:\path\to\repo"    cd there, label = folder name
#   claude-remote -Repo "C:\path" -Name "X"  cd there, label = "X"

param(
    [string]$Repo = (Get-Location).Path,
    [string]$Name
)

if (-not (Test-Path $Repo -PathType Container)) {
    Write-Error "Path not found: $Repo"
    exit 1
}

if (-not $Name) {
    $Name = Split-Path $Repo -Leaf
}

Write-Host "[claude-remote] Repo:  $Repo"
Write-Host "[claude-remote] Label: $Name"
Write-Host "[claude-remote] Launching Claude Code with --remote-control..."
Write-Host ""

Set-Location -Path $Repo
& claude --remote-control $Name
