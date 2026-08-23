---
name: memory-hunt
description: Track down C++ memory leaks, corruption, and heap misuse with ASAN, Application Verifier, and UMDH heap snapshots. TRIGGER when the user says "memory leak", "leak detected", "heap grows over time", "DLL_PROCESS_DETACH leak", "ASAN leak report", "Application Verifier fires", "double free", "invalid heap free", "vld reports". DO NOT TRIGGER for crashes at fault (use cpp-crash-triage) or stack overflows (usually recursion depth). Covers Windows-specific tooling -- heap snapshots via DebugDiag, UMDH baseline+diff, Application Verifier heap page -- plus ASAN on clang-cl builds.
---

# memory-hunt

## Classify first
- **True leak**: RSS grows unbounded.
- **Fragmentation**: RSS grows, working set stable.
- **Cached**: pool intentionally holds; not a leak.
- **DLL unload leak**: at teardown only, not real growth.

## Tools

### ASAN (clang-cl)
Rebuild, then `ASAN_OPTIONS=detect_leaks=1:leak_check_at_exit=1`. Ship a `lsan.supp` to filter DirectX/vendored DLL globals.

### UMDH (MSVC / any Windows)
```
gflags -i the engine.exe +ust
umdh -p:<pid> -f:before.txt
# exercise 5 min
umdh -p:<pid> -f:after.txt
umdh before.txt after.txt -f:diff.txt
```
Sort by delta; top offenders are your leak.

### Application Verifier + `!heap`
For corruption. Enable Heaps test, run in WinDbg, `!heap -x <addr>` on failing address.

### VLD
`#include <vld.h>` in main.cpp for MSVC Debug. Fine for early-dev; slows Debug 3x.

## Systemic leak sites
- Shader hot-reload: `ID3DBlob` not `Release()`d before map overwrite. Use `ComPtr`.
- Jobs: shared_ptr cycles from lambda captures.
- Reflection registry: plugin unload leaves entries pinned.
- Asset cache: strong refs everywhere; introduce `weak_ptr` where cache isn't owner.

## Method
1. Reproducer with a single asset/scene.
2. Snapshot at t=0 and t=+5 min steady state.
3. Diff, group by alloc site, ignore <MB.
4. Top allocator -> caller chain -> fix.
5. Re-snapshot; if a new site tops the list, you fixed a real leak.

## the engine allocator hook
If the engine has `engine::alloc::hook_new`, inject `CaptureStackBackTrace` -> ring buffer -> dump at leak time = 100% leak-site info with no external tool.