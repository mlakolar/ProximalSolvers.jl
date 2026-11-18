import re,sys,collections
fn=sys.argv[1]; which=sys.argv[2]  # real|fast|naive
rows=collections.defaultdict(dict)
for line in open(fn):
    m=re.match(r'(Float\d\d) sx=(-?\d+) sr=(-?\d+) \| (.*?) \| real=(\S+) \| fast=(\S+) \| naive=(\S+) \| (.*)',line)
    if not m: continue
    T,sx,sr=m.group(1),int(m.group(2)),int(m.group(3))
    br=m.group(4); real=float(m.group(5)); fast=float(m.group(6)); naive=float(m.group(7)); err=m.group(8)
    if which=='br':
        if 'refuse' in br: s='X'
        elif 'off_' in br and 'band' in br: s='M'
        elif re.search(r'off_(asmall|abig|runder|rsmall|rbig|r0|a0)',br): s='f'
        elif 'off_d' in br: s='d'
        elif 'band' in br: s='b'
        else: s='o'
    else:
        v={'real':real,'fast':fast,'naive':naive}[which]
        if which=='real' and err: s='X'
        elif v!=v: s='?'
        elif v==float('inf'): s='I'
        elif v<=1: s='.'
        elif v<1e3: s='+'
        else: s='#'
    rows[T].setdefault(sr,{})[sx]=s
for T in rows:
    print(T,which,' rows: residual scale sr (top high); cols: column scale sx')
    sxs=sorted({sx for sr in rows[T] for sx in rows[T][sr]})
    print('     '+''.join('%5d'%sx for sx in sxs))
    for sr in sorted(rows[T],reverse=True):
        print('%5d'%sr+''.join('%5s'%rows[T][sr].get(sx,' ') for sx in sxs))
