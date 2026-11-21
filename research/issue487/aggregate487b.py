"""Aggregate probe487b output (tab-separated rows inside a battery .out file)."""
import sys, collections, math

path = sys.argv[1]
hdr = None
rows = []
for line in open(path, encoding="utf-8"):
    line = line.rstrip("\n")
    if line.startswith("fixture\tfamily"):
        hdr = line.split("\t"); continue
    if hdr and line.count("\t") == len(hdr) - 1:
        rows.append(dict(zip(hdr, line.split("\t"))))
print(f"{len(rows)} rows")

def fl(x):
    try: return float(x)
    except ValueError: return math.nan

RULES = ["cur", "A", "B", "Bh", "C", "E"]
free_fams = {"free-offset", "free-column", "free-multi", "tiny-weight", "large-weight", "group", "rescale", "ill-conditioned", "control"}

def table(sel, title):
    print(f"\n== {title}")
    print("T        loss  rule  n    CC  FALSE  AU   NC   max_relex_conv  med_iter  pl_rows")
    for T in ("Float64", "Float32"):
        for loss in ("ls", "logistic"):
            for r in RULES:
                rs = [x for x in sel if x["T"] == T and x["loss"] == loss and x["rule"] == r]
                if not rs: continue
                c = collections.Counter(x["class"] for x in rs)
                conv = [fl(x["relexcess"]) for x in rs if x["converged"] == "true"]
                its = sorted(int(x["iter"]) for x in rs)
                pl = sum(x["plimitedB"] == "true" for x in rs)
                print(f"{T:8} {loss:5} {r:4} {len(rs):4} {c['CC']:4} {c['FALSE']:5} {c['AU']:4} {c['NC']:4}   "
                      f"{(max(conv) if conv else float('nan')):.2e}        {its[len(its)//2]:5}    {pl}")

table([x for x in rows if x["family"] != "all-free"], "all fixtures except all-free (AF*)")
table([x for x in rows if x["family"] in free_fams - {"control"} or x["family"] == "logistic" and "no free" not in x["fixture"]],
      "fixtures with a free or tiny-weight coordinate (incl. rescale, IC)")
table([x for x in rows if x["family"] == "ordinary" or "no free" in x["fixture"] or x["family"] == "control"],
      "ordinary (no free coordinate) and controls")
table([x for x in rows if x["family"] == "all-free"], "all coordinates free (AF*)")

# false stops by rule, listed
print("\n== false stops (converged, relexcess > 1e-6)")
for r in RULES:
    fs = [x for x in rows if x["rule"] == r and x["class"] == "FALSE"]
    print(f"-- {r}: {len(fs)}")
    for x in fs:
        print(f"   {x['fixture']} | {x['T']} {x['method']} it={x['iter']} relex={x['relexcess']} prog={x['progexcess']} ang={x['kkt_angle']} pl={x['plimitedB']}")

# decision changes vs cur on ordinary rows
print("\n== ordinary rows (family ordinary, controls, logistic no free): flag/class changes vs cur")
key = lambda x: (x["fixture"], x["T"], x["method"])
cur = {key(x): x for x in rows if x["rule"] == "cur"}
for r in RULES[1:]:
    ch = []
    itr = []
    for x in rows:
        if x["rule"] != r: continue
        if not (x["family"] in ("ordinary", "control") or "no free" in x["fixture"]): continue
        c = cur[key(x)]
        if c["converged"] == x["converged"] and c["converged"] == "true":
            itr.append(int(x["iter"]) / int(c["iter"]))
        if c["converged"] != x["converged"] or c["class"] != x["class"]:
            ch.append((x, c))
    itr.sort()
    q = (lambda p: itr[min(len(itr) - 1, int(p * len(itr)))]) if itr else (lambda p: float("nan"))
    print(f"-- {r}: {len(ch)} changes; iteration ratio (both converged) min {q(0):.2f} median {q(0.5):.2f} max {q(0.999):.2f} (n={len(itr)})")
    for x, c in ch:
        print(f"   {x['fixture']} | {x['T']} {x['method']}: cur {c['class']} it={c['iter']} relex={c['relexcess']} -> {x['class']} it={x['iter']} {x['reason']} relex={x['relexcess']} pl={x['plimitedB']}")

# precision-limited classification vs outcome for rule B
print("\n== rule B: precision-limited flag at the returned point vs class")
cnt = collections.Counter((x["T"], x["plimitedB"], x["class"]) for x in rows if x["rule"] == "B")
for k in sorted(cnt): print("  ", k, cnt[k])

# accurate-uncertified vs genuine nonconvergence, B: reasons
print("\n== rule B non-converged rows: reason x class")
cnt = collections.Counter((x["T"], x["reason"], x["class"]) for x in rows if x["rule"] == "B" and x["converged"] == "false")
for k in sorted(cnt): print("  ", k, cnt[k])

# disagreement between relexcess class and KKT-angle class
print("\n== accuracy-classifier disagreement (relexcess<=1e-6 vs kkt_angle<=1e-4), any rule")
dis = [x for x in rows if (fl(x["relexcess"]) <= 1e-6) != (fl(x["kkt_angle"]) <= 1e-4)]
print(len(dis), "rows")
for x in dis[:30]:
    print(f"   {x['fixture']} | {x['T']} {x['method']} {x['rule']} relex={x['relexcess']} ang={x['kkt_angle']} prog={x['progexcess']}")
