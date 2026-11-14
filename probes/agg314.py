#!/usr/bin/env python3
"""#314 aggregator (disposable). Reads probe314 TSVs (and formal run.jl metrics for Phase A).

usage:
  agg314.py phaseA <formal_dir_j110> <formal_dir_j113> <probe_j110.tsv> <probe_j113.tsv>
  agg314.py profiles <label> <probe.tsv> [<probe.tsv> ...]    # per profile x solver x precision
  agg314.py select <probe.tsv> [...]                           # preregistered selection/confirmation rule
"""
import csv, glob, math, statistics, sys
from collections import defaultdict, Counter

def rows_of(paths):
    out = []
    for p in paths:
        with open(p) as fh:
            out += list(csv.DictReader(fh, delimiter="\t"))
    return out

def gm(xs):
    xs = [x for x in xs if x > 0]
    return math.exp(sum(map(math.log, xs)) / len(xs)) if xs else float("nan")

def q(xs, f):
    xs = sorted(xs)
    if not xs: return float("nan")
    i = f * (len(xs) - 1); lo = int(math.floor(i)); hi = min(lo + 1, len(xs) - 1)
    return xs[lo] + (xs[hi] - xs[lo]) * (i - lo)

T = lambda r: r["T"].replace("Float", "F")
def short(id_):
    return id_.replace("gradient/", "").replace("/call", "")

def formal_metrics(d):
    m = defaultdict(dict)   # id -> rep -> row
    for p in glob.glob(f"{d}/*-metrics.tsv"):
        for r in csv.DictReader(open(p), delimiter="\t"):
            m[r["id"]][int(r["rep"])] = r
    return m

def phaseA(f110, f113, p110, p113):
    F = {"1.10": formal_metrics(f110), "1.13": formal_metrics(f113)}
    P = {"1.10": rows_of([p110]), "1.13": rows_of([p113])}
    ids = sorted(F["1.13"])
    core = [i for i in ids if not i.endswith("/R/call")]
    print("### Formal run.jl (harness settings), 10 draws per case\n")
    print("| case | ok 1.10 | ok 1.13 | worst gap 1.10 | worst gap 1.13 | median µs (ok draws) 1.10 / 1.13 | median bytes 1.13 |")
    print("|---|---:|---:|---:|---:|---|---:|")
    allok = 0
    for i in ids:
        cells = []
        oks = {}
        for v in ("1.10", "1.13"):
            reps = F[v][i]
            oks[v] = sum(r["status"] == "ok" for r in reps.values())
        def med_us(v):
            xs = [int(r["median_ns"]) for r in F[v][i].values() if r["status"] == "ok" and r["median_ns"]]
            return f"{statistics.mean(xs)/1e3:.1f}" if xs else "—"
        wg = {v: max(float(r["worst_value"]) for r in F[v][i].values()) for v in F}
        nrep = {v: len(F[v][i]) for v in F}
        b = [int(r["median_bytes"]) for r in F["1.13"][i].values() if r["median_bytes"]]
        if i in core and oks["1.10"] == 10 and oks["1.13"] == 10: allok += 1
        print(f"| `{short(i)}` | {oks['1.10']}/{nrep['1.10']} | {oks['1.13']}/{nrep['1.13']} | {wg['1.10']:.2e} | {wg['1.13']:.2e} | {med_us('1.10')} / {med_us('1.13')} | {statistics.median(b) if b else '—'} |")
    print(f"\n**Core cases ok in all 10 draws on both versions: {allok} of {len(core)}.**\n")
    # cross-check formal status vs probe H
    mism = 0; checked = 0
    for v in P:
        for r in P[v]:
            if r["profile"] != "H": continue
            fr = F[v][r["id"]][int(r["draw"])]
            checked += 1
            fpass = fr["status"] == "ok"
            same_gap = float(fr["worst_value"]) == float(r["gap"])
            if fpass != (r["pass"] == "true") or not same_gap: mism += 1
    print(f"Cross-check: probe profile H vs formal records: {checked} case-draws, {mism} differences in status or gap.\n")
    for prof in ("H", "S", "P1", "P2", "D"):
        print(f"### Probe profile {prof}: per case (1.10 / 1.13)\n")
        print("| case | pass | false success | termination (1.13) | iters med (1.13) | products med (1.13) | k* med | worst gap 1.10 / 1.13 | return µs med (1.13) | to-target µs med (1.13) | bytes (1.13) |")
        print("|---|---|---|---|---:|---:|---:|---|---:|---:|---:|")
        allpass = 0
        for i in core:
            rr = {v: [r for r in P[v] if r["id"] == i and r["profile"] == prof] for v in P}
            pas = {v: sum(r["pass"] == "true" for r in rr[v]) for v in P}
            fs = {v: sum(r["converged"] == "true" and r["pass"] != "true" for r in rr[v]) for v in P}
            if pas["1.10"] == 10 and pas["1.13"] == 10: allpass += 1
            r13 = rr["1.13"]
            term = ", ".join(f"{k} {c}" for k, c in Counter(r["termination"] for r in r13).most_common())
            it = statistics.median(int(r["iterations"]) for r in r13)
            pr = statistics.median(int(r["products"]) for r in r13)
            ks = statistics.median(int(r["kstar"]) for r in r13)
            wg = " / ".join(f"{max(float(r['gap']) for r in rr[v]):.1e}" for v in ("1.10", "1.13"))
            tm = statistics.median(int(r["time_med_ns"]) for r in r13) / 1e3
            tt = [int(r["ttt_med_ns"]) for r in r13 if r["ttt_med_ns"] not in ("", None)]
            ttm = f"{statistics.median(tt)/1e3:.1f}" if tt else "—"
            by = statistics.median(int(r["alloc_bytes"]) for r in r13)
            print(f"| `{short(i)}` | {pas['1.10']} / {pas['1.13']} | {fs['1.10']} / {fs['1.13']} | {term} | {it:.0f} | {pr:.0f} | {ks:.0f} | {wg} | {tm:.1f} | {ttm} | {by:.0f} |")
        print(f"\n**{prof}: cases passing all 10 draws on both versions: {allpass} of {len(core)}.**\n")
    aa(P["1.10"] + P["1.13"])

