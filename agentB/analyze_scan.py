import sys, re, collections, glob
for fn in sorted(glob.glob("scan_*.tsv")):
    rows = [l.rstrip("\n").split("\t") for l in open(fn)][1:]
    st = collections.Counter(r[3] for r in rows)
    refusal = collections.Counter(r[6][:60] for r in rows if r[3] != "ok")
    ok = [r for r in rows if r[3] == "ok"]
    def has(r, k): return (k + " =>") in r[6]
    keys = ["outside_band","exceptional_step_l1","cs_two_roots","cs_root_p","rs_t2","rs_exc","exc_ridge_refuse"]
    print("=====", fn, "cases", len(rows), dict(st))
    for k in keys:
        sel = [r for r in ok if has(r, k)]
        if sel:
            js = sorted(set(int(r[0]) for r in sel)); ls_ = sorted(set(int(r[2]) for r in sel)); ii = sorted(set(int(r[1]) for r in sel))
            print(f"  fires {k}: {len(sel)} cases; j in [{js[0]},{js[-1]}] i in [{ii[0]},{ii[-1]}] l in [{ls_[0]},{ls_[-1]}]")
    for k, v in refusal.most_common(8): print("  refused:", v, k)
    # wrong answers: converged but rel err > bound
    thr = 5e-3 if "f32" in fn else 1e-6
    bad = [r for r in ok if r[4] == "true" and float(r[5]) > thr]
    print("  converged=true with relerr >", thr, ":", len(bad))
    for r in bad[:6]: print("    ", r[:6], r[6][:100])
    nc = [r for r in ok if r[4] != "true"]
    print("  ok but not converged (maxpasses):", len(nc))
