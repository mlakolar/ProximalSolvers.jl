import csv, sys, collections, math, statistics
f = sys.argv[1]
rows = list(csv.DictReader(open(f), delimiter='\t'))
def fl(x):
    try: return float(x)
    except: return float('nan')
key = lambda r: (r['set'], r['T'], r['method'])
g = collections.defaultdict(list)
for r in rows: g[key(r)].append(r)
print("%-6s %-8s %-6s %5s %5s %6s %6s  why-counts" % ("set","T","meth","N","cert","false","unsnd"))
for k in sorted(g):
    rs = g[k]; N=len(rs)
    cert = [r for r in rs if r['ok']=='true']
    # false certification: ratio < true lower excess ; unsound: float ratio < big ratio
    false = [r for r in cert if fl(r['ratio']) < fl(r['lbexc']) - 1e-12]
    uns = [r for r in rs if r['bigratio'] not in ('NaN','') and fl(r['ratio'])==fl(r['ratio']) and fl(r['ratio']) < fl(r['bigratio']) - 1e-13]
    # certified although excess > 1e-4 (should never happen)
    bad = [r for r in cert if fl(r['excess']) > 1e-4*1.0000001 + 1e-9 and fl(r['ratio']) < fl(r['lbexc'])]
    why = collections.Counter(r['why'] for r in rs)
    print("%-6s %-8s %-6s %5d %5d %6d %6d  %s" % (k[0],k[1],k[2],N,len(cert),len(false),len(uns),dict(why)))
