# pool-guardian.ps1 - Diagnose long-uptime Windows kernel-pool pressure.
#
# This tool is deliberately read-only. It reports pool ownership tags and blocks
# unsafe advice such as trimming process working sets or purging the standby list:
# neither operation releases outstanding allocations owned by kernel drivers.
#
# Exit codes: 0 = OK, 1 = CAUTION, 2 = CRITICAL, 3 = query/tool failure.
# Pure ASCII on purpose (Windows PowerShell 5.1 parses BOM-less scripts as ANSI).
[CmdletBinding()]
param(
  [ValidateRange(1, 100)]
  [int]$Top = 12,

  [ValidateRange(15, 86400)]
  [int]$IntervalSeconds = 300,

  [ValidateRange(0.25, 64)]
  [double]$WarningPoolGB = 2.5,

  [ValidateRange(0.5, 128)]
  [double]$CriticalPoolGB = 4.5,

  [ValidateRange(5, 1440)]
  [int]$TagRefreshMinutes = 60,

  [switch]$Watch,
  [switch]$Json,
  [switch]$Quiet,
  [switch]$NoLog,
  [switch]$IncludeTags,
  [switch]$Notify,
  [switch]$SelfTest,

  [string]$LogPath = (Join-Path $env:LOCALAPPDATA 'PoolGuardian\history.jsonl'),
  [string]$StatePath = (Join-Path $env:LOCALAPPDATA 'PoolGuardian\state.json'),

  [ValidateRange(1, 100)]
  [int]$MaxHistoryMB = 10
)

$ErrorActionPreference = 'Stop'

if ($CriticalPoolGB -le $WarningPoolGB) {
  Write-Error 'CriticalPoolGB must be greater than WarningPoolGB.'
  exit 3
}

