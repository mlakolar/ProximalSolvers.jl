#!/usr/bin/env python3
"""Extract a subagent's hand-back text (the largest string input of its SubagentHandback
tool call) from its JSONL transcript and write it to a file. Usage: save_handback.py SRC DST"""
import json, sys
src, dst = sys.argv[1], sys.argv[2]
best = None
def walk(o):
    global best
    if isinstance(o, dict):
        if o.get("type") == "tool_use" and "andback" in str(o.get("name", "")):
            for v in (o.get("input") or {}).values():
                if isinstance(v, str) and (best is None or len(v) > len(best)): best = v
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
for line in open(src, encoding="utf-8"):
    try: walk(json.loads(line))
    except Exception: pass
if best is None: sys.exit("no hand-back found")
open(dst, "w", encoding="utf-8").write(best)
print("wrote", len(best), "chars:", best[:60].replace("\n", " "))
