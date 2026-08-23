---
name: verify-claim
description: Check whether a number you are about to quote as evidence actually measures what you think, before reporting it as progress or success. TRIGGER when you are about to say "N errors", "N tests passing", "N warnings", "down from", "now clean", "build succeeded", "it works", or "fixed" -- and whenever a count is exactly 0 or 1, or has dropped sharply. DO NOT TRIGGER for reporting a number the user already has, for exploratory measurement you are not drawing a conclusion from, or as a substitute for superpowers:verification-before-completion when finishing a task (use that too, this is narrower and about the metric itself).
---

# verify-claim

A count is not evidence until you know what produced it. This is the check that
runs *before* you quote a number, not after.

## The one question

**Could this number be a floor rather than a total?**

Anything that stops a tool early shrinks its count without improving anything:

| Cause | What you see |
|---|---|
| Early phase failed | parse error hides every semantic error behind it |
| Tool hit its own cap | clang stops at 20 errors by default, MSVC at 100 |
| Process never launched | one "could not run" line reads as one error |
| Timeout / kill | **zero** errors, which looks exactly like success |
| Truncated output | the tail was dropped, and errors are usually at the tail |
| Pagination / `[:N]` | a slice reported as a total |
| Filter matched nothing | zero findings because the pattern was wrong |

## The checks

1. **Exactly 0 or 1 is the classic tell.** That is what an infrastructure
   failure looks like. Find out what produced it before believing it.
2. **Two counts compare only when both runs reached the same stage.** Zero
   failures at stage N says nothing about N+1: lint before typecheck, typecheck
   before test, parse before bind, compile before run.
3. **A sharp drop deserves more suspicion than a small one.** Real fixes move
   counts by a little. 106 -> 2 usually means something stopped measuring.
4. **Read the actual output, not the count.** Look at what the tool printed. If
   you cannot name the last thing it did, you do not know that it finished.
5. **Silence is not success.** An empty result set from a command that failed to
   start is indistinguishable from a clean run unless you check the exit path.

## What to do instead of asserting

- Re-run the measurement and look at the raw output.
- Name the mechanism: "3 tests fail, all in `X`, because `Y`."
- If you cannot explain *why* a number moved, say so rather than claiming the
  improvement. "Down to 2, but I have not confirmed that is real" is honest and
  costs nothing.
- State the stage: "2 errors *at the parse stage* — the binder has not run yet."

## Related

`superpowers:verification-before-completion` for finishing a task at all. This
skill is narrower: it is about whether one number means what you are about to
say it means.

## Provenance

Written 2026-08-06 after a session in which I reported "106 -> 14 -> 2 errors"
as progress **four separate times**. The true counts were 99, then 109. Each
time an early-phase failure had stopped the compiler before it measured the
rest, so the falling number meant "it got less far", not "it got better".

The specific failures, all in one session:

- **2 errors** — parse errors; the binder never ran. Real count 99.
- **1 error** — a duplicate member (C# CS0111). The type parsed but could not be
  declared, so no dependent file bound. Real count 109. This one fooled me
  *after* I had built a parse-error guard and believed the problem solved.
- **1 error** — my own build wrapper returning "error: build could not run",
  which counted as one ordinary error in the trustworthy tier, so a build that
  never launched outscored an honest one with thirty real errors.
- **0 errors** — a build killed by a timeout before printing anything, rendered
  as BUILD SUCCEEDED.

`superpowers:verification-before-completion` was installed the entire time and I
never invoked it. The gap was not tooling.
