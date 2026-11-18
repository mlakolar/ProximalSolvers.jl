import csv,collections,statistics as st,sys
def load(f): return list(csv.DictReader(open('out/'+f+'.tsv'),delimiter='\t'))
def q(v,p): v=sorted(v); return v[min(len(v)-1,int(p*len(v)))] if v else float('nan')
C=[('A1 zero-compare','A1_113'),('A2 zero-restart','A2_113'),('B best-pair','B113'),('C 1 dir-step x8','C113'),('C multi 30x8','Cm113'),('C multi 100x100','Cm_big'),('E lambda-path','E113'),('D smooth, prod cert','L1'),('D2 smooth+dual bank','K7')]
out=[]
P=out.append
P('TABLE 1: all triggered runs (uncertified stage-1 stop), Julia 1.13, matrix of 948 runs (763 triggered: F64 386, F32 377)')
P('%-20s %-3s %5s | %5s %5s %5s %5s | base155->optimal | base156->(cert / same / moved / bad)'%('candidate','T','trig','cert','optU','nonop','FALSE'))
for name,f in C:
    rows=[r for r in load(f) if r['trig']=='true']
    for T in ('Float64','Float32'):
        v=[r for r in rows if r['T']==T]
        c=collections.Counter(r['final_class'] for r in v)
        b155=[r for r in v if r['base_class']=='nonoptimal']; b156=[r for r in v if r['base_class']=='optimal-uncert']
        ok155=sum(r['final_class'] in('certified','optimal-uncert') for r in b155)
        c156=collections.Counter()
        for r in b156:
            if r['final_class']=='certified': c156['cert']+=1
            elif r['final_class']=='optimal-uncert': c156['same' if abs(float(r['excess'])-float(r['base_excess']))<=1e-12 else 'moved']+=1
            else: c156['bad']+=1
        P('%-20s %-3s %5d | %5d %5d %5d %5d | %3d/%3d          | %d / %d / %d / %d  (n=%d)'%(name,T[-2:],len(v),c['certified'],c['optimal-uncert'],c['nonoptimal'],c['FALSE-CERT'],ok155,len(b155),c156['cert'],c156['same'],c156['moved'],c156['bad'],len(b156)))
P('')
P('TABLE 2: cost of the fallback on triggered runs (passes = all production/stage passes of the fallback; escape-only candidates add dirlasso passes), wall time and allocation (fallback only)')
P('%-20s %-3s | passes med p90 max | ratio to stage-1 passes med | esc/stages med max | sec med max | MB med max'%('candidate','T'))
for name,f in C:
    rows=[r for r in load(f) if r['trig']=='true']
    for T in ('Float64','Float32'):
        v=[r for r in rows if r['T']==T]
        ps=[int(r['escpasses'])+int(r['respasses']) for r in v]
        ratio=[(int(r['escpasses'])+int(r['respasses']))/max(1,int(r['base_passes'])) for r in v]
        es=[int(r['esc']) for r in v]; sec=[float(r['fb_seconds']) for r in v]; mb=[float(r['fb_bytes'])/1e6 for r in v]
        P('%-20s %-3s | %6d %6d %7d | %8.1f | %2d %3d | %.4f %.3f | %.2f %.1f'%(name,T[-2:],st.median(ps),q(ps,.9),max(ps),st.median(ratio),st.median(es),max(es),st.median(sec),max(sec),st.median(mb),max(mb)))
P('')
P('TABLE 3: D2 (K7: c0=0.3,q=0.2,J=8) and D (L1) by family, F64/F32 certified of triggered; untriggered rows by family')
for f in ('K7','L1'):
    rows=load(f); P(f)
    g=collections.defaultdict(lambda: collections.Counter())
    for r in rows:
        key=r['family'][:26]+' '+r['T'][-2:]
        g[key]['trig' if r['trig']=='true' else 'untrig']+=1
        if r['trig']=='true': g[key][r['final_class']]+=1
    for k in sorted(g): P('  %-32s %s'%(k,dict(g[k])))
P('')
P('TABLE 4: oracle-start experiment (start = oracle optimum rounded to T, exact-fit optima only; stage 1 = production CD)')
for name,f in [('A2','O_A2'),('B','O_B'),('C multi','O_Cm'),('E','O_E'),('D prod cert (c0=.1,q=.3,J=20)','O_D'),('D (L1 cfg)','O_L1'),('D2 (K7 cfg)','O_K7')]:
    rows=load(f)
    for T in ('Float64','Float32'):
        v=[r for r in rows if r['T']==T]
        c=collections.Counter(r['final_class'] for r in v); b=collections.Counter(r['base_class'] for r in v)
        same=sum(abs(float(r['excess'])-float(r['base_excess']))<=1e-12 for r in v)
        P('%-30s %-3s runs=%3d base=%s final=%s  excess unchanged (|Δ|≤1e-12) in %d, max final excess %.1e'%(name,T[-2:],len(v),dict(b),dict(c),same,max(float(r['excess']) for r in v)))
print('\n'.join(out)); open('out/tables.txt','w').write('\n'.join(out)+'\n')
