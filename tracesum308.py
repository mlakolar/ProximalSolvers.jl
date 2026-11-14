# Summary of trace308 logs across the matrix.   python3 tracesum308.py <trace dir> <version tag e.g. v1.13>
import csv, sys, glob, os, statistics as S, collections
d, v = sys.argv[1], sys.argv[2]
summ = {(r['case'], r['rep']): r for r in csv.DictReader(open(os.path.join(d, f"{v}-Float32-summary.tsv")), delimiter='\t')}
agg = collections.defaultdict(list); runhist = collections.Counter(); percase = collections.defaultdict(lambda: collections.defaultdict(list))
for (case, rep), sm in sorted(summ.items()):
    rows = list(csv.DictReader(open(os.path.join(d, f"{v}-Float32-{case}-{rep}.tsv")), delimiter='\t'))
    st = [int(r['stall']) for r in rows]; P = [float(r['P64']) for r in rows]; gap = [float(r['gap']) for r in rows]
    nbt = [int(r['nbt']) for r in rows]; nv = [int(r['nver']) for r in rows]; ul = [float(r['dx_ulps']) for r in rows]
    pr = [int(r['prods']) for r in rows]; L = [float(r['L']) for r in rows]
    N = len(rows); Pref = abs(min(P))
    k1 = next(i for i in range(N) if st[i]) + 1
    khit = int(sm['k_hit'])
    kB = next(i for i in range(N) if st[i] and nbt[i] >= 1 and nv[i] >= 1) + 1
    lastp = 0; best = float('inf')
    for i, p in enumerate(P):
        if p < best - 1e-10 * Pref: lastp = i + 1
        best = min(best, p)
    c = 0; runs = []
    for s in st:
        if s: c += 1
        elif c: runs.append(c); c = 0
    if c: runs.append(c)
    runhist.update(runs)
    rec = dict(k1=k1, khit=khit, kB=kB, lastp=lastp, stallfrac=sum(st) / N, maxrun=max(runs),
               gain_after_k1=(P[k1 - 1] - min(P[k1 - 1:])) / Pref, maxulps_after_k1=max(ul[k1:]),
               gapmin_after=min(gap[k1 - 1:]), gapmax_after=max(gap[k1 - 1:]),
               prods_after_hit=pr[-1] - pr[khit - 1], prods_total=pr[-1], prods_at_B=pr[kB - 1],
               iters_after_lastp=N - lastp, cyc=int(sm['mu']) > 0, period=int(sm['period']), mu=int(sm['mu']),
               Lmin=min(L[k1 - 1:]), Lmax=max(L[k1 - 1:]))
    for k, x in rec.items():
        agg[k].append(x); percase[case][k].append(x)
def rng(k): xs = agg[k]; return f"median {S.median(xs):.3g} [{min(xs):.3g}, {max(xs):.3g}]"
print(f"{v}: {len(summ)} solves, all maxiter: {all(r['iterations']=='10000' for r in summ.values())}, all same: {all(r['check_equal']=='true' for r in summ.values())}")
for k in ("khit", "lastp", "k1", "kB", "stallfrac", "maxrun", "gain_after_k1", "maxulps_after_k1", "gapmin_after", "gapmax_after",
          "iters_after_lastp", "prods_after_hit", "prods_total", "prods_at_B", "Lmin", "Lmax"):
    print(f"  {k:18s} {rng(k)}")
print("  B after hit in all:", all(b >= h for b, h in zip(agg['kB'], agg['khit'])), " B >= lastp in all:", all(b >= l for b, l in zip(agg['kB'], agg['lastp'])),
      " k1 >= lastp in all:", all(a >= l for a, l in zip(agg['k1'], agg['lastp'])))
print("  exact state cycles within 10000:", sum(agg['cyc']), "/", len(agg['cyc']), " periods:", sorted(p for p in agg['period'] if p))
print("  stall-run histogram (len:count):", sorted(runhist.items()))
for case, r in percase.items():
    print(f"  {case:13s} khit med {S.median(r['khit']):.0f} kB med {S.median(r['kB']):.0f} max {max(r['kB'])} stallfrac {S.mean(r['stallfrac']):.2f} maxrun {max(r['maxrun'])}")
