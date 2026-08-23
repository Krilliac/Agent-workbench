# Shell boundaries

Use the syntax native to the shell that launches the command. PowerShell, `cmd.exe`, Bash, Git Bash, and WSL do not share the same quoting, path, or exit-code rules.

On Windows, pass Windows paths to PowerShell or `cmd.exe`. In Bash/WSL, convert them with `cygpath` or use the environment’s mounted path form. Prefer a temporary-directory variable over hand-building a path inside a repository.

When a command launches another shell, capture and verify the child exit code inside that shell. Do not infer success from a wrapper’s final `echo` or from an empty filtered log.

Before staging a large change, inspect `git status --short` and verify that no temporary path tree, cache, session file, or generated report was created under the repository root.
