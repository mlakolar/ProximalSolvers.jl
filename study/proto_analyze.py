#!/usr/bin/env python3
"""Tables of the prototype sweep (protosweep.jl). usage: python3 -I proto_analyze.py NAME PROTO_DIR [SWEEP_DIR]

Standard library only. One solve = one input (design, loss, penalty, start, configuration, tol) solved by
master and by each prototype. The class of a returned point is the one of analyze.py: within target
(tight reference and upper bound on the suboptimality <= target), above (lower bound > target), undecided.
With SWEEP_DIR, the master rows are compared with the rows of sweep378.jl for the same input.
"""
import collections, glob, gzip, os, sys

TARGET = {"Float64": 1e-8, "Float32": 1e-5}
MODS = ["master"]      # the other modules are read from the data
KEY = ["family", "T", "design", "loss", "pen", "l1frac", "l2par", "start", "dir", "j", "container", "order", "momentum", "seed", "tol", "relative", "maxpasses"]


def fl(x):
    try:
        return float(x)
    except ValueError:
        return float("nan")


def rows_of(d):
    for f in sorted(glob.glob(os.path.join(d, "*.tsv.gz"))):
        hdr = None
        with gzip.open(f, "rt") as io:
            for line in io:
                c = line.rstrip("\n").split("\t")
                if c[0] == "family":
                    hdr = c
                    continue
                if hdr is None or len(c) != len(hdr):
                    continue
                yield dict(zip(hdr, c))


def cls(r):
    tgt = TARGET[r["T"]]
    if r["tight"] == "true" and fl(r["subopt_hi"]) <= tgt:
        return "within"
    if r["informative"] == "true" and fl(r["subopt_lo"]) > tgt:
        return "above"
    return "undecided"


def table(title, cols, lines):
    print("\n" + title)
    print("\t".join(cols))
    for l in lines:
        print("\t".join(str(x) for x in l))


