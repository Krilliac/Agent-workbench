---
name: adaptive-orchestration
description: Route complex coding/research work across models, effort levels, ChatGPT/Codex workspaces, and parallel workers using uncertainty-, risk-, and parallelism-aware escalation. TRIGGER for substantial multi-step coding goals, unattended /goal runs, multi-agent delegation, model/effort selection, repeated failed fixes, large repo-wide work, or when deciding whether to use Ultra/parallel workers. DO NOT TRIGGER for trivial single-step edits that can be completed directly without meaningful routing decisions.
---

# adaptive-orchestration

Use `docs/orchestration-policy.md` as the canonical policy. This skill turns that policy into an execution loop.

## 1. Classify the work

Estimate these axes independently:

- **uncertainty** — how unclear is the correct solution/root cause?
- **risk** — cost of a wrong answer/change;
- **parallelism** — how cleanly can the work split into independent lanes?
- **mechanical load** — how much discovery/repetition can cheaper workers absorb?
- **latency sensitivity** — interactive vs unattended goal execution.

Do not equate size with difficulty.

## 2. Choose the owner

Default owner for substantial coding work: **Astra High** when available.

Route downward for routine work:

- **Luna Medium/High** — search, inventory, docs, repetitive edits, simple tests, logs, classification, mechanical verification.
- **Terra Medium/High** — ordinary implementation, tests, routine refactors/migrations, known-pattern fixes.
- **Sol High/XHigh** — difficult implementation, debugging, integration-heavy subsystem work.

Route upward for uncertainty/risk:

- **Astra XHigh** — ambiguous architecture, difficult root-cause analysis, repeated failed fixes, multi-system uncertainty.
- **Astra Max** — hardest single reasoning bottlenecks, critical architecture/security decisions, catastrophic/nondeterministic failures, final high-stakes review.

Route outward for parallelism:

- **Sol Ultra** or equivalent multi-agent parallel execution — broad, highly divisible multi-workstream goals.

If exact model names are unavailable in the current environment, preserve the roles: cheap mechanical worker, ordinary implementer, strong subsystem worker, strongest judge/captain, parallel execution tier.

## 3. Search before expensive reasoning

Before deep repository reasoning, dispatch cheap/read-only reconnaissance when useful. Gather:

- relevant files/symbols/call graph;
- TODO/FIXME/stub inventory;
- failing tests/CI/logs;
- dependencies and API contracts;
- prior decisions/docs;
- changed-file state.

Compress findings into an evidence packet. Do not burn frontier context rediscovering reliable mechanical facts.

## 4. Decompose and lock ownership

Split only work that is truly independent.

For concurrent writers, state:

- owned files/modules;
- forbidden files/modules;
- exact acceptance tests;
- whether commits are forbidden;
- known concurrent writers.

Use worktrees/branches for risky substantial changes when supported.

## 5. Add independent challenge

For important/risky work:

- implementation lane(s);
- independent critic lane;
- red-team lane when security/networking/anti-cheat/runtime/engine/infrastructure sensitive.

The author cannot be the sole acceptance authority.

For a hard ambiguous problem, use speculative parallelism: 2–3 independent approaches, then a stronger judge compares evidence and chooses/synthesizes.

## 6. Escalate intelligently

Escalate when:

- confidence is low;
- assumptions remain material/unresolved;
- fixes repeatedly fail;
- strong workers disagree;
- invariants fail;
- architecture/system interactions defeat local reasoning;
- consequence justifies stronger scrutiny.

Repeated failure must change strategy. Stop symptom patching and force fresh root-cause/architecture analysis.

## 7. Verify cheap-first

Use cheaper lanes first for:

- lint/format;
- unit/integration/regression tests;
- static analysis;
- grep/symbol checks;
- docs drift;
- CI/log inspection;
- packaging/install verification.

Escalate only failures that require judgment.

Where useful:

- differential-test old vs new behavior on the same inputs;
- adversarially perturb timing/order/latency/malformed state;
- write acceptance/regression tests before or alongside risky implementation.

## 8. Make routing visible

When a meaningful model, effort, workspace, or strategy transition occurs, send a concise status update naming when known:

- destination model/effort;
- ChatGPT/Codex/Ultra/worker lane;
- why the transition is happening.

Do not spam trivial routing details.

## 9. Checkpoint context

After meaningful milestones, record:

- decisions/invariants;
- changed files;
- unresolved risks/assumptions;
- exact tests/results;
- next steps.

Prefer this checkpoint for new workers over replaying an entire long session.

## 10. Finish with independent acceptance

Before declaring success:

- review the diff/scope;
- run definitive tests/CI where applicable;
- obtain independent review for risky work;
- verify rollback/recovery for critical infrastructure when feasible;
- harvest nearby opportunities, but implement only those clearly in scope and low risk.

Where authorized, repair failed CI/PRs automatically and continue until green; merge when green only when that workflow is explicitly authorized.
