# Aggregate a cluster out-<tag>/ directory for #308.   python3 agg308.py <out dir>...
import csv, sys, os, math, statistics as S, collections
def rd(fn):
    with open(fn) as f:
        return [r for r in csv.DictReader(f, delimiter='\t')]
def gm(xs): return math.exp(S.mean(math.log(x) for x in xs))
for d in sys.argv[1:]:
    print("=" * 30, d)
    print(open(os.path.join(d, "node.txt")).read().strip())
    # matrices
    for s in ("strict", "harness"):
        b = rd(os.path.join(d, f"matrix-base-{s}.tsv")); c = rd(os.path.join(d, f"matrix-cand-{s}.tsv"))
        for T in ("Float32", "Float64"):
            for lab, rows in (("base", [r for r in b if r['T'] == T]), ("cand", [r for r in c if r['T'] == T])):
                n = len(rows)
                byc = collections.Counter(r['termination'] for r in rows)
                passes = [sum(r['pass'] == 'true' for r in rows if r['case'] == k) for k in ("lasso", "lasso-B", "lasso-B-warm", "lasso-C", "lasso-D")]
                m = lambda k: S.mean(float(r[k]) for r in rows)
                print(f"{s:7s} {T} {lab}: pass {passes} worst gap {max(float(r['gap']) for r in rows):.2e} term {dict(byc)} "
                      f"iters mean {m('iterations'):.1f} max {max(int(r['iterations']) for r in rows)} | products {m('products'):.0f} "
                      f"f {m('f_calls'):.0f} grad {m('grad_calls'):.0f} prox {m('prox_calls'):.0f} bt {m('backtracks'):.0f} verif {m('verif'):.0f} "
                      f"alloc {m('alloc_bytes'):.0f}B time {m('time_us'):.0f}us")
            # identical outcome where the rule must be inert
            if not (s == "strict" and T == "Float32"):
                keys = ("iterations", "termination", "converged", "x_conv", "f_conv", "g_conv", "f_increased", "backtracks", "f_calls", "grad_calls", "prox_calls", "gap")
                diff = [(r1['case'], r1['rep']) for r1, r2 in zip([r for r in b if r['T'] == T], [r for r in c if r['T'] == T])
                        if any(r1[k] != r2[k] for k in keys)]
                print(f"        {s} {T}: base/cand outcome differences: {len(diff)} {diff[:5]}")
    # paired timing
    rows = [l.rstrip('\n').split('\t') for l in open(os.path.join(d, "paired.tsv")) if l.startswith('T\t') and not l.startswith('T\tround')]
    info = [l.rstrip('\n').split('\t') for l in open(os.path.join(d, "paired.tsv")) if l.startswith('INFO\t') and not l.startswith('INFO\tgroup')]
    samex = collections.Counter((r[1], r[3], r[-1]) for r in info)
    print("same_x_as_base by (group, side):", {k: v for k, v in samex.items() if k[1] in ('cand', 'cand2')})
    alloc = collections.defaultdict(list)
    for r in info: alloc[(r[1], r[3])].append(int(r[11]))
    print("alloc mean bytes:", {k: round(S.mean(v)) for k, v in alloc.items() if k[1] in ('base', 'cand')})
    per = collections.defaultdict(lambda: collections.defaultdict(list))
    for r in rows:
        _, k, grp, case, tb, tc, tb2, tc2 = r
        tb, tc, tb2, tc2 = map(float, (tb, tc, tb2, tc2))
        per[grp][case].append((tc / tb, tb2 / tb, tc2 / tc, tb, tc))
    for grp, cases in per.items():
        cb = [S.median(x[0] for x in v) for v in cases.values()]
        aa1 = [S.median(x[1] for x in v) for v in cases.values()]
        aa2 = [S.median(x[2] for x in v) for v in cases.values()]
        tbm = S.mean(S.median(x[3] for x in v) for v in cases.values()); tcm = S.mean(S.median(x[4] for x in v) for v in cases.values())
        print(f"paired {grp:12s} cases {len(cases)}: cand/base gm {gm(cb):.4f} ({min(cb):.3f}-{max(cb):.3f}) | A/A base2/base gm {gm(aa1):.4f} "
              f"({min(aa1):.3f}-{max(aa1):.3f}) cand2/cand gm {gm(aa2):.4f} ({min(aa2):.3f}-{max(aa2):.3f}) | mean base {tbm:.1f}us cand {tcm:.1f}us")
