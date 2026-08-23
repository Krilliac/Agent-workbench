---
name: release-checklist
description: Cut a the engine release -- version bump, changelog, tag, build matrix, artifact upload, smoke test. TRIGGER when the user says "cut a release", "tag v", "release checklist", "ship a build", "prepare release notes", "bump version", "publish artifacts", "smoke test the release". DO NOT TRIGGER for deploy-to-production of a live service (use engineering:deploy-checklist). Focused on tagged engine releases with an artifact matrix and public changelog.
---

# release-checklist

## Preconditions
- Main green on CI matrix for last 3 commits.
- No open P0 in milestone.
- CHANGELOG.md "Unreleased" section is real entries, not placeholders.

## Version bump
Semver. Files:
- `CMakeLists.txt`: `project(the engine VERSION X.Y.Z)`
- `include/engine/version.h`: `#define ENGINE_VERSION_MAJOR X` etc.
- `CHANGELOG.md`: rename Unreleased -> vX.Y.Z (YYYY-MM-DD); add fresh Unreleased.
- `docs/roadmap.md`: check off shipped items.

MAJOR = API/ABI break. MINOR = user-visible feature. PATCH = bug fixes only.

## Tag
```
git switch main && git pull --ff-only
git tag -a vX.Y.Z -m "the engine vX.Y.Z"
git push origin vX.Y.Z
```
Never move a tag. If wrong, cut vX.Y.Z+1.

## Build matrix
- `the engine-vX.Y.Z-win-msvc-x64.zip`
- `the engine-vX.Y.Z-win-clang-x64.zip`
- `the engine-vX.Y.Z-linux-x64.tar.gz` (if Linux supported)

Contents: binaries, PDBs (Win), headers, LICENSE, README, CHANGELOG entry.

## Smoke test
- Extract clean.
- Run sample project.
- Verify FPS on reference GPU.
- Verify debugger loads PDBs.
Publish only after smoke pass.

## Release notes
Break changes at top. Install instructions. Docs links.

## Post-release
Docs website bump. Discord `#releases`. Open milestone vX.(Y+1).Z; move Unreleased items in.

## Rollback (bug found in 24h)
Delete GitHub release (keep tag). Warn in `#releases`. Cut vX.Y.(Z+1); repeat.
