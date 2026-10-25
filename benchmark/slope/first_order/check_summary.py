"""Reject missing, inconsistent and unsuccessful evidence as speed wins."""
import contextlib
import csv
import io
import math
import tempfile
from pathlib import Path
from summarize import FIELDS,analyze,expected,identity,paired

assert [len(expected(p)) for p in ("canary","main","confirmation")]==[32,576,256]
def row(seed,method,valid,seconds):
    return dict(n=1000,p=2000,rho=.9,sparsity=10,weights="bh",seed=seed,round=1,method=method,valid=str(valid).lower(),seconds=seconds)
methods=[row(i,"native_fista_none",a,6) for i,(a,b) in enumerate(((True,True),(True,False),(False,True),(False,False)),1)]
bases=[row(i,"SLOPE.jl",b,2) for i,(a,b) in enumerate(((True,True),(True,False),(False,True),(False,False)),1)]
index={identity(r):r for r in methods+bases};p=paired(methods,index,"SLOPE.jl")
assert p["median_ratio"]==3 and all(p[k]==1 for k in ("both_valid","method_only","baseline_only","unresolved"))

with tempfile.TemporaryDirectory() as temporary:
    root=Path(temporary);calls=[];levels=[];profiles=[]
    for key in sorted(expected("main")):
        prefix=dict(zip(FIELDS,key))
        r=prefix|dict(seconds=1,julia_bytes=0,valid="true",status="target",returned=12,max_gap=0,
                      passes=1,iterations=2,grad_calls=3,prox_calls=4,certificate_calls=5,restarts=0,backtracks=4)
        calls.append(r)
        for k in range(1,13):
            levels.append(prefix|dict(level=k,alpha=math.exp(math.log(.05)*(k-1)/11),valid="true",gap=0,
                                     primal=1,dual=1,feasibility=1,fixedpoint=0,passes=1))
        if key[-1]=="APG_workspace_L":
            profiles.append(prefix|dict(plain_seconds=1,profile_seconds=1.01,valid="true",exact_match="true",
                iterations=2,grad_calls=3,prox_calls=4,certificate_calls=5,restarts=0,backtracks=4,
                gradient_ns=20,prox_ns=5,trial_loss_ns=20,update_ns=50,certificate_ns=10,setup_ns=5,total_ns=100))
    def write(kind,rows):
        with (root/f"{kind}-1.csv").open("w") as h:
            w=csv.DictWriter(h,fieldnames=list(rows[0]),lineterminator="\n");w.writeheader();w.writerows(rows)
    def attempt(cs,ls,ps):
        for k,v in (("calls",cs),("levels",ls),("profiles",ps)):write(k,v)
        with contextlib.redirect_stdout(io.StringIO()):return analyze(root,"main",root/"out")
    assert attempt(calls,levels,profiles)["profile_pairs"]==72
    for cs,ls,ps in ((calls[:-1],levels,profiles),(calls+[calls[0]],levels,profiles),
                     (calls,levels[:-1],profiles),(calls,levels,profiles[:-1]),
                     (calls,levels,[dict(profiles[0],exact_match="false")]+profiles[1:]),
                     (calls,levels,[dict(profiles[0],iterations=3)]+profiles[1:]),
                     (calls,levels,[dict(profiles[0],update_ns=1)]+profiles[1:]),
                     (calls,[dict(levels[0],valid="false")]+levels[1:],profiles)):
        try:attempt(cs,ls,ps)
        except AssertionError:pass
        else:raise AssertionError("invalid evidence accepted")
print("FIRST_ORDER_SUMMARY_CHECKS_PASSED")
