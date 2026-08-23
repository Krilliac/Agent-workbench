# Script conventions

The utilities in this repository follow a few practical conventions:

- Python tools use the standard library and stream files instead of loading entire trees into memory.
- Bulk scanners emit a short stdout summary and put detailed findings in JSONL or a caller-selected output file.
- Rewrite tools default to a dry run and show a diff before changing files.
- PowerShell tools use explicit paths, preserve meaningful exit codes, and avoid hidden privilege escalation.
- Logs, reports, screenshots, caches, and temporary build output belong outside the repository.

When adding a utility, document its inputs, outputs, destructive behavior, supported shells, and a minimal example. Add a self-check when the tool rewrites source or configuration.
