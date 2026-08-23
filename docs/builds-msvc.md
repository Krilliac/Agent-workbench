# C++ / MSVC / CMake builds

Windows shells often do not have `cl.exe` and the correct linker environment on `PATH`. Configure and build through the Visual Studio developer environment, pinning `CC=cl` and `CXX=cl` when CMake creates a fresh tree.

```powershell
cmd //c "call \"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat\" && set CC=cl && set CXX=cl && cmake --build build --config Debug"
```

Prefer Ninja Multi-Config for portable automation. For preset builds, set the working directory explicitly so `CMakePresets.json` is resolved from the project root. The workbench `scripts/build.ps1` wrapper performs a memory preflight, runs the command through `vcvars`, distills the log, and returns the underlying build exit code.

For MSVC Debug caching, embedded debug information (`/Z7`, or CMake’s `Embedded` setting with policy `CMP0141`) avoids separate PDB output that many compiler caches cannot package reliably. Verify a fresh configure and a clean build before attributing cache misses to the cache itself.

Always give CTest targets a timeout. A hung test can otherwise make the entire run look incomplete instead of failed.
