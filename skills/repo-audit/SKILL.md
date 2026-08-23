---
name: repo-audit
description: Read-only sweep of a C++ engine repo for tech debt, dead code, TODO/FIXME/HACK counts, cyclomatic outliers, and stale branches. TRIGGER when the user says "audit the repo", "code health", "what should we refactor first", "find dead code", "how much tech debt", "TODO count", "cyclomatic complexity", "stale branches". DO NOT TRIGGER for code review of a specific diff (use engineering:code-review) or refactor planning (use refactor-planner agent). Produces a rank-ordered debt report -- not a plan, not a diff, just a survey.
---

# repo-audit

## Output

```
# Repo audit -- <repo> -- <date>
## Executive summary
- N files, M SLOC, K markers.
## Debt hotspots (rank-ordered)
1. file.cpp -- CCN X, N TODOs, last modified <date>. Notes.
## Dead code candidates
## Stale branches
## Suggested first refactors (top 5)
```

## Method

1. `cloc . --exclude-dir=build,vendored,third_party,.vs --quiet` for SLOC.
2. `git grep -c "TODO\|FIXME\|HACK\|XXX" -- "*.cpp" "*.h" | sort -t: -k2 -n -r | head -30` for marker density.
3. `lizard -l cpp -T CCN=15 .` for cyclomatic outliers. CCN>15 worth looking, >30 untestable.
4. `cppcheck --enable=unusedFunction` + clangd cross-refs for dead code candidates (30% false positive; verify).
5. `git for-each-ref --sort=-committerdate refs/remotes/origin` for stale branches (>180 days = candidate delete).

## Debt density score
```
score = 0.4 * CCN + 0.3 * markers + 0.2 * (stale?10:0) + 0.1 * (size>500?10:0)
```
Top 20 = shortlist.

## Exclude
Generated files, `third_party/`, `external/`, test fixture data.

## Handoff
Audit is diagnostic. Rank list -> `refactor-planner` or human triage.