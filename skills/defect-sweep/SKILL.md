---
name: defect-sweep
description: Hunt a codebase for three recurring defect shapes -- a guard that silently no-ops, a metric that blends signals of different trustworthiness, and a count reported as a total when it is a floor. TRIGGER when you have just fixed a bug of one of those shapes and want its siblings, when a guard "should have caught that" and did not, when a health number looks too good, or when the user asks to audit for a class of bug rather than review a diff. DO NOT TRIGGER for reviewing a specific change (use engineering:code-review), for security scanning (use claude-security), or for general tech-debt surveys (use repo-audit).
---

# defect-sweep

Three shapes recur, they hide from tests, and **fixing one instance almost never
fixes the others**. Sweep for siblings after every fix.

## Shape A -- a guard that silently no-ops

A check that, when it cannot do its job, quietly does nothing instead of failing
loudly. Grep for, then *read*:

- `is` identity comparisons against a function or object a caller might wrap,
  decorate, or subclass
- `except Exception: pass` / `except: continue` / `except: return <permissive>`
  around a check
- a fallback that is permissive rather than restrictive
- `hasattr` / `getattr` feature probes that silently degrade

**The tell:** ask *"if this guard never ran, would anything look different?"* If
no, it can be dead without anyone noticing.

### Shape A2 -- a guard that fails closed into a consumer that reopens it

The nastiest variant. The guard *does* return the strict value, so it reads as
correct and its comment says "fail closed" -- but something downstream relaxes
that value before it decides anything. **Returning a scarier class is inert if
the consumer degrades it.**

**Do not read the guard. Read the matrix it feeds, and check every production
caller's flags.** A production gate should be treated as a contract: every
called `decide(interactive=False)`, where `ask` degrades to `allow`. So *no
severity of grade could fail closed*. Three separate sites believed they were
failing closed and none were -- one returned `"ask"` under a comment reading
"Fail closed", another returned `"dangerous"` under a comment claiming dangerous
"stops in every mode", which was false in three of four modes.

The fix is never a scarier grade. It is a value the consumer **cannot** degrade
(a distinct non-degradable class with its own row in the decision matrix).

**Sibling to hunt:** any enum where severity is ordered and a downstream step
clamps, defaults, or maps it. Escalating within the enum changes nothing.

## Shape B -- a metric that blends trust levels

One number averaging sources of different reliability: self-reported with
externally-validated, machine-graded with human-judged, synthetic with earned.

**The tell:** find the *threshold* that reads the blend, not just the display.
Fixing the display and leaving the gate is the standard half-fix.

## Shape C -- a count that is a floor

A number reported as a total when something stopped the measurement early:
truncation, caps, early exit, timeout, a failed launch, pagination, `[:N]`.

**The tell:** a count of exactly 0 or 1, or a sharp drop. See `verify-claim`.

## Method

1. **Grep for the pattern, then read the code.** A pattern match is not a
   finding.
2. **Construct the path.** For each candidate, say concretely how it misfires in
   production. If you cannot, discard it and record that you discarded it.
3. **Rank by consequence:** does it silently disable a correctness guard, or
   mislead a human decision?
4. **Prefer 5 verified findings to 30 speculative ones.** False positives cost
   more than they save.
5. **Report coverage.** List what you checked and cleared, so the sweep's blind
   spots are known.

Run it read-only when other work is live in the tree — a sweep that also edits
collides with whoever is writing.

## Provenance

Written 2026-08-06. Three defects of these shapes were found and fixed
individually in one session; a deliberate sweep afterwards found that **each fix
had been applied at exactly one site and every one had surviving siblings**:

- a blended-metric fix reached the display but not the gate's fallback branch,
  and missed 2 of 4 consumers of the same report
- an `embed_fn is embeddings.embed` fix left **5 identical copies** elsewhere
- a "count is a floor" guard missed the most common cause, and the harness
  built to enforce it had introduced a fresh instance of the same bug — a build
  that never ran scored better than one with thirty real errors

The sweep found a live fail-open guard in an update path, and a quarantine gate
whose base rates were 97.9% autograded, so lessons a human rejected were the
ones most likely to be silently removed. Neither was reachable by reviewing the
diffs that introduced them.
