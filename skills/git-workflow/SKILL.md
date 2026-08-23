---
name: git-workflow
description: "Branch, PR, rebase, and merge patterns for the engine and other C++ engine projects. TRIGGER when the user says 'how do I rebase', 'safe force push', 'worktree', 'cherry-pick', 'clean up my branch', 'prepare a PR', 'amend that commit', 'rewrite history safely', 'git conflict in generated header'. DO NOT TRIGGER for repo audits (use repo-audit), CI failures (use ci-troubleshoot), or code review (use engineering:code-review). Handles the claude/topic naming convention, per-branch worktrees for parallel MSVC builds, safe --force-with-lease, and how to recover after a botched rebase."
---

# git-workflow

the engine convention: every autonomous / long-running branch uses `claude/<topic>` (e.g. `claude/harden-fleet`). Human-authored branches use plain `<topic>`.

## Branch lifecycle
1. `git switch -c claude/<topic> origin/main` -- fork from `origin/main`, never local main.
2. Commit small; each commit compiles under MSVC Debug.
3. Rebase, don't merge, when catching up: `git fetch origin && git rebase origin/main`.
4. Force-push with lease: `git push --force-with-lease origin claude/<topic>`.

## Worktrees for parallel MSVC builds
```
git worktree add ../the engine-fleet claude/harden-fleet
git worktree add ../the engine-msvc  claude/msvc-cleanup
```
Each worktree gets its own `build/` so MSVC and clang-cl can co-exist without stomping caches.

## PR checklist (the engine)
- Branch name matches `claude/<topic>` if agent-authored.
- CI matrix green: MSVC Debug, MSVC Release, clang-cl.
- No generated headers committed.
- CHANGELOG.md updated if user-facing subsystem changed.

## Recovering from a bad rebase
```
git reflog
git reset --hard HEAD@{N}
```

## Windows gotchas
- Don't commit `*.pdb`, `*.ilk`, `*.exp`.
- Pin line endings in `.gitattributes`: `*.hlsl text eol=lf`.
- After `git checkout <sha>`: `git switch -c` before committing.