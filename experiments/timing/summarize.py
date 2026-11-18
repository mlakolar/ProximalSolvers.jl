#!/usr/bin/env python3
"""Summarize paired timing TSVs: per case, median/min/max of the per-round ratio side/base0."""
import csv, sys, statistics as st
from collections import defaultdict
for path in sys.argv[1:]:
    rows = list(csv.DictReader(open(path), delimiter="\t"))
    keyf = [k for k in rows[0].keys() if k not in ("round", "side", "ns", "passes", "converged", "objective", "load1")]
    d = defaultdict(lambda: defaultdict(dict)); meta = defaultdict(dict); load = defaultdict(list)
    for r in rows:
        k = tuple(r[c] for c in keyf)
        d[k][r["round"]][r["side"]] = float(r["ns"]); meta[k][r["side"]] = (r["passes"], r["converged"]); load[k].append(float(r["load1"]))
    sides = [s for s in dict.fromkeys(r["side"] for r in rows) if s != "base0"]
    print("##", path); print("\t".join(keyf + ["base0_us", "load"] + [f"{s}:med[min,max]" for s in sides] + ["passes(base0|" + "|".join(sides) + ")"]))
    worst = {s: [] for s in sides}
    for k, rounds in d.items():
        base = st.median(v["base0"] for v in rounds.values())
        cells = []
        for s in sides:
            ra = [v[s]/v["base0"] for v in rounds.values() if s in v]
            worst[s].append(st.median(ra)); cells.append(f"{st.median(ra):.3f}[{min(ra):.3f},{max(ra):.3f}]")
        ps = "|".join(meta[k][s][0] for s in ["base0"] + sides)
        print("\t".join(list(k) + [f"{base/1e3:.2f}", f"{st.mean(load[k]):.1f}"] + cells + [ps]))
    for s in sides: print(f"# {s}: median-ratio range over cases [{min(worst[s]):.3f}, {max(worst[s]):.3f}], geo-mean {st.geometric_mean(worst[s]):.4f}")
