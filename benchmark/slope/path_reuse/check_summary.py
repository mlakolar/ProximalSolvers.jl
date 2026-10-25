"""Keep missing paths and scientific failures out of speed wins."""
import contextlib,csv,io,tempfile
from pathlib import Path
from summarize import FIELDS,analyze,expected,paired,identity

assert len(expected("main"))==720
assert len(expected("confirmation"))==288
def row(seed,method,valid,seconds):
    return dict(n=1000,p=2000,rho=.9,sparsity=10,weights="bh",seed=seed,round=1,method=method,valid=str(valid).lower(),seconds=seconds)
methods=[row(i,"workspace_L",a,6) for i,(a,b) in enumerate(((True,True),(True,False),(False,True),(False,False)),1)]
baselines=[row(i,"SLOPE.jl",b,2) for i,(a,b) in enumerate(((True,True),(True,False),(False,True),(False,False)),1)]
index={identity(r):r for r in methods+baselines};s=paired(methods,index,"SLOPE.jl")
assert s["median_ratio"]==3 and s["pairs"]==4
assert all(s[k]==1 for k in ("both_valid","method_only","baseline_only","unresolved"))

with tempfile.TemporaryDirectory() as temporary:
    root=Path(temporary);calls=[];levels=[]
    for key in sorted(expected("main")):
        r=dict(zip(FIELDS,key))|dict(valid="true",seconds=2 if key[-1]=="SLOPE.jl" else 6,
            returned=12,max_gap=0,julia_bytes=0,iterations=1,backtracks=0,restarts=0,
            f_calls=1,grad_calls=1,prox_calls=1,certificate_calls=1)
        calls.append(r)
        for k in range(1,13):
            levels.append(dict(zip(FIELDS,key))|dict(level=k,valid="true",status="target",gap=0,
                feasibility=1,fixedpoint=0,initial_L=1,final_L=1,initial_k=0,final_k=0))
    def write(kind,rows):
        with (root/f"{kind}-1.csv").open("w") as h:
            w=csv.DictWriter(h,fieldnames=list(rows[0]),lineterminator="\n");w.writeheader();w.writerows(rows)
    def silent():
        with contextlib.redirect_stdout(io.StringIO()):return analyze(root,"main",root/"out")
    write("calls",calls);write("levels",levels)
    assert silent()["phase_gate"]
    for cs,ls in ((calls[:-1],levels),(calls+[calls[0]],levels),(calls,levels[:-1]),
                  (calls,[dict(levels[0],valid="false")]+levels[1:])):
        write("calls",cs);write("levels",ls)
        try:silent()
        except AssertionError:pass
        else:raise AssertionError("incomplete/duplicate/inconsistent evidence accepted")
print("PATH_REUSE_SUMMARY_CHECKS_PASSED")
