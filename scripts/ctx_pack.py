#!/usr/bin/env python3
"""Concatenate several related files into ONE result with clear per-file headers and
line numbers - so reading N files is one tool call instead of N. RAM-lean: streams
each file; enforces per-file and total caps so the output stays readable.

Positional args are file paths and/or directories. For directories, pass --glob to
pick files recursively (repeatable). Plain file paths are always included.

Examples:
  python ctx_pack.py src/Player.h src/Player.cpp
  python ctx_pack.py --glob "*.h" D:/mangos-unified/src/game/Object
  python ctx_pack.py --no-numbers --max-lines 200 a.cpp b.cpp
"""
import argparse
import fnmatch
import os
import sys

DEFAULT_SKIP_DIRS = {".git", ".vs", "node_modules", "build", "Build", "out",
                     "bin", "obj", "Library", "Temp", "__pycache__"}


def resolve(paths, globs, skip):
    seen = set()
    for p in paths:
        if os.path.isfile(p):
            if p not in seen:
                seen.add(p); yield p
        elif os.path.isdir(p):
            for dirpath, dirnames, filenames in os.walk(p):
                dirnames[:] = [d for d in dirnames if d not in skip]
                for name in sorted(filenames):
                    if not globs or any(fnmatch.fnmatch(name, g) for g in globs):
                        fp = os.path.join(dirpath, name)
                        if fp not in seen:
                            seen.add(fp); yield fp
        else:
            # treat as a glob pattern relative to cwd
            import glob as _g
            for fp in sorted(_g.glob(p, recursive=True)):
                if os.path.isfile(fp) and fp not in seen:
                    seen.add(fp); yield fp


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="+", help="files, dirs, or glob patterns")
    ap.add_argument("-g", "--glob", action="append", default=[],
                    help="filename glob for directory args, repeatable")
    ap.add_argument("--no-numbers", action="store_true", help="omit line numbers")
    ap.add_argument("--max-lines", type=int, default=0, help="cap lines shown per file (0=all)")
    ap.add_argument("--max-bytes", type=int, default=2_000_000,
                    help="total output byte cap (default 2 MB)")
    ap.add_argument("--skip-dir", action="append", default=[])
    args = ap.parse_args()
    try:  # emit clean UTF-8 regardless of the Windows console codepage
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass
    skip = DEFAULT_SKIP_DIRS | set(args.skip_dir)

    out = sys.stdout
    written = 0
    n_files = 0
    truncated_total = False
    for path in resolve(args.paths, args.glob, skip):
        if written >= args.max_bytes:
            truncated_total = True
            break
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
        except OSError as e:
            print(f"# skip {path}: {e}", file=sys.stderr)
            continue
        n_files += 1
        shown = lines if args.max_lines <= 0 else lines[:args.max_lines]
        header = f"===== {path} ({len(lines)} lines" + \
                 (f", showing {len(shown)}" if len(shown) < len(lines) else "") + ") =====\n"
        out.write(header); written += len(header)
        for i, line in enumerate(shown, 1):
            text = line.rstrip("\n")
            rendered = text if args.no_numbers else f"{i:6}\t{text}"
            rendered += "\n"
            out.write(rendered); written += len(rendered)
            if written >= args.max_bytes:
                out.write("# ... (total byte cap hit; raise --max-bytes)\n")
                truncated_total = True
                break
        out.write("\n")
        if truncated_total:
            break

    print(f"# packed {n_files} file(s), ~{written} bytes"
          + (" (TRUNCATED)" if truncated_total else ""), file=sys.stderr)


if __name__ == "__main__":
    main()
