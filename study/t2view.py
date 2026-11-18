import sys
f, fam = sys.argv[1], sys.argv[2]
cs = ["0", "4", "16", "64", "256", "1024"]
for T in ("Float32", "Float64"):
    on = False; data = {}; pops = None
    for l in open(f):
        l = l.rstrip("\n")
        if l.startswith(f"T2. Rules, {fam}, {T}"): on = True; continue
        if on and l.startswith("T") and not l.startswith("T2. Rules, " + fam + ", " + T) and l[1:2].isdigit(): on = False
        if not on: continue
        c = l.split("\t")
        if len(c) < 10 or c[0] == "rule": continue
        data.setdefault(c[0], {})[c[1]] = c
    print(f"== {fam} {T}: cells are must-keep refused (fixtures+generated) | above-target and E>p thr refused | smallest j escaping")
    first = next(iter(data.values()))["0"]
    kc, kv = first[2].split("/")[1], first[3].split("/")[1]
    print(f"   populations: keep {kc}+{kv}, bad {first[5].split('/')[1]}, of which empty-pass {first[7].split('/')[1]}, moving {first[8].split('/')[1]}")
    print("rule".ljust(44) + "".join(("c=" + c).ljust(22) for c in cs))
    for rn, d in data.items():
        print(rn[:43].ljust(44) + "".join((str(int(d[c][2].split('/')[0]) + int(d[c][3].split('/')[0])) + " | " + d[c][5].split('/')[0] + " | " + d[c][-1]).ljust(22) for c in cs))
