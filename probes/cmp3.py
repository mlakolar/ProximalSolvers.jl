# Compare variant TSVs (with a data column) against base.
# FS     = converged and relgap > target (Float64 1e-8, Float32 1e-5)
# FSscale= FS at a tiny alpha whose alpha=1 counterpart (same data/T/method/frac/start/opts) has a
#          relgap at least 100x smaller, i.e. the inaccuracy is attributable to the loss scale
import csv,sys,collections,math
def load(p): return [r for r in csv.DictReader(open(p),delimiter='\t')]
def tgt(T): return 1e-8 if T=='Float64' else 1e-5
ORD=('1.0','0.03333333333333333','0.033333335')
def key(r): return (r['data'],r['T'],r['alpha'],r['method'],r['frac'],r['start'],r['opts'])
def k1(r): return (r['data'],r['T'],'1.0',r['method'],r['frac'],r['start'],r['opts'])
import os
DS=os.environ.get('DS')
_load=load
def load(p): return [r for r in _load(p) if DS is None or r['data'] in DS.split(',')]
base={key(r):r for r in load(sys.argv[1])}
for p in sys.argv[1:]:
    rows=load(p); R={key(r):r for r in rows}; c=collections.Counter(); itr=[]; fl=collections.Counter()
    for r in rows:
        if r['method']=='CD': continue
        grp='ord' if r['alpha'] in ORD else 'tiny'
        if r['error']:
            c[grp+'_err']+=1; fl['ERR '+r['error'][:40]]+=1; continue
        rg=float(r['relgap']); acc=rg<=tgt(r['T']); conv=r['converged']=='true'
        c[grp+'_n']+=1; c[grp+'_acc']+=acc; c[grp+'_conv']+=conv; c[grp+'_TS']+=conv and acc
        if conv and not acc:
            c[grp+'_FS']+=1
            if grp=='tiny':
                o=R.get(k1(r))
                if o and not o['error'] and float(o['relgap'])*100 < rg:
                    c['tiny_FSscale']+=1
                    fl[(r['opts'],r['start'],''.join(ch for ch,f in (('x','x_conv'),('f','f_conv'),('g','g_conv')) if r[f]=='true'))]+=1
        b=base.get(key(r))
        if grp=='ord' and b and not b['error']:
            bacc=float(b['relgap'])<=tgt(r['T']); bconv=b['converged']=='true'
            if bconv and bacc and not conv: c['ord_lost_TS']+=1
            if acc and not bacc: c['ord_acc_gain']+=1
            if bacc and not acc: c['ord_acc_loss']+=1
            if (r['converged'],r['x_conv'],r['f_conv'],r['g_conv'],r['stagnated'],r['itlim'])!=(b['converged'],b['x_conv'],b['f_conv'],b['g_conv'],b['stagnated'],b['itlim']): c['ord_flagchange']+=1
            itr.append(int(r['iters'])/max(1,int(b['iters'])))
    gm=math.exp(sum(map(math.log,itr))/len(itr)) if itr else float('nan')
    print('##',p.split('/')[-1]); print('  ',dict(sorted(c.items())))
    print('   ord iter ratio geo=%.4f min=%.3f max=%.3f  n=%d changed=%d'%(gm,min(itr),max(itr),len(itr),sum(1 for x in itr if x!=1)))
    for k,v in sorted(fl.items(),key=str): print('    ',k,v)
