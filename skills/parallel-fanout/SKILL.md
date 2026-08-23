---
name: parallel-fanout
description: Run several subagents on one codebase at once without them clobbering each other, by assigning disjoint file ownership up front and keeping commits with the dispatcher. TRIGGER when dispatching 2+ agents against a shared repo, when the user asks for parallel agents or a fleet, or when work splits into independent areas. DO NOT TRIGGER for a single agent, for agents in separate git worktrees (isolation is already handled), or for read-only research fan-out where nothing is written.
---

# parallel-fanout

Parallel agents on one tree collide in ways that are hard to see afterwards:
two agents edit the same file, one's write lands on the other's stale read, and
the tests still pass because each change is individually fine.

## The rules

1. **Name owned files in every prompt, and name the forbidden ones.**
   "YOU OWN ONLY: `x.py` and `tests/test_x.py`. Do NOT edit `y.py`, `z.py`."
   A file with two owners is the bug.

2. **The dispatcher commits, never the agents.** Tell them so explicitly. Agents
   that commit race each other's index and produce commits nobody reviewed. They
   leave changes in the working tree; you verify, then commit.

3. **Give each agent the measured facts, and tell it to verify them.** "Verify
   this yourself before acting; do not take it on faith." Agents that inherit a
   wrong premise produce confident wrong work — one checked a claim in its brief
   and found it false on the data.

4. **Read-only agents can overlap freely.** An audit that only reports can run
   alongside writers. Say READ-ONLY and forbid edits explicitly.

5. **Warn about concurrent writers.** Otherwise an agent reports "another
   session is live on this tree" as a finding, having noticed your own edits.

6. **Verify before you commit.** Re-run the headline claim yourself. Agent
   reports are evidence, not conclusions — one reported "8 new tests" when it
   had added 2 and counted someone else's.

## Sizing

Check RAM before dispatching on a memory-constrained box, using the preflight
script in the user's `~\.claude\scripts` directory:

```
powershell -NoProfile -File $env:USERPROFILE\.claude\scripts\fleet-preflight.ps1
```

It reports GO / CAUTION / STOP as exit 0/1/2. **STOP** means don't launch, and
only physical-memory pressure or an already-running build causes it: free RAM
< 1.5G, commit headroom < 8%, an active WSL Rust build, or 2+ builds running.

**Kernel pool and its runway are advisory, not blocking.** A high pool means
"reboot soon" — reclaim is reboot-only — but it does not make the next build
fail. Report it and proceed.

Concurrency is bounded by what the machine sustains, not by how many tasks you
can name. Compile-bound work does not parallelise past ~2 builds on 16 GB.

## Prompt template

```
Repo: <path>. <language>. Tests: <exact command>. Baseline: <N passing>.

YOU OWN ONLY: <files>. Do NOT edit <files owned by others>.
Do NOT git commit -- leave changes in the working tree.

BACKGROUND (verify before acting, do not take on faith): <measured facts>

YOUR TASK: <specific, with the judgement calls named>

RULES:
- Every change needs a test whose docstring says WHY, citing measured numbers.
- A negative result is a valid outcome; do not manufacture a change.
- Run the FULL suite and report exact counts.

Report back: what you verified, what you changed, what you deliberately left
alone and why, and full-suite results.
```

## Provenance

Written 2026-08-06 from a session that ran six subagents across two repos with
zero file collisions, using exactly these rules. What each rule is for:

- **Disjoint ownership** — the one near-miss was two agents both wanting
  `server.py`; splitting it to "narrow call sites only" avoided it.
- **Dispatcher commits** — agents left work in the tree, which allowed verifying
  each headline claim before it landed. Two claims were wrong on inspection.
- **"Verify, do not take on faith"** — one agent checked a claim in its own brief
  against the data and found it false, which changed its design.
- **Warn about writers** — one agent reported a "concurrent writer" as a finding;
  it was the dispatcher's own edits.
- **Negative results welcome** — one agent concluded a suspected defect was
  working as intended and produced measurements proving it, which was more
  valuable than a change.
