#!/usr/bin/env python3
"""Regex find/replace across a tree. DRY-RUN by default: prints unified diffs and
a summary; pass --write to apply. Processes one file at a time (RAM-lean), skips
binaries, preserves each file's dominant newline style, writes utf-8 without BOM.

Examples:
  python bulk_edit.py -r "OldClass" -s "NewClass" -g "*.cpp" -g "*.h" D:/src
  python bulk_edit.py -r "GetGUID\\(\\)" -s "GetObjectGuid()" -g "*.cpp" D:/src --write
"""
import argparse
import difflib
import fnmatch
import os
import re
import sys

DEFAULT_SKIP_DIRS = {".git", ".vs", "node_modules", "build", "Build", "out",
                     "bin", "obj", "Library", "Temp", "__pycache__"}


def iter_files(roots, globs, skip_dirs):
    for root in roots:
        if os.path.isfile(root):
            yield root
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in skip_dirs]
            for name in filenames:
                if not globs or any(fnmatch.fnmatch(name, g) for g in globs):
                    yield os.path.join(dirpath, name)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("roots", nargs="+")
    ap.add_argument("-r", "--regex", required=True)
    ap.add_argument("-s", "--sub", required=True, help="replacement (supports \\1 groups)")
    ap.add_argument("-g", "--glob", action="append", default=[], help="repeatable filename glob")
    ap.add_argument("-i", "--ignore-case", action="store_true")
    ap.add_argument("--write", action="store_true", help="apply changes (default: dry-run)")
    ap.add_argument("--no-diff", action="store_true", help="suppress diffs, summary only")
    ap.add_argument("--max-diff-lines", type=int, default=40, help="diff lines shown per file")
    ap.add_argument("--skip-dir", action="append", default=[])
    args = ap.parse_args()

    rx = re.compile(args.regex, re.IGNORECASE if args.ignore_case else 0)
    skip = DEFAULT_SKIP_DIRS | set(args.skip_dir)

    scanned = changed = total_subs = 0
    for path in iter_files(args.roots, args.glob, skip):
        scanned += 1
        try:
            with open(path, "rb") as f:
                raw = f.read()
        except OSError:
            continue
        if b"\x00" in raw[:8192]:
            continue
        text = raw.decode("utf-8", errors="replace")
        new_text, n = rx.subn(args.sub, text)
        if n == 0:
            continue
        changed += 1
        total_subs += n
        print(f"{'WRITE' if args.write else 'DRY'}: {path}  ({n} substitution{'s' if n != 1 else ''})")
        if not args.no_diff:
            diff = difflib.unified_diff(text.splitlines(), new_text.splitlines(),
                                        path, path, lineterm="", n=1)
            for i, dline in enumerate(diff):
                if i >= args.max_diff_lines:
                    print("  ... (diff truncated)")
                    break
                print("  " + dline)
        if args.write:
            data = new_text
            if "\r\n" in text:  # preserve dominant newline style
                data = data.replace("\r\n", "\n").replace("\n", "\r\n")
            with open(path, "w", encoding="utf-8", newline="") as f:
                f.write(data)

    mode = "APPLIED" if args.write else "DRY-RUN (use --write to apply)"
    print(f"# {mode}: {scanned} files scanned, {changed} files changed, "
          f"{total_subs} substitutions", file=sys.stderr)


if __name__ == "__main__":
    main()
