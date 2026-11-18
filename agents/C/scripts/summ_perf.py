import csv,sys,collections,statistics as st
rows=[]
for f in sys.argv[1:]:
    for r in csv.DictReader(open(f),delimiter='\t'):
        r['f']=f; rows.append(r)
cells=collections.OrderedDict()
for r in rows: cells.setdefault((r['problem'],r['T'],r['cfg']),[]).append(r)
def ratio_stats(cell, num, den):
    # per (file,rep): mean time of num copies / mean time of den copies
    by=collections.defaultdict(dict)
    for r in cell: by[(r['f'],r['rep'])][r['variant']]=float(r['seconds_per_solve'])
    out=[]
    for k,d in by.items():
        out.append(st.mean(d[v] for v in num)/st.mean(d[v] for v in den))
    return out
print("ratio = mean over copies of variant / mean over copies of {old,ctl} in the same interleaved repetition; median IQR over %d repetitions (2 processes pooled)"%len(set((r['f'],r['rep']) for r in rows)))
print("%-20s %-7s %-8s %6s %6s | %-24s | %-24s | %-24s | %-24s"%("problem","T","cfg","passes","K","A/A ctl/old","(i) v1,v1b/old,ctl","(ii) v2,v2b/old,ctl","copy spread v1/v1b | v2/v2b"))
for k,c in cells.items():
    a=ratio_stats(c,['ctl'],['old']); i=ratio_stats(c,['v1','v1b'],['old','ctl']); ii=ratio_stats(c,['v2','v2b'],['old','ctl'])
    s1=ratio_stats(c,['v1'],['v1b']); s2=ratio_stats(c,['v2'],['v2b'])
    q=lambda x,a: sorted(x)[int(a*(len(x)-1))]
    f=lambda x: "%.3f IQR[%.3f,%.3f]"%(st.median(x),q(x,.25),q(x,.75))
    print("%-20s %-7s %-8s %6s %6s | %s | %s | %s | %s | %s"%(k[0],k[1],k[2],c[0]['passes'],c[0]['K'],f(a),f(i),f(ii),"%.3f"%st.median(s1),"%.3f"%st.median(s2)))
