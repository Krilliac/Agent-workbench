# build.ps1 - one-call MSVC build for this box: RAM preflight -> build through vcvars
# (with CC/CXX pinned to cl) -> distill the log to just the errors -> sccache stats.
# Collapses the dominant compile->fix loop (check RAM, build, find errors, check cache)
# into a single tool call.
#
# Pass the FULL build command as the argument (no per-project guessing):
#   powershell -File build.ps1 "cmake --build build --config Debug"
#   powershell -File build.ps1 -Config Release "ninja -C build"
#   powershell -File build.ps1 "ninja -C build" -VcvarsArgs '10.0.26100.0 -vcvars_ver=14.44'
#   powershell -File build.ps1 -Dir "<repo>" "cmake --build --preset msvc-debug"
# -Dir sets the working directory for the build (REQUIRED for preset-based builds:
# CMakePresets.json is resolved from the CWD, and this script's CWD is the caller's,
# usually the caller's home directory - not the repo).
# Exit code = the build's exit code (0 = success). Pure ASCII (PS 5.1).
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$Command,
  [string]$Dir = '',
  [string]$Vcvars = 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat',
  [string]$VcvarsArgs = '',
  [switch]$SkipPreflight,
  [switch]$RawLog          # also print the full raw log path for drill-down
)

$here = $PSScriptRoot
$log  = Join-Path $env:TEMP ("build-{0}.log" -f $PID)

# 1) RAM preflight. STOP is a hard gate; -SkipPreflight is the explicit override.
if (-not $SkipPreflight) {
  Write-Host "--- preflight ---"
  & (Join-Path $here 'fleet-preflight.ps1')
  $pf = $LASTEXITCODE
  if ($pf -ge 2) {
    Write-Host "ERROR: preflight says STOP - build was not started."
    Write-Host "Use -SkipPreflight only after reviewing the reported RAM/commit/pool condition."
    # Also on stderr: callers routinely pipe this script's stdout through a
    # filter (Select-String 'error|warning'), which DROPS the line above. On
    # 2026-08-18 that happened for real - the build never ran, the filtered
    # output looked clean, and the ctest that followed passed on the PREVIOUS
    # binary. stderr is not part of the stdout pipeline, so it still reaches the
    # terminal. The exit code (8) remains the authoritative signal.
    [Console]::Error.WriteLine("BUILD DID NOT RUN: preflight STOP (exit 8). Any test result after this is from a STALE binary.")
    exit 8
  }
  Write-Host ""
}

# 2) Build through vcvars with the MSVC compiler and binary tools pinned. This sidesteps both the
#    CC=claude.exe gotcha and MinGW link/ar discovery when CMake creates a fresh Ninja cache.
if (-not (Test-Path $Vcvars)) { Write-Host "ERROR: vcvars not found at $Vcvars"; exit 9 }
if ($Dir) {
  if (-not (Test-Path -LiteralPath $Dir)) { Write-Host "ERROR: -Dir not found: $Dir"; exit 10 }
  Write-Host "--- dir: $Dir ---"
}
Write-Host "--- build: $Command ---"
$cd = if ($Dir) { 'cd /d "' + (Resolve-Path -LiteralPath $Dir).Path + '" && ' } else { '' }
$inner = $cd + 'call "' + $Vcvars + '" ' + $VcvarsArgs + ' >nul && set CC=cl && set CXX=cl && set LD=link && set AR=lib && ' + $Command
cmd /c $inner *> $log
$code = $LASTEXITCODE

# 3) Distill the log to the errors that matter.
Write-Host "--- errors (distilled) ---"
$distiller = Join-Path $here 'distill_log.py'
& python $distiller --msvc $log
Write-Host ""

# 3b) Ground-truth safety net: grep the raw log for MSVC/linker error codes
# directly. The distiller has silently reported 0 errors on a real build
# failure (parallel -m MSBuild stream interleaving), so ALWAYS cross-check
# against the exit code. A nonzero exit with no raw error line usually means
# a lock/config failure, not a compile error - flag that too so it is never
# mistaken for "clean".
$rawErr = @(Select-String -Path $log -Pattern 'error [A-Za-z]+[0-9]+\s*:|error LNK[0-9]+' -ErrorAction SilentlyContinue)
if ($rawErr.Count -gt 0) {
  Write-Host ("--- raw error scan: {0} compiler/linker error line(s) ---" -f $rawErr.Count)
  $rawErr | Select-Object -First 5 | ForEach-Object { Write-Host $_.Line.Trim() }
  Write-Host ""
} elseif ($code -ne 0) {
  Write-Host "--- raw error scan: build FAILED (exit $code) with NO compiler error lines ---"
  Write-Host "    likely a lock/config/link-input failure, not a source error. Check the raw log:"
  Write-Host "    $log"
  Write-Host ""
}
Write-Host ("--- build exit code: {0} ({1}) ---" -f $code, $(if ($code -eq 0) { 'SUCCESS' } else { 'FAILED' }))
# Same reasoning as the preflight STOP above: a failed build leaves the previous
# binary on disk, so filtered stdout showing no compiler errors is precisely what
# a silent failure looks like. Put the verdict where a stdout filter cannot
# swallow it.
if ($code -ne 0) {
  [Console]::Error.WriteLine("BUILD FAILED (exit $code). The previous binary is still on disk - do NOT trust a test run against it.")
}

# 4) sccache hit-rate (the global compiler cache).
$sccache = Get-Command sccache -ErrorAction SilentlyContinue
if ($sccache) {
  $stats = & sccache --show-stats 2>$null
  $rows = $stats | Where-Object { $_ -match 'Cache hits|Cache misses|Compile requests|hit rate' }
  if ($rows) { Write-Host "--- sccache ---"; $rows | ForEach-Object { Write-Host $_ } }
}

if ($RawLog) { Write-Host "raw log: $log" }
exit $code
