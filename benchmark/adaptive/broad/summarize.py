"""Complete-grid, failure-aware summary of the prospective adaPGM protocol."""
import argparse,csv,collections,json,math,statistics,random
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument("files",nargs="+");p.add_argument("--out",required=True);p.add_argument("--expected",type=int);p.add_argument("--phase",choices=("main","confirmation"),default="main");a=p.parse_args()
rows=[]
for file in a.files:
    with open(file) as h:rows.extend(csv.DictReader(h))
if a.expected is not None:assert len(rows)==a.expected,(len(rows),a.expected)
assert rows
identity=("family","p","kappa","seed","lambda_fraction","round","method","initialization")
seen=set()
for r in rows:
    key=tuple(r[k] for k in identity);assert key not in seen,key;seen.add(key)
    r["ok"]=r["valid"]=="true"
    assert float(r["seconds"])>=0
    if r["ok"]:assert math.isfinite(float(r["kkt"])) and float(r["kkt"])<=1e-6 and math.isfinite(float(r["gap"])) and float(r["gap"])<=1e-6
out=Path(a.out);out.mkdir(parents=True,exist_ok=True)
def clean(value):
    if isinstance(value,float) and not math.isfinite(value):return str(value)
    if isinstance(value,dict):return {k:clean(v) for k,v in value.items()}
    if isinstance(value,list):return [clean(v) for v in value]
    return value

def write(name,records,fields):
    with (out/name).open("w") as h:
        w=csv.DictWriter(h,fieldnames=fields,lineterminator="\n");w.writeheader();w.writerows(records)
keys=("family","p","kappa","method","initialization")
groups=collections.defaultdict(list)
for r in rows:groups[tuple(r[k] for k in keys)].append(r)
summary=[]
for key,rs in sorted(groups.items()):
    good=[r for r in rs if r["ok"]]
    summary.append(dict(zip(keys,key))|{"fits":len(rs),"valid":len(good),"success_rate":len(good)/len(rs),"median_valid_seconds":statistics.median(float(r["seconds"]) for r in good) if good else "", "statuses":json.dumps(dict(collections.Counter(r["status"] for r in rs)),sort_keys=True)})
write("strata.csv",summary,(*keys,"fits","valid","success_rate","median_valid_seconds","statuses"))

index={tuple(r[k] for k in identity):r for r in rows}
pairs=[]
for r in rows:
    if r["method"]!="adaPGM":continue
    key=tuple(r[k] for k in identity[:6])
    for base in ("APG","PG"):
        b=index.get(key+(base,"default"));assert b is not None,key
        if r["ok"] and b["ok"]:
            ratio=float(r["seconds"])/float(b["seconds"]);outcome="both_valid"
        elif r["ok"]:
            ratio=0.;outcome="adaptive_only"
        elif b["ok"]:
            ratio=math.inf;outcome="baseline_only"
        else:
            ratio=math.nan;outcome="unresolved"
        pairs.append({k:r[k] for k in identity[:6]}|{"initialization":r["initialization"],"baseline":base,"ratio":ratio,"outcome":outcome,"adaptive_valid":r["ok"],"baseline_valid":b["ok"]})
write("pairs.csv",pairs,(*identity[:6],"initialization","baseline","ratio","outcome","adaptive_valid","baseline_valid"))

def ratio_summary(rs):
    resolved=[r["ratio"] for r in rs if r["outcome"]!="unresolved"]
    finite=[r["ratio"] for r in rs if r["outcome"]=="both_valid"]
    return {"pairs":len(rs),"both_valid":len(finite),"adaptive_valid":sum(r["adaptive_valid"] for r in rs),"baseline_valid":sum(r["baseline_valid"] for r in rs),"unresolved":sum(r["outcome"]=="unresolved" for r in rs),"adaptive_only":sum(r["outcome"]=="adaptive_only" for r in rs),"baseline_only":sum(r["outcome"]=="baseline_only" for r in rs),"median_failure_aware_ratio":statistics.median(resolved) if resolved else None,"median_both_valid_ratio":statistics.median(finite) if finite else None}

primary=[r for r in pairs if r["initialization"]==("unit" if r["family"]=="quartic" else "reference")]
byfam=collections.defaultdict(list)
for r in primary:byfam[(r["family"],r["baseline"])].append(r)
report=[]
for (family,base),rs in sorted(byfam.items()):
    # Cluster bootstrap over seeds; each sampled seed brings its complete
    # dimension/conditioning/penalty/repetition block. Diagnostic CI only.
    seeds=sorted(set(r["seed"] for r in rs));byseed={s:[r for r in rs if r["seed"]==s] for s in seeds}
    rng=random.Random(81025);boot=[]
    for _ in range(1000):
        sampled=[r for seed in rng.choices(seeds,k=len(seeds)) for r in byseed[seed] if r["outcome"]!="unresolved"]
        if sampled:boot.append(statistics.median(r["ratio"] for r in sampled))
    boot.sort()
    d={"family":family,"baseline":base}|ratio_summary(rs)
    d["seed_bootstrap_median_ratio_95ci"]=[boot[int(.025*(len(boot)-1))],boot[int(.975*(len(boot)-1))]] if boot else None
    report.append(d)
(out/"primary.json").write_text(json.dumps(clean(report),indent=2,allow_nan=False)+"\n")

conditioning=[]
condition_groups=collections.defaultdict(list)
for r in primary:condition_groups[(r["family"],r["p"],r["kappa"],r["baseline"])].append(r)
for key,rs in sorted(condition_groups.items()):conditioning.append(dict(zip(("family","p","kappa","baseline"),key))|ratio_summary(rs))
(out/"conditioning.json").write_text(json.dumps(clean(conditioning),indent=2,allow_nan=False)+"\n")

allinit=[]
byinit=collections.defaultdict(list)
for r in pairs:byinit[(r["family"],r["initialization"],r["baseline"])].append(r)
for key,rs in sorted(byinit.items()):allinit.append(dict(zip(("family","initialization","baseline"),key))|ratio_summary(rs))
(out/"initializations.json").write_text(json.dumps(clean(allinit),indent=2,allow_nan=False)+"\n")
# Primary reliability uses each adaPGM fit once, not the duplicated PG/APG pairs.
pr=[r for r in rows if r["method"]=="adaPGM" and r["initialization"]==("unit" if r["family"]=="quartic" else "reference")]
rate=sum(r["ok"] for r in pr)/len(pr)
candidates=[r["family"] for r in report if r["baseline"]=="APG" and r["median_failure_aware_ratio"] is not None and r["median_failure_aware_ratio"]<=.8 and r["adaptive_valid"]>=.99*r["pairs"]]
result={"phase":a.phase,"rows":len(rows),"valid":sum(r["ok"] for r in rows),"primary_fits":len(pr),"primary_valid":sum(r["ok"] for r in pr),"primary_success_rate":rate,"candidate_families":candidates,"main_gate":rate>=.99 and len(candidates)>=2,"fresh_seed_confirmation_required":a.phase=="main"}
(out/"gate.json").write_text(json.dumps(result,indent=2)+"\n")
print(json.dumps(result,indent=2))
for r in report:print(r)