function Initialize-PoolGuardianNative {
  if ('PoolGuardian.NativeMethods' -as [type]) { return }

  Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

namespace PoolGuardian
{
    public sealed class PoolTagRecord
    {
        public string Tag { get; set; }
        public UInt64 PagedAllocations { get; set; }
        public UInt64 PagedFrees { get; set; }
        public UInt64 PagedBytes { get; set; }
        public UInt64 NonPagedAllocations { get; set; }
        public UInt64 NonPagedFrees { get; set; }
        public UInt64 NonPagedBytes { get; set; }

        public UInt64 PagedOutstanding
        {
            get { return PagedAllocations >= PagedFrees ? PagedAllocations - PagedFrees : 0; }
        }

        public UInt64 NonPagedOutstanding
        {
            get { return NonPagedAllocations >= NonPagedFrees ? NonPagedAllocations - NonPagedFrees : 0; }
        }

        public UInt64 TotalBytes
        {
            get { return PagedBytes + NonPagedBytes; }
        }
    }

    public static class NativeMethods
    {
        private const int SystemPoolTagInformation = 22;
        private const int StatusInfoLengthMismatch = unchecked((int)0xC0000004);
        private const int MaximumBufferBytes = 64 * 1024 * 1024;

        [DllImport("ntdll.dll")]
        private static extern int NtQuerySystemInformation(
            int systemInformationClass,
            IntPtr systemInformation,
            int systemInformationLength,
            out int returnLength);

        private static UInt32 ReadUInt32(IntPtr buffer, int offset)
        {
            return unchecked((UInt32)Marshal.ReadInt32(buffer, offset));
        }

        private static UInt64 ReadSizeT(IntPtr buffer, int offset)
        {
            return IntPtr.Size == 8
                ? unchecked((UInt64)Marshal.ReadInt64(buffer, offset))
                : ReadUInt32(buffer, offset);
        }

        private static string ReadTag(IntPtr buffer, int offset)
        {
            byte[] bytes = new byte[4];
            Marshal.Copy(IntPtr.Add(buffer, offset), bytes, 0, bytes.Length);
            StringBuilder result = new StringBuilder(4);
            foreach (byte value in bytes)
                result.Append(value >= 0x20 && value <= 0x7e ? (char)value : '.');
            return result.ToString();
        }

        public static PoolTagRecord[] QueryPoolTags()
        {
            int capacity = 1024 * 1024;
            while (capacity <= MaximumBufferBytes)
            {
                IntPtr buffer = Marshal.AllocHGlobal(capacity);
                try
                {
                    int required;
                    int status = NtQuerySystemInformation(
                        SystemPoolTagInformation, buffer, capacity, out required);
                    if (status == StatusInfoLengthMismatch)
                    {
                        capacity = Math.Max(capacity * 2, required + 65536);
                        continue;
                    }
                    if (status < 0)
                        throw new Win32Exception(status,
                            "NtQuerySystemInformation(SystemPoolTagInformation) failed with NTSTATUS 0x" +
                            status.ToString("X8"));

                    UInt32 count = ReadUInt32(buffer, 0);
                    int first = IntPtr.Size == 8 ? 8 : 4;
                    int stride = IntPtr.Size == 8 ? 40 : 28;
                    long requiredBytes = (long)first + (long)count * stride;
                    if (count > 1000000 || requiredBytes > capacity)
                        throw new InvalidOperationException("Windows returned an invalid pool-tag table.");

                    List<PoolTagRecord> records = new List<PoolTagRecord>((int)count);
                    for (int index = 0; index < count; ++index)
                    {
                        int entry = first + index * stride;
                        if (IntPtr.Size == 8)
                        {
                            records.Add(new PoolTagRecord {
                                Tag = ReadTag(buffer, entry),
                                PagedAllocations = ReadUInt32(buffer, entry + 4),
                                PagedFrees = ReadUInt32(buffer, entry + 8),
                                PagedBytes = ReadSizeT(buffer, entry + 16),
                                NonPagedAllocations = ReadUInt32(buffer, entry + 24),
                                NonPagedFrees = ReadUInt32(buffer, entry + 28),
                                NonPagedBytes = ReadSizeT(buffer, entry + 32)
                            });
                        }
                        else
                        {
                            records.Add(new PoolTagRecord {
                                Tag = ReadTag(buffer, entry),
                                PagedAllocations = ReadUInt32(buffer, entry + 4),
                                PagedFrees = ReadUInt32(buffer, entry + 8),
                                PagedBytes = ReadSizeT(buffer, entry + 12),
                                NonPagedAllocations = ReadUInt32(buffer, entry + 16),
                                NonPagedFrees = ReadUInt32(buffer, entry + 20),
                                NonPagedBytes = ReadSizeT(buffer, entry + 24)
                            });
                        }
                    }
                    return records.ToArray();
                }
                finally
                {
                    Marshal.FreeHGlobal(buffer);
                }
            }
            throw new InvalidOperationException("Pool-tag data exceeded the 64 MiB safety limit.");
        }
    }
}
'@
}

function Convert-BytesToGB([UInt64]$Bytes) {
  return [math]::Round($Bytes / 1GB, 3)
}

