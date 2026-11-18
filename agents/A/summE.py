import csv, collections
rows = list(csv.DictReader(open(__import__('sys').argv[1]), delimiter='\t'))
g = collections.defaultdict(list)
for r in rows: g[(r['set'],r['T'])].append(r)
for k,rs in sorted(g.items()):
    ok=[r for r in rs if r['ok']=='true']; so=[r for r in rs if r['selfok']=='true']
    false=[r for r in ok if float(r['ratio'])<float(r['lbexc'])-1e-12]
    pas=sorted(int(r['passes']) for r in rs)
    print(k,len(rs),'transplant-ok',len(ok),'smoothed-point-ok',len(so),'false',len(false),'passes median',pas[len(pas)//2],'max',pas[-1])
print()
for r in rows:
    if r['set']=='M81' and r['ok']!='true': print(r['id'],r['T'],r['start'],r['config'],r['excess'],r['passes'],r['selfok'])