def aa(rows):
    h = {}; a = {}
    for r in rows:
        key = (r["julia"], r["id"], r["draw"])
        if r["profile"] == "H": h[key] = int(r["time_med_ns"])
        if r["profile"] == "Haa": a[key] = int(r["time_med_ns"])
    rat = [a[k] / h[k] for k in h if k in a and h[k] > 0]
    if rat:
        print(f"A/A control (Haa/H medians, {len(rat)} problems): geometric mean {gm(rat):.4f}, "
              f"2.5–97.5% {q(rat, .025):.3f}–{q(rat, .975):.3f}, max deviation {max(abs(x-1) for x in rat):.3f}\n")

def profiles(label, paths):
    rows = [r for r in rows_of(paths) if r["profile"] != "Haa"]
    by = defaultdict(list)
    for r in rows:
        by[(r["solver"], T(r), r["profile"])].append(r)
    order = ["D", "H", "S", "P1", "P2"]
    print(f"### {label}\n")
    print("| solver | T | profile | n | pass % | missed | false success | accurate, not converged | unreachable | termination | iters med | products med | return/to-target (gm, passes) | return ms gm | to-target ms gm (reachable) | bytes med |")
    print("|---|---|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|")
    for s in ("pg", "apg"):
        for t in ("F64", "F32"):
            for p in order:
                rr = by.get((s, t, p), [])
                if not rr: continue
                n = len(rr)
                pas = sum(r["pass"] == "true" for r in rr)
                fs = sum(r["converged"] == "true" and r["pass"] != "true" for r in rr)
                anc = sum(r["pass"] == "true" and r["converged"] != "true" for r in rr)
                unr = sum(r["kstar"] == "-1" for r in rr)
                term = ", ".join(f"{k} {c}" for k, c in Counter(r["termination"] for r in rr).most_common(4))
                it = statistics.median(int(r["iterations"]) for r in rr)
                pr = statistics.median(int(r["products"]) for r in rr)
                ov = gm([int(r["time_med_ns"]) / int(r["ttt_med_ns"]) for r in rr
                         if r["pass"] == "true" and r["ttt_med_ns"] not in ("", "0")])
                ret = gm([int(r["time_med_ns"]) for r in rr]) / 1e6
                ttt = gm([int(r["ttt_med_ns"]) for r in rr if r["ttt_med_ns"] not in ("", "0")]) / 1e6
                byt = statistics.median(int(r["alloc_bytes"]) for r in rr)
                print(f"| {s} | {t} | {p} | {n} | {100*pas/n:.1f} | {n-pas} | {fs} | {anc} | {unr} | {term} | {it:.0f} | {pr:.0f} | {ov:.2f} | {ret:.3f} | {ttt:.3f} | {byt:.0f} |")
    print()
    # misses broken down by design/level/start for candidates and controls
    print("Missed targets by design × λ level (summed over start, solver and precision; FS = of which false successes):\n")
    print("| profile | " + " | ".join(f"{d}/{l}" for d in ("ord","cor","equi","wide","ill") for l in ("high","mid","low")) + " |")
    print("|---|" + "---:|" * 15)
    for p in order:
        cells = []
        for d in ("ord","cor","equi","wide","ill"):
            for l in ("high","mid","low"):
                rr = [r for r in rows if r["profile"] == p and r["design"] == d and r["level"] == l]
                m = sum(r["pass"] != "true" for r in rr); f = sum(r["pass"] != "true" and r["converged"] == "true" for r in rr)
                cells.append(f"{m}/{len(rr)}" + (f" (FS {f})" if f else ""))
        print(f"| {p} | " + " | ".join(cells) + " |")
    print()
    fsr = [r for r in rows if r["converged"] == "true" and r["pass"] != "true"]
    print(f"False successes: {len(fsr)} in total; by profile " +
          ", ".join(f"{p} {sum(r['profile']==p for r in fsr)}" for p in order) + "\n")
    aa(rows_of(paths))

def select(paths):
    rows = [r for r in rows_of(paths) if r["profile"] in ("P1", "P2")]
    by = defaultdict(list)
    for r in rows: by[(r["solver"], T(r), r["profile"])].append(r)
    for s in ("pg", "apg"):
        for t in ("F64", "F32"):
            res = {}
            for p in ("P1", "P2"):
                rr = by[(s, t, p)]
                fs = sum(r["converged"] == "true" and r["pass"] != "true" for r in rr)
                miss_reach = sum(r["pass"] != "true" and r["kstar"] != "-1" for r in rr)
                ret = gm([int(r["time_med_ns"]) for r in rr])
                res[p] = (fs == 0 and miss_reach == 0, fs, miss_reach, ret, len(rr))
            elig = [p for p in res if res[p][0]]
            choice = min(elig, key=lambda p: res[p][3]) if elig else "none"
            print(f"{s} {t}: " + "; ".join(f"{p}: eligible={res[p][0]} false_success={res[p][1]} missed_reachable={res[p][2]} "
                                           f"return_gm_ms={res[p][3]/1e6:.3f} n={res[p][4]}" for p in res) + f"  => {choice}")

if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "phaseA": phaseA(*sys.argv[2:6])
    elif mode == "profiles": profiles(sys.argv[2], sys.argv[3:])
    elif mode == "select": select(sys.argv[2:])
