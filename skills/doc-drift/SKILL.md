---
name: doc-drift
description: Detect divergence between code and docs (README, CHANGELOG, CLAUDE.md, engine handbook). TRIGGER when the user says "docs out of date", "README wrong", "doc drift", "sync docs to code", "is the CHANGELOG current", "does CLAUDE.md still match", "docs audit", "update the getting-started guide". DO NOT TRIGGER for writing new docs (use engineering:documentation). Compares docs against code, flags mismatches, produces a diff-list.
---

# doc-drift

## Compare
- `README.md` install commands + quick-start.
- `CHANGELOG.md` Unreleased vs commits since last tag.
- `CLAUDE.md` architecture claims vs actual layout.
- `docs/*.md` API refs vs current headers.
- Fenced code blocks compile against current API.

## Detection

### Code snippets
For every fenced `cpp`/`cmake`/`sh` block: extract, compile-test with current project. Fail = drifted.

### Install commands
Run in fresh docker container. Fail = drifted.

### Feature list
Parse feature claims. Cross-ref code presence (e.g. "supports Vulkan" -> `src/renderer/vulkan/`).

### API references
For each symbol in `docs/api/*.md`: confirm exists + signature matches. `clangd` or `include-what-you-use` for current symbol set.

### CHANGELOG vs git log
```
git log $(git describe --tags --abbrev=0)..HEAD --oneline
```
Diff against Unreleased. Missing = drift.

## Output table
```
| File | Section | Issue | Fix |
|---|---|---|---|
| README.md | Quick start | `-DBUILD_TYPE` -> `-DCMAKE_BUILD_TYPE` | Update snippet |
| CHANGELOG.md | Unreleased | 12 commits not documented | Append list |
```

## Fix, don't just report
When asked to sync, apply fixes. Never invent -- quote source (git log, header sig) per suggested change.