"""Summarize common-target results without discarding failed fits."""
import argparse,csv,collections,statistics,math,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument("files",nargs="+");p.add_argument("--out",required=True);a=p.parse_args()
rows=[]
for f in a.files:
    with open(f) as h: rows.extend(csv.DictReader(h))
assert rows and all(float(r["seconds"])>=0 for r in rows)
for r in rows:
    r["ok"]=r["valid"]=="true"
    if r["ok"]: assert math.isfinite(float(r["error"])) and float(r["error"])<=1e-6
keys=("track","family","p","mode","lambda","method","gamma0")
groups=collections.defaultdict(list)
for r in rows:groups[tuple(r[k] for k in keys)].append(r)
out=Path(a.out);out.mkdir(parents=True,exist_ok=True)
with (out/"summary.csv").open("w") as h:
    w=csv.writer(h,lineterminator="\n");w.writerow((*keys,"returned","valid","median_valid_seconds","median_valid_error","max_rejections"))
    for k,rs in sorted(groups.items()):
        good=[r for r in rs if r["ok"]]
        med=lambda field:statistics.median(float(r[field]) for r in good) if good else math.nan
        w.writerow((*k,len(rs),len(good),med("seconds"),med("error"),max(int(r["domain_rejections"]) for r in rs)))
# Per-instance paired ratios; adaptive initial-step sweeps reuse the baseline
# gamma0=1 fit with identical seed, round, family, dimension and path position.
index={(r["track"],r["family"],r["p"],r["seed"],r["round"],r["mode"],r["level"],r["lambda"],r["method"],r["gamma0"]):r for r in rows}
pairs=[]
for r in rows:
    if r["method"] not in ("PANOCplus","adaPGM","MM"):continue
    for base in (("APG","QUIC") if r["track"]=="panocplus" else ("PG","APG")):
        key=tuple(r[k] for k in ("track","family","p","seed","round","mode","level","lambda"))+(base,"1.0")
        b=index.get(key)
        if b is None:continue
        ratio=float(r["seconds"])/float(b["seconds"]) if r["ok"] and b["ok"] else math.nan
        pairs.append({k:r[k] for k in ("track","family","p","seed","round","mode","level","lambda","method","gamma0")}|{"baseline":base,"valid_pair":math.isfinite(ratio),"ratio":ratio})
with (out/"paired.csv").open("w") as h:
    w=csv.DictWriter(h,fieldnames=list(pairs[0]),lineterminator="\n");w.writeheader();w.writerows(pairs)
stats=collections.defaultdict(list)
for r in pairs:stats[(r["track"],r["family"],r["method"],r["baseline"],r["gamma0"])].append(r)
report=[]
for k,rs in sorted(stats.items()):
    good=[r["ratio"] for r in rs if r["valid_pair"]]
    report.append(dict(zip(("track","family","method","baseline","gamma0"),k))|{"pairs":len(rs),"valid_pairs":len(good),"median_ratio":statistics.median(good) if good else None,"min_ratio":min(good) if good else None,"max_ratio":max(good) if good else None})
(out/"ratios.json").write_text(json.dumps(report,indent=2)+"\n")
print("Rows:",len(rows),"valid:",sum(r["ok"] for r in rows))
print("Status counts:",dict(collections.Counter((r["track"],r["family"],r["method"],r["status"]) for r in rows)))
for r in report:print(r)
