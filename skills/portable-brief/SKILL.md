---
name: portable-brief
description: Produce a single-file "cheaper-model brief" - a concentrated markdown document that loads the essential context a Sonnet-class or Opus-4.8-class model needs to work productively on a project without the top-tier model. TRIGGER when the user says "brief for cheaper model", "handoff to Sonnet", "context pack for smaller model", "escape hatch when Opus retires", "portable context bundle", "one-page project brief", or "onboarding doc for AI assistant". DO NOT TRIGGER for building the FULL skill library (use fable5-skill-forge - this produces one document, not a directory tree), for user-facing marketing docs, or for developer onboarding aimed at humans (use a normal README).
---

# portable-brief

Produce `<repo>/AI-BRIEF.md` (or a name the user requests). One document, opinionated, high-density.

## Structure

The brief must have exactly these sections, in this order:

1. **What this is** - 2-3 sentences. Product-level intent, not implementation.
2. **How to build and run** - exact commands, in order, that a cold laptop would need. Include known trap lines.
3. **The invariants** - things that must never break. If a change touches these, gate it hard.
4. **The hot files** - top 8-15 files by "if you touch this, understand what depends on it". One line each.
5. **The current campaign** - what's actively being worked on. What the user cares about right now.
6. **The traps** - top 5-8 mistakes past sessions made. One line each, verbatim symptom -> what fixed it.
7. **What NOT to touch** - files/subsystems where drive-by edits have historically caused regressions.
8. **Evidence bar** - what counts as "this works" for this project. Numbers, not vibes.
9. **Provenance** - date, git SHA, and the one-line re-verification command.

## Authoring rules

- Under 400 lines. If it's longer, this is the wrong tool - use `fable5-skill-forge` for a full library instead.
- No prose padding. Every sentence must be actionable or a hard constraint.
- Copy-paste-safe commands. No `<placeholder>` tokens.
- Cite files with their real paths, not aliases.
- Ground-truth every claim against the repo before writing it.

## When to prefer this over fable5-skill-forge

- The project is small enough that 10-16 skills would be overkill (one-person side project, dozen files).
- The user needs a HANDOFF today, not a curated library over the next few hours.
- The audience is a specific cheaper model on a specific narrow task, not a general future-Sonnet.

## When NOT to use

- The project has real complexity (large codebase, multiple subsystems, non-trivial invariants). Use `fable5-skill-forge` - a single doc will silently drop crucial context.
- The user wants a human-readable onboarding doc. Different genre.
- The user wants a marketing one-pager. Different genre.

## Provenance and maintenance

- Format anchored to Fable-5 authoring rules as of 2026-07-07.
- Re-verify sibling: `Test-Path ~/.claude/skills/fable5-skill-forge/SKILL.md`