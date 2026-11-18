#!/usr/bin/env python3
"""Tables of the #378 sweep. usage: python3 -I analyze.py NAME FILE_OR_DIR... (TSV, .tsv.gz, or a smoke log).

Standard library only. Every count is over converged solves with status ok whose probe run matched
solve! bit for bit; the header of the output says how many rows were dropped and why.
"""
import collections, glob, gzip, math, os, sys

TARGET = {"Float64": 1e-8, "Float32": 1e-5}
EPS = {"Float64": 2.0 ** -52, "Float32": 2.0 ** -23}
FLOORS = [0, 1, 4, 16, 64, 256, 1024, 4096, 16384]
CALIB = {"orth", "gauss", "corr95", "rankdef", "wide", "wide_exact", "zerocol", "colscale", "tall_exact", "offset"}


def fl(x):
    try:
        return float(x)
    except ValueError:
        return float("nan")


def load(paths):
    rows, hdr, bad = [], None, collections.Counter()
    files = []
    for p in paths:
        files += sorted(glob.glob(os.path.join(p, "*.tsv.gz")) + glob.glob(os.path.join(p, "*.tsv"))) if os.path.isdir(p) else [p]
    for f in files:
        op = gzip.open if f.endswith(".gz") else open
        with op(f, "rt") as io:
            for line in io:
                c = line.rstrip("\n").split("\t")
                if c[0] == "family":
                    hdr = c
                    continue
                if hdr is None or len(c) != len(hdr) or not (c[0] == "scalar" or c[0].startswith("group")):
                    continue
                r = dict(zip(hdr, c))
                if r["status"] != "ok":
                    bad["status " + r["status"][:30]] += 1
                    continue
                if r["equiv"] != "true" or r["mism"] != "0":
                    bad["not bit-identical to solve!"] += 1
                    continue
                rows.append(r)
    return rows, bad, len(files)


def prep(r):
    T = r["T"]
    d = {k: fl(r[k]) for k in ("tolerance", "resp", "maxchange", "tol", "A", "Aq", "Aq0", "A0q", "Bq", "Ballq", "Cuq", "C352", "K296", "Rimg",
                               "Rinit", "R64", "P", "P0", "path", "conf_init", "confAq_init", "conf_img", "confAq_img", "kkt_rel",
                               "subopt_lo", "subopt_hi", "E", "dres", "amp", "minerr", "l1frac", "l2par")}
    d["T"], d["eps"] = T, EPS[T]
    d["p"] = int(r["p"])
    d["nhnz"] = int(r["nhnz"]); d["nabs"] = int(r["nabs"])
    d["empty"] = d["maxchange"] == 0
    tgt = TARGET[T]
    if r["tight"] == "true" and d["subopt_hi"] <= tgt:
        d["cls"] = "within"
    elif r["informative"] == "true" and d["subopt_lo"] > tgt:
        d["cls"] = "above"
    else:
        d["cls"] = "undecided"
    thr = d["tolerance"]
    d["Ethr"] = d["E"] / thr if thr > 0 else float("inf")
    d["dthr"] = d["dres"] / thr if thr > 0 else float("inf")
    d["roundfalse"] = d["Ethr"] > d["p"]            # beyond what a converged pass allows in exact arithmetic
    stale = d["dthr"] >= 1
    if not d["roundfalse"]:
        d["mech"] = "-"
    elif stale and d["nhnz"] == 0:
        d["mech"] = "H2 stale, empty pass"
    elif stale:
        d["mech"] = "H3 stale, moving pass"
    elif d["nabs"] > 0:
        d["mech"] = "H1 absorbed"
    else:
        d["mech"] = "other"
    d["ordinary"] = r["start"] != "adv"
    d["positive"] = d["l1frac"] > 0 or d["l2par"] > 0
    d["calib"] = r["design"] in CALIB
    d["rel"] = r["relative"] == "true"
    return d


def lim(d, c):          # the threshold with a floor, in the unit √s‖y‖
    return max(d["tol"], c * d["eps"]) * d["resp"]