function Get-PoolGuardianSnapshot([switch]$ForceTags) {
  $memory = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory
  $os = Get-CimInstance Win32_OperatingSystem
  $computer = Get-CimInstance Win32_ComputerSystem

  $pagedBytes = [UInt64]$memory.PoolPagedBytes
  $nonPagedBytes = [UInt64]$memory.PoolNonpagedBytes
  $kernelPoolBytes = $pagedBytes + $nonPagedBytes
  $totalPhysicalBytes = [UInt64]$computer.TotalPhysicalMemory
  $warningBytes = [UInt64]($WarningPoolGB * 1GB)
  $criticalBytes = [UInt64]($CriticalPoolGB * 1GB)
  $poolPercent = if ($totalPhysicalBytes) {
    [math]::Round(100.0 * $kernelPoolBytes / $totalPhysicalBytes, 1)
  } else { 0.0 }

  # The pool-tag table is an internal NT interface. Avoid compiling/querying it on
  # healthy scheduled samples, and degrade to documented global counters if its
  # layout ever changes in a future Windows release.
  $tags = @()
  $cachedTagRows = @()
  [UInt64]$cachedKnownBytes = 0
  $tagQuery = 'skipped_below_warning'
  $tagQueryError = $null
  $tagCapturedAt = $null
  $queryTagsNow = [bool]$ForceTags
  if (-not $queryTagsNow -and $kernelPoolBytes -ge $warningBytes) {
    $queryTagsNow = $true
    if (Test-Path -LiteralPath $StatePath) {
      try {
        $cached = [System.IO.File]::ReadAllText($StatePath) | ConvertFrom-Json
        if ($cached.tag_captured_at) {
          $cachedAt = [datetime]::Parse($cached.tag_captured_at, $null,
            [Globalization.DateTimeStyles]::RoundtripKind)
          if (((Get-Date).ToUniversalTime() - $cachedAt.ToUniversalTime()).TotalMinutes -lt $TagRefreshMinutes) {
            $queryTagsNow = $false
            $cachedTagRows = @($cached.top_pool_tags)
            $cachedKnownBytes = [UInt64]$cached.known_file_filter_family_bytes
            $tagCapturedAt = $cached.tag_captured_at
            $tagQuery = 'cached'
          }
        }
      } catch {
        # Ignore stale/corrupt cache and refresh the native tag table.
        $queryTagsNow = $true
      }
    }
  }
  if ($queryTagsNow) {
    try {
      Initialize-PoolGuardianNative
      $tags = @([PoolGuardian.NativeMethods]::QueryPoolTags())
      $tagQuery = 'ok'
      $tagCapturedAt = (Get-Date).ToUniversalTime().ToString('o')
    } catch {
      $tagQuery = 'unavailable'
      $tagQueryError = $_.Exception.Message
    }
  }

  $knownTags = @('File', 'IoFE', 'SQSF', 'Ntfc', 'IoNm', 'FMfn', 'D2d ')
  $knownRows = @($tags | Where-Object { $knownTags -contains $_.Tag })
  [UInt64]$knownBytes = if ($tagQuery -eq 'cached') {
    $cachedKnownBytes
  } else {
    ($knownRows | Measure-Object -Property TotalBytes -Sum).Sum
  }

  $topRows = if ($tagQuery -eq 'cached') {
    @($cachedTagRows | Select-Object -First $Top)
  } else {
    @(
      $tags |
        Sort-Object TotalBytes -Descending |
        Select-Object -First $Top |
        ForEach-Object {
          [PSCustomObject][ordered]@{
            tag = $_.Tag
            total_bytes = [UInt64]$_.TotalBytes
            paged_bytes = [UInt64]$_.PagedBytes
            nonpaged_bytes = [UInt64]$_.NonPagedBytes
            paged_outstanding = [UInt64]$_.PagedOutstanding
            nonpaged_outstanding = [UInt64]$_.NonPagedOutstanding
          }
        }
    )
  }

  $topProcesses = @(
    Get-Process -ErrorAction SilentlyContinue |
      Sort-Object WorkingSet64 -Descending |
      Select-Object -First 8 |
      ForEach-Object {
        [PSCustomObject][ordered]@{
          name = $_.ProcessName
          pid = $_.Id
          working_set_bytes = [UInt64]$_.WorkingSet64
          private_bytes = [UInt64]$_.PrivateMemorySize64
          handles = $_.HandleCount
        }
      }
  )

  $availableBytes = [UInt64]$memory.AvailableMBytes * 1MB
  $severity = 'OK'
  $exitCode = 0
  $reasons = @()

  if ($kernelPoolBytes -ge $warningBytes) {
    $severity = 'CAUTION'; $exitCode = 1
    $reasons += ('kernel pool {0} GiB >= warning {1} GiB' -f (Convert-BytesToGB $kernelPoolBytes), $WarningPoolGB)
  }
  if ($kernelPoolBytes -ge $criticalBytes) {
    $severity = 'CRITICAL'; $exitCode = 2
    $reasons += ('kernel pool {0} GiB >= critical {1} GiB' -f (Convert-BytesToGB $kernelPoolBytes), $CriticalPoolGB)
  }
  if ($availableBytes -lt 1.5GB) {
    if ($exitCode -lt 2) { $severity = 'CRITICAL'; $exitCode = 2 }
    $reasons += ('available RAM {0} GiB < 1.5 GiB' -f (Convert-BytesToGB $availableBytes))
  } elseif ($availableBytes -lt 3GB) {
    if ($exitCode -lt 1) { $severity = 'CAUTION'; $exitCode = 1 }
    $reasons += ('available RAM {0} GiB < 3 GiB' -f (Convert-BytesToGB $availableBytes))
  }

  return [PSCustomObject][ordered]@{
    schema_version = 1
    captured_at = (Get-Date).ToUniversalTime().ToString('o')
    boot_time_utc = $os.LastBootUpTime.ToUniversalTime().ToString('o')
    computer = $env:COMPUTERNAME
    severity = $severity
    exit_code = $exitCode
    reasons = @($reasons)
    uptime_hours = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalHours, 1)
    physical_total_bytes = $totalPhysicalBytes
    available_bytes = $availableBytes
    committed_bytes = [UInt64]$memory.CommittedBytes
    commit_limit_bytes = [UInt64]$memory.CommitLimit
    paged_pool_bytes = $pagedBytes
    nonpaged_pool_bytes = $nonPagedBytes
    kernel_pool_bytes = $kernelPoolBytes
    kernel_pool_percent_of_ram = $poolPercent
    known_file_filter_family_bytes = $knownBytes
    tag_query = $tagQuery
    tag_captured_at = $tagCapturedAt
    tag_query_error = $tagQueryError
    top_pool_tags = $topRows
    top_processes = $topProcesses
  }
}

