import csv,sys,collections,statistics as st
def q(v,p): v=sorted(v); return v[min(len(v)-1,int(p*len(v)))]
print('%-8s %-4s %5s %5s %5s %5s | stages med/p90/max | passes med/p90/max | sec med/max | MB med/max'%('file','T','n','cert','optU','nonopt'))
for f in sys.argv[1:]:
    rows=[r for r in csv.DictReader(open(f),delimiter='\t') if r['trig']=='true']
    for T in ('Float64','Float32'):
        v=[r for r in rows if r['T']==T]
        c=collections.Counter(r['final_class'] for r in v)
        s=[int(r['esc']) for r in v]; p=[int(r['escpasses']) for r in v]; t=[float(r['fb_seconds']) for r in v]; b=[float(r['fb_bytes'])/1e6 for r in v]
        print('%-8s %-4s %5d %5d %5d %5d | %3d %3d %3d | %6d %6d %6d | %.4f %.3f | %.2f %.1f'%(f.split('/')[-1][:-4],T[-2:],len(v),c['certified'],c['optimal-uncert'],c['nonoptimal']+c['FALSE-CERT'],st.median(s),q(s,.9),max(s),st.median(p),q(p,.9),max(p),st.median(t),max(t),st.median(b),max(b)))
