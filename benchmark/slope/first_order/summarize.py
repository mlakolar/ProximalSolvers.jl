"""Complete-grid, failure-aware comparisons and exact-replay phase summaries."""
import argparse
import collections
import csv
import itertools
import json
import math
import statistics
from pathlib import Path

METHODS=("APG_workspace_L","SLOPE.jl","native_pgd_none","native_pgd_strong",
         "native_fista_none","native_fista_strong","native_hybrid_none","native_hybrid_strong")
FIELDS=("n","p","rho","sparsity","weights","seed","round","method")

def identity(r):
    return (int(r["n"]),int(r["p"]),float(r["rho"]),int(r["sparsity"]),
            r["weights"],int(r["seed"]),int(r["round"]),r["method"])

def expected(phase):
    n,p,seeds,rounds,sparsities=(80,120,[0],[1],[10]) if phase=="canary" else (
        (1000,2000,range(1,4),range(1,4),[10,100]) if phase=="main" else
        (1000,2000,[11,12],[1,2],[10,100]))
    return {(n,p,*v) for v in itertools.product((0.,.9),sparsities,("linear","bh"),seeds,rounds,METHODS)}

def read(root,kind):
    rows=[]
    for file in sorted(root.glob(f"{kind}-*.csv")):
        with file.open() as f:rows.extend(csv.DictReader(f))
    return rows

def paired(rows,index,baseline):
    outcomes=collections.Counter();ratios=[]
    for r in rows:
        b=index[identity(r)[:-1]+(baseline,)]
        good,base=r["valid"]=="true",b["valid"]=="true"
        label="both_valid" if good and base else "method_only" if good else "baseline_only" if base else "unresolved"
        outcomes[label]+=1
        if good and base:ratios.append(float(r["seconds"])/float(b["seconds"]))
    return dict(pairs=len(rows),**{k:outcomes[k] for k in ("both_valid","method_only","baseline_only","unresolved")},
                median_ratio=statistics.median(ratios) if ratios else None)

