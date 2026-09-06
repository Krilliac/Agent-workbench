# Parallel agent workflows

See [`orchestration-policy.md`](orchestration-policy.md) for the canonical model/effort/workspace routing policy. This file focuses on shared-repository fleet mechanics.

Parallel read-only analysis is usually safe. Parallel writers are safe only when file ownership is explicit and non-overlapping.

Recommended shape:

`recon → design → contract freeze → ownership audit → writers → tests → independent critic → adversarial review → integration`

Before launching a build-heavy workflow:

1. Check available memory and commit headroom.
2. Keep concurrent C++ builds bounded; separate build directories do not isolate a shared source tree.
3. Give every writer an owned-file list and a forbidden-file list.
4. Keep the strongest/orchestrating model focused on architecture, conflict resolution, and integration when routine implementation can be delegated.
5. Have one dispatcher run the definitive test suite after writers finish.
6. Have an independent reviewer inspect risky changes; the author must not be the only acceptance authority.
7. Record whether a reported test result was produced while other writers were active.
8. Escalate repeated failures or material model disagreement instead of piling on more local patches.

For hard problems with several plausible approaches, use speculative parallelism: ask 2–3 independent workers to investigate differently, then have a stronger judge compare or synthesize the results.

Treat model-generated patches as drafts. Require a diff review, relevant tests, and a size/scope sanity check before accepting automated repairs. Use differential testing for replacements/refactors and adversarial or mutation-style tests for timing-, networking-, security-, engine-, runtime-, and infrastructure-sensitive changes when practical.

Do not spend expensive model context on mechanical discovery if a cheaper read-only lane can gather symbols, logs, TODOs, failing tests, documentation, or dependency facts first. Distill those findings before handing them to the stronger model.

Do not pass secrets, credentials, private transcripts, or proprietary source to an unapproved remote model.

In multi-worktree repositories, avoid shared stash state. Prefer explicit branches or temporary copies when a clean comparison is needed. For risky or substantial parallel work, isolated branches/worktrees are preferred when supported.

After a milestone, write a compact checkpoint: decisions/invariants, changed files, unresolved risks, exact tests/results, and next steps. New workers should start from that checkpoint instead of replaying an entire long session when possible.
