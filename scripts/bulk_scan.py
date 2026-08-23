#!/usr/bin/env python3
"""Streaming regex scan/extract over a directory tree. RAM-lean: never loads a
whole tree; reads files line-by-line; writes matches incrementally as JSONL.

Examples:
  python bulk_scan.py -r "TODO|FIXME" -g "*.cpp" -g "*.h" D:/src
  python bulk_scan.py -r "class\\s+(\\w+)" -g "*.h" -o classes.jsonl --files-only D:/src
  python bulk_scan.py -r "SendPacket" --count D:/mangos-unified/src
"""
import argparse
import fnmatch
import json
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
    ap.add_argument("roots", nargs="+", help="files or directories to scan")
    ap.add_argument("-r", "--regex", required=True, help="pattern (line-oriented)")
    ap.add_argument("-g", "--glob", action="append", default=[],
                    help="filename glob filter, repeatable (default: all files)")
    ap.add_argument("-i", "--ignore-case", action="store_true")
    ap.add_argument("-o", "--out", default=None,
                    help="JSONL output path (default: stdout summary only in --count/--files-only, else bulk_scan_hits.jsonl in cwd)")
    ap.add_argument("--files-only", action="store_true", help="list matching files, not lines")
    ap.add_argument("--count", action="store_true", help="per-file match counts only")
    ap.add_argument("--max-matches", type=int, default=200000, help="global cap")
    ap.add_argument("--max-per-file", type=int, default=1000)
    ap.add_argument("--skip-dir", action="append", default=[],
                    help="extra directory names to skip")
    args = ap.parse_args()

    rx = re.compile(args.regex, re.IGNORECASE if args.ignore_case else 0)
    skip = DEFAULT_SKIP_DIRS | set(args.skip_dir)

    out_path = args.out
    if out_path is None and not (args.files_only or args.count):
        out_path = "bulk_scan_hits.jsonl"
    out = open(out_path, "w", encoding="utf-8") if out_path else None

    files_scanned = files_hit = total = 0
    capped = False
    try:
        for path in iter_files(args.roots, args.glob, skip):
            files_scanned += 1
            per_file = 0
            try:
                with open(path, "r", encoding="utf-8", errors="replace") as f:
                    for lineno, line in enumerate(f, 1):
                        if "\x00" in line:  # binary — bail on this file
                            per_file = 0
                            break
                        m = rx.search(line)
                        if not m:
                            continue
                        per_file += 1
                        total += 1
                        if out and not args.count:
                            rec = {"file": path, "line": lineno,
                                   "text": line.rstrip("\n")[:400]}
                            if m.groups():
                                rec["groups"] = list(m.groups())
                            out.write(json.dumps(rec, ensure_ascii=False) + "\n")
                        if args.files_only or per_file >= args.max_per_file:
                            break
            except OSError:
                continue
            if per_file:
                files_hit += 1
                if args.files_only:
                    print(path)
                elif args.count:
                    print(f"{per_file}\t{path}")
                    if out:
                        out.write(json.dumps({"file": path, "count": per_file}) + "\n")
            if total >= args.max_matches:
                capped = True
                break
    finally:
        if out:
            out.close()

    print(f"# scanned {files_scanned} files; {files_hit} files matched; "
          f"{total} matches{' (CAPPED)' if capped else ''}"
          + (f"; details -> {out_path}" if out_path else ""), file=sys.stderr)


if __name__ == "__main__":
    main()