function Add-PoolGuardianTrend($Snapshot) {
  [Int64]$growthPerHour = 0
  [int]$growthStrikes = 0
  $priorSeverity = $null
  $lastAlertAt = $null

  if (Test-Path -LiteralPath $StatePath) {
    try {
      $prior = [System.IO.File]::ReadAllText($StatePath) | ConvertFrom-Json
      $priorSeverity = $prior.severity
      $lastAlertAt = $prior.last_alert_at
      if ($prior.boot_time_utc -eq $Snapshot.boot_time_utc) {
        $then = [datetime]::Parse($prior.captured_at, $null,
          [Globalization.DateTimeStyles]::RoundtripKind)
        $now = [datetime]::Parse($Snapshot.captured_at, $null,
          [Globalization.DateTimeStyles]::RoundtripKind)
        $elapsedSeconds = ($now - $then).TotalSeconds
        if ($elapsedSeconds -ge 60 -and $elapsedSeconds -le 3600) {
          [Int64]$delta = [Int64]$Snapshot.kernel_pool_bytes - [Int64]$prior.kernel_pool_bytes
          $growthPerHour = [Int64]($delta * 3600.0 / $elapsedSeconds)
          $priorStrikes = if ($null -ne $prior.growth_strikes) { [int]$prior.growth_strikes } else { 0 }
          if ($growthPerHour -ge 256MB) {
            $growthStrikes = [math]::Min(1000, $priorStrikes + 1)
          } else {
            $growthStrikes = [math]::Max(0, $priorStrikes - 1)
          }
        }
      }
    } catch {
      # A stale/corrupt state file is never fatal; the next atomic write repairs it.
      $growthPerHour = 0
      $growthStrikes = 0
    }
  }

  $Snapshot | Add-Member -NotePropertyName growth_bytes_per_hour -NotePropertyValue $growthPerHour
  $Snapshot | Add-Member -NotePropertyName growth_strikes -NotePropertyValue $growthStrikes
  if ($growthStrikes -ge 2 -and $Snapshot.exit_code -lt 1) {
    $Snapshot.severity = 'CAUTION'
    $Snapshot.exit_code = 1
    $Snapshot.reasons += ('kernel pool grew {0} MiB/hour for {1} samples' -f
      [math]::Round($growthPerHour / 1MB, 0), $growthStrikes)
  }
  $shouldNotify = $false
  if ($Snapshot.severity -ne 'OK') {
    if ($priorSeverity -ne $Snapshot.severity) {
      $shouldNotify = $true
    } elseif (-not $lastAlertAt) {
      $shouldNotify = $true
    } else {
      try {
        $alertTime = [datetime]::Parse($lastAlertAt, $null,
          [Globalization.DateTimeStyles]::RoundtripKind)
        $shouldNotify = ((Get-Date).ToUniversalTime() - $alertTime.ToUniversalTime()).TotalHours -ge 6
      } catch { $shouldNotify = $true }
    }
  }
  $Snapshot | Add-Member -NotePropertyName previous_severity -NotePropertyValue $priorSeverity
  $Snapshot | Add-Member -NotePropertyName should_notify -NotePropertyValue $shouldNotify
  $Snapshot | Add-Member -NotePropertyName last_alert_at -NotePropertyValue $lastAlertAt
  $Snapshot | Add-Member -NotePropertyName notification_error -NotePropertyValue $null
  return $Snapshot
}

