---
name: skill-linter
description: Validate one or many Claude Code SKILL.md files against Anthropic's spec plus the Fable-5 authoring discipline (trigger-rich descriptions, TRIGGER/DO-NOT-TRIGGER structure, provenance section, no fabricated commands). TRIGGER when the user says "lint this skill", "validate skill", "check SKILL.md", "audit .claude/skills", "is this skill file correct", "skill review", after any skill-authoring session, or when reviewing a PR that touches .claude/skills. DO NOT TRIGGER for authoring new skills from scratch (use fable5-skill-forge) or for reviewing general documentation.
---

# skill-linter

Run the linter script and interpret the report. This skill does not itself parse skills - it wraps `scripts/skill-lint.ps1`.

## Usage

```powershell
# lint a whole tree
powershell -NoProfile -File ~/.claude/skills/skill-linter/scripts/skill-lint.ps1 -Path <repo>/.claude/skills

# lint one file
powershell -NoProfile -File ~/.claude/skills/skill-linter/scripts/skill-lint.ps1 -Path <repo>/.claude/skills/<name>/SKILL.md
```

Exit codes: `0` clean, `1` warnings only, `2` errors present.

## Checks performed

1. YAML frontmatter present and parses (between `---` markers at top of file).
2. `name` field exists and matches the containing folder name.
3. `description` field exists, is >= 120 chars, contains at least one TRIGGER cue (regex `TRIGGER when` or `Use when`) and at least one DO-NOT cue (regex `DO NOT TRIGGER` or `Do not use for`).
4. Description does not read as generic ("A skill for X" style openers are flagged).
5. Body contains a `## Provenance` or `## Provenance and maintenance` section OR contains at least one date-stamp (regex `20\d{2}-\d{2}-\d{2}`).
6. Body does not contain obvious placeholder tokens: `TODO`, `FIXME`, `<your project>`, `PLACEHOLDER`, `TBD`.
7. If the skill references a co-located script (`scripts/*.ps1`, `scripts/*.py`, `scripts/*.sh`), that file exists.

## When a skill fails

Rewrite it. Do not lower the linter's bar. If the check is wrong, edit `skill-lint.ps1` and note the change in the skill's provenance.

## When NOT to use

- Authoring a skill from a blank slate: use `fable5-skill-forge`.
- Deciding whether a skill SHOULD exist: not a linter question. That's a taxonomy question.
- Validating non-skill markdown: this linter is skill-shape specific.

## Provenance and maintenance

- Linter spec anchored to Anthropic best-practices guidance and Fable-5 authoring rules as of 2026-07-07.
- Re-run: `powershell -NoProfile -File ~/.claude/skills/skill-linter/scripts/skill-lint.ps1 -Path ~/.claude/skills`
- Re-verify: `Test-Path ~/.claude/skills/skill-linter/scripts/skill-lint.ps1`