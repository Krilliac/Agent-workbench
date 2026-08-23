#!/usr/bin/env python3
"""Distill a big build/server log down to the lines that matter, so Claude reads a
~30-line digest instead of ingesting thousands of log lines (or greping repeatedly).

Streams input line-by-line (RAM-lean). Reads log FILES given as args, or stdin if
none / if `-` is given.

Modes (auto-detected; override with a flag):
  --msvc     MSVC / clang-cl / ninja build errors+warnings, deduped and grouped.
             Emits the FIRST error verbatim (usual root cause) + a counted table.
  --generic  Any log: pull error/fatal/exception/failed/warn lines, dedupe by
             normalized message (strips timestamps/paths/numbers), rank by count.
             Good for server logs (mangosd/realmd) and fleet output.
  --summary  Counts only (errors, warnings, first error) - one glance.

Examples:
  python distill_log.py build.log                 # auto-detect
  ninja 2>&1 | python distill_log.py --msvc        # pipe a build straight in
  python distill_log.py --generic mangosd.log
  python distill_log.py --summary build.log
"""
import argparse
import os
import re
import sys
from collections import OrderedDict

# MSVC/cl: "path(line): error CXXXX: msg"  and linker "foo.obj : error LNK2019: msg"
RX_MSVC = re.compile(
    r"^(?P<file>.+?)(?:\((?P<line>\d+)(?:,\d+)?\))?\s*:\s*"
    r"(?P<sev>fatal error|error|warning)\s+(?P<code>[A-Za-z]+\d+)\s*:\s*(?P<msg>.*)$"
)
# clang/gcc: "path:line:col: error: msg"
RX_CLANG = re.compile(
    r"^(?P<file>.+?):(?P<line>\d+):(?:\d+:)?\s*"
    r"(?P<sev>fatal error|error|warning):\s*(?P<msg>.*)$"
)
SEV_RANK = {"fatal error": 0, "error": 1, "warning": 2}

RX_GENERIC = re.compile(
    r"(?i)\b(error|fatal|exception|traceback|failed|failure|panic|"
    r"undefined reference|segfault|assert(?:ion)? failed|warning|warn)\b"
)
# normalize a message for dedup: drop digits, hex, quoted paths, addresses
RX_NORM = re.compile(r"0x[0-9a-fA-F]+|[0-9]+|[A-Za-z]:[\\/][^\s'\"]+|/[^\s'\"]+")


def iter_lines(paths):
    if not paths or paths == ["-"]:
        for line in sys.stdin:
            yield line.rstrip("\n")
        return
    for p in paths:
        if p == "-":
            for line in sys.stdin:
                yield line.rstrip("\n")
            continue
        try:
            with open(p, "r", encoding="utf-8", errors="replace") as f:
                for line in f:
                    yield line.rstrip("\n")
        except OSError as e:
            print(f"# cannot read {p}: {e}", file=sys.stderr)


def distill_build(lines, cap):
    groups = OrderedDict()   # key -> {sev, code, file, msg, count, sample}
    first_error = None
    total = 0
    for line in lines:
        m = RX_MSVC.match(line) or RX_CLANG.match(line)
        if not m:
            continue
        d = m.groupdict()
        sev = d["sev"].lower()
        code = d.get("code") or ""
        fname = os.path.basename((d.get("file") or "").strip())
        msg = (d.get("msg") or "").strip()
        total += 1
        if first_error is None and sev in ("error", "fatal error"):
            first_error = line.strip()
        key = (sev, code, fname, msg[:120])
        g = groups.get(key)
        if g:
            g["count"] += 1
        else:
            groups[key] = {"sev": sev, "code": code, "file": fname,
                           "msg": msg, "count": 1}
    ordered = sorted(groups.values(),
                     key=lambda g: (SEV_RANK.get(g["sev"], 9), -g["count"]))
    n_err = sum(g["count"] for g in groups.values() if g["sev"] != "warning")
    n_warn = sum(g["count"] for g in groups.values() if g["sev"] == "warning")

    out = []
    out.append(f"# build log: {n_err} error(s), {n_warn} warning(s), "
               f"{len(groups)} unique")
    if first_error:
        out.append(f"# first error: {first_error}")
    if not ordered:
        out.append("# no compiler errors/warnings matched (build likely clean)")
    for g in ordered[:cap]:
        loc = f"{g['file']} " if g["file"] else ""
        cnt = f" (x{g['count']})" if g["count"] > 1 else ""
        out.append(f"{g['sev']:11} {g['code']:8} {loc}{g['msg']}{cnt}")
    if cap > 0 and len(ordered) > cap:
        out.append(f"# ... {len(ordered) - cap} more unique (raise --cap)")
    return "\n".join(out)


def distill_generic(lines, cap):
    groups = OrderedDict()  # norm -> {sample, count, warn}
    total = 0
    for line in lines:
        if not RX_GENERIC.search(line):
            continue
        total += 1
        norm = RX_NORM.sub("#", line).strip()[:160]
        is_warn = bool(re.search(r"(?i)\bwarn", line))
        g = groups.get(norm)
        if g:
            g["count"] += 1
        else:
            groups[norm] = {"sample": line.strip()[:200], "count": 1, "warn": is_warn}
    ordered = sorted(groups.values(), key=lambda g: (g["warn"], -g["count"]))
    n_err = sum(g["count"] for g in groups.values() if not g["warn"])
    n_warn = sum(g["count"] for g in groups.values() if g["warn"])

    out = [f"# log: {total} flagged line(s); {n_err} error-ish, {n_warn} warn-ish; "
           f"{len(groups)} unique"]
    for g in ordered[:cap]:
        cnt = f" (x{g['count']})" if g["count"] > 1 else ""
        out.append(f"{g['sample']}{cnt}")
    if len(ordered) > cap:
        out.append(f"# ... {len(ordered) - cap} more unique (raise --cap)")
    return "\n".join(out)


def looks_like_build(sample):
    return any(RX_MSVC.match(l) or RX_CLANG.match(l) for l in sample)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("logs", nargs="*", help="log files (default/`-`: stdin)")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--msvc", action="store_true", help="force build-error mode")
    g.add_argument("--generic", action="store_true", help="force generic-log mode")
    g.add_argument("--summary", action="store_true", help="counts only")
    ap.add_argument("--cap", type=int, default=50, help="max rows shown (default 50)")
    args = ap.parse_args()

    # For auto-detect we need to peek; buffer a small sample, then chain it back.
    lines_iter = iter_lines(args.logs)
    mode = "msvc" if args.msvc else "generic" if args.generic else None
    if mode is None and not args.summary:
        sample = []
        for line in lines_iter:
            sample.append(line)
            if len(sample) >= 400:
                break
        mode = "msvc" if looks_like_build(sample) else "generic"
        # rebuild a combined iterator: buffered sample + the rest
        def chained(buf, rest):
            for x in buf:
                yield x
            for x in rest:
                yield x
        lines_iter = chained(sample, lines_iter)

    if args.summary:
        print(distill_build(lines_iter, 0))
    elif mode == "msvc":
        print(distill_build(lines_iter, args.cap))
    else:
        print(distill_generic(lines_iter, args.cap))


if __name__ == "__main__":
    main()
