# Scripts

These scripts are small, composable utilities used by the workbench. They are intentionally independent of a particular repository.

## Repository and text analysis

- `repo_digest.py` — stream a language, size, and LOC inventory for a repository.
- `ctx_pack.py` — concatenate related files with stable headers and line numbers.
- `bulk_scan.py` — scan large trees line-by-line and emit compact JSONL findings.
- `bulk_edit.py` — dry-run-first regex replacement with unified diffs.
- `dir_size_report.py` — report immediate-child sizes without following links.
- `find_dupes.py` — identify likely duplicate code for refactoring review.
- `distill_log.py` — reduce noisy build or server logs to deduplicated errors and warnings.

## Windows and agent workflows

- `build.ps1` — run an MSVC build through `vcvars`, distill the output, and preserve the real exit code.
- `fleet-preflight.ps1` — report memory/commit headroom before starting a build or parallel workflow.
- `claude-search.ps1` — search a local Claude configuration tree without printing full session content.
- `claude-remote.ps1` and `claude-remote.bat` — launch a Claude Code session with remote control enabled.
- `new-agent.ps1` and `new-skill.ps1` — scaffold public-facing agent and skill files.
- `screenshot.py` — capture a screen or window for visual debugging on Windows.
- `pool-guardian.ps1` — read-only Windows kernel-pool diagnostics; use only when you understand the platform API involved.

`backup-claude.ps1` is included as an example of a backup with explicit exclusions. Review its source and adapt the source/destination policy before using it. It must never be used as a substitute for a tested backup plan.

All scripts should be treated as examples: inspect arguments, run read-only modes first, and keep generated output outside the repository.
