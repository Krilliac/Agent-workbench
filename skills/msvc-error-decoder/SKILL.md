---
name: msvc-error-decoder
description: "Decode cryptic MSVC compiler and linker errors (C####, LNK####, MSB####) to root cause and concrete fix. TRIGGER when the user pastes an MSVC error, says 'what does C2760 mean', 'MSVC won''t compile', 'LNK2019 unresolved external', 'internal compiler error', 'std::ranges won''t compile', 'modules not found'. DO NOT TRIGGER for clang or gcc errors, runtime crashes (use cpp-crash-triage), or architectural link issues (use linker-error-fixer agent). Specializes in MSVC C++20/23 pitfalls including coroutines, modules, ranges, concepts, chrono, and iterator debug level mismatches."
---

# msvc-error-decoder

## Compiler errors (C####)
| Code | Cause on the engine |
|---|---|
| C1001 | ICE. Usually `/std:c++latest` + coroutine. Isolate offending fn. |
| C2039 | "not a member" -- lost include after IntelliSense edit. Check `git diff`. |
| C2065 | Undeclared -- `windows.h` before `NOMINMAX`/`WIN32_LEAN_AND_MEAN`. |
| C2760 | "expected ;" -- concept constraint failure, misleading. `static_assert` each requirement. |
| C2938 | Alias template specialize fail -- CTAD w/ `requires`. Add explicit args. |
| C3861 | Not found -- two-phase name lookup gap. Add `typename` / `this->`. |
| C7555 | Designated init order -- must match declaration order. |

## Linker errors (LNK####)
| Code | Cause |
|---|---|
| LNK2001 | Missing `.lib` in `target_link_libraries`, or dllimport/dllexport mismatch. |
| LNK2019 | Signature mismatch -- read whitespace/const/calling conv carefully; often template not instantiated. |
| LNK2005 | `.cpp` includes `.cpp`, or header defn not `inline`. |
| LNK4098 | `/MT` vs `/MD` mismatch. Rebuild the dep. |
| LNK1104 | `.pdb` locked -- kill `msbuild.exe`; check Defender. |
| LNK1120 | Rollup -- fix LNK2019s above. |

## Build system (MSB####)
- MSB4181 `tracker.exe 9009`: delete `%TEMP%\<user>\Microsoft\WindowsSDK\` cache.
- MSB6006 `CL -1073741819`: AV in the compiler -- bad `.pch`, delete intermediates.

## C++20/23 on MSVC 19.4x
- `<expected>` needs `/std:c++23`; feature test `__cpp_lib_expected >= 202211L`. VS 17.7+.
- `std::ranges::zip` -- VS 17.8+.
- Coroutines: `promise_type` needs `return_void()` XOR `return_value(T)`, never both.
- Modules: `.ixx` via `target_sources(... FILE_SET CXX_MODULES ...)`. CMake 3.28+.

## Method
1. Extract only the *first* error.
2. Translate to plain English.
3. Give the fix as a diff.