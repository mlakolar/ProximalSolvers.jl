import re,sys,glob,os
root="../pb-pin-a19c59aa/src"
files=sorted(glob.glob(root+"/**/*.jl",recursive=True))
names=sys.argv[1:]
lines={f:open(f).read().split("\n") for f in files}
for n in names:
    pat=re.compile(r"(?<![\w!])"+re.escape(n)+r"(?![\w!])")
    hits=[];defs=[]
    for f in files:
        for i,l in enumerate(lines[f],1):
            code=l.split("#")[0]
            if pat.search(code):
                short=os.path.relpath(f,root)
                isdef=re.match(r"\s*(@inline\s+|@noinline\s+)*(function\s+)?"+re.escape(n)+r"(\(|\{)",code) and ("=" in code or code.strip().startswith(("function","@inline function","@noinline function"))) and not re.match(r"\s*return",code)
                (defs if isdef else hits).append(f"{short}:{i}")
    print(f"{n}: defs={len(defs)} callers={len(hits)}")
    print("   "+" ".join(hits))
