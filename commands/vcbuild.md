---
description: Build a CMake project with MSVC on Windows (handles the vcvars + CC=cl gotcha)
---
Build a C++ CMake project with MSVC. `cl.exe` may not be on `PATH`, so run the build through the Visual Studio developer environment with the compiler pinned. Run via the shell appropriate to the host:

cmd //c "call \"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat\" && set CC=cl && set CXX=cl && $ARGUMENTS"

If $ARGUMENTS is empty, default to building the current project: `cmake --build build --config Debug` (run from the project root; configure first with `-G "Ninja Multi-Config"` if there's no build dir). Report compile/link errors clearly; never claim success without seeing a clean build + link.

For any nontrivial build, pipe the output through the log distiller instead of reading the raw log — it collapses thousands of lines to the deduped errors (first error verbatim), saving context in compile→fix loops:
`... 2>&1 | python "$env:USERPROFILE\.claude\scripts\distill_log.py" --msvc`
(or redirect the build to a file and run the distiller on it). Read the raw log only when the distilled root cause isn't enough.
