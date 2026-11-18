import csv,collections,sys,statistics as st
ver=sys.argv[1]
rows=list(csv.DictReader(open(f'exp3_rows_{ver}.tsv'),delimiter='\t'))
by=collections.defaultdict(dict)
for r in rows: by[(r['T'],r['kind'],r['n'],r['p'],r['lf'],r['cfg'])][r['tree']]=r
def q(v):
    if not v: return 'n/a'
    v=sorted(v); n=len(v)
    return ' / '.join('%.3g'%v[min(n-1,int(p*(n-1)+0.5))] for p in (0,.5,.9,1))
def grp(name,filt):
    ks=[k for k in by if filt(k,by[k])]
    rel=[];dg=[];dp=[];ex=0;conv=0
    for k in ks:
        b,x=by[k]['base'],by[k]['x1b']
        mb,mx=float(b['minimum']),float(x['minimum'])
        r=abs(mx-mb)/abs(mb) if mb else abs(mx)
        rel.append(r); ex+= (r==0)
        if b['gap']!='NaN' and x['gap']!='NaN': dg.append(float(x['gap'])-float(b['gap']))
        dp.append(int(x['passes'])-int(b['passes']))
        conv+= b['conv']!=x['conv']
    print(f"{name}: n={len(ks)}; obj rel diff (min/med/90%/max) {q(rel)}, exactly equal {ex}; gap diff (x1b-base) {q(dg)}; passes diff {q(dp)} with {sum(1 for d in dp if d)} nonzero; |passes diff|>5: {sum(1 for d in dp if abs(d)>5)}; converged changes {conv}")
for T in ('Float32','Float64'):
    grp(T+' certified in BASE', lambda k,v: k[0]==T and v['base']['conv']=='true')
    grp(T+' certified, gauss/corr', lambda k,v: k[0]==T and v['base']['conv']=='true' and k[1] in('gauss','corr'))
    grp(T+' uncertified in BASE', lambda k,v: k[0]==T and v['base']['conv']=='false')
    grp(T+' uncertified, kinds', lambda k,v: k[0]==T and v['base']['conv']=='false')
c=collections.Counter((k[0],k[1],by[k]['base']['conv']) for k in by if by[k]['base']['conv']=='false'); print('uncertified (u) by type/kind:',dict(c))
