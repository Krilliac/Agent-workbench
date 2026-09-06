---
name: claude-code-tricks
description: Meta-skill for power-user Claude Code CLI usage -- hidden flags, MCP debugging, hook diagnosis, /permissions presets, session forking, remote-control patterns, and deliberate session routing. TRIGGER when the user says "how do I get Claude to", "Claude Code trick", "MCP not connecting", "hook loop", "how do I fork a session", "remote control", "/permissions", "resume that session", "why did the tool call fail", or wants extra Claude/Codex worker sessions. DO NOT TRIGGER for questions about Anthropic's API or the SDK, or about specific skills. Focused on operational tricks for driving the CLI hard.
---

# claude-code-tricks

## Flags
- `--model <id>` -- pin a model supported by the installed CLI.
- `--resume <sid>` -- resume a specific session.
- `--continue` -- last session in cwd.
- `--print` -- one-shot; stdin -> respond -> exit.
- `--output-format json` -- machine-readable; combine with `--print`.
- `--dangerously-skip-permissions` -- only in trusted contexts.
- `--remote-control "<name>"` -- WebSocket for external control when supported.
- `claude models` (or the installed CLI's equivalent) -- inspect current model IDs before hard-coding one.

## Session/workspace routing

Treat sessions as execution resources, not as sacred linear conversations.

- Fork or open a separate session for independent research, review, or speculative approaches when parallelism helps.
- Keep tightly coupled edits in one ownership lane unless files/modules are explicitly partitioned.
- Use read-only sessions freely for critic/red-team/research lanes.
- Prefer a fresh/compacted reasoning session when the current context is noisy enough to harm judgment.
- When another environment such as Codex is better for repository execution or extra coding workers, route the implementation there and keep architecture/review in the reasoning-oriented session when supported.
- Surface meaningful model/session/workspace routing changes to the user instead of silently moving work.

See `docs/orchestration-policy.md` and the `adaptive-orchestration` skill for the canonical routing policy.

## MCP debug
- `/mcp` in-session shows state when supported by the installed CLI.
- Servers may connect lazily. Restart CLI or use the MCP status/control command to re-check.
- Inspect the CLI's MCP logs under the user Claude config directory when debugging connection failures.
- OAuth generally requires an interactive authorization at least once; reuse the authorized connection afterwards.

## Hooks
Common hook points include pre-tool-use, post-tool-use, session-start, and session-stop.
- Slow session = hook may be hanging on I/O.
- Loop: hook edits file -> edit fires hook. Guard with lockfile/reentrancy protection.
- Keep a small debug log for hook failures rather than flooding the main transcript.

## /permissions
Example `.claude/settings.json` pattern:
```json
{ "permissions": {
    "allow": ["Bash(cmake:*)", "Bash(ninja:*)", "Read", "Edit"],
    "deny": ["Bash(rm:*)"]
}}
```
Review exact permission syntax against the installed CLI version before deploying broadly.

## Fork
Use the CLI's supported session fork/resume mechanism where available. If manipulating session files directly, first confirm the installed version's on-disk format and make a backup; internal storage formats can change.

## Remote-control launcher
```
@echo off
cd /d "%~1"
claude --remote-control "%~2"
```
Useful for project-specific launchers when that flag is supported by the installed version.

## --print pipeline
```
echo "summarize changes" | claude --print --output-format json > out.json
```
Pin a model only after checking the current IDs exposed by the installed CLI. One-shot mode is useful for scheduled or mechanical tasks.

## Failure modes
- Context too long/noisy: compact or start a fresh session.
- Tools missing after discovery: inspect MCP state/logs and restart the connection or CLI if necessary.
- Model unavailable: query the installed CLI's current model list rather than relying on stale IDs.
- Autorestart loop: launcher retries too fast; add backoff between attempts.
- Parallel writers collide: stop, re-establish ownership boundaries, and use the `parallel-fanout` workflow.
