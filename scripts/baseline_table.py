#!/usr/bin/env python3
"""Per-configuration reliability table and exclusion classes from cross_solver.csv (#110 baseline).

Reads only the cross_solver.csv that benchmark/cross_solver.py wrote; copies counts, adds nothing
statistical. Configuration = solver + variant without the problem (precision and start kept).
Settings class: `accuracy` for acc- variants (accuracy_options), `record-only` for variants with no
finite target (historical R cases, default settings), `default` otherwise (harness settings).
usage: baseline_table.py cross_solver.csv out.md [label]
"""
import csv
import math
import sys
from collections import OrderedDict, defaultdict

src, out = sys.argv[1], sys.argv[2]
label = sys.argv[3] if len(sys.argv) > 3 else src
rows = list(csv.DictReader(open(src, newline="")))
seen = set()
uniq = []
for r in rows:  # a case appears once per group; ungrouped rows appear once too
    k = (r["julia"], r["id"])
    if k in seen:
        continue
    seen.add(k)
    uniq.append(r)


def settings(r):
    v = r["id"].split("/")[3]
    if r["target"] in ("", "nan", "NaN") or not math.isfinite(float(r["target"] or "nan")):
        return "record-only"
    return "accuracy" if v.startswith("acc-") else "default"


def config(r):
    solver, variant = r["id"].split("/")[2:4]
    return f"{solver} {variant}"


def classify(r):
    if r["timing"] == "shown":
        return None
    st = settings(r)
    if st == "record-only":
        return "no finite target (accuracy recorded only)"
    bad = {k: int(r["status_" + k]) for k in ("error", "timeout", "uncertifiable", "incomplete")}
    if any(bad.values()):
        return "failure: " + ", ".join(f"{k}={v}" for k, v in bad.items() if v)
    if int(r["status_target_missed"]):
        prec = r["precision"]
        return f"target missed, {st} settings, {prec}"
    return "other: " + r["exclusion"]


def g(x):
    return f"{float(x):.3g}"


lines = [f"# Per-configuration baseline table ({label})", ""]
lines.append("Counts are repetitions (runs) unless marked cases. `worst cert / target` is the largest "
             "worst certificate over the configuration's cases divided by their target "
             "(> 1 means at least one sample missed). `timed` = cases with every run ok and a finite "
             "target, the only cases that get a time in the readout. Copied from cross_solver.csv; "
             "no ranking, no between-solver statistics.")
for jl in sorted({r["julia"] for r in uniq}):
    lines += ["", f"## Julia {jl}", "",
              "| Configuration | Settings | Cases | Ok runs / total | Target missed (runs; cases) | Error | Timeout | Uncertifiable / incomplete | Worst cert / target | Timed cases |",
              "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    agg = OrderedDict()
    for r in sorted((r for r in uniq if r["julia"] == jl), key=lambda r: (settings(r), config(r))):
        key = (config(r), settings(r))
        a = agg.setdefault(key, defaultdict(float))
        a["cases"] += 1
        a["ok"] += int(r["status_ok"])
        a["runs"] += int(r["runs"])
        tm = int(r["status_target_missed"])
        a["tm"] += tm
        a["tmcases"] += tm > 0
        a["err"] += int(r["status_error"])
        a["to"] += int(r["status_timeout"])
        a["unc"] += int(r["status_uncertifiable"]) + int(r["status_incomplete"])
        a["timed"] += r["timing"] == "shown"
        try:
            ratio = float(r["worst_value"]) / float(r["target"])
        except (ValueError, ZeroDivisionError):
            ratio = float("nan")
        if math.isfinite(ratio):
            a["ratio"] = max(a.get("ratio", 0.0), ratio)
        else:
            a.setdefault("ratio", float("nan"))
    for (cfg, st), a in agg.items():
        ratio = a.get("ratio", float("nan"))
        lines.append(f"| {cfg} | {st} | {int(a['cases'])} | {int(a['ok'])} / {int(a['runs'])} | "
                     f"{int(a['tm'])}; {int(a['tmcases'])} | {int(a['err'])} | {int(a['to'])} | {int(a['unc'])} | "
                     f"{g(ratio) if math.isfinite(ratio) else 'n/a'} | {int(a['timed'])} / {int(a['cases'])} |")
    cls = defaultdict(list)
    for r in uniq:
        if r["julia"] == jl:
            c = classify(r)
            if c:
                cls[c].append(f"`{r['id']}` ({r['status_ok']}/{r['runs']} ok, worst {g(r['worst_value'])})")
    lines += ["", f"### Exclusions, Julia {jl}", ""]
    for c in sorted(cls):
        lines.append(f"- **{c}** ({len(cls[c])} cases): " + "; ".join(sorted(cls[c])))
open(out, "w").write("\n".join(lines) + "\n")
print(out)
