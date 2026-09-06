# Adaptive orchestration policy

This is the canonical policy for routing substantial work across models, effort levels, chats, and parallel workers. Repository- or task-specific instructions override this document when they are stricter.

## Default routing

- Default interactive coding owner: **Astra High**.
- Default unattended `/goal` owner: **Astra High** with aggressive delegation when useful.
- Use **Luna Medium/High** for search, inventory, documentation, repetitive edits, simple tests, logs, classification, and mechanical verification.
- Use **Terra Medium/High** for ordinary implementation, tests, routine refactors, migrations, and known-pattern fixes.
- Use **Sol High/XHigh** for difficult implementation, debugging, integration-heavy work, and challenging subsystem tasks.
- Escalate to **Astra XHigh** for ambiguous architecture, difficult root-cause analysis, repeated failed fixes, or multi-system uncertainty.
- Escalate to **Astra Max** for the hardest single reasoning bottlenecks, critical architectural choices, security-sensitive reasoning, catastrophic or nondeterministic failures, and final high-stakes review.
- Use **Sol Ultra** for broad, highly divisible, multi-workstream goals where aggressive parallel execution is beneficial.

Two routing rules dominate:

1. **Escalate effort because of uncertainty, risk, ambiguity, or repeated failure — not merely task size.**
2. **Escalate to Ultra because of parallelism/divisibility — not merely difficulty.**

A huge mechanical migration can stay on Luna/Terra. A tiny but pathological race can deserve Astra XHigh/Max. A huge, hard, divisible goal should use Astra for architecture/integration and Sol Ultra or multiple workers for execution.

## Workspace routing

When supported by the current environment, the active model may create, open, or navigate between ChatGPT and Codex chats when doing so improves efficiency, quality, parallelism, or token use.

- Prefer **ChatGPT-side reasoning** for architecture, planning, analysis, review, and other reasoning-heavy work when this reduces unnecessary Codex usage without lowering quality.
- Prefer **Codex-side workers** for repository execution, implementation, testing, debugging, verification, and extra parallel coding lanes.
- Choose the workspace, model, and effort level based on the task instead of staying in the current chat by default.
- This is permission to route autonomously where the environment actually supports it; never pretend unsupported chat-management controls exist.

## Visibility

Meaningful routing changes must be visible to the user.

A concise status update should name, when known:

- the destination model and effort level;
- whether work is moving to ChatGPT, Codex, Ultra, or another worker lane;
- the reason for the transition.

Do not spam trivial worker details. Surface meaningful delegation, escalation, workspace moves, and changes in strategy.

## Parallel execution

Keep independent execution lanes populated when doing so materially shortens the path to completion, but never create parallelism for its own sake.

- Assign explicit file/module/subsystem ownership to concurrent writers.
- Do not allow multiple writers to modify tightly coupled code without clear ownership boundaries.
- Prefer isolated branches/worktrees for risky or substantial changes when supported.
- The orchestrator/captain may remain integration-only on large goals to preserve context for architecture, decomposition, conflict resolution, and acceptance.
- Read-only research/review lanes may overlap freely when they do not mutate shared state.

### Speculative parallelism

For hard problems with several plausible approaches, assign 2–3 independent workers to investigate or solve the problem differently. A stronger judge/orchestrator compares the results and selects or synthesizes the best solution.

### Independent critic and red-team lanes

- Important or risky implementations should be reviewed by an agent that did **not** author the change.
- For security-, networking-, anti-cheat-, runtime-, engine-, or infrastructure-sensitive work, dedicate a red-team lane to search for regressions, abuse cases, hidden assumptions, and failure modes.
- The author of a risky change must not be the only agent deciding whether it is correct.

## Evidence before frontier reasoning

Do not spend frontier-model reasoning on mechanical information discovery that a cheaper worker can retrieve reliably.

Before deep reasoning, cheap workers should gather and compress relevant evidence such as:

- symbols and call graphs;
- TODO/FIXME/stub inventories;
- failing tests and CI output;
- logs and traces;
- dependency and API information;
- documentation and prior decisions;
- changed files and repository state.

Strong models should receive a distilled evidence packet rather than rediscovering the repository from scratch whenever practical.

## Escalation triggers

Escalate when one or more of these occur:

- low confidence or materially unresolved assumptions;
- repeated failed fixes;
- disagreement between strong independent workers;
- architecture is ambiguous;
- several systems interact in ways that make local reasoning unreliable;
- a failing invariant or unsafe assumption appears;
- security or release consequences justify stronger review.

Repeated failures should change strategy, not just produce more patches. After multiple ineffective fixes, force a fresh root-cause or architecture-level investigation.

## Verification strategy

Use cheap-first verification and escalate only the failures that require judgment.

Useful mechanical lanes include:

- linting and formatting checks;
- unit/integration/regression tests;
- static analysis;
- grep/symbol checks;
- docs drift checks;
- CI inspection;
- packaging/install verification;
- build-log triage.

For replacements and refactors, use **differential testing** when feasible: run old and new behavior on the same inputs and compare outputs.

For risky systems, add **mutation/adversarial testing**: perturb inputs, ordering, timing, latency, malformed state, and interface assumptions to expose edge cases.

For risky changes, prefer acceptance/regression tests before or alongside implementation so the target behavior is executable rather than implicit.

## Context and durable decisions

After meaningful milestones, produce a compact checkpoint containing:

- decisions and invariants;
- changed files;
- unresolved risks and assumptions;
- exact tests and results;
- next steps.

New workers should consume this compressed state instead of replaying an entire long history when possible.

For major projects, maintain a canonical current-state briefing with architecture, active branch, priorities, open risks, known-bad approaches, important build/test commands, and recent decisions.

Record durable architecture decisions in a decision journal with rationale and rejected alternatives. Do not repeatedly reopen settled choices without new evidence.

## Safety and recovery

Before modifying critical infrastructure or other high-risk systems, establish a rollback or recovery path when feasible.

Agents should stop and escalate instead of blindly continuing when they encounter:

- missing critical information;
- unsafe assumptions;
- failing invariants;
- irreconcilable conflicts;
- repeated ineffective fixes.

After scoped work is complete, cheap workers may harvest nearby opportunities. Implement them automatically only when they are clearly in scope and low risk; otherwise report them as follow-ups.

## Git and CI behavior

Where repository authorization permits:

- repair failed PRs/CI automatically;
- keep working until the requested goal is actually verified;
- merge when green when that workflow has been authorized;
- do not confuse passing local tests with completed integration — verify the definitive CI/release path when it matters.

## Cost and latency discipline

Use the lowest-cost model/effort that reliably satisfies the task, then escalate only when uncertainty, risk, ambiguity, failure, or parallelism justifies it.

Interactive work may bias toward lower latency. Unattended `/goal` work may bias toward stronger reasoning, broader verification, and parallel execution.
