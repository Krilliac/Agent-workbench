# fleet-preflight.ps1 - RAM/swap headroom check before launching agent fleets or
# C++ builds. Prints a report and a GO / CAUTION / STOP verdict.
# Exit code encodes the verdict so it is scriptable: 0 = GO, 1 = CAUTION, 2 = STOP.
#
# Signals:
#   FreeRAM    - available physical RAM (thrash starts as this approaches 0)
#   CommitFree - free commit headroom vs the commit limit (phys + pagefile);
#                when this runs out, allocations fail and paging goes wild
#   KernelPool - paged + nonpaged allocations owned by the kernel/drivers;
#                unlike cache, these cannot be reclaimed by a memory cleaner
#   Builds     - running cl/link/ninja/cmake/msbuild processes (rule:
#                never >3 concurrent C++ builds on 31 GB box)
#
# Pure ASCII on purpose (PS 5.1 parses this BOM-less file as ANSI).
[CmdletBinding()]
param([switch]$Quiet)

$os  = Get-CimInstance Win32_OperatingSystem
$cs  = Get-CimInstance Win32_ComputerSystem
$totalRam  = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
$freeRam    = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
# TotalVirtualMemorySize / FreeVirtualMemory are the commit limit / free commit (KB).
$commitLimit = [math]::Round($os.TotalVirtualMemorySize / 1MB, 1)
$commitFree  = [math]::Round($os.FreeVirtualMemory / 1MB, 1)
$commitFreePct = if ($commitLimit -gt 0) { [math]::Round(100 * $commitFree / $commitLimit, 0) } else { 0 }
$memory = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory
$pagedPool = [math]::Round([UInt64]$memory.PoolPagedBytes / 1GB, 2)
$nonPagedPool = [math]::Round([UInt64]$memory.PoolNonpagedBytes / 1GB, 2)
$kernelPool = [math]::Round($pagedPool + $nonPagedPool, 2)

# Kernel-pool RUNWAY. The absolute pool number says little on its own: what
# matters before launching a fleet is how long until it wedges. pool-guardian
# already measures the observed growth rate, so reuse its latest sample rather
# than re-deriving it. Under heavy agent/build load the rate has been observed
# at ~0.6 GB/h - two orders above idle - so a "fine" pool reading can still be
# under three hours from CRITICAL. Pool is NOT reclaimable without a reboot.
$poolRateGBph = $null; $runwayHours = $null
$poolHistory = Join-Path $env:LOCALAPPDATA 'PoolGuardian\history.jsonl'
if (Test-Path -LiteralPath $poolHistory) {
  try {
    $lastSample = Get-Content -LiteralPath $poolHistory -Tail 1 | ConvertFrom-Json
    if ($null -ne $lastSample.growth_bytes_per_hour) {
      $poolRateGBph = [math]::Round($lastSample.growth_bytes_per_hour / 1GB, 2)
      if ($poolRateGBph -gt 0.01) {
        $runwayHours = [math]::Round(([math]::Max(0, 4.5 - $kernelPool)) / $poolRateGBph, 1)
      }
    }
  } catch { $poolRateGBph = $null }
}

$buildProcs = @(Get-Process cl, link, ninja, cmake, msbuild, devenv -ErrorAction SilentlyContinue)
# WSL cargo/rustc builds are represented by the long-lived wsl.exe launcher on
# Windows, so Get-Process cargo/rustc cannot see them. Detect the launcher
# command line to keep another session from treating WSL as idle and issuing
# `wsl --shutdown` underneath an active Rust build.
$wslBuildProcs = @(
  Get-CimInstance Win32_Process -Filter "Name = 'wsl.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match '(?i)(^|[\\/\s])(cargo|rustc)(\.exe)?([\s''"]|$)' }
)
$builds = $buildProcs.Count + $wslBuildProcs.Count

