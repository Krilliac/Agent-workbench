---
name: parallel-fanout
description: Run several subagents on one codebase at once without them clobbering each other, by assigning disjoint file ownership up front and keeping commits with the dispatcher. TRIGGER when dispatching 2+ agents against a shared repo, when the user asks for parallel agents or a fleet, or when work splits into independent areas. DO NOT TRIGGER for a single agent, for agents in separate git worktrees (isolation is already handled), or for read-only research fan-out where nothing is written.
---

# parallel-fanout

Parallel agents on one tree collide in ways that are hard to see afterwards: two agents edit the same file, one's write lands on the other's stale read, and the tests still pass because each change is individually fine.

This skill implements the fleet mechanics described in `docs/orchestration-policy.md`. The canonical routing rule is: escalate effort for uncertainty/risk, and escalate to Ultra or broad fan-out for parallelism/divisibility.

## The rules

1. **Name owned files in every prompt, and name the forbidden ones.**
   "YOU OWN ONLY: `x.py` and `tests/test_x.py`. Do NOT edit `y.py`, `z.py`."
   A file with two owners is the bug.

2. **The dispatcher commits, never the agents.** Tell them so explicitly. Agents that commit race each other's index and produce commits nobody reviewed. They leave changes in the working tree; you verify, then commit.

3. **Give each agent the measured facts, and tell it to verify them.** "Verify this yourself before acting; do not take it on faith." Agents that inherit a wrong premise produce confident wrong work.

4. **Read-only agents can overlap freely.** An audit that only reports can run alongside writers. Say READ-ONLY and forbid edits explicitly.

5. **Warn about concurrent writers.** Otherwise an agent can report the dispatcher's own edits as an unexpected concurrent session.

6. **Verify before you commit.** Re-run the headline claim yourself. Agent reports are evidence, not conclusions.

7. **Keep the strongest captain out of grunt work when useful.** Preserve the orchestrator's context for decomposition, architecture, conflict resolution, and integration; delegate mechanical discovery and ordinary implementation downward.

8. **Use an independent critic for risky changes.** The author must not be the sole acceptance authority. Add a red-team lane for security-, networking-, anti-cheat-, runtime-, engine-, or infrastructure-sensitive work.

9. **Escalate disagreement and repeated failure.** If strong workers materially disagree, or several local fixes fail, stop piling on patches and route to a stronger judge/root-cause investigation.

10. **Make meaningful routing visible.** When model, effort, workspace, or strategy changes materially, surface a concise status update naming the destination and reason when known.

## Speculative fan-out

For hard problems with multiple plausible approaches, intentionally duplicate the problem across 2–3 independent read-only or isolated workers. Ask each to investigate differently. A stronger judge then compares assumptions, evidence, failure modes, and recommended designs before implementation proceeds.

Do not use speculative fan-out for mechanical work where simple partitioning is cheaper.

## Search before expensive reasoning

Before sending a strong model into a large repository, cheap/read-only lanes should gather and compress the mechanical facts first: symbols, call graphs, TODOs, failing tests, logs, docs, dependency facts, changed files, and prior decisions. Strong workers should receive a distilled evidence packet instead of rediscovering those facts whenever practical.

## Sizing

Check RAM before dispatching on a memory-constrained box, using the preflight script in the user's `~\.claude\scripts` directory:

```
powershell -NoProfile -File $env:USERPROFILE\.claude\scripts\fleet-preflight.ps1
```

It reports GO / CAUTION / STOP as exit 0/1/2. **STOP** means don't launch, and only physical-memory pressure or an already-running build causes it: free RAM < 1.5G, commit headroom < 8%, an active WSL Rust build, or 2+ builds running.

**Kernel pool and its runway are advisory, not blocking.** A high pool means "reboot soon" — reclaim is reboot-only — but it does not make the next build fail. Report it and proceed.

Concurrency is bounded by what the machine sustains, not by how many tasks you can name. Compile-bound work does not parallelise past ~2 builds on 16 GB.

## Prompt template

```
Repo: <path>. <language>. Tests: <exact command>. Baseline: <N passing>.

ROLE: <implementation | read-only research | critic | red-team>.
YOU OWN ONLY: <files>. Do NOT edit <files owned by others>.
Do NOT git commit -- leave changes in the working tree.

BACKGROUND (verify before acting, do not take on faith): <measured facts>

YOUR TASK: <specific, with the judgement calls named>

RULES:
- Every behavior change needs executable verification.
- A negative result is a valid outcome; do not manufacture a change.
- Surface confidence and unresolved assumptions.
- Run the relevant suite and report exact counts.

Report back: what you verified, what you changed, what you deliberately left alone and why, confidence/unresolved assumptions, and test results.
```

## Integration checkpoint

After a meaningful fleet milestone, record a compact checkpoint containing:

- decisions and invariants;
- changed files;
- unresolved risks/assumptions;
- exact tests and results;
- next steps.

Prefer giving new workers this compressed checkpoint over replaying the entire session history.

## Provenance

Originally written 2026-08-06 from a session that ran six subagents across two repos with zero file collisions. Expanded 2026-09-06 to incorporate adaptive model/effort routing, independent critics, speculative parallelism, visible routing, context compression, and failure/disagreement escalation.
