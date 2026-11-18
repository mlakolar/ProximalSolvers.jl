import csv,sys,collections
rows=list(csv.DictReader(open(sys.argv[1]),delimiter='\t'))
g=collections.OrderedDict()
for r in rows: g.setdefault((r['id'],r['T'],r['start']),{})[r['variant']]=r
for k,d in g.items():
    r0=d['h0']
    s=f"{k[0]:24s} {k[1][5:]} {k[2]:8s} conv0={r0['stuck_conv'][0]} {r0['cert_code_stuck'][:6]:6s} P/P*={float(r0['Pstuck_over_Pstar']):.3g} |"
    for v in ['h0','fix1','trk1','trkh']:
        r=d[v]
        if r['fired']!='true': s+=f" {v}:-"
        else: s+=f" {v}:{'C' if r['certified']=='true' else 'N'}/{r['nstages']}/{r['passes']}/{float(r['ret_excess']):.0e}/{r['ret_nnz']}"
    print(s)
