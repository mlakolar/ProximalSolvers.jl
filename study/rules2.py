#!/usr/bin/env python3
"""Second look at the rules on the sweep: floors in the unit of the residual's own resolution P at the stop
(P = eps sqrt(s) sum_k |X_k| |x_k|) instead of eps sqrt(s)|y|. usage: python3 -I rules2.py NAME DIR
Populations as in table T2 of analyze.py (whose load/prep are reused)."""
import os, sys
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "analyze.py")).read().replace("\nmain()\n", "\n")
exec(src)
name, paths = sys.argv[1], sys.argv[2:]
rows, bad, nfiles = load(paths)
conv = [(r, prep(r)) for r in rows if r["converged"] == "true"]
fam = lambda r: "group" if r["family"].startswith("group") else "scalar"
print(f"# {name}: {nfiles} files, {len(rows)} rows kept, {len(conv)} converged")
G = 64
KAPPA = [1, 4, 16, 64, 256, 1024]
def acc_at_once(d, c):      # the confirm pass from the recomputed residual passes the unfloored test
    return d["conf_img"] < d["tolerance"] and d["confAq_img"] < G
R2 = {
    "G(64) then R >= max(tol, c eps) resp": lambda d, k: gate(d, G) and d["Rimg"] >= lim(d, k),
    "G(64) then R >= max(thr, k P)": lambda d, k: gate(d, G) and d["Rimg"] >= max(d["tolerance"], k * d["P"]),
    "G(64) then R >= max(thr, k (P + eps path))": lambda d, k: gate(d, G) and d["Rimg"] >= max(d["tolerance"], k * (d["P"] + d["eps"] * d["path"])),
    "G(64) then confirm pass >= max(thr, k P), or A": lambda d, k: gate(d, G) and (d["conf_img"] >= max(d["tolerance"], k * d["P"]) or d["confAq_img"] >= G),
    "G(64) then confirm pass >= max(tol, c eps) resp, or A": lambda d, k: gate(d, G) and (d["conf_img"] >= lim(d, k) or d["confAq_img"] >= G),
}
for famname in ("scalar", "group"):
    sel = [(r, d) for r, d in conv if fam(r) == famname and d["rel"] and d["resp"] > 0]
    for T in ("Float32", "Float64"):
        keep = [(r, d) for r, d in sel if d["T"] == T and d["ordinary"] and d["positive"] and d["cls"] != "above" and r["tol"] in ("1.0e-7", "1e-07", "0.0001")]
        keepc = [x for x in keep if x[1]["calib"]]; keepv = [x for x in keep if not x[1]["calib"]]
        bad_ = [(r, d) for r, d in sel if d["T"] == T and d["cls"] == "above" and d["roundfalse"]]
        print(f"\n{famname} {T}: keep fixtures {len(keepc)}, keep generated {len(keepv)}, bad {len(bad_)}; gate(64) fires on {sum(gate(d, G) for r, d in keep)} keep, {sum(gate(d, G) for r, d in bad_)} bad")
        print("rule".ljust(56) + "".join(f"k={k}".ljust(20) for k in KAPPA))
        for rn, rule in R2.items():
            cells = []
            for k in KAPPA:
                esc = [(d["kkt_rel"], r["design"], r["j"]) for r, d in bad_ if not rule(d, k)]
                cells.append(f"{sum(rule(d, k) for r, d in keepc)}+{sum(rule(d, k) for r, d in keepv)} | {len(bad_) - len(esc)}" + (f" ({max(esc)[0]:.1e})" if esc else ""))
            print(rn.ljust(56) + "".join(c.ljust(20) for c in cells))
        # the escapes of G then R at c = 64, and the must-keep refusals at c = 256
        esc = sorted(((d["kkt_rel"], r["design"], r["pen"], r["l1frac"], r["start"], r["dir"], r["j"], r["order"], r["tol"], d["Rimg"] / (d["eps"] * d["resp"]), d["P"] / (d["eps"] * d["resp"]))
                      for r, d in bad_ if not (gate(d, G) and d["Rimg"] >= lim(d, G))), reverse=True)
        for e in esc[:4]:
            print("#  escapes G then R at 64:", *[f"{x:.3g}" if isinstance(x, float) else x for x in e])
        lost = sorted(((d["Rimg"] / (d["eps"] * d["resp"]), r["design"], r["pen"], r["l1frac"], r["start"], r["container"], r["order"], r["momentum"], r["tol"], r["passes"],
                        d["P"] / (d["eps"] * d["resp"]), d["path"] / d["resp"], d["conf_img"] / d["tolerance"], d["kkt_rel"], d["subopt_hi"])
                       for r, d in keep if gate(d, G) and d["Rimg"] >= lim(d, 256)), reverse=True)
        for e in lost[:6]:
            print("#  must-keep refused by G then R at 256 [R/(eps resp), ..., passes, P/(eps resp), path/resp, confirm/thr, KKT, subopt]:", *[f"{x:.3g}" if isinstance(x, float) else x for x in e])
