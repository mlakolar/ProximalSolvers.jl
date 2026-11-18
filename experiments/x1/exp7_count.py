import re,sys,glob,collections
def analyze(path):
    txt=open(path).read().split('\n')
    # strip to function body
    labels=[];cur='entry';order={}
    blocks=collections.OrderedDict(); cur='entry'; blocks[cur]=[]
    for ln in txt:
        m=re.match(r'^([\w\.\-]+):',ln)
        if m: cur=m.group(1); blocks[cur]=[]; continue
        blocks[cur].append(ln)
    idx={b:i for i,b in enumerate(blocks)}
    back=set()
    for b,ls in blocks.items():
        for ln in ls:
            for t in re.findall(r'label %([\w\.\-]+)',ln):
                if t in idx and idx[t]<=idx[b]: back.add(t)
    body='\n'.join(txt)
    cnt=lambda pat: len(re.findall(pat,body))
    d=dict(loops=len(back), vec_loops=sum(1 for b in back if 'vector' in b),
      fdiv=cnt(r'= fdiv (double|float) '), vfdiv=cnt(r'= fdiv <'), sqrt=cnt(r'call (double|float) @llvm\.sqrt\.f\d+'),
      fcmp=cnt(r'= fcmp '), fmul=cnt(r'= fmul (double|float) '), fadd=cnt(r'= f(add|sub) (double|float) '), fma=cnt(r'llvm\.fma|llvm\.fmuladd'),
      maxmin=cnt(r'llvm\.(maxnum|minnum|maximum|minimum)'),
      gcalloc=cnt(r'gc_alloc|jl_gc_pool_alloc|jl_gc_alloc|newstruct|julia\.gc_alloc_obj'), alloca=cnt(r'= alloca '),
      calls=sorted(set(re.findall(r'call [^@\n]*@([\w\.\$]+)\(',body)) - {'llvm.sqrt.f64','llvm.sqrt.f32','llvm.fabs.f64','llvm.fabs.f32'}),
      lines=len([l for l in txt if l.strip()]))
    return d
for ver in ('1.13','1.10'):
  for T in ('Float64','Float32'):
    for t in ('base','x1a','x1b'):
        d=analyze(f'ir/cs_{T}_{t}_{ver}.ll')
        calls=[c for c in d['calls'] if not c.startswith('llvm.lifetime') ]
        print(f"{ver} {T} {t}: loops={d['loops']} (vector loops {d['vec_loops']}) fdiv={d['fdiv']} sqrt={d['sqrt']} fcmp={d['fcmp']} fmul={d['fmul']} fadd/sub={d['fadd']} fma={d['fma']} min/max={d['maxmin']} gc_alloc={d['gcalloc']} alloca={d['alloca']} IRlines={d['lines']}\n      calls: {[c[:70] for c in calls]}")
