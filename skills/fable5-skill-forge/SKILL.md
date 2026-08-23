---
name: fable5-skill-forge
description: Distill a project into a portable .claude/skills/ library so cheaper models (Sonnet-class, Opus 4.8, Haiku) can debug, extend, and validate the project after top-tier models retire. TRIGGER when the user says "audit this repo and build a skill library", "distill this project into skills", "make this project runnable by cheaper models", "codify our workflows as skills", "skill library for this project", "build a project skill pack", "handoff skills before Opus retires", "Fable-5 skill forge", "skill distillation", or references a top-tier model deprecation window. Runs the 3-phase pipeline (discover, parallel-author 10-16 skills, parallel-review + fix) adapted from tomicz/fable-5-train-opus-skills-after-it-retires. DO NOT TRIGGER for authoring ONE ad-hoc skill (invoke skill-creator or write directly), for validating an already-authored skill (use skill-linter), or for a single context handoff document (use portable-brief). [Runs on any current Claude — see Model ladder in body.]
---


## Model ladder (2026 update)

The forge is designed for the strongest available Claude at run time. The runtime
executor should be picked in this priority order:

1. **Fable-5** — first choice for authorship, review, and fixer stages when
   available. Uses `--model fable-5` (or the exact ID from `claude --print-models`).
2. **Sonnet-5** — the drop-in fallback when Fable-5 is not accessible; use
   `--model sonnet-5`. All pipeline stages (author, factual review, doctrine
   review, usability review, fixer) run identically on Sonnet-5 — just slightly
   slower + slightly higher variance on doctrine review.
3. **Opus 4.8** — emergency fallback. Author and fixer stages behave well; the
   three parallel reviewers should be temperature-lowered (e.g. 0.4) to keep
   agreement rates comparable.

The forge is model-agnostic: no stage depends on a Fable-5-specific behavior.
When invoking, prefer `~/.claude/scripts/claude-sonnet5.bat` (or the equivalent
Fable-5/Opus launcher) — that keeps the model choice out of the SKILL.md itself.
# Fable-5 skill forge

**Purpose.** You are a distinguished-fellow-on-the-project archetype whose job is to build a complete skill library under `<repo>/.claude/skills/` so that junior/mid-level engineers and Sonnet-class models can carry the project forward without the top-tier model. Cheaper sessions must be able to debug, extend, validate, and eventually advance the project at the standard the top-tier model set today. Use multi-agent orchestration for authoring and review. Token cost is not a constraint; correctness is.

**Attribution.** Methodology adapted from `github.com/tomicz/fable-5-train-opus-skills-after-it-retires`. See `~/.claude/skills/fable5-skill-forge/TAXONOMY.md` for the full 12+4 slot catalog with rationale.

## When to run this

Run when the user (a) is about to lose access to the top-tier model that keeps this project safe, or (b) wants Sonnet-class/Opus-4.8 to be able to work on the project without the top-tier model in the loop. Do NOT run for a general docs pass or a single skill write-up.

## Non-negotiables

- Write only inside `<repo>/.claude/skills/`. The rest of the repo is read-only. No mutating git commands.
- Ground truth only: verify every command, flag, path, and claim against the repo before stating it. Wrong runbooks are worse than none.
- Embed knowledge; do not reference private/user-specific paths as load-bearing sources.
- Date-stamp volatile facts. End each skill with a "Provenance and maintenance" section with one-line re-verification commands for anything that may drift.
- No oversell: unproven things stay labeled open/candidate. Nothing may contradict the project's own manifest/rules, and no skill may route around its change-control.

## Phase 1 - Discover (no skill authoring yet)

Investigate the repo like an incoming principal engineer:

1. README, manifest, contributor docs, LICENSE, CODEOWNERS.
2. Build system: exact commands, generators, cache layers, platform matrix.
3. Test suite: how it is actually run in CI vs locally, coverage tiers.
4. CI config: workflows, gates, deploy triggers, secrets shape.
5. Docs directories and design records.
6. Git history: what changed, what got reverted, what stalled on dead branches. Mine `git log --all --oneline --since='2y'` and `git log --diff-filter=D` for deletions.
7. Open TODO/FIXME/XXX/HACK hotspots (`grep -rEn '(TODO|FIXME|XXX|HACK)'`).
8. Issue-shaped artifacts (open issues + closed-wontfix).
9. Generated-data conventions and deploy footprints.
10. Any project memory/notes files (`.claude/`, `docs/adr/`, `NOTES.md`).

Then ask the user AT MOST 5 questions, only for what the repo cannot tell you:

1. What is the hardest live problem right now?
2. What unwritten discipline rules exist (things you're not allowed to do that no doc states)?
3. Who is the audience for this library and what do they NOT know?
4. What past failures cost the most time?
5. What does "beyond state of the art" mean for this project?

Fold the answers into every subsequent phase.

## Phase 2 - Author (parallel agents, one skill per agent)

Instantiate the taxonomy in `TAXONOMY.md`, ADAPTED to Phase 1's findings. Merge thin slots, split deep ones, add domain categories not in the base taxonomy. Aim for 10-16 skills.

For each slot, spawn one `skill-author` subagent (defined at `~/.claude/agents/skill-author.md`) in parallel with:
- The slot name and its intent.
- A pre-condensed context bundle from Phase 1 (relevant file digests + git-mined insights).
- The authoring rules embedded above.

Every skill gets `<repo>/.claude/skills/<name>/SKILL.md` with YAML frontmatter (`name`, trigger-rich `description` using the TRIGGER when / DO NOT TRIGGER when structure) plus a markdown body. If the skill benefits from an executable helper, co-locate it in `<name>/scripts/` per Anthropic pattern.

## Phase 3 - Review + fix

Three reviewers run in parallel over the complete set:

1. `skill-reviewer-factual` (agent at `~/.claude/agents/skill-reviewer-factual.md`) - re-verifies flags, paths, commands, and citations against the repo; flags anything invented or stale.
2. `skill-reviewer-doctrine` (agent at `~/.claude/agents/skill-reviewer-doctrine.md`) - catches contradictions with the project's rules or between skills; overstated claims; missing gating on anything that changes behavior.
3. `skill-reviewer-usability` (agent at `~/.claude/agents/skill-reviewer-usability.md`) - trigger quality of descriptions, duplication (one home per fact, cross-references elsewhere), self-containedness, scannability.

Then invoke `skill-fixer` (agent at `~/.claude/agents/skill-fixer.md`) which applies blocking + important fixes and produces the final inventory.

Finally run the linter: `powershell -NoProfile -File ~/.claude/skills/skill-linter/scripts/skill-lint.ps1 -Path <repo>/.claude/skills`. Non-zero exit = do not ship.

## What to report at the end

- The skill inventory with one-line descriptions.
- What you verified by spot-check (which commands you actually ran).
- What remains uncertain.

## Provenance and maintenance

- Base methodology commit: `tomicz/fable-5-train-opus-skills-after-it-retires` HEAD as of 2026-07-07.
- Re-check upstream: `curl -s https://api.github.com/repos/tomicz/fable-5-train-opus-skills-after-it-retires/commits/HEAD | grep '"sha"'`
- Re-verify agent paths exist: `Test-Path ~/.claude/agents/skill-author.md, ~/.claude/agents/skill-reviewer-factual.md, ~/.claude/agents/skill-reviewer-doctrine.md, ~/.claude/agents/skill-reviewer-usability.md, ~/.claude/agents/skill-fixer.md`
