#!/usr/bin/env python3
"""Report recursive sizes for the immediate children of one directory.

The sweep is deliberately streaming and never follows reparse points or
symlinks. Full per-child results are written as JSONL; stdout stays compact.
"""

from __future__ import annotations

import argparse
import heapq
import json
import os
import stat
import sys
import tempfile
from pathlib import Path


REPARSE_POINT = getattr(os.stat_result, "st_file_attributes", 0)
FILE_ATTRIBUTE_REPARSE_POINT = 0x400


def is_reparse(stat_result: os.stat_result) -> bool:
    return bool(
        getattr(stat_result, "st_file_attributes", REPARSE_POINT)
        & FILE_ATTRIBUTE_REPARSE_POINT
    )


def measure(path: Path, excluded_path: Path | None = None) -> tuple[int, int, int, int]:
    """Return bytes, files, directories, errors without following links."""
    total_bytes = 0
    file_count = 0
    directory_count = 0
    error_count = 0
    stack = [path]

    while stack:
        current = stack.pop()
        if current == excluded_path:
            continue
        try:
            current_stat = current.stat(follow_symlinks=False)
        except OSError:
            error_count += 1
            continue
        if is_reparse(current_stat):
            continue
        if not current.is_dir():
            total_bytes += current_stat.st_size
            file_count += 1
            continue

        directory_count += 1
        try:
            with os.scandir(current) as entries:
                for entry in entries:
                    try:
                        entry_stat = entry.stat(follow_symlinks=False)
                    except OSError:
                        error_count += 1
                        continue
                    entry_path = Path(entry.path)
                    if entry_path == excluded_path:
                        continue
                    if is_reparse(entry_stat) or entry.is_symlink():
                        continue
                    if entry.is_dir(follow_symlinks=False):
                        stack.append(entry_path)
                    elif entry.is_file(follow_symlinks=False):
                        total_bytes += entry_stat.st_size
                        file_count += 1
        except OSError:
            error_count += 1

    return total_bytes, file_count, directory_count, error_count


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Stream a recursive size inventory of a directory's immediate children."
    )
    parser.add_argument("root", type=Path, help="directory whose children should be measured")
    parser.add_argument("--top", type=int, default=20, help="largest rows to print (default: 20)")
    parser.add_argument("-o", "--output", type=Path, help="JSONL destination (default: temp file)")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        root_stat = args.root.stat(follow_symlinks=False)
    except OSError as exc:
        raise SystemExit(f"cannot stat root {args.root}: {exc}") from exc
    if is_reparse(root_stat) or stat.S_ISLNK(root_stat.st_mode):
        raise SystemExit(f"root must not be a reparse point or symlink: {args.root}")
    if not stat.S_ISDIR(root_stat.st_mode):
        raise SystemExit(f"root is not a directory: {args.root}")
    root = args.root.resolve(strict=True)
    if args.top < 0:
        raise SystemExit("--top must be non-negative")

    output = args.output
    if output is None:
        output = Path(tempfile.gettempdir()) / f"dir-size-report-{os.getpid()}.jsonl"
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    excluded_output = output if output.is_relative_to(root) else None

    rows = 0
    aggregate_bytes = 0
    aggregate_errors = 0
    largest: list[tuple[int, str, str, int]] = []

    with output.open("w", encoding="utf-8", newline="\n") as stream:
        with os.scandir(root) as children:
            for entry in children:
                child = Path(entry.path)
                if child == excluded_output:
                    continue
                size, files, directories, errors = measure(child, excluded_output)
                record: dict[str, object] = {
                    "path": str(child),
                    "bytes": size,
                    "files": files,
                    "directories": directories,
                    "errors": errors,
                }
                stream.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")
                rows += 1
                aggregate_bytes += size
                aggregate_errors += errors
                if args.top:
                    child_path = str(child)
                    item = (size, child_path.casefold(), child_path, files)
                    if len(largest) < args.top:
                        heapq.heappush(largest, item)
                    elif item[:3] > largest[0][:3]:
                        heapq.heapreplace(largest, item)

    print(
        f"scanned {rows} immediate entries, {aggregate_bytes / (1024 ** 3):.2f} GiB, "
        f"{aggregate_errors} error(s); JSONL: {output}"
    )
    for size, _, path, files in sorted(largest, reverse=True):
        print(
            f"{size / (1024 ** 3):8.2f} GiB  "
            f"{files:8d} files  {path}"
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("interrupted", file=sys.stderr)
        raise SystemExit(130)
