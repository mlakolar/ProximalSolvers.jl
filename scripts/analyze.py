#!/usr/bin/env python3
"""#320 Stage 2 analysis: python3 -I analyze.py <results/cluster dir> [<phase0 archive dir>]"""
import csv, glob, math, os, statistics, sys, collections

root = sys.argv[1]
arch = sys.argv[2] if len(sys.argv) > 2 else None
VERS = sorted(d for d in os.listdir(root) if d[0].isdigit())
HARN = {"lasso", "lasso-B", "lasso-B-warm", "lasso-C", "lasso-D"}
pop = lambda d: "harness" if d in HARN else "adverse"
arm = lambda r: f"{r['T']} {r['solver'].upper()}"

def rows(pattern):
    for fn in sorted(glob.glob(pattern)):
        yield from csv.DictReader(open(fn), delimiter="\t")

def q(xs, p):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(math.ceil(p * len(xs))) - 1)] if xs else float("nan")

print("# 0. Data hashes against Phase 0")
if arch:
    p0 = {}
    for r in rows(arch + "/results/*/*/run-summary.tsv.gz".replace(".gz", "")):
        pass
    import gzip
    for fn in glob.glob(arch + "/results/*/*/run-summary.tsv.gz"):
        for r in csv.DictReader(gzip.open(fn, "rt"), delimiter="\t"):
            p0[(r["julia"], r["design"], r["draw"], r["T"])] = r["data_hash"]
    same = diff = missing = 0
    for v in VERS:
        for r in rows(f"{root}/{v}/traj-*-rules.tsv"):
            if r["rule"] != "R1": continue
            key = (v.replace("1.13.4", "1.13.3"), r["design"], r["draw"], r["T"])
            h = p0.get(key)
            if h is None: missing += 1
            elif h == r["data_hash"]: same += 1
            else: diff += 1
    print(f"same {same}, different {diff}, not in Phase 0 {missing}")

print("\n# 1. Accuracy of the evaluator against BigFloat(256)")
acc = collections.defaultdict(lambda: collections.defaultdict(list))
under2 = collections.Counter(); nband = collections.Counter()
for v in VERS:
    for r in rows(f"{root}/{v}/traj-*-accuracy.tsv"):
        b = float(r["big_rel"])
        if not (math.isfinite(b) and b > 0): continue
        key = (v, arm(r))
        inb = 1e-5 / 3 <= b <= 3e-5 if r["T"] == "Float32" else 1e-8 / 3 <= b <= 3e-8
        for col in ("w1_rel", "w1_rel_pd", "w2_rel", "r32_rel", "cert64_rel"):
            x = float(r[col])
            if not math.isfinite(x): continue
            e = abs(x - b) / b
            acc[key][col].append(e)
            if inb: acc[key][col + "@band"].append(e)
        if inb:
            nband[key] += 1
            if float(r["r32_rel"]) < b / 2: under2[key] += 1
for key in sorted(acc):
    d = acc[key]
    print(f"{key[0]} {key[1]}: iterates {len(d['w1_rel'])} (band {nband[key]})")
    for col in ("w1_rel", "w1_rel_pd", "w2_rel", "cert64_rel", "r32_rel"):
        a, bnd = d[col], d[col + "@band"]
        print(f"   {col:11s} max {max(a):.2e}  p99 {q(a, .99):.2e} | band max {max(bnd) if bnd else float('nan'):.2e}  band p99 {q(bnd, .99) if bnd else float('nan'):.2e}")
    print(f"   r32 underestimates big by >2x on {under2[key]} of {nband[key]} band iterates")

print("\n# 2. Degenerate cases")
for v in VERS:
    for r in rows(f"{root}/{v}/degen-degenerate.tsv"):
        b, w = float(r["rel_big"]), float(r["rel_w1"])
        ok = (math.isnan(b) and r["status"] == "nonfinite") or (b == 0 and w == 0) or (b > 0 and abs(w - b) / b <= 1e-10)
        print(f"{v} {'PASS' if ok else 'FAIL'} {r['case'][:46]:46s} status {r['status']:14s} w1 {w:.6g} big {b:.6g} r32 {float(r['rel_r32']):.6g}")

print("\n# 3. Hypothetical stopping")
R = collections.defaultdict(list)
Hrec = {}
for v in VERS:
    for r in rows(f"{root}/{v}/traj-*-rules.tsv"):
        R[(v, arm(r), pop(r["design"]), r["rule"])].append(r)
        Hrec[(v, arm(r), pop(r["design"]), r["design"], r["draw"])] = r
