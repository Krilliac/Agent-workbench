---
name: ci-troubleshoot
description: Diagnose GitHub Actions Windows runner failures, cache misses, and matrix issues for a C++ engine project. TRIGGER when the user says "CI failed", "workflow broken", "GitHub Actions timeout", "windows-latest failed", "matrix job", "cache miss", "artifact upload broken", "why didn't the workflow trigger", "runner ran out of disk". DO NOT TRIGGER for local build issues (use cmake-msvc, msvc-error-decoder). Focused on GHA Windows-runner quirks -- disk pressure, path length, Defender interference -- plus standard failure patterns for MSVC + Ninja + vcpkg jobs.
---

# ci-troubleshoot

## Windows runner fragility
`windows-latest` has ~14 GB free after image bring-up minus vcpkg cache. Rule: `df -h` at job top.

## Failure patterns

### Cache miss (vcpkg/ninja)
`hashFiles('**/CMakeLists.txt')` is order-sensitive; whitespace re-hashes. Narrow the glob:
```yaml
- uses: actions/cache@v4
  with:
    path: |
      C:\vcpkg\installed
      $env:LOCALAPPDATA\vcpkg\archives
    key: vcpkg-${{ runner.os }}-${{ hashFiles('vcpkg.json','vcpkg-configuration.json') }}
```

### Wrong MSBuild picked
```yaml
- uses: ilammy/msvc-dev-cmd@v1
  with: { arch: x64 }
```
Or `-G Ninja -DCMAKE_MAKE_PROGRAM=ninja`.

### Defender scan slows link 10x
```yaml
- run: Add-MpPreference -ExclusionPath "${{ github.workspace }}\build"
  shell: pwsh
```

### Path > 260
```yaml
- run: git config --global core.longpaths true
- run: New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name LongPathsEnabled -Value 1 -PropertyType DWORD -Force
  shell: pwsh
```

### Job cancelled by GH
Stalled process. `timeout-minutes: 30` + `Set-PSDebug -Trace 1`.

## Live debug
- `actions/upload-artifact@v4` on `if: always()` -- CMakeError.log, build logs.
- Reproduce via `ghcr.io/actions/runner-images`.
- `ACTIONS_RUNNER_DEBUG=true` for verbose logs.

## Matrix guidance
Don't over-matrix. Baseline for the engine:
- `windows-latest` + MSVC Release
- `windows-latest` + clang-cl Debug (catches warnings MSVC misses)
- `ubuntu-latest` + gcc-14 Release (catches Windows-only shortcuts)

## Method
1. `gh run view <id> --log-failed`.
2. First ERROR (not FAILED, that's downstream).
3. Correlate with last-good run's commit -- `git log`.