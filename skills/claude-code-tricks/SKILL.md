---
name: claude-code-tricks
description: Meta-skill for power-user Claude Code CLI usage -- hidden flags, MCP debugging, hook diagnosis, /permissions presets, session forking, remote-control patterns. TRIGGER when the user says "how do I get Claude to", "Claude Code trick", "MCP not connecting", "hook loop", "how do I fork a session", "remote control", "/permissions", "resume that session", "why did the tool call fail". DO NOT TRIGGER for questions about Anthropic's API or the SDK, or about specific skills. Focused on operational tricks for driving the CLI hard.
---

# claude-code-tricks

## Flags
- `--model <id>` -- pin. `--model sonnet-5`, `--model opus-4.8`.
- `--resume <sid>` -- resume specific session.
- `--continue` -- last session in cwd.
- `--print` -- one-shot; stdin -> respond -> exit.
- `--output-format json` -- machine-readable; combine with `--print`.
- `--dangerously-skip-permissions` -- only in trusted contexts.
- `--remote-control "<name>"` -- WebSocket for external control.
- `claude models` (or `--print-models`) -- list current IDs.

## MCP debug
- `/mcp` in-session shows state.
- Servers connect lazily. Restart CLI or `/mcp` to kick.
- Logs: `~/.claude/mcp-*.log`.
- OAuth only interactive; authorize once, then reuse.

## Hooks
Fire on: pre-tool-use, post-tool-use, session-start, session-stop.
- Slow session = hook hanging on I/O.
- Loop: hook edits file -> edit fires hook. Guard with lockfile.
- Debug log: `~/.claude/hooks.log`.

## /permissions
`.claude/settings.json`:
```json
{ "permissions": {
    "allow": ["Bash(cmake:*)", "Bash(ninja:*)", "Read", "Edit"],
    "deny": ["Bash(rm:*)"]
}}
```
Glob-matched. `Bash(cmake:*)` = any bash call whose first arg is cmake.

## Fork
Copy `~/.claude/sessions/<sid>.jsonl` to `<newsid>.jsonl`, then continue.

## Remote-control launcher
```
@echo off
cd /d "%~1"
claude --remote-control "%~2"
```
Desktop shortcut per project.

## --print pipeline
```
echo "summarize changes" | claude --print --model sonnet-5 --output-format json | jq -r '.text' > out.md
```
Great for scheduled tasks.

## Failure modes
- Context too long: `/compact` or fresh session.
- Tools missing post-ToolSearch: MCP crashed; `/mcp` or restart.
- Model unavailable: `claude models`.
- Autorestart loop: launcher retries too fast; sleep 5s between attempts.