function Send-PoolGuardianNotification($Snapshot) {
  if (-not $Notify -or -not $Snapshot.should_notify) { return }

  try {
    $ping = Join-Path $PSScriptRoot '..\sounds\play-ping.ps1'
    if (Test-Path -LiteralPath $ping) { & $ping }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $icon = New-Object System.Windows.Forms.NotifyIcon
    try {
      $icon.Icon = [System.Drawing.SystemIcons]::Warning
      $icon.Visible = $true
      $icon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning
      $icon.BalloonTipTitle = 'Pool Guardian: ' + $Snapshot.severity
      $icon.BalloonTipText = ('Kernel pool {0} GiB; available RAM {1} GiB. Save work and plan a full Restart.' -f
        (Convert-BytesToGB $Snapshot.kernel_pool_bytes),
        (Convert-BytesToGB $Snapshot.available_bytes))
      $icon.ShowBalloonTip(8000)
      Start-Sleep -Seconds 5
    } finally {
      $icon.Visible = $false
      $icon.Dispose()
    }
  } catch {
    $Snapshot.notification_error = $_.Exception.Message
  }
  $Snapshot.last_alert_at = (Get-Date).ToUniversalTime().ToString('o')
}

function Write-PoolGuardianState($Snapshot) {
  $parent = Split-Path -Parent $StatePath
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }

  $json = $Snapshot | ConvertTo-Json -Depth 8 -Compress
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  $temporary = "$StatePath.$PID.tmp"
  [System.IO.File]::WriteAllText($temporary, $json, $utf8)
  if (Test-Path -LiteralPath $StatePath) {
    $backup = "$StatePath.bak"
    if (Test-Path -LiteralPath $backup) { [System.IO.File]::Delete($backup) }
    [System.IO.File]::Replace($temporary, $StatePath, $backup, $true)
    if (Test-Path -LiteralPath $backup) { [System.IO.File]::Delete($backup) }
  } else {
    [System.IO.File]::Move($temporary, $StatePath)
  }
}

function Write-PoolGuardianLog($Snapshot) {
  if ($NoLog) { return }
  $parent = Split-Path -Parent $LogPath
  if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  [Int64]$segmentLimit = [math]::Max(1MB, ([Int64]$MaxHistoryMB * 1MB) / 2)
  if ((Test-Path -LiteralPath $LogPath) -and
      (Get-Item -LiteralPath $LogPath).Length -ge $segmentLimit) {
    $older = "$LogPath.1"
    if (Test-Path -LiteralPath $older) { [System.IO.File]::Delete($older) }
    [System.IO.File]::Move($LogPath, $older)
  }

  $line = $Snapshot | ConvertTo-Json -Depth 8 -Compress
  [System.IO.File]::AppendAllText($LogPath, $line + [Environment]::NewLine,
    (New-Object System.Text.UTF8Encoding($false)))
}

