#!/usr/bin/env python3
"""Orient in a (possibly huge) repo in ONE call: language breakdown, file/LOC counts,
biggest dirs and files - instead of many Glob/ls probes. RAM-lean: streams via
os.walk, counts lines by scanning bytes (encoding-safe, no whole-file loads).

Examples:
  python repo_digest.py D:/mangos-unified
  python repo_digest.py --no-loc D:/mangos-unified/src   # faster: sizes only
  python repo_digest.py --top 15 .
"""
import argparse
import os
import sys

DEFAULT_SKIP_DIRS = {".git", ".vs", "node_modules", "build", "Build", "out",
                     "bin", "obj", "Library", "Temp", "__pycache__", "packages",
                     ".gradle", "target", "dist", "vendor"}


def count_lines(path):
    n = 0
    try:
        with open(path, "rb") as f:
            while True:
                chunk = f.read(1 << 20)
                if not chunk:
                    break
                n += chunk.count(b"\n")
    except OSError:
        return 0
    return n


def human(nbytes):
    for unit in ("B", "K", "M", "G", "T"):
        if nbytes < 1024:
            return f"{nbytes:.0f}{unit}" if unit == "B" else f"{nbytes:.1f}{unit}"
        nbytes /= 1024
    return f"{nbytes:.1f}P"


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("roots", nargs="+")
    ap.add_argument("--no-loc", action="store_true", help="skip line counting (faster)")
    ap.add_argument("--top", type=int, default=12, help="rows in each top-N table")
    ap.add_argument("--skip-dir", action="append", default=[])
    args = ap.parse_args()
    skip = DEFAULT_SKIP_DIRS | set(args.skip_dir)

    by_ext = {}            # ext -> [files, loc, bytes]
    dir_bytes = {}         # top-level-ish dir -> bytes
    biggest = []           # (bytes, path) - kept small
    total_files = total_bytes = total_loc = 0

    for root in args.roots:
        root = os.path.abspath(root)
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in skip]
            for name in filenames:
                path = os.path.join(dirpath, name)
                try:
                    sz = os.path.getsize(path)
                except OSError:
                    continue
                ext = os.path.splitext(name)[1].lower() or "(none)"
                loc = 0 if args.no_loc else count_lines(path)
                rec = by_ext.setdefault(ext, [0, 0, 0])
                rec[0] += 1; rec[1] += loc; rec[2] += sz
                total_files += 1; total_bytes += sz; total_loc += loc
                # attribute to the first path segment under root
                rel = os.path.relpath(dirpath, root)
                top = root if rel == "." else os.path.join(root, rel.split(os.sep)[0])
                dir_bytes[top] = dir_bytes.get(top, 0) + sz
                biggest.append((sz, path))
                if len(biggest) > 4000:   # keep the list bounded
                    biggest.sort(reverse=True)
                    del biggest[args.top * 4:]

    print(f"# {', '.join(args.roots)}")
    loc_str = "" if args.no_loc else f", {total_loc:,} LOC"
    print(f"# {total_files:,} files, {human(total_bytes)}{loc_str}")

    print("\n## by language (top {0})".format(args.top))
    hdr = f"{'ext':10} {'files':>7} {'LOC':>10} {'size':>8}"
    print(hdr)
    exts = sorted(by_ext.items(), key=lambda kv: kv[1][1] if not args.no_loc else kv[1][2],
                  reverse=True)
    for ext, (fc, lc, bz) in exts[:args.top]:
        print(f"{ext:10} {fc:>7} {lc:>10,} {human(bz):>8}")

    print(f"\n## biggest dirs (top {args.top})")
    for d, bz in sorted(dir_bytes.items(), key=lambda kv: kv[1], reverse=True)[:args.top]:
        print(f"{human(bz):>8}  {d}")

    print(f"\n## biggest files (top {args.top})")
    biggest.sort(reverse=True)
    for sz, path in biggest[:args.top]:
        print(f"{human(sz):>8}  {path}")


if __name__ == "__main__":
    main()