def pi(d):              # history form of the resolution: at the start, plus the path
    return d["P0"] + d["eps"] * d["path"]


def gate(d, c):         # the gate of the prototypes: the resolution at the stop plus twice the path
    return d["P"] + 2 * d["eps"] * d["path"] >= lim(d, c)


RULES = collections.OrderedDict([
    ("A  absorbed, per-coordinate unit", lambda d, c: d["Aq"] >= c if c > 0 else d["A"] >= d["tolerance"]),
    ("A' absorbed, unit sqrt(s)|y|", lambda d, c: d["Aq0"] >= c if c > 0 else d["A"] >= d["tolerance"]),
    ("A0 all visits", lambda d, c: d["A0q"] >= max(c, 1e-300)),
    ("B  absorbed, recomputed (cached r)", lambda d, c: d["Bq"] >= max(c, 1e-300)),
    ("C  unrounded step, fresh r, all coords", lambda d, c: d["Cuq"] >= max(c, 1e-300)),
    ("C352 final-point statistic of #352", lambda d, c: d["C352"] >= lim(d, c)),
    ("K  wp KKT/max(l1,lmax) >= max(tol, c eps)", lambda d, c: d["K296"] >= max(d["tol"], c * d["eps"])),
    ("R  cached vs fresh r (image first)", lambda d, c: d["Rimg"] >= lim(d, c)),
    ("Ri cached vs fresh r (init order)", lambda d, c: d["Rinit"] >= lim(d, c)),
    ("P  resolution at the stop", lambda d, c: d["P"] >= lim(d, c)),
    ("Ph resolution at the start + path", lambda d, c: pi(d) >= lim(d, c)),
    ("F  refresh (image first) + pass, with A", lambda d, c: not (d["conf_img"] < d["tolerance"] and (d["confAq_img"] < c if c > 0 else True))),
    ("Fi refresh (init order) + pass, with A", lambda d, c: not (d["conf_init"] < d["tolerance"] and (d["confAq_init"] < c if c > 0 else True))),
    ("G  gate eps(P + 2 path) at the stop", lambda d, c: gate(d, c)),
    ("G then R (image first)", lambda d, c: gate(d, c) and d["Rimg"] >= lim(d, c)),
    ("G then F: not accepted at once", lambda d, c: gate(d, c) and not (d["conf_img"] < d["tolerance"] and (d["confAq_img"] < c if c > 0 else True))),
    ("A or R", lambda d, c: (d["Aq"] >= c if c > 0 else d["A"] >= d["tolerance"]) or d["Rimg"] >= lim(d, c)),
    ("Ph gate, then C", lambda d, c: pi(d) >= lim(d, c) and d["Cuq"] >= max(c, 1e-300)),
])


def table(title, cols, lines):
    print("\n" + title)
    print("\t".join(cols))
    for l in lines:
        print("\t".join(str(x) for x in l))


