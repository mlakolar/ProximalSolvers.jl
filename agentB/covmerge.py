import glob, collections, sys
tgt = sys.argv[1]
hits = collections.defaultdict(int); per = {}
for fn in glob.glob("cov/*.info"):
    cur = None
    for l in open(fn):
        l = l.strip()
        if l.startswith("SF:"): cur = l[3:]
        elif l.startswith("DA:") and cur and cur.endswith(tgt):
            ln, c = l[3:].split(",")[:2]; hits[int(ln)] += int(c); per.setdefault(int(ln), {})[fn[4:-5]] = int(c)
src = open("<WORK>/ps-353/" + tgt).read().split("\n")
zero = sorted(l for l, c in hits.items() if c == 0)
print(tgt, "instrumented lines:", len(hits), "zero-hit:", len(zero))
for l in zero: print(f"  L{l}: {src[l-1].strip()[:150]}")
