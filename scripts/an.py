import csv, sys, glob, os, collections
def load(pattern):
    rows=[]
    for f in sorted(glob.glob(pattern)):
        parts=f.split('/')
        d=os.path.basename(os.path.dirname(f))   # rev-jv
        tag=parts[-3]
        with open(f) as fh:
            for r in csv.DictReader(fh,delimiter='\t'):
                r['_tag']=tag; r['_dir']=d; rows.append(r)
    return rows
def fl(x):
    try: return float(x)
    except: return float('nan')