print("H (current library, harness options): converged / false success (big > tol) / truthful miss / ok, per 50 harness or 70 adverse solves")
for key in sorted({k[:3] for k in Hrec}):
    hs = [r for k, r in Hrec.items() if k[:3] == key]
    tol = float(hs[0]["target"])
    conv = sum(r["H_converged"] == "true" for r in hs)
    fs = sum(r["H_converged"] == "true" and float(r["H_big_rel"]) > tol for r in hs)
    miss = sum(r["H_converged"] != "true" and float(r["H_big_rel"]) > tol for r in hs)
    ok = sum(float(r["H_big_rel"]) <= tol for r in hs)
    cls = collections.Counter(r["H_class"] for r in hs)
    print(f"  {key[0]} {key[1]:13s} {key[2]:8s} n {len(hs)}: converged {conv}, false success {fs}, truthful miss {miss}, ok {ok}; classes {dict(cls)}")
print("rules: success / false success / nonconverged (reasons) / median(stop - k*) over successes / median gap evals")
for key in sorted(R):
    rs = R[key]
    succ = [r for r in rs if r["success"] == "true"]
    for r in succ:
        if not math.isfinite(float(r["big_rel_at_stop"])):
            sys.exit(f"missing BigFloat reference at a success: {key} {r['design']} {r['draw']}")
    fs = sum(float(r["big_rel_at_stop"]) > float(r["gaptol"]) for r in succ)
    nan_big = sum(r["success"] == "true" and not math.isfinite(float(r["big_rel_at_stop"])) for r in rs)
    reasons = collections.Counter(r["reason"] for r in rs if r["success"] != "true")
    dk = [int(r["stop_k"]) - int(r["kstar_cert"]) for r in succ if int(r["kstar_cert"]) > 0]
    ev = [int(r["n_gap_evals"]) for r in rs]
    print(f"  {key[0]} {key[1]:13s} {key[2]:8s} {key[3]:6s} gaptol {rs[0]['gaptol']:>8s}: success {len(succ)}/{len(rs)}, false {fs}"
          f"{' (big missing ' + str(nan_big) + ')' if nan_big else ''}, other {dict(reasons)}, "
          f"stop-k* median {statistics.median(dk) if dk else float('nan')}, [{min(dk) if dk else ''},{max(dk) if dk else ''}], evals median {statistics.median(ev)}")

print("\n# 4. Cost (Float32 PGD; minimum over rounds)")
T = collections.defaultdict(dict)
for v in VERS:
    for r in rows(f"{root}/{v}/time-time.tsv"):
        T[(v, r["design"], r["draw"])][r["arm"]] = r
for v in VERS:
    ks = [k for k in T if k[0] == v]
    ratio = lambda a, b: [float(T[k][a]["min_s"]) / float(T[k][b]["min_s"]) for k in ks]
    med = lambda xs: f"{statistics.median(xs):.3f} [{min(xs):.3f}, {max(xs):.3f}]"
    print(f"{v}: problems {len(ks)}, cpu {T[ks[0]]['H']['cpu']}")
    for a, b in (("Haa", "H"), ("W1aa", "W1"), ("W1", "G32"), ("W2", "G32"), ("R32", "G32"), ("W1", "H"), ("W2", "H"), ("W2setup", "H")):
        print(f"   {a}/{b}: {med(ratio(a, b))}")
    print("   alloc bytes per call: " + ", ".join(f"{a} {sorted({T[k][a]['alloc_bytes'] for k in ks})}" for a in ("W1", "W2", "R32", "W2setup", "H")))
    per_design = collections.defaultdict(list)
    for k in ks:
        per_design[k[1]].append(float(T[k]["W1"]["min_s"]) * 1e6)
    print("   W1 microseconds by design: " + ", ".join(f"{d} {statistics.median(x):.1f}" for d, x in sorted(per_design.items())))
    # projected overhead of rules on the same problems (Float32 PGD trajectories)
    for rule in ("R1", "R10", "RK", "R1i", "RKi"):
        over = []
        for k in ks:
            tr = [r for r in R[(v, "Float32 PGD", pop(k[1]), rule)] if r["design"] == k[1] and r["draw"] == k[2]]
            if not tr: continue
            evals = int(tr[0]["n_gap_evals"])
            over.append(evals * float(T[k]["W1"]["min_s"]) / float(T[k]["H"]["min_s"]))
        if over:
            print(f"   projected gap-evaluation cost of {rule} / H solve time: {med(over)}")