function Show-PoolGuardianSnapshot($Snapshot) {
  if ($Json) {
    $Snapshot | ConvertTo-Json -Depth 8
    return
  }
  if ($Quiet) { return }

  Write-Host ('[{0}] Kernel pool: {1} GiB ({2}% of RAM)' -f
    $Snapshot.severity,
    (Convert-BytesToGB $Snapshot.kernel_pool_bytes),
    $Snapshot.kernel_pool_percent_of_ram)
  Write-Host ('  Nonpaged {0} GiB + paged {1} GiB; available RAM {2} GiB; uptime {3} h' -f
    (Convert-BytesToGB $Snapshot.nonpaged_pool_bytes),
    (Convert-BytesToGB $Snapshot.paged_pool_bytes),
    (Convert-BytesToGB $Snapshot.available_bytes),
    $Snapshot.uptime_hours)
  Write-Host ('  File/minifilter-family tags: {0} GiB' -f
    (Convert-BytesToGB $Snapshot.known_file_filter_family_bytes))

  if ($Snapshot.reasons.Count) {
    Write-Host ('  Reason: ' + ($Snapshot.reasons -join '; '))
  }

  if ($Snapshot.top_pool_tags.Count) {
    Write-Host ''
    Write-Host 'Top pool tags:'
    $Snapshot.top_pool_tags |
      Select-Object @{N='Tag';E={$_.tag}},
                    @{N='TotalGiB';E={Convert-BytesToGB $_.total_bytes}},
                    @{N='PagedGiB';E={Convert-BytesToGB $_.paged_bytes}},
                    @{N='NonpagedGiB';E={Convert-BytesToGB $_.nonpaged_bytes}},
                    @{N='Outstanding';E={$_.paged_outstanding + $_.nonpaged_outstanding}} |
      Format-Table -AutoSize | Out-String | Write-Host
  } elseif ($Snapshot.tag_query -eq 'unavailable') {
    Write-Warning ('Pool-tag detail unavailable: ' + $Snapshot.tag_query_error)
  }

  if ($Snapshot.exit_code -ge 2) {
    Write-Warning 'This is allocated kernel pool, not reclaimable cache. Do not use working-set/standby-list cleaners or force-free injectors.'
    Write-Host 'Safe recovery: save work and perform a full Windows Restart. Shutdown/hibernate may preserve kernel state.'
  }
  if (-not $NoLog) { Write-Host ("History: $LogPath") }
}

function Invoke-PoolGuardianSelfTest {
  $snapshot = Get-PoolGuardianSnapshot -ForceTags
  if (-not $snapshot.top_pool_tags.Count) { throw 'Pool-tag query returned no rows.' }
  if ($snapshot.kernel_pool_bytes -le 0) { throw 'Kernel-pool counter returned zero.' }
  if ($snapshot.nonpaged_pool_bytes -le 0) { throw 'Nonpaged-pool counter returned zero.' }
  if ($snapshot.top_pool_tags[0].tag.Length -ne 4) { throw 'Pool tag width is not four bytes.' }

  [UInt64]$tagTotal = ($snapshot.top_pool_tags | Measure-Object -Property total_bytes -Sum).Sum
  if ($tagTotal -le 0) { throw 'Top pool tags have no allocated bytes.' }

  $roundTrip = ($snapshot | ConvertTo-Json -Depth 8 -Compress) | ConvertFrom-Json
  if ($roundTrip.schema_version -ne 1) { throw 'JSON schema round trip failed.' }
  Write-Host ('PASS: queried {0} displayed tags; kernel pool {1} GiB; severity {2}' -f
    $snapshot.top_pool_tags.Count,
    (Convert-BytesToGB $snapshot.kernel_pool_bytes),
    $snapshot.severity)
}

if ($SelfTest) {
  try {
    Invoke-PoolGuardianSelfTest
    exit 0
  } catch {
    Write-Error ("Pool Guardian self-test failed: " + $_.Exception.Message)
    exit 3
  }
}

$mutex = New-Object System.Threading.Mutex($false, 'Local\AgentWorkbench-PoolGuardian')
$mutexHeld = $false
try {
  try { $mutexHeld = $mutex.WaitOne(0) }
  catch [System.Threading.AbandonedMutexException] { $mutexHeld = $true }
  if (-not $mutexHeld) {
    if (-not $Quiet) { Write-Host 'Pool Guardian is already sampling in another process.' }
    exit 0
  }

  do {
    $snapshot = Get-PoolGuardianSnapshot -ForceTags:$IncludeTags
    $snapshot = Add-PoolGuardianTrend $snapshot
    Send-PoolGuardianNotification $snapshot
    Write-PoolGuardianState $snapshot
    Write-PoolGuardianLog $snapshot
    Show-PoolGuardianSnapshot $snapshot
    $lastExitCode = [int]$snapshot.exit_code
    if ($Watch) { Start-Sleep -Seconds $IntervalSeconds }
  } while ($Watch)

  exit $lastExitCode
} catch {
  Write-Error ("Pool Guardian failed: " + $_.Exception.Message)
  exit 3
} finally {
  if ($mutexHeld) { $mutex.ReleaseMutex() }
  $mutex.Dispose()
}
