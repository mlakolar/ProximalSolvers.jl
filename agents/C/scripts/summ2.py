import csv,sys,glob,re,collections
for v in ['fix1','trk1','fix1h','trkh']:
    rows=list(csv.DictReader(open(f'stress2_{v}_all.tsv'),delimiter='\t'))
    for T in ['Float64','Float32']:
        f=[r for r in rows if r['T']==T and r['fired']=='true']
        c=[r for r in f if r['certified']=='true']
        nc=[r for r in f if r['certified']!='true']
        st=sorted(int(r['nstages']) for r in c)
        print(f"{v:6s} {T:7s} fired={len(f):3d} certified={len(c):3d} med_stages={st[len(st)//2] if st else None} max_stages={max(st) if st else None} max_passes={max((int(r['passes']) for r in f),default=0)}  max_excess_cert={max((float(r['ret_excess']) for r in c),default=0):.1e}")
        for r in nc: print("      UNCERT",r['id'],r['start'],"ratio=%s excess=%s nnz=%s n=%s Pst/P*=%.3g"%(r['ret_ratio'][:9],r['ret_excess'][:9],r['ret_nnz'],r['n'],float(r['Pstuck_over_Pstar'])))
