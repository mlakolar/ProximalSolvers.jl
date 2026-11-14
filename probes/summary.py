# One-line summary per variant: tiny (FSscale, TS, err), ordinary (lost TS, acc gain, iter geo by opts, max relKKT of
# converged), adversarial (FS, worst relKKT among FS).
import csv,collections,math,sys
ORD=('1.0','0.03333333333333333','0.033333335'); ORIG=('base','ill','zerocol','small','big','exact')
def load(p): return {tuple(r[k] for k in ('data','T','alpha','method','frac','start','opts')):r for r in csv.DictReader(open(p),delimiter='\t') if r['method']!='CD'}
def tg(T): return 1e-8 if T=='Float64' else 1e-5
B=load(sys.argv[1])
print('variant | tiny FSscale | tiny conv+acc | tiny err | ord lost acc. succ. | ord acc gains | ord iter geo (default/ftol0/strict) | ord conv max relKKT | adv FS | adv worst relKKT(FS)')
for p in sys.argv[1:]:
    C=load(p); c=collections.Counter(); it=collections.defaultdict(list); kk=0; aw=0
    for k,r in C.items():
        d,T,a=k[0],k[1],k[2]
        if r['error']:
            c['tiny_err' if (d in ORIG and a not in ORD) else 'x_err']+=1; continue
        conv=r['converged']=='true'; rg=float(r['relgap']); rk=float(r['relkkt']); acc=rg<=tg(T)
        if d in ('diag','orth'):
            if conv and not acc: c['adv_FS']+=1; aw=max(aw,rk)
            continue
        if a in ORD:
            b=B[k]
            if b['converged']=='true' and float(b['relgap'])<=tg(T) and not conv: c['lost']+=1
            if acc and float(b['relgap'])>tg(T): c['gain']+=1
            it[k[6]].append(int(r['iters'])/int(b['iters']))
            if conv: kk=max(kk,rk)
        else:
            if conv and acc: c['tiny_TS']+=1
            if conv and not acc:
                o=C.get((d,T,'1.0')+k[3:])
                if o and not o['error'] and float(o['relgap'])*100<rg: c['tiny_FSscale']+=1
    g=lambda v: math.exp(sum(map(math.log,v))/len(v))
    print(f"{p.replace('repro-','').replace('-s0.tsv','')} | {c['tiny_FSscale']} | {c['tiny_TS']} | {c['tiny_err']} | {c['lost']} | {c['gain']} | {g(it['default']):.3f}/{g(it['ftol0']):.3f}/{g(it['strict']):.3f} | {kk:.2g} | {c['adv_FS']} | {aw:.3g}")
