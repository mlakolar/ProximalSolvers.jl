# master vs prototype X1 (an unchanged iterate proposes a stop under ftol = 0; the stationarity check decides)
import sys, collections
sys.path.insert(0, __file__.rsplit("/", 1)[0])
from summ import load, fl, classify
KEY = ["solver", "T", "fixture", "loss", "penalty", "l1frac", "options", "start"]
for T in ("Float64", "Float32"):
    A = {tuple(r[k] for k in KEY): r for r in load("evidence/sweep-release/grad_%s.tsv" % T)}
    B = {tuple(r[k] for k in KEY): r for r in load("evidence/sweep-x1/grad_%s.tsv" % T)}
    assert A.keys() == B.keys()
    print("=====", T)
    same = collections.Counter(); 
    for opt in ("default", "default-20k", "allow-inc", "gradtol1e-8", "ftol0", "strict"):
        ks = [k for k in A if k[6] == opt and A[k]["status"] == "ok"]
        ident = sum(all(A[k][c] == B[k][c] for c in ("converged", "exit", "iterations", "F", "kkt_rel")) for k in ks)
        print("options %-12s solves %d, identical outcome and returned point: %d" % (opt, len(ks), ident))
    for sol in ("pgd", "apg"):
        for opt in ("ftol0", "strict"):
            ks = [k for k in A if k[0] == sol and k[6] == opt and A[k]["status"] == "ok"]
            ca = collections.Counter(A[k]["exit"] for k in ks); cb = collections.Counter(B[k]["exit"] for k in ks)
            ita = sum(int(A[k]["iterations"]) for k in ks); itb = sum(int(B[k]["iterations"]) for k in ks)
            newc = [k for k in ks if A[k]["converged"] != "true" and B[k]["converged"] == "true"]
            lost = [k for k in ks if A[k]["converged"] == "true" and B[k]["converged"] != "true"]
            viol = [k for k in ks if B[k]["converged"] == "true" and not fl(B[k]["kkt_rel"]) < fl(B[k]["bound"])]
            cls = collections.Counter(classify(B[k]) for k in newc)
            worst = max((fl(B[k]["kkt_rel"]) / fl(B[k]["bound"]) for k in ks if B[k]["converged"] == "true"), default=0)
            moved = sum(A[k]["F"] != B[k]["F"] for k in newc)
            print(" %s %-6s master %s | X1 %s" % (sol, opt, dict(ca), dict(cb)))
            print("    total iterations %d -> %d; newly converged %d (%s), returned objective differs in %d of them; lost %d; converged with exact KKT >= bound: %d (worst ratio %.3f)"
                  % (ita, itb, len(newc), dict(cls), moved, len(lost), len(viol), worst))