def main():
    name, pdir = sys.argv[1], sys.argv[2]
    solves = collections.OrderedDict()
    errors = collections.Counter()
    n = 0
    for r in rows_of(pdir):
        n += 1
        if r["status"] != "ok":
            errors[(r["module"], r["status"][:40])] += 1
            continue
        k = tuple(r[c] for c in KEY)
        o = dict(conv=r["converged"] == "true", passes=int(r["passes"]), maxchange=r["maxchange"], kkt=r["kkt_rel"], cls=cls(r),
                 E=fl(r["E"]), cap=int(r["passes"]) >= int(r["maxpasses"]), lo=fl(r["subopt_lo"]), kktv=fl(r["kkt_rel"]))
        solves.setdefault(k, {})[r["module"]] = o
    for v in solves.values():
        for m in v:
            m in MODS or MODS.append(m)
    full = {k: v for k, v in solves.items() if all(m in v for m in MODS)}
    print(f"# {name}: {n} rows, {len(solves)} inputs, {len(full)} with all of {MODS}; errors: {dict(errors) if errors else 'none'}")
    ix = {c: i for i, c in enumerate(KEY)}
    fam = lambda k: "group" if k[ix["family"]].startswith("group") else "scalar"
    start = lambda k: "ordinary" if k[ix["start"]] != "adv" else "adversarial"
    pos = lambda k: fl(k[ix["l1frac"]]) > 0 or fl(k[ix["l2par"]]) > 0
    p_of = {}
    for r in rows_of(pdir):
        p_of.setdefault(r["design"], int(r["p"]))
        if len(p_of) >= 49:
            break
    # a converged stop that exact arithmetic does not allow: E > p (E is in the unit of the tolerance); scalar only
    rf = lambda k, o: o["E"] > p_of[k[ix["design"]]]

    # For groups (no E): a converged stop above target whose KKT residual is more than 10 times the largest one
    # among master's converged solves of the same problem, configuration and tolerance from ordinary starts.
    prob = lambda k: tuple(k[ix[c]] for c in ("family", "T", "design", "loss", "pen", "l1frac", "l2par", "container", "order", "momentum", "seed", "tol"))
    refk = {}
    for k, v in full.items():
        if start(k) == "ordinary" and v["master"]["conv"]:
            refk[prob(k)] = max(refk.get(prob(k), 0.0), v["master"]["kktv"])
    far = lambda k, o: o["conv"] and o["cls"] == "above" and prob(k) in refk and o["kktv"] > 10 * refk[prob(k)]
    agree = collections.Counter()
    for k, v in full.items():
        if fam(k) == "scalar":
            for m in MODS:
                o = v[m]
                if o["conv"] and o["cls"] == "above":
                    agree[(rf(k, o), far(k, o))] += 1
    print(f"# scalar, converged above target: E>p and KKT>10x ordinary {agree[(True, True)]}; E>p only {agree[(True, False)]}; KKT>10x only {agree[(False, True)]}; neither {agree[(False, False)]}")

    # ---- P1: outcomes by module
    acc = collections.defaultdict(collections.Counter)
    for k, v in full.items():
        for m in MODS:
            o = v[m]
            a = acc[(fam(k), k[ix["T"]], start(k), m)]
            a["n"] += 1
            if o["conv"]:
                a["conv"] += 1; a[o["cls"]] += 1
                a["above_rf"] += o["cls"] == "above" and fam(k) == "scalar" and rf(k, o)
                a["far"] += far(k, o)
            else:
                a["cap" if o["cap"] else "refused"] += 1
                a["refused_" + o["cls"]] += (not o["cap"])
            a["passes"] += o["passes"]
    table("P1. Outcomes by module (all inputs)",
          ["family", "T", "starts", "module", "solves", "converged", "within", "undecided", "above", "above and E>p thr (scalar)", "above and KKT > 10x ordinary",
           "stopped unconverged before the cap", "of those: within", "undecided", "above", "pass cap reached", "passes, total"],
          [list(k) + [a["n"], a["conv"], a["within"], a["undecided"], a["above"], a["above_rf"], a["far"], a["refused"], a["refused_within"],
                      a["refused_undecided"], a["refused_above"], a["cap"], a["passes"]]
           for k, a in sorted(acc.items(), key=lambda kv: (kv[0][0], kv[0][1], kv[0][2], MODS.index(kv[0][3])))])

    # ---- P2: against master, input by input
    acc = collections.defaultdict(collections.Counter)
    worst = collections.defaultdict(list)
    for k, v in full.items():
        m0 = v["master"]
        if m0["conv"]:
            mc = "master converged, above target" if m0["cls"] == "above" else "master converged, not above target"
        else:
            mc = "master not converged"
        for m in MODS[1:]:
            o = v[m]
            a = acc[(fam(k), k[ix["T"]], start(k), mc, m)]
            a["n"] += 1
            same = o["conv"] == m0["conv"] and o["passes"] == m0["passes"] and o["maxchange"] == m0["maxchange"] and o["kkt"] == m0["kkt"]
            a["same"] += same
            if o["conv"]:
                a["conv_" + o["cls"]] += 1
            else:
                a["cap" if o["cap"] else "refused"] += 1
            a["more"] += o["passes"] > m0["passes"]; a["fewer"] += o["passes"] < m0["passes"]
            a["p0"] += m0["passes"]; a["p1"] += o["passes"]
            if mc == "master converged, not above target" and not o["conv"] and start(k) == "ordinary" and pos(k):
                worst[(fam(k), k[ix["T"]], m)].append(k)
    table("P2. Each prototype against master on the same input",
          ["family", "T", "starts", "master", "module", "inputs", "identical outcome (flag, passes, last change, KKT)", "converged: within", "undecided",
           "above", "stopped unconverged before the cap", "pass cap", "more passes", "fewer passes", "passes master", "passes module"],
          [list(k) + [a["n"], a["same"], a["conv_within"], a["conv_undecided"], a["conv_above"], a["refused"], a["cap"], a["more"], a["fewer"], a["p0"], a["p1"]]
           for k, a in sorted(acc.items(), key=lambda kv: (kv[0][0], kv[0][1], kv[0][2], kv[0][3], MODS.index(kv[0][4])))])

    # ---- P3: the must-keep population (ordinary start, positive penalty, master converged and not above target)
    acc = collections.defaultdict(collections.Counter)
    for k, v in full.items():
        m0 = v["master"]
        if not (start(k) == "ordinary" and pos(k) and m0["conv"] and m0["cls"] != "above"):
            continue
        calib = "fixtures" if k[ix["design"]] in CALIB else "generated"
        for m in MODS[1:]:
            o = v[m]
            a = acc[(fam(k), k[ix["T"]], calib, k[ix["tol"]], m)]
            a["n"] += 1; a["lost"] += not o["conv"]; a["more"] += o["passes"] > m0["passes"]
            a["same"] += o["conv"] and o["passes"] == m0["passes"] and o["maxchange"] == m0["maxchange"] and o["kkt"] == m0["kkt"]
            a["p0"] += m0["passes"]; a["p1"] += o["passes"]
            a["maxextra"] = max(a["maxextra"], o["passes"] - m0["passes"])
    table("P3. Must-keep inputs: ordinary start, positive penalty, master converged and not above target",
          ["family", "T", "designs", "tol", "module", "inputs", "no longer converged", "identical outcome", "more passes", "largest increase in passes",
           "passes master", "passes module"],
          [list(k) + [a["n"], a["lost"], a["same"], a["more"], a["maxextra"], a["p0"], a["p1"]]
           for k, a in sorted(acc.items(), key=lambda kv: (kv[0][0], kv[0][1], kv[0][2], kv[0][3], MODS.index(kv[0][4])))])
    for kk, ks in sorted(worst.items()):
        print(f"\n# must-keep inputs no longer converged, {kk}: {len(ks)}; first: " + "; ".join(" ".join(k[ix[c]] for c in ("design", "loss", "pen", "l1frac", "l2par", "start", "container", "order", "momentum", "tol")) for k in ks[:8]))

    # ---- P4: false convergence that survives, by size of the start
    acc = collections.defaultdict(collections.Counter)
    for k, v in full.items():
        if start(k) != "adversarial":
            continue
        for m in MODS:
            o = v[m]
            a = acc[(fam(k), k[ix["T"]], int(k[ix["j"]]), m)]
            a["n"] += 1
            a["above"] += o["conv"] and o["cls"] == "above"
            a["far"] += far(k, o)
            a["rf"] += o["conv"] and o["cls"] == "above" and fam(k) == "scalar" and rf(k, o)
            a["within"] += o["conv"] and o["cls"] == "within"
            a["und"] += o["conv"] and o["cls"] == "undecided"
            a["refused"] += (not o["conv"]) and not o["cap"]
            a["cap"] += (not o["conv"]) and o["cap"]
            if o["conv"] and o["cls"] == "above":
                a["worstkkt"] = max(a["worstkkt"], o["kktv"]) if "worstkkt" in a else o["kktv"]
    lines = []
    for (f, T, j, m), a in sorted(acc.items(), key=lambda kv: (kv[0][0], kv[0][1], kv[0][2], MODS.index(kv[0][3]))):
        lines.append([f, T, j, m, a["n"], a["within"], a["und"], a["above"], a["rf"], a["far"], a["refused"], a["cap"], ("%.3g" % a["worstkkt"]) if "worstkkt" in a else "-"])
    table("P4. Starts xref + 2^j z: outcome by j", ["family", "T", "j", "module", "solves", "converged within", "converged undecided", "converged above target", "of those E>p thr (scalar)", "of those KKT > 10x ordinary",
                                                     "stopped unconverged before the cap", "pass cap", "largest KKT/max(l1,lmax) among converged above"], lines)

    # ---- P5: by configuration, adversarial starts
    acc = collections.defaultdict(collections.Counter)
    for k, v in full.items():
        if start(k) != "adversarial":
            continue
        for m in MODS:
            o = v[m]
            a = acc[(fam(k), k[ix["T"]], k[ix["container"]], k[ix["order"]], k[ix["momentum"]], m)]
            a["n"] += 1; a["above"] += o["conv"] and o["cls"] == "above"; a["good"] += o["conv"] and o["cls"] != "above"
            a["far"] += far(k, o); a["rf"] += o["conv"] and o["cls"] == "above" and fam(k) == "scalar" and rf(k, o)
            a["refused"] += (not o["conv"]) and not o["cap"]; a["cap"] += (not o["conv"]) and o["cap"]
    table("P5. Starts xref + 2^j z: outcome by configuration", ["family", "T", "container", "order", "momentum", "module", "solves", "converged, not above",
                                                               "converged above target", "of those E>p thr (scalar)", "of those KKT > 10x ordinary", "stopped unconverged before the cap", "pass cap"],
          [list(k) + [a["n"], a["good"], a["above"], a["rf"], a["far"], a["refused"], a["cap"]]
           for k, a in sorted(acc.items(), key=lambda kv: (kv[0][:5], MODS.index(kv[0][5])))])

    # ---- cross-check of the master rows with the sweep
    if len(sys.argv) > 3:
        want = {k: v["master"] for k, v in solves.items() if "master" in v}
        seen = same = 0
        diff = []
        for r in rows_of(sys.argv[3]):
            if r["status"] != "ok":
                continue
            k = tuple(("%.6g" % fl(r[c])) if c == "tol" else r[c] for c in KEY)
            o = want.get(k)
            if o is None:
                continue
            seen += 1
            ok = o["conv"] == (r["converged"] == "true") and o["passes"] == int(r["passes"]) and o["maxchange"] == r["maxchange"] and (r["kkt_rel"] == "NA" or o["kkt"] == r["kkt_rel"])
            same += ok
            if not ok and len(diff) < 5:
                diff.append((k, o["conv"], o["passes"], o["maxchange"], o["kkt"], r["converged"], r["passes"], r["maxchange"], r["kkt_rel"]))
        print(f"\n# cross-check with {sys.argv[3]}: {seen} inputs of {len(want)} found in the sweep; {same} with the same flag, passes, last change and KKT")
        for d in diff:
            print("# differs:", d)


CALIB = {"orth", "gauss", "corr95", "rankdef", "wide", "wide_exact", "zerocol", "colscale", "tall_exact", "offset"}
main()