def main():
    name, paths = sys.argv[1], sys.argv[2:]
    rows, bad, nfiles = load(paths)
    print(f"# {name}: {nfiles} files, {len(rows)} rows kept; dropped: {dict(bad) if bad else 'none'}")
    conv = [(r, prep(r)) for r in rows if r["converged"] == "true"]
    print(f"# converged: {len(conv)}; not converged: {len(rows) - len(conv)}")
    fam = lambda r: "group" if r["family"].startswith("group") else "scalar"

    # ---- T0: the population of #352's probe_cd_gate.jl (fixtures, positive penalty, cold/ref/pert, default tol,
    # dense, cyclic and random order without momentum, seed 1) and its final-point check without a floor
    lines = []
    for T in ("Float32", "Float64"):
        pop = [(r, d) for r, d in conv if r["family"] == "scalar" and r["T"] == T and d["calib"] and d["rel"] and r["tol"] in ("1.0e-7", "1e-07")
               and r["start"] in ("cold", "ref", "pert") and r["container"] == "dense" and r["momentum"] == "false" and r["seed"] == "1"
               and ((r["pen"] == "l1" and d["l1frac"] > 0) or r["pen"] == "enet352")]
        ref = [x for x in pop if x[1]["C352"] >= x[1]["tolerance"]]
        lines.append([T, len(pop), len(ref), sum(1 for r, d in ref if d["cls"] == "within"), sum(1 for r, d in ref if d["cls"] == "undecided"),
                      sum(1 for r, d in ref if d["cls"] == "above"), sum(1 for r, d in pop if d["empty"]), sum(1 for r, d in ref if d["empty"])])
    table("T0. The check of #352 (final point, fresh residual, no floor) on #352's population",
          ["T", "converged", "refused", "refused, within", "refused, undecided", "refused, above", "empty stopping pass", "of those refused"], lines)

    # ---- Task 1: where false convergence occurs
    acc = collections.defaultdict(lambda: collections.Counter())
    for r in rows:
        key = (fam(r), r["T"], r["start"] if r["start"] != "adv" else "adv:" + r["dir"], r["j"])
        acc[key]["solves"] += 1
    for r, d in conv:
        if not d["rel"]:
            continue
        key = (fam(r), r["T"], r["start"] if r["start"] != "adv" else "adv:" + r["dir"], r["j"])
        a = acc[key]
        a["conv"] += 1; a[d["cls"]] += 1; a["empty"] += d["empty"]; a["roundfalse"] += d["roundfalse"]
        a["above&roundfalse"] += d["cls"] == "above" and d["roundfalse"]
        a[d["mech"]] += 1
    mechs = ["H1 absorbed", "H2 stale, empty pass", "H3 stale, moving pass", "other"]
    table("T1. Stops by start (relative=true rows for the converged counts; 'solves' counts every row)",
          ["family", "T", "start", "j", "solves", "converged", "within", "undecided", "above", "empty pass", "E>p thr", "above and E>p thr"] + mechs,
          [list(k) + [a["solves"], a["conv"], a["within"], a["undecided"], a["above"], a["empty"], a["roundfalse"], a["above&roundfalse"]] + [a[m] for m in mechs]
           for k, a in sorted(acc.items(), key=lambda kv: (kv[0][0], kv[0][1], kv[0][2], int(kv[0][3])))])

    acc = collections.defaultdict(lambda: collections.Counter())
    for r, d in conv:
        if not d["rel"]:
            continue
        key = (fam(r), r["T"], r["container"], r["order"], r["momentum"], "ordinary" if d["ordinary"] else "adv")
        a = acc[key]
        a["conv"] += 1; a["above&roundfalse"] += d["cls"] == "above" and d["roundfalse"]; a["roundfalse"] += d["roundfalse"]; a[d["mech"]] += 1
    table("T1b. The same by configuration", ["family", "T", "container", "order", "momentum", "starts", "converged", "E>p thr", "above and E>p thr"] + mechs,
          [list(k) + [a["conv"], a["roundfalse"], a["above&roundfalse"]] + [a[m] for m in mechs] for k, a in sorted(acc.items())])

    acc = collections.defaultdict(lambda: collections.Counter())
    for r, d in conv:
        key = (fam(r), r["T"], r["relative"], "ordinary" if d["ordinary"] else "adv")
        a = acc[key]
        a["conv"] += 1; a["above"] += d["cls"] == "above"; a["empty"] += d["empty"]; a["above&empty"] += d["cls"] == "above" and d["empty"]
    table("T1c. relative = true and false", ["family", "T", "relative", "starts", "converged", "above", "empty pass", "above and empty"],
          [list(k) + [a["conv"], a["above"], a["empty"], a["above&empty"]] for k, a in sorted(acc.items())])

    # ---- Task 2: rules
    for famname in ("scalar", "group"):
        sel = [(r, d) for r, d in conv if fam(r) == famname and d["rel"] and d["resp"] > 0]
        for T in ("Float32", "Float64"):
            keep = [(r, d) for r, d in sel if d["T"] == T and d["ordinary"] and d["positive"] and d["cls"] != "above" and r["tol"] in ("1.0e-7", "1e-07", "0.0001")]
            keepc = [x for x in keep if x[1]["calib"]]
            keepv = [x for x in keep if not x[1]["calib"]]
            sub = [(r, d) for r, d in sel if d["T"] == T and d["ordinary"] and d["positive"] and d["cls"] != "above" and d["tol"] < EPS[T]]
            bad_ = [(r, d) for r, d in sel if d["T"] == T and d["cls"] == "above" and d["roundfalse"]]
            und = [(r, d) for r, d in sel if d["T"] == T and d["cls"] != "above" and d["roundfalse"]]
            lines = []
            for rn, rule in RULES.items():
                if famname == "group" and rn.startswith(("B ", "C", "K", "Ph gate")):
                    continue
                for c in FLOORS:
                    def cnt(pop, cond=lambda r, d: True):
                        return sum(1 for r, d in pop if cond(r, d) and rule(d, c))
                    esc = [int(r["j"]) for r, d in bad_ if r["start"] == "adv" and not rule(d, c)]
                    lines.append([rn, c, f"{cnt(keepc)}/{len(keepc)}", f"{cnt(keepv)}/{len(keepv)}", f"{cnt(sub)}/{len(sub)}",
                                  f"{cnt(bad_)}/{len(bad_)}"] +
                                 [f"{cnt(bad_, lambda r, d, m=m: d['mech'] == m)}/{sum(1 for r, d in bad_ if d['mech'] == m)}" for m in mechs] +
                                 [f"{cnt(und)}/{len(und)}", min(esc) if esc else "-"])
            table(f"T2. Rules, {famname}, {T}: refused / population. keep = ordinary starts, positive penalty, within target or undecided, tol 1e-7 or 1e-4",
                  ["rule", "c", "keep (fixtures)", "keep (generated)", "keep, tol < eps(T)", "above target and E>p thr"] + mechs +
                  ["not above target, E>p thr", "smallest j escaping"], lines)

    # ---- distribution of the q statistics on the must-keep population, for the choice of a floor
    for famname in ("scalar", "group"):
        for T in ("Float32", "Float64"):
            keep = [d for r, d in conv if fam(r) == famname and d["T"] == T and d["rel"] and d["resp"] > 0 and d["ordinary"] and d["positive"] and d["cls"] != "above"]
            if not keep:
                continue
            lines = []
            for label, f in (("Aq", lambda d: d["Aq"]), ("Aq0", lambda d: d["Aq0"]), ("Bq", lambda d: d["Bq"]), ("Cuq", lambda d: d["Cuq"]),
                             ("Rimg/(eps resp)", lambda d: d["Rimg"] / (d["eps"] * d["resp"])), ("Rinit/(eps resp)", lambda d: d["Rinit"] / (d["eps"] * d["resp"])),
                             ("dres/(eps resp)", lambda d: d["dres"] / (d["eps"] * d["resp"])),
                             ("P/(eps resp)", lambda d: d["P"] / (d["eps"] * d["resp"])), ("(P0+eps path)/(eps resp)", lambda d: pi(d) / (d["eps"] * d["resp"])),
                             ("path/resp", lambda d: d["path"] / d["resp"]), ("E/thr", lambda d: d["Ethr"])):
                v = sorted(x for x in (f(d) for d in keep) if not math.isnan(x))
                if not v:
                    continue
                q = lambda a: v[min(len(v) - 1, int(a * len(v)))]
                lines.append([label, len(v), f"{q(0.5):.3g}", f"{q(0.9):.3g}", f"{q(0.99):.3g}", f"{q(0.999):.3g}", f"{v[-1]:.3g}"])
            table(f"T3. Statistics on the must-keep population (all tol), {famname}, {T}", ["statistic", "n", "median", "90%", "99%", "99.9%", "max"], lines)


main()
