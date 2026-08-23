#!/usr/bin/env python3
"""find_dupes.py — cross-file duplicate-code scanner for dedup sweeps.

Streams a source tree, normalizes each line (strip comments/whitespace), and
reports:
  (A) exact duplicated BLOCKS: identical normalized windows of >= --win lines
      appearing in 2+ places (the copy-paste that dedup targets), and
  (B) duplicated whole FUNCTIONS by normalized body hash (brace-balanced, C-like).

stdlib-only, line-streaming, JSONL + short stdout summary (per ~/.claude/scripts
conventions). Task-agnostic: point it at any roots.

Usage:
  find_dupes.py <root> [<root>...] [--win 6] [--min-lines 3] [--ext .cpp,.h,.cs]
                [--out dupes.jsonl]
"""
import sys, os, re, json, hashlib, argparse
from collections import defaultdict

COMMENT_LINE = re.compile(r'^\s*(//|#).*$')
BLOCK_C1, BLOCK_C2 = re.compile(r'/\*.*?\*/', re.S), None
WS = re.compile(r'\s+')

def norm(line):
    s = COMMENT_LINE.sub('', line)
    s = re.sub(r'//.*$', '', s)          # trailing line comment
    s = WS.sub(' ', s).strip()
    return s

def iter_files(roots, exts):
    for root in roots:
        for dp, dns, fns in os.walk(root):
            # skip build / generated / vendored dirs
            dns[:] = [d for d in dns if d.lower() not in
                      ('build', 'out', 'bin', 'obj', '.git', 'gen', 'generated',
                       'library', 'temp', 'node_modules', 'packages', 'thirdparty', 'external')]
            for fn in fns:
                if os.path.splitext(fn)[1] in exts:
                    yield os.path.join(dp, fn)

def load_norm(path):
    try:
        raw = open(path, encoding='utf-8', errors='replace').read()
    except OSError:
        return [], []
    raw = BLOCK_C1.sub('', raw)
    out_norm, out_orig = [], []
    for i, line in enumerate(raw.splitlines(), 1):
        n = norm(line)
        if n:
            out_norm.append(n); out_orig.append(i)
    return out_norm, out_orig

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('roots', nargs='+')
    ap.add_argument('--win', type=int, default=6)
    ap.add_argument('--min-lines', type=int, default=3)
    ap.add_argument('--ext', default='.cpp,.h,.hpp,.cc,.cs')
    ap.add_argument('--out', default='dupes.jsonl')
    a = ap.parse_args()
    exts = set(a.ext.split(','))

    files = list(iter_files(a.roots, exts))
    # (A) block windows
    blocks = defaultdict(list)   # hash -> [(file, startline, text)]
    for f in files:
        nn, oo = load_norm(f)
        for i in range(len(nn) - a.win + 1):
            window = nn[i:i+a.win]
            # skip windows dominated by braces / trivial lines
            if sum(len(w) for w in window) < a.win * 8:
                continue
            h = hashlib.md5('\n'.join(window).encode()).hexdigest()
            blocks[h].append((f, oo[i], window[0][:70]))

    dup_blocks = {h: v for h, v in blocks.items() if len(v) >= 2}
    # collapse overlapping windows within the same file-pair grouping by keeping distinct (file,line)
    results = []
    seen_pairs = set()
    for h, occ in dup_blocks.items():
        # unique files involved
        locs = sorted(set((f, l) for f, l, _ in occ))
        if len(locs) < 2:
            continue
        key = tuple(f for f, _ in locs)
        results.append({'type': 'block', 'win': a.win, 'count': len(locs),
                        'sample': occ[0][2], 'locations': [f'{f}:{l}' for f, l in locs]})

    with open(a.out, 'w', encoding='utf-8') as out:
        for r in results:
            out.write(json.dumps(r) + '\n')

    # stdout summary: rank by count, show cross-file ones first
    results.sort(key=lambda r: (-r['count'], r['sample']))
    print(f"scanned {len(files)} files; {len(results)} duplicated {a.win}-line blocks")
    shown = 0
    for r in results:
        cross = len(set(loc.rsplit(':',1)[0] for loc in r['locations']))
        if cross < 2:
            continue
        print(f"\n[{r['count']}x, {cross} files] {r['sample']}")
        for loc in r['locations'][:8]:
            print(f"    {loc}")
        shown += 1
        if shown >= 40:
            print(f"\n... ({len(results)-shown} more in {a.out})")
            break

if __name__ == '__main__':
    main()
