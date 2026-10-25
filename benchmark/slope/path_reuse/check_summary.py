"""Keep missing paths and scientific failures out of speed wins."""
from summarize import expected,paired,identity

assert len(expected("main"))==720
assert len(expected("confirmation"))==288
def row(seed,method,valid,seconds):
    return dict(n=1000,p=2000,rho=.9,sparsity=10,weights="bh",seed=seed,round=1,method=method,valid=str(valid).lower(),seconds=seconds)
methods=[row(i,"workspace_L",a,6) for i,(a,b) in enumerate(((True,True),(True,False),(False,True),(False,False)),1)]
baselines=[row(i,"SLOPE.jl",b,2) for i,(a,b) in enumerate(((True,True),(True,False),(False,True),(False,False)),1)]
index={identity(r):r for r in methods+baselines};s=paired(methods,index,"SLOPE.jl")
assert s["median_ratio"]==3 and s["pairs"]==4
assert all(s[k]==1 for k in ("both_valid","method_only","baseline_only","unresolved"))
print("PATH_REUSE_SUMMARY_CHECKS_PASSED")
