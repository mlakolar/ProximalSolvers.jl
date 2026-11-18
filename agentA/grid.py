import re,sys,collections
fn=sys.argv[1]
rows=collections.defaultdict(dict)
for line in open(fn):
    m=re.match(r'(Float\d\d) sx=(-?\d+) sy=(-?\d+) \| (.*)',line)
    if not m: continue
    T,sx,sy,rest=m.group(1),int(m.group(2)),int(m.group(3)),m.group(4)
    if rest.strip() in ('lamrange','datainf','datazero','lamfail'):
        sym='.'
    else:
        parts=rest.split(' | ')
        br=parts[0]; solve=parts[3] if len(parts)>3 else ''
        has_off='off_' in br; has_band='band=' in br; has_ref='refuse' in br
        ok='conv=true' in solve; thr='THROW' in solve
        cu='conv=false' in solve
        if has_ref: sym='X'   # refusal inside the step
        elif thr: sym='T'
        else:
            tags=''
            if has_off and has_band: sym='M'
            elif has_off: sym=('a' if ('off_asmall' in br or 'off_abig' in br) else 'r')
            elif has_band: sym='b'
            else: sym='o'
            if cu: sym=sym.upper() if sym!='o' else 'u'
    rows[T].setdefault(sy,{})[sx]=sym
for T in rows:
    print(T,'  rows: sy (y scale 2^sy) top=high; cols: sx (X scale 2^sx) left=low')
    sxs=sorted({sx for sy in rows[T] for sx in rows[T][sy]})
    print('      '+' '.join('%5d'%sx for sx in sxs))
    for sy in sorted(rows[T],reverse=True):
        print('%5d '%sy+' '.join('%5s'%rows[T][sy].get(sx,' ') for sx in sxs))
