import csv, collections
rows = list(csv.DictReader(open('out/oracleC.tsv'), delimiter='\t'))
ev = {}
for r in csv.DictReader(open('out/eval_main.tsv'), delimiter='\t'):
    ev[(r['set'],r['id'],r['T'],r['start'],r['config'],r['method'])] = r
f=lambda x: float(x)
g = collections.defaultdict(list)
for r in rows: g[(r['set'],r['T'])].append(r)
print("set T: N | status counts | tau<=1 | tau<=1 & oracle-ratio<=1e-4 | tau>1")
for k,rs in sorted(g.items()):
    st = collections.Counter(r['status'] for r in rs)
    t1 = [r for r in rs if r['tau'] not in ('NaN','') and f(r['tau'])<=1.0]
    ok = [r for r in rs if r['ratio_big_theta'] not in ('NaN','') and f(r['ratio_big_theta'])<=1e-4]
    tg = [r for r in rs if r['tau'] not in ('NaN','') and f(r['tau'])>1.0]
    print(k, len(rs), dict(st), len(t1), len(ok), len(tg))
# M81: which failures of B correspond to oracle C feasible?
print("\nM81 detail: B ok? | C status tau ratio | excess")
for r in rows:
    if r['set']!='M81': continue
    b = ev[(r['set'],r['id'],r['T'],r['start'],r['config'],'B')]
    d = ev[(r['set'],r['id'],r['T'],r['start'],r['config'],'D')]
    if b['ok']!='true' or d['ok']!='true' or True:
        pass
cnt = collections.Counter()
for r in rows:
    if r['set']!='M81': continue
    b = ev[(r['set'],r['id'],r['T'],r['start'],r['config'],'B')]
    cok = r['ratio_big_theta'] not in ('NaN','') and f(r['ratio_big_theta'])<=1e-4
    cnt[(r['T'], 'B-ok' if b['ok']=='true' else 'B-fail', 'C-ok' if cok else 'C-no('+r['status']+')')] += 1
for k,v in sorted(cnt.items()): print(k,v)
