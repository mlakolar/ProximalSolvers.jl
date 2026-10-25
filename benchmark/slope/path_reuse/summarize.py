"""Complete-grid and failure-aware analysis of the focused path handoffs."""
import argparse
import collections
import csv
import itertools
import json
import math
import statistics
from pathlib import Path

METHODS=("reset","carry_L","workspace_reset","workspace_L","full_state","SLOPE.jl")
FIELDS=("n","p","rho","sparsity","weights","seed","round","method")

def identity(row):
    return (int(row["n"]),int(row["p"]),float(row["rho"]),int(row["sparsity"]),
            row["weights"],int(row["seed"]),int(row["round"]),row["method"])

def expected(phase):
    seeds,rounds=(range(1,6),range(1,4)) if phase=="main" else (range(8,11),range(1,3))
    return {(1000,2000,*x) for x in itertools.product((0.,.9),(10,100),("linear","bh"),seeds,rounds,METHODS)}

def read(root,kind):
    rows=[]
    for path in sorted(root.glob(f"{kind}-*.csv")):
        with path.open() as h:rows.extend(csv.DictReader(h))
    return rows

def paired(rows,index,baseline):
    outcomes=collections.Counter();ratios=[]
    for r in rows:
        b=index[identity(r)[:-1]+(baseline,)]
        good=r["valid"]=="true";base=b["valid"]=="true"
        outcome="both_valid" if good and base else "method_only" if good else "baseline_only" if base else "unresolved"
        outcomes[outcome]+=1
        if good and base:ratios.append(float(r["seconds"])/float(b["seconds"]))
    return {"pairs":len(rows),**{k:outcomes[k] for k in ("both_valid","method_only","baseline_only","unresolved")},
            "median_ratio":statistics.median(ratios) if ratios else None}

def analyze(root,phase,out):
    calls,levels=read(root,"calls"),read(root,"levels");index={};points={}
    for r in calls:
        key=identity(r);assert key not in index,("duplicate call",key);index[key]=r
        if r["valid"]=="true":
            assert int(r["returned"])==12
            assert math.isfinite(float(r["seconds"])) and float(r["seconds"])>0
            assert 0<=float(r["max_gap"])<=1e-6
    assert set(index)==expected(phase),("call coverage",len(index))
    for r in levels:
        key=identity(r)+(int(r["level"]),);assert key not in points,("duplicate point",key);points[key]=r
        if r["valid"]=="true":
            assert math.isfinite(float(r["gap"])) and 0<=float(r["gap"])<=1e-6
            assert float(r["feasibility"])<=1+1e-12
            assert math.isfinite(float(r["fixedpoint"]))
    assert set(points)=={key+(k,) for key in index for k in range(1,13)},"point coverage"
    for key,r in index.items():
        rs=[points[key+(k,)] for k in range(1,13)]
        first_alpha=float(rs[0]["alpha"])
        assert first_alpha>0 and all(math.isclose(float(x["alpha"])/first_alpha,
            math.exp(math.log(.05)*i/11),rel_tol=1e-12) for i,x in enumerate(rs)),("alpha path",key)
        assert all(float(points[key[:-1]+(m,k+1)]["alpha"])==float(x["alpha"])
                   for k,x in enumerate(rs) for m in METHODS),("different alpha grids",key)
        assert (r["valid"]=="true")==all(x["valid"]=="true" for x in rs),("path validity",key)
        if key[-1]=="SLOPE.jl":continue
        returned=[x for x in rs if x["status"]!="not_returned"]
        for i,x in enumerate(returned):
            if key[-1] in ("reset","workspace_reset"):assert float(x["initial_L"])==1
            elif i:assert float(x["initial_L"])==float(returned[i-1]["final_L"])
            if key[-1]=="full_state" and i:assert int(x["initial_k"])==int(returned[i-1]["final_k"])
            else:assert int(x["initial_k"])==0
    records=[];details=[]
    for rho,method in itertools.product((0.,.9),METHODS):
        rows=[r for r in calls if float(r["rho"])==rho and r["method"]==method]
        good=[r for r in rows if r["valid"]=="true"]
        entry={"rho":rho,"method":method,"paths":len(rows),"valid":len(good),"success_rate":len(good)/len(rows),
               "vs_reset":paired(rows,index,"reset"),"vs_library":paired(rows,index,"SLOPE.jl")}
        for field in ("seconds","julia_bytes","iterations","backtracks","restarts","f_calls","grad_calls","prox_calls","certificate_calls"):
            values=[float(r[field]) for r in good if float(r[field])>=0]
            entry["median_"+field]=statistics.median(values) if values else None
        records.append(entry)
        for sparsity,weights in itertools.product((10,100),("linear","bh")):
            group=[r for r in rows if int(r["sparsity"])==sparsity and r["weights"]==weights]
            details.append({"rho":rho,"sparsity":sparsity,"weights":weights,"method":method,
                            "vs_reset":paired(group,index,"reset"),"vs_library":paired(group,index,"SLOPE.jl")})
    correlated={r["method"]:r for r in records if r["rho"]==.9}
    primary=correlated["workspace_L"];lib=correlated["SLOPE.jl"]
    closing=[m for m in METHODS[1:5] if correlated[m]["success_rate"]>=.99 and
             correlated[m]["vs_library"]["both_valid"]>=.9*correlated[m]["paths"] and
             correlated[m]["vs_library"]["median_ratio"] is not None and
             correlated[m]["vs_library"]["median_ratio"]<3]
    ratio=primary["vs_library"]["median_ratio"]
    gate={"phase":phase,"paths":len(calls),"valid_paths":sum(r["valid"]=="true" for r in calls),
          "points":len(levels),"valid_points":sum(r["valid"]=="true" for r in levels),
          "primary_success_rate":primary["success_rate"],"library_success_rate":lib["success_rate"],
          "primary_remaining_library_ratio":ratio,"closing_variants":closing,
          "phase_gate":primary["success_rate"]>=.99 and lib["success_rate"]>=.99 and
             primary["vs_library"]["both_valid"]>=.9*primary["paths"] and ratio is not None and ratio>=3 and not closing,
          "confirmation_required":phase=="main"}
    out.mkdir(parents=True,exist_ok=True)
    for name,data in (("gate.json",gate),("comparisons.json",records),("details.json",details)):
        (out/name).write_text(json.dumps(data,indent=2,allow_nan=False)+"\n")
    print(json.dumps(gate,indent=2));return gate

if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("root",type=Path);p.add_argument("--phase",choices=("main","confirmation"),default="main");p.add_argument("--out",type=Path,required=True)
    a=p.parse_args();analyze(a.root,a.phase,a.out)