def analyze(root,phase,out):
    calls,levels,profiles=(read(root,k) for k in ("calls","levels","profiles"))
    index={};points={};replays={}
    for r in calls:
        key=identity(r);assert key not in index,("duplicate call",key);index[key]=r
        if r["valid"]=="true":
            assert int(r["returned"])==12 and r["status"]=="target"
            assert math.isfinite(float(r["seconds"])) and float(r["seconds"])>0
            assert 0<=float(r["max_gap"])<=1e-6
    assert set(index)==expected(phase),("call coverage",len(index))
    for r in levels:
        key=identity(r)+(int(r["level"]),);assert key not in points,("duplicate point",key);points[key]=r
        if r["valid"]=="true":
            assert 0<=float(r["gap"])<=1e-6 and float(r["feasibility"])<=1+1e-12
            assert all(math.isfinite(float(r[f])) for f in ("primal","dual","fixedpoint"))
    assert set(points)=={key+(k,) for key in index for k in range(1,13)},"point coverage"
    for key,r in index.items():
        rows=[points[key+(k,)] for k in range(1,13)]
        a=float(rows[0]["alpha"]);assert a>0
        assert all(math.isclose(float(x["alpha"])/a,math.exp(math.log(.05)*i/11),rel_tol=1e-12) for i,x in enumerate(rows))
        assert all(float(points[key[:-1]+(m,i+1)]["alpha"])==float(x["alpha"]) for i,x in enumerate(rows) for m in METHODS)
        assert (r["valid"]=="true")==all(x["valid"]=="true" for x in rows),"path/point validity mismatch"
        if r["valid"]=="true":assert float(r["max_gap"])==max(float(x["gap"]) for x in rows)
    for r in profiles:
        key=identity(dict(r,method="APG_workspace_L"))
        assert key not in replays,("duplicate replay",key);replays[key]=r
        assert r["valid"]==r["exact_match"]=="true"
        assert all(float(r[f])>0 and math.isfinite(float(r[f])) for f in ("plain_seconds","profile_seconds"))
        assert all(int(r[f])>=0 for f in ("gradient_ns","prox_ns","trial_loss_ns","update_ns","certificate_ns","setup_ns","total_ns"))
        assert int(r["gradient_ns"])+int(r["prox_ns"])+int(r["trial_loss_ns"])<=int(r["update_ns"])
        assert int(r["update_ns"])+int(r["certificate_ns"])+int(r["setup_ns"])<=int(r["total_ns"])
        for f in ("iterations","grad_calls","prox_calls","certificate_calls","restarts","backtracks"):
            assert int(r[f])==int(index[key][f]),("replay/comparison counter mismatch",key,f)
    wanted={k for k in index if k[-1]=="APG_workspace_L"} if phase!="confirmation" else set()
    assert set(replays)==wanted,("replay coverage",len(replays),len(wanted))
    comparisons=[];strata=[];screening=[]
    for rho,method in itertools.product((0.,.9),METHODS):
        rows=[r for r in calls if float(r["rho"])==rho and r["method"]==method]
        good=[r for r in rows if r["valid"]=="true"]
        entry=dict(rho=rho,method=method,paths=len(rows),valid=len(good),success_rate=len(good)/len(rows))
        for baseline in ("APG_workspace_L","SLOPE.jl","native_fista_none","native_hybrid_strong"):
            entry["vs_"+baseline]=paired(rows,index,baseline)
        for field in ("seconds","passes","iterations","julia_bytes","grad_calls","prox_calls","certificate_calls","restarts","backtracks"):
            values=[float(r[field]) for r in good if float(r[field])>=0]
            entry["median_"+field]=statistics.median(values) if values else None
        comparisons.append(entry)
        for sparsity,weights in itertools.product(sorted({int(r["sparsity"]) for r in rows}),("linear","bh")):
            group=[r for r in rows if int(r["sparsity"])==sparsity and r["weights"]==weights]
            strata.append(dict(rho=rho,sparsity=sparsity,weights=weights,method=method,
                               vs_apg=paired(group,index,"APG_workspace_L"),vs_library=paired(group,index,"SLOPE.jl")))
    for rho,solver in itertools.product((0.,.9),("pgd","fista","hybrid")):
        rows=[r for r in calls if float(r["rho"])==rho and r["method"]==f"native_{solver}_strong"]
        screening.append(dict(rho=rho,solver=solver,strong_vs_none=paired(rows,index,f"native_{solver}_none")))
    phase_profiles=[]
    for rho in (0.,.9):
        rows=[r for r in profiles if float(r["rho"])==rho]
        if not rows:continue
        fractions=collections.defaultdict(list)
        for r in rows:
            ns={k:int(r[k+"_ns"]) for k in ("gradient","prox","trial_loss","update","certificate","setup","total")}
            ns["remaining_update"]=ns["update"]-ns["gradient"]-ns["prox"]-ns["trial_loss"]
            ns["remaining_path"]=ns["total"]-ns["update"]-ns["certificate"]-ns["setup"]
            for k in ("gradient","prox","trial_loss","remaining_update","certificate","setup","remaining_path"):
                fractions[k].append(ns[k]/ns["total"])
        phase_profiles.append(dict(rho=rho,paths=len(rows),all_exact_replays=True,
            median_instrumented_over_plain=statistics.median(float(r["profile_seconds"])/float(r["plain_seconds"]) for r in rows),
            median_fractions={k:statistics.median(v) for k,v in fractions.items()}))
    coverage=dict(phase=phase,paths=len(calls),valid_paths=sum(r["valid"]=="true" for r in calls),
                  points=len(levels),valid_points=sum(r["valid"]=="true" for r in levels),profile_pairs=len(profiles),
                  decision="Defer hybrid unless it adds useful capability beyond matching libslope; no speed-ratio acceptance gate")
    out.mkdir(parents=True,exist_ok=True)
    for name,data in (("coverage",coverage),("comparisons",comparisons),("screening",screening),("profiles",phase_profiles),("strata",strata)):
        (out/(name+".json")).write_text(json.dumps(data,indent=2,allow_nan=False)+"\n")
    print(json.dumps(coverage,indent=2));return coverage

if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("root",type=Path);p.add_argument("--phase",choices=("canary","main","confirmation"),required=True);p.add_argument("--out",type=Path,required=True)
    a=p.parse_args();analyze(a.root,a.phase,a.out)
