# Agent Workbench

Reusable skills, agents, hooks, commands, and small diagnostic scripts for AI-assisted software work with Codex and Claude Code.

## What is here

- `skills/` — focused, triggerable workflows for C++, build systems, debugging, documentation, Git, performance, and agent operations.
- `agents/` — reusable role prompts for review, diagnosis, planning, and skill authoring.
- `commands/` — command-oriented workflows that can be adapted to either assistant.
- `hooks/` — optional PowerShell hooks for linting, session context, and local event logging.
- `scripts/` — standalone Python and PowerShell utilities for repository analysis, build triage, fleet preflight, and skill scaffolding.
- `docs/` — notes on safe configuration, shell behavior, verification, multi-agent workflows, and adaptive model/effort routing.

The material is intentionally tool-agnostic where possible. Paths and installation details use placeholders so the repository can be cloned on another machine without importing a personal home directory or runtime state.

## Adaptive orchestration

For substantial coding and unattended goal runs, start with [`docs/orchestration-policy.md`](docs/orchestration-policy.md) and the triggerable [`adaptive-orchestration`](skills/adaptive-orchestration/SKILL.md) skill. They define model/effort routing, ChatGPT/Codex workspace routing, visible escalation status, critic/red-team lanes, speculative parallelism, context checkpointing, and cheap-first verification.

The shared-tree mechanics remain documented in [`docs/fleets.md`](docs/fleets.md) and [`parallel-fanout`](skills/parallel-fanout/SKILL.md).

## Install or adapt

Copy the directories you want into the corresponding user or project configuration location. For Claude Code, that is commonly `.claude/`; for Codex, use the equivalent skill or agent location supported by your installation. Review each script before enabling it as a hook.

Most Python utilities use only the standard library. PowerShell scripts target Windows PowerShell 5.1 or PowerShell 7 unless their header says otherwise.

## Safety boundary

This repository contains templates and tools, not a complete assistant runtime backup. It deliberately excludes credentials, tokens, session transcripts, conversation history, SQLite databases, caches, logs, personal memories, machine-specific settings, allowlists, and generated artifacts. Do not add those files in future commits.

Scripts that can change system state are documented as optional and should be reviewed before use. Nothing here should be treated as a substitute for repository-specific tests, security review, or human approval of destructive operations.

## Contributing

Keep skills self-contained, trigger-rich, and explicit about when they should not run. Prefer small, composable scripts with dry-run behavior and clear exit codes. Run the relevant checks before opening a pull request.
