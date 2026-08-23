---
name: cmake-msvc
description: CMake presets for MSVC + Ninja + clang-cl, generator expression gotchas, cache invalidation, toolchain files. TRIGGER when the user says "CMakePresets", "MSVC config", "clang-cl won't find", "Ninja generator", "toolchain file", "target_link_libraries wrong", "generator expression not evaluating", "why did CMake reconfigure", "vcpkg triplet". DO NOT TRIGGER for simple CMakeLists edits with no build-system questions, or pure C++ compile errors (use msvc-error-decoder). Covers the engine's preset layout, Ninja Multi-Config vs single-config, and CMake cache invalidation rules.
---

# cmake-msvc

## Preset baseline
```json
{
  "version": 6, "cmakeMinimumRequired": { "major": 3, "minor": 28 },
  "configurePresets": [
    {
      "name": "msvc-debug", "generator": "Ninja",
      "binaryDir": "${sourceDir}/build/msvc-debug",
      "cacheVariables": { "CMAKE_C_COMPILER": "cl.exe", "CMAKE_CXX_COMPILER": "cl.exe",
        "CMAKE_BUILD_TYPE": "Debug", "CMAKE_CXX_STANDARD": "23" },
      "environment": { "CXXFLAGS": "/W4 /permissive- /Zc:__cplusplus /Zc:preprocessor" }
    },
    {
      "name": "clang-cl-release", "inherits": "msvc-debug",
      "binaryDir": "${sourceDir}/build/clang-cl-release",
      "cacheVariables": { "CMAKE_C_COMPILER": "clang-cl.exe", "CMAKE_CXX_COMPILER": "clang-cl.exe", "CMAKE_BUILD_TYPE": "Release" }
    }
  ]
}
```
`cmake --preset msvc-debug && cmake --build --preset msvc-debug -j`.

## Generator choice
- **Ninja**: fast, single-config. CI + command-line default.
- **Ninja Multi-Config**: multi-config in one dir; useful locally.
- **Visual Studio 17 2022**: only if you must have `.sln`.

## clang-cl
- `MSVC` variable is true for clang-cl too. Distinguish with `CMAKE_CXX_COMPILER_ID STREQUAL "MSVC"`.
- clang-cl silently ignores unknown `/Zc:` options; add `-Wno-unused-command-line-argument` for readable logs.
- LTO: `-flto=thin` (clang-cl) vs `/GL /LTCG` (MSVC).

## Cache invalidation
Reconfigures on: `CMakeLists.txt`, `CMakePresets.json`, `CMAKE_MODULE_PATH` files, env `CC`/`CXX`/`CFLAGS`/`CXXFLAGS`/`LDFLAGS`/`CMAKE_TOOLCHAIN_FILE`.

Does NOT: `find_package` config changes, vcpkg baseline (delete `vcpkg_installed/` to force).

If in doubt: `rm -rf build/<preset>` and reconfigure.

## Genex traps
- `$<CONFIG:Debug>` -- per-config, evaluates against `CMAKE_BUILD_TYPE` in single-config.
- `$<TARGET_PROPERTY>` fails inside `install(FILES ...)` (config-time only). Use `install(CODE "...")`.

## vcpkg triplets
- `x64-windows` -- dynamic MSVCRT + dynamic libs.
- `x64-windows-static` -- static MSVCRT + static libs.
- `x64-windows-static-md` -- dynamic MSVCRT + static libs. the engine's `/MD` default match.

## Method
1. Use presets. Never hand-type `-D...`.
2. One binary dir per config; never share across compilers.
3. Nuke binary dir before debugging "CMake bugs" -- half are cache staleness.