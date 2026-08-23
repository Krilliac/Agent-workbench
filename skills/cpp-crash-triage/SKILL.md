---
name: cpp-crash-triage
description: Windows C++ crash dump analysis with procdump, WinDbg, ASAN, UBSAN, and Application Verifier. TRIGGER when the user says "crashed", "access violation", "0xC0000005", "stack overflow", "read a .dmp", "why is it crashing", "ASAN says", "double free", "use after free". DO NOT TRIGGER for compile errors (use msvc-error-decoder), memory leaks not causing crash (use memory-hunt), or hangs (need thread dump instead). Covers procdump automation, WinDbg command reference, Application Verifier's allocator interception, and interpreting ASAN/UBSAN traces from clang-cl builds.
---

# cpp-crash-triage

## Capture the dump

`procdump -ma -e -x C:\dumps the engine.exe` (full dump on unhandled exception, launch + monitor).

WER: `reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting\LocalDumps" /v DumpType /t REG_DWORD /d 2 /f`, dumps land in `%LOCALAPPDATA%\CrashDumps`.

## Read (WinDbg)
```
!analyze -v       # first-pass summary
.ecxr             # context to fault (for AVs)
kb                # stack with args
~*kb              # every thread's stack
!heap -stat       # heap stats, flags corruption
!heap -x <addr>   # walk heap for corruption addr
```

## Application Verifier

`appverif.exe` UI -> add the engine.exe -> Basics + Heaps. Reproduces near-miss corruptions as hard crashes on the exact instruction.

## ASAN / UBSAN (clang-cl)

`-fsanitize=address,undefined -fno-omit-frame-pointer -g`; set `ASAN_OPTIONS=abort_on_error=1:halt_on_error=1:symbolize=1`, point `ASAN_SYMBOLIZER_PATH` at `llvm-symbolizer.exe`.

Read top-to-bottom: classification -> WRITE/READ site -> freed-by (for UAF).

## Common the engine sites
- Renderer: dangling `ID3D12Resource*` after Reset. Null on Reset, check before Bind.
- Jobs: capture `this` in lambda that outlives job. Use `weak_ptr` or copy state.
- Reflection: `type_index` of template moved to different TU across hot reload. Pin generation to one TU.

## Method
1. Dump -> `!analyze -v` -> classification.
2. Top 5 frames of call stack.
3. Cross-ref recent commits touching those files.
4. If corruption suspected, enable Application Verifier; reproduce. 10x easier.