import sys, csv, collections
rows = []
hdr = None
for line in open(sys.argv[1]):
    f = line.rstrip("\n").split("\t")
    if f[0] == "family": hdr = f; continue
    if hdr and len(f) == len(hdr) and (f[0] == "scalar" or f[0].startswith("group")): rows.append(dict(zip(hdr, f)))
print(len(rows), "rows")
c = collections.Counter()
for r in rows:
    c[(r["family"][:5], r["T"], "status=" + r["status"][:14], "conv=" + r["converged"], "equiv=" + r["equiv"], "mism=" + r["mism"])] += 1
for k, v in sorted(c.items()): print(v, k)
def fl(x):
    try: return float(x)
    except: return float("nan")
tgt = {"Float64": 1e-8, "Float32": 1e-5}
print("converged rows above target (subopt_lo > target, informative):")
n = 0
for r in rows:
    if r["converged"] != "true": continue
    if r["informative"] == "true" and fl(r["subopt_lo"]) > tgt[r["T"]]:
        n += 1
        if n <= 40:
            print(" ", r["family"], r["T"], r["loss"], r["pen"], r["l1frac"], r["start"], r["dir"], r["j"], r["container"], r["order"], r["momentum"], "tol", r["tol"], "rel", r["relative"],
                  "| passes", r["passes"], "maxch", r["maxchange"], "thr", r["tolerance"], "nabs", r["nabs"], "nhnz", r["nhnz"],
                  "| A", r["A"], "Ball", r["Ball"], "C352", r["C352"], "Rimg", r["Rimg"], "R64", r["R64"], "P", r["P"],
                  "| kkt", r["kkt_rel"], "sub", r["subopt_lo"], "E", r["E"], "dres", r["dres"], "amp", r["amp"])
print(n, "above-target converged rows")
