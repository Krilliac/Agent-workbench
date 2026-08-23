# Fable-5 skill forge - taxonomy

Adapt these slots to what Phase 1 finds. Merge thin, split deep, add domain categories. Aim for 10-16 total.

## CORE (every project has these)

| Slot | Intent |
| --- | --- |
| `<project>-change-control` | How changes are classified, gated, reviewed here. Non-negotiables with rationale and the historical incident behind each. |
| `<project>-debugging-playbook` | Symptom -> triage table for the project's failure modes. The traps that cost real time (each with its story). Discriminating experiments. |
| `<project>-failure-archaeology` | Every major investigation, dead end, rejected fix, revert. Symptom -> root cause -> evidence -> status. Mine git history hard. |
| `<project>-architecture-contract` | Load-bearing design decisions and WHY. Invariants that must hold. Open known-weak points stated plainly. |
| `<domain>-reference` | Domain-theory knowledge pack a mid-level person lacks (field's math/protocols/standards AS THEY APPLY HERE). |
| `<project>-config-and-flags` | Catalog of every configuration axis. Options, defaults, production vs experimental, guards. How to add one (checklist). Re-verification commands. |
| `<project>-build-and-env` | Recreate the environment from scratch. Known traps. |
| `<project>-run-and-operate` | Running/deploying. Command anatomy. Data/artifact conventions. Where output lands. |
| `<project>-diagnostics-and-tooling` | How to MEASURE instead of eyeball. Ship actual scripts inside the skill's `scripts/` dir where they exist. |
| `<project>-validation-and-qa` | What counts as evidence. Acceptance-threshold discipline. Certified/golden inventory. How to add tests. |
| `<project>-docs-and-writing` | Maintaining docs of record. Templates. House style. |
| `<project>-external-positioning` | Papers/releases/ecosystem: what is novel vs known; what must be proven before claiming; reproducibility standards. |

## ADVANCED (the layer that makes juniors dangerous, in the good way)

| Slot | Intent |
| --- | --- |
| `<project>-<hardest-problem>-campaign` | Executable, decision-gated campaign for Phase 1's hardest live problem. Numbered phases, exact commands, EXPECTED observations/numbers at every gate ("if you see X instead -> branch to Y"). Solution menu ranked with theory/derivation obligations. Known wrong paths fenced off. Validation-and-promotion protocol that routes through change control. |
| `<project>-proof-and-analysis-toolkit` | First-principles analysis methods of the domain (whatever "prove it, don't just install it" means here), each as a recipe with a worked example from this repo's history. |
| `<project>-research-frontier` | Open problems where this project could advance state of the art. For each: why current SOTA fails, this project's specific asset, first three concrete steps IN THIS REPO, falsifiable "you have a result when..." milestone. |
| `<project>-research-methodology` | Discipline that turns a hunch into an accepted result. Evidence bar: one mechanism must explain ALL observations (including negatives) and survive assigned adversarial refutation. Hypothesis-predicts-numbers-before-running. Idea lifecycle from experiment-flag to adopted change or documented retirement. Where good ideas historically came from. |

## Slot picking rules

- If the repo has no meaningful domain math (pure app code), collapse `<domain>-reference` into `<project>-architecture-contract`.
- If the repo has multiple hard live problems, spawn multiple `-campaign` skills but only if each has a decision tree that would fit on one screen.
- If the repo is not research-adjacent, drop `-research-frontier` and `-research-methodology`.
- Never merge `-failure-archaeology` with `-debugging-playbook`. Archaeology is chronological (what happened, why we stopped). Playbook is symptomatic (what to try when this fires).

## Skill description grammar

Every `description:` must contain:

1. What the skill does (one clause).
2. `TRIGGER when the user says ...` with 4-8 exact phrases.
3. `DO NOT TRIGGER for ...` naming at least one sibling skill.

Descriptions should be pushy - Claude undertriggers skills. Bias toward loading, not skipping.