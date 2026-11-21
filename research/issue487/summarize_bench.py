"""Summarize probe487-bench.jl rows: init and per-check costs, and paired total-solve ratios."""
import sys, statistics as st, collections, random

PER_IT = len(sys.argv) > 2 and sys.argv[2] == "per-iteration"
rows = []
cpu = None
for line in open(sys.argv[1], encoding="utf-8"):
    line = line.rstrip("\n")
    if line.startswith("julia "): cpu = line
    f = line.split("\t")
    if len(f) == 14 and f[0] in ("init", "check", "gradient", "solve"):
        rows.append(f)
print(cpu)
key = lambda r: (int(r[1]), int(r[2]), int(r[3]))
sizes = sorted({key(r) for r in rows})
for k in sizes:
    n, p, nF = k
    R = [r for r in rows if key(r) == k]
    init = {r[5]: float(r[7]) for r in R if r[0] == "init"}
    print(f"\n### n={n} p={p} |F|={nF}")
    print("init (min ns): " + ", ".join(f"{a}={init[a]/1e3:.1f}us" for a in init))
    for m in ("PGD", "APG"):
        chk = {r[5]: (float(r[7]), r[9]) for r in R if r[0] == "check" and r[4] == m}
        gr = [float(r[7]) for r in R if r[0] == "gradient" and r[4] == m]
        print(f"{m} check (min ns, alloc B): " + ", ".join(f"{a}={v[0]/1e3:.2f}us/{v[1]}B" for a, v in chk.items())
              + (f"; one gradient Xᵀ(Xx−y) = {gr[0]/1e3:.1f}us" if gr else ""))
        sol = collections.defaultdict(list)
        its = collections.defaultdict(set)
        for r in R:
            if r[0] == "solve" and r[4] == m:
                sol[r[5]].append((int(r[6]), float(r[7]) / int(r[10]) if PER_IT else float(r[7]))); its[r[5]].add(r[10])
        if not sol: continue
        base = dict(sol["cur"])
        out = []
        for rule in sol:
            d = dict(sol[rule])
            ratios = [d[i] / base[i] for i in d if i in base]
            med = st.median(ratios)
            # bootstrap CI over repetitions
            rng = random.Random(1)
            bs = sorted(st.median(rng.choices(ratios, k=len(ratios))) for _ in range(2000))
            tmed = st.median(v for _, v in sol[rule])
            out.append(f"{rule}: {tmed/1e6:.2f}ms it={'/'.join(sorted(its[rule]))} ratio={med:.3f} [{bs[50]:.3f},{bs[1949]:.3f}]")
        print(f"{m} solve (median time, iterations, paired ratio to cur [95% bootstrap]): " + "; ".join(out))