print("\n# 5. Solve length and evaluation overhead relative to the run's own iterations (Float32 PGD, timed problems)")
for v in VERS:
    ks = [k for k in T if k[0] == v]
    for rule in ("R1", "R10", "RK"):
        for popn in ("harness", "adverse"):
            lens, overs = [], []
            for k in ks:
                if pop(k[1]) != popn: continue
                tr = [r for r in R[(v, "Float32 PGD", popn, rule)] if r["design"] == k[1] and r["draw"] == k[2]]
                if not tr: continue
                r = tr[0]
                hit = int(r["H_iterations"]); sk = int(r["stop_k"])
                titer = float(T[k]["H"]["min_s"]) / int(T[k]["H"]["H_iterations"])
                lens.append(sk / hit)
                overs.append(int(r["n_gap_evals"]) * float(T[k]["W1"]["min_s"]) / (sk * titer))
            if lens:
                print(f"  {v} {rule:4s} {popn:8s} n {len(lens)}: stop_k / H_iterations median {statistics.median(lens):.2f} [{min(lens):.2f}, {max(lens):.2f}]; "
                      f"evaluation time / own iteration time median {statistics.median(overs):.3f} [{min(overs):.3f}, {max(overs):.3f}]")
    # all draws: stop length ratio for the rules (no timing needed)
    for rule in ("R1", "RK"):
        for popn in ("harness", "adverse"):
            rs = R[(v, "Float32 PGD", popn, rule)]
            lens = [int(r["stop_k"]) / int(r["H_iterations"]) for r in rs if r["success"] == "true"]
            print(f"  {v} {rule} {popn} successes {len(lens)}: stop_k / H_iterations median {statistics.median(lens):.2f} [{min(lens):.2f}, {max(lens):.1f}]")

print("\n# 6. Degenerate relative errors")
for v in VERS:
    for r in rows(f"{root}/{v}/degen-degenerate.tsv"):
        print(f"  {v} {r['case'][:46]:46s} relerr {r['relerr_rel_w1']}  |gap_w1-gap_big| {abs(float(r['gap_w1_id'])-float(r['gap_big'])) if r['gap_big']!='NaN' else 'nan'}  P {r['P_big']}")

print("\n# 7. Review checks")
# (a) every success has a finite BigFloat reference
bad = sum(1 for k, rs in R.items() for r in rs if r["success"] == "true" and not math.isfinite(float(r["big_rel_at_stop"])))
print(f"successes without a finite BigFloat reference: {bad}; total successes {sum(r['success']=='true' for rs in R.values() for r in rs)}")
# (b) R1i/RKi successes on an iteration that also had a computed increase (increase-priority counts)
inc = {}
for v in VERS:
    for r in rows(f"{root}/{v}/traj-*-accuracy.tsv"):
        inc[(v, r["design"], r["draw"], r["T"], r["solver"], r["k"])] = r["f_increased"] == "true"
for key in sorted(R):
    if key[3] not in ("R1i", "RKi"): continue
    rs = R[key]
    succ = [r for r in rs if r["success"] == "true"]
    tie = sum(inc.get((key[0], r["design"], r["draw"], r["T"], r["solver"], r["stop_k"]), False) for r in succ)
    print(f"  {key[0]} {key[1]:13s} {key[2]:8s} {key[3]}: success {len(succ)}, of which same-iteration increase {tie}; increase-priority success {len(succ)-tie}")
# (c) trajectory ends
ends = collections.Counter(r["trajectory_end"] for rs in R.values() for r in rs if r["rule"] == "R1")
print("trajectory ends (one per trajectory):", dict(ends))
# (d) R10 solve-length maximum; APG R1 vs RK stop differences
for v in VERS:
    for popn in ("harness", "adverse"):
        rs = [r for r in R[(v, "Float32 PGD", popn, "R10")] if r["success"] == "true"]
        print(f"  {v} R10 {popn} stop/H max {max(int(r['stop_k'])/int(r['H_iterations']) for r in rs):.2f}")
    for popn in ("harness", "adverse"):
        a = {(r["design"], r["draw"]): r["stop_k"] for r in R[(v, "Float32 APG", popn, "R1")]}
        b = {(r["design"], r["draw"]): r["stop_k"] for r in R[(v, "Float32 APG", popn, "RK")]}
        print(f"  {v} APG {popn}: R1 and RK stop at different iterations in {sum(a[k] != b[k] for k in a)} of {len(a)}")
# (e) timing joins: CPU agreement and H iteration agreement; R10 projection normalized by the timing table's H iterations
for v in VERS:
    ks = [k for k in T if k[0] == v]
    cross = itdiff = 0; over10 = []
    for k in ks:
        tr = [r for r in R[(v, "Float32 PGD", pop(k[1]), "R10")] if r["design"] == k[1] and r["draw"] == k[2]][0]
        cross += tr["cpu"] != T[k]["H"]["cpu"]
        itdiff += int(tr["H_iterations"]) != int(T[k]["H"]["H_iterations"])
        over10.append(int(tr["n_gap_evals"]) * float(T[k]["W1"]["min_s"]) / float(T[k]["H"]["min_s"]))
    print(f"  {v}: timing joins {len(ks)}, cross-CPU {cross}, H-iteration mismatch {itdiff}; R10 evals x W1 / H time median {statistics.median(over10):.3f}")
