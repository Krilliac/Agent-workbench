---
name: test-triage
description: For a given code diff, identify the minimum test set that must run and the likely-affected suites. TRIGGER when the user says "what tests should I run", "test impact", "which suites cover this", "am I safe to skip", "test triage", "affected tests", "smoke test for this PR". DO NOT TRIGGER for test-strategy design (use engineering:testing-strategy) or writing new tests. Fast-answer skill for iteration -- picks a minimum viable test set from a diff.
---

# test-triage

## Method
1. Enumerate changed files.
2. Per file, find tests referencing the file or declared symbols.
3. Group by test binary.
4. Rank: must-run > should-run > safe-skip.

## Static -> test mapping
Repo has `tests/impact.json`? Use it. Otherwise:
- Tests under `tests/` mirroring src.
- `grep -R "include.*<changed_file>"` finds tests pulling the header.
- `TEST(SuiteName, ...)` or `TEST_CASE(...)`. `grep -R SuiteName` finds file.

## Must-run
Renderer.cpp change:
- Tests including Renderer.h.
- Golden-image renderer tests.
- Integration boot+scene tests.

Docs change: nothing.
CMake change: reconfigure + smoke.

## the engine smoke set (3-5 s)
- `engine_unit_tests --gtest_filter="Startup.*:Shutdown.*"`
- `engine_smoke_tests --scene=empty`
- `renderer_golden_tests --scene=triangle`

## Full-test cost
Core touch (`memory`, `job_system`, `reflection`) = full unit test binary, 30 s. Don't slice.

## Output
```
Diff: 3 files
Must run (est 90 s): renderer_unit_tests --gtest_filter="Frame*:D3D12*"; renderer_golden_tests --scene=triangle,quad,cube
Should run (est 30 s): engine_smoke_tests
Safe skip: audio, physics, importer.
```

## Gotcha
Public-header change (`include/engine/type_id.h`) impacts everything downstream -> full run.