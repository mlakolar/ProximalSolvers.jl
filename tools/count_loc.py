#!/usr/bin/env python3
"""Per-top-level-definition executable LOC for a Julia file.
Executable = not blank, not comment-only, not inside a docstring (triple-quoted
string that starts a line at column 0) and not inside a #= =# block comment.
A top-level item starts at a column-0 code line and extends to the line before
the next column-0 code line that is not `end`/`)`/`]`.
Usage: count_loc.py FILE [FILE...]"""
import re, sys
def items(path):
    out, cur, in_doc, in_blk = [], None, False, False
    for i, raw in enumerate(open(path, encoding="utf-8"), 1):
        line = raw.rstrip("\n"); s = line.strip()
        if in_blk:
            if "=#" in s: in_blk = False
            continue
        if in_doc:
            if '"""' in s: in_doc = False
            continue
        if s.startswith("#="):
            if "=#" not in s: in_blk = True
            continue
        if line.startswith('"""') or line.startswith('@doc raw"""') or line.startswith('raw"""'):
            if s.count('"""') < 2: in_doc = True
            continue
        if not s or s.startswith("#"): continue
        col0 = not line[0].isspace()
        if col0 and not re.match(r"(end|\)|\]|else|elseif)\b|[\)\]]", s):
            m = re.match(r"(?:@\w+\s+)*(?:function\s+|macro\s+|struct\s+|mutable struct\s+|const\s+|abstract type\s+)?([A-Za-z_][\w.!]*)", s)
            cur = [m.group(1) if m else s[:30], i, 0]; out.append(cur)
        if cur is None: cur = ["<prelude>", i, 0]; out.append(cur)
        cur[2] += 1
    return out
for p in sys.argv[1:]:
    its = items(p); tot = sum(x[2] for x in its)
    print(f"## {p}  executable={tot}  physical={sum(1 for _ in open(p, encoding='utf-8'))}")
    for name, ln, n in its: print(f"{n:5d}  L{ln:<5d} {name}")