# Verdict: worst signal wins.
$verdict = 'GO'; $code = 0; $reasons = @(); $advisories = @()
function Demote($to, $c, $why) {
  if ($script:code -lt $c) { $script:verdict = $to; $script:code = $c }
  $script:reasons += $why
}
# Physical memory is the only memory signal that blocks: it is what actually
# decides whether the next build thrashes or the box stalls.
# Thresholds sized for 31 GB RAM / ~36 GB commit limit (9900X3D box).
if ($freeRam -lt 4)        { Demote 'CAUTION' 1 "free RAM ${freeRam}G < 4G" }
if ($freeRam -lt 2)        { Demote 'STOP'    2 "free RAM ${freeRam}G < 2G (critically low; thrash risk)" }
if ($commitFreePct -lt 12) { Demote 'CAUTION' 1 "commit headroom ${commitFreePct}% < 12%" }
if ($commitFreePct -lt 5)  { Demote 'STOP'    2 "commit headroom ${commitFreePct}% < 5% (near OOM)" }
# Kernel pool is report-only and never changes the launch verdict. A high pool
# remains useful maintenance information, but available physical/commit memory
# is the stability gate. This lets healthy-RAM work continue regardless of a
# long-uptime pool reading.
if ($kernelPool -ge 2.5)   { $advisories += "kernel pool ${kernelPool}G >= 2.5G" }
if ($kernelPool -ge 4.5)   { $advisories += "kernel pool ${kernelPool}G >= 4.5G; reboot soon (reclaim is reboot-only)" }
# A short runway is actionable even while the absolute pool still reads OK:
# reboot BEFORE a long fleet, not after it wedges mid-run. Advisory for the same
# reason -- it forecasts a future problem, it is not a present one.
if ($null -ne $runwayHours -and $runwayHours -lt 6) { $advisories += "pool runway ${runwayHours}h at ${poolRateGBph}G/h" }
if ($null -ne $runwayHours -and $runwayHours -lt 2) { $advisories += "reboot before a long fleet" }
if ($wslBuildProcs.Count)  { Demote 'STOP'    2 "$($wslBuildProcs.Count) WSL Rust build(s) active; do not launch another build or shut down WSL" }
if ($builds -eq 2)         { Demote 'CAUTION' 1 "2 builds already running" }
if ($builds -ge 3)         { Demote 'STOP'    2 "$builds builds already running (rule: max 3)" }

if (-not $Quiet) {
  Write-Host ("RAM   : {0}G free / {1}G total" -f $freeRam, $totalRam)
  Write-Host ("Commit: {0}G free / {1}G limit ({2}% headroom)" -f $commitFree, $commitLimit, $commitFreePct)
  Write-Host ("Pool  : {0}G kernel ({1}G nonpaged + {2}G paged)" -f $kernelPool, $nonPagedPool, $pagedPool)
  if ($null -ne $poolRateGBph) {
    $runwayText = if ($null -ne $runwayHours) { "{0}h to 4.5G" -f $runwayHours } else { "stable" }
    Write-Host ("Runway: {0}G/h growth -> {1} (reboot-only reclaim)" -f $poolRateGBph, $runwayText)
  }
  $buildNames = @($buildProcs | Select-Object -Expand ProcessName -Unique)
  if ($wslBuildProcs.Count) { $buildNames += 'wsl-rust' }
  Write-Host ("Builds: {0} running{1}" -f $builds, $(if ($builds) { " (" + ($buildNames -join ', ') + ")" } else { "" }))
  $tag = switch ($verdict) { 'GO' { '[GO]' } 'CAUTION' { '[CAUTION]' } 'STOP' { '[STOP]' } }
  Write-Host ""
  Write-Host ("{0} {1}" -f $tag, $(if ($reasons.Count) { $reasons -join '; ' } else { 'headroom OK to launch' }))
  if ($advisories.Count) {
    Write-Host ("Advisory only: {0}" -f ($advisories -join '; '))
  }
  if ($kernelPool -ge 2.5) {
    Write-Host "Detail: powershell -NoProfile -File $PSScriptRoot\pool-guardian.ps1"
  }
}
exit $code
