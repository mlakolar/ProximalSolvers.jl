import csv,sys,glob,collections,os
def load(fn):
    with open(fn) as f: return list(csv.DictReader(f,delimiter='\t'))
pat=sys.argv[1]
allruns=collections.Counter()
for fn in sorted(glob.glob(pat)):
    rows=load(fn)
    st=[int(r['stall']) for r in rows]; P=[float(r['P64']) for r in rows]; gap=[float(r['gap']) for r in rows]
    ul=[float(r['dx_ulps']) for r in rows]
    runs=[];c=0
    for s in st:
        if s: c+=1
        else:
            if c: runs.append(c)
            c=0
    if c: runs.append(c)
    allruns.update(runs)
    k1=next((i+1 for i,s in enumerate(st) if s),None)
    khit=next((i+1 for i,g in enumerate(gap) if g<=1e-5),None)
    Pabs=abs(P[-1])
    best=P[0]; last={}
    for thr in (1e-6,1e-8,1e-10,0):
        best=float('inf'); lk=0
        for i,p in enumerate(P):
            if p < best - thr*Pabs: lk=i+1
            best=min(best,p)
        last[thr]=lk
    # max ulps after first stall
    mu=max(ul[k1:]) if k1 else None
    # tiny streak: first k at which K consecutive iterations had dx<=1 ulp
    print(os.path.basename(fn), "k1stall",k1,"khit",khit,"last>1e-6",last[1e-6],"last>1e-8",last[1e-8],"last>1e-10",last[1e-10],"last>0",last[0],
          "maxrun",max(runs) if runs else 0,"nruns",len(runs),"maxulps_after_stall",mu,"gapmax_after_k1 %.2e"%max(gap[k1:]),"Pbest-Pk1 %.2e"%((min(P)-P[k1-1])/Pabs))
print("run length histogram:",sorted(allruns.items()))
