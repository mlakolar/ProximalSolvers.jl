#!/usr/bin/env python3
"""Path-free gate on the sweep: rho0 = resolution of the residual at the start, rho = at the stop
(rho = eps sqrt(s) sum_k |X_k| |x_k|), L(c) = max(tol, c eps) sqrt(s)|y|. usage: python3 -I rules3.py NAME DIR
Populations as in table T2 of analyze.py (whose load/prep are reused). Cells: must-keep fixtures+generated | bad (largest KKT among the bad not selected)."""
import os, sys
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "analyze.py")).read().replace("\nmain()\n", "\n")
exec(src)
name, paths = sys.argv[1], sys.argv[2:]
rows, bad, nfiles = load(paths)
conv = [(r, prep(r)) for r in rows if r["converged"] == "true"]
fam = lambda r: "group" if r["family"].startswith("group") else "scalar"
print(f"# {name}: {nfiles} files, {len(rows)} rows kept, {len(conv)} converged")
CS = [16, 64, 256, 1024, 4096, 16384]
R3 = {
    "rho >= L (unverifiable at the stop)": lambda d, c: d["P"] >= lim(d, c),
    "rho0 >= L (start)": lambda d, c: d["P0"] >= lim(d, c),
    "G0: rho >= L or rho0 >= L": lambda d, c: d["P"] >= lim(d, c) or d["P0"] >= lim(d, c),
    "G: rho + 2 eps path >= L": lambda d, c: gate(d, c),
    "G0 then R >= L": lambda d, c: (d["P"] >= lim(d, c) or d["P0"] >= lim(d, c)) and d["Rimg"] >= lim(d, c),
    "rho >= L, or rho0 >= L and R >= L": lambda d, c: d["P"] >= lim(d, c) or (d["P0"] >= lim(d, c) and d["Rimg"] >= lim(d, c)),
    "rho >= L, or rho0 >= L and confirm pass >= thr": lambda d, c: d["P"] >= lim(d, c) or (d["P0"] >= lim(d, c) and d["conf_img"] >= d["tolerance"]),
}
for famname in ("scalar", "group"):
    sel = [(r, d) for r, d in conv if fam(r) == famname and d["rel"] and d["resp"] > 0]
    for T in ("Float32", "Float64"):
        keep = [(r, d) for r, d in sel if d["T"] == T and d["ordinary"] and d["positive"] and d["cls"] != "above" and r["tol"] in ("1.0e-7", "1e-07", "0.0001")]
        keepc = [x for x in keep if x[1]["calib"]]; keepv = [x for x in keep if not x[1]["calib"]]
        bad_ = [(r, d) for r, d in sel if d["T"] == T and d["cls"] == "above" and d["roundfalse"]]
        allk = [(r, d) for r, d in sel if d["T"] == T and d["ordinary"] and d["cls"] != "above"]
        print(f"\n{famname} {T}: keep fixtures {len(keepc)}, keep generated {len(keepv)}, bad {len(bad_)}; max over must-keep of rho/(eps resp) {max(d['P'] / (d['eps'] * d['resp']) for r, d in keep):.3g}, of rho0/(eps resp) {max(d['P0'] / (d['eps'] * d['resp']) for r, d in keep):.3g}")
        print("rule".ljust(50) + "".join(f"c={c}".ljust(26) for c in CS))
        for rn, rule in R3.items():
            cells = []
            for c in CS:
                esc = [(d["kkt_rel"], r["design"], r["j"]) for r, d in bad_ if not rule(d, c)]
                cells.append(f"{sum(rule(d, c) for r, d in keepc)}+{sum(rule(d, c) for r, d in keepv)} | {len(bad_) - len(esc)}" + (f" ({max(esc)[0]:.1e})" if esc else ""))
            print(rn.ljust(50) + "".join(x.ljust(26) for x in cells))
        for c in (256, 1024):
            hit = sorted(((d["P0"] / (d["eps"] * d["resp"]), d["P"] / (d["eps"] * d["resp"]), r["design"], r["pen"], r["l1frac"], r["l2par"], r["start"], r["tol"], r["passes"], d["Rimg"] / (d["eps"] * d["resp"]))
                          for r, d in keep if d["P"] >= lim(d, c) or d["P0"] >= lim(d, c)), reverse=True)
            seen = set()
            for h in hit:
                k = h[2:7]
                if k in seen: continue
                seen.add(k)
                if len(seen) > 6: break
                print(f"#  must-keep on which G0({c}) fires [rho0/(eps resp), rho/(eps resp), ..., passes, R/(eps resp)]:", *[f"{x:.3g}" if isinstance(x, float) else x for x in h])
