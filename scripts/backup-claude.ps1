# backup-claude.ps1 - mirror ~/.claude (memory, settings, scripts, projects, plugins...)
# to a secondary fixed drive, resolved at runtime - NOT hardcoded:
#   preferred = non-system fixed drive with the most free space (>5 GB free)
#   fallback  = the system drive (protects against ~/.claude corruption/deletion only)
# Excludes regenerable ephemera (cache, paste-cache, shell-snapshots, downloads,
# telemetry, daemon, session-env). Uses robocopy /MIR into <Drive>:\ClaudeBackup\claude.
# Modes:
#   (no args)        run a backup now
#   -IfDue           only run if the last successful backup is older than -MaxAgeHours
#   -MaxAgeHours <n> freshness threshold for -IfDue (default 24)
[CmdletBinding()]
param(
  [switch]$IfDue,
  [int]$MaxAgeHours = 24
)

$ErrorActionPreference = 'Continue'
$src   = Join-Path $env:USERPROFILE '.claude'
$stamp = Join-Path $src '.last-backup'
$log   = Join-Path $src 'backup.log'

if ($IfDue -and (Test-Path $stamp)) {
  $age = (Get-Date) - (Get-Item $stamp).LastWriteTime
  if ($age.TotalHours -lt $MaxAgeHours) { return }
}

# Resolve target drives: every local fixed disk, non-system first (most free space
# wins), system drive last as fallback.
$sysDrive = $env:SystemDrive   # e.g. "C:"
$fixed = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue)
$candidates = @($fixed |
  Where-Object { $_.DeviceID -ne $sysDrive -and $_.FreeSpace -gt 5GB } |
  Sort-Object FreeSpace -Descending |
  ForEach-Object { $_.DeviceID })
$candidates += $sysDrive

$exDirs = @('cache','paste-cache','shell-snapshots','downloads','telemetry','daemon','session-env','sessions','backups') |
  ForEach-Object { Join-Path $src $_ }

$started = Get-Date
$target = $null
foreach ($drive in $candidates) {
  $dest = Join-Path "$drive\" 'ClaudeBackup\claude'
  $rcArgs = @($src, $dest, '/MIR', '/R:1', '/W:1', '/NFL', '/NDL', '/NP', '/NJH',
              '/XF', '*.lock', '.credentials.json', '/XD') + $exDirs
  & robocopy @rcArgs | Out-Null
  $code = $LASTEXITCODE   # robocopy: 0-7 = success flavors, >=8 = failure
  if ($code -lt 8) { $target = $dest; break }
  "$((Get-Date).ToString('o')) FAILED (rc=$code) -> $dest" | Out-File $log -Append -Encoding utf8
}

$secs = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
if ($target) {
  "$((Get-Date).ToString('o')) OK (${secs}s) -> $target" | Out-File $stamp -Encoding utf8
  "$((Get-Date).ToString('o')) OK (${secs}s) -> $target" | Out-File $log -Append -Encoding utf8
  Write-Host "claude backup: mirrored ~/.claude -> $target (${secs}s)"
} else {
  Write-Host "claude backup FAILED on all drives: $($candidates -join ', ') - see $log"
}
