"""Recompute paired timing/allocation summaries from the measured TSVs."""
import csv
import json
import math
from collections import defaultdict
from pathlib import Path
import statistics
import sys
import tomllib

root=Path(sys.argv[1])
groups=defaultdict(list)
with (root/'solve.tsv').open() as file:
    for row in csv.DictReader(file,delimiter='\t'):
        if not math.isfinite(float(row['seconds'])) or float(row['seconds'])<=0:
            raise ValueError('invalid solve time')
        if not math.isfinite(float(row['bytes'])) or float(row['bytes'])<0:
            raise ValueError('invalid solve allocation')
        groups[tuple(row[k] for k in ('comparison','type','n','p','occupancy'))].append(row)
expected_solves={(comparison,t,str(n),str(p),occupancy)
    for comparison in ("dense-base-head","dense-head-control","dense-owner")
    for t in ("Float32","Float64") for n,p in ((128,32),(1024,256))
    for occupancy in ("low","full")}
if set(groups)!=expected_solves:
    raise ValueError("missing or unexpected complete solve case")
summaries=[]
for key,rows in sorted(groups.items()):
    if len(rows)!=60:
        raise ValueError(f'incomplete group {key}')
    pairs=defaultdict(dict)
    for row in rows:
        pairs[int(row['round'])][int(row['side'])]=row
    if sorted(pairs)!=list(range(1,31)) or any(set(pair)!={0,1} for pair in pairs.values()):
        raise ValueError('incomplete or repeated round')
    if len({row['diagnostics'] for row in rows})!=1:
        raise ValueError(f'numerical/stopping divergence: {key}')
    ratios=[float(pair[1]['seconds'])/float(pair[0]['seconds']) for pair in pairs.values()]
    quantiles=statistics.quantiles(ratios,n=10)
    allocations=[sorted({float(row['bytes']) for row in rows if int(row['side'])==side}) for side in (0,1)]
    summaries.append(dict(comparison=key[0],type=key[1],n=int(key[2]),p=int(key[3]),occupancy=key[4],
        repetitions=30,median_ratio=statistics.median(ratios),p10_ratio=quantiles[0],p90_ratio=quantiles[-1],
        median_seconds=[statistics.median(float(row['seconds']) for row in rows if int(row['side'])==side) for side in (0,1)],
        allocation_bytes=allocations,identical_diagnostics=True))
copies=defaultdict(list)
with (root/'copy.tsv').open() as file:
    for row in csv.DictReader(file,delimiter='\t'):
        if not math.isfinite(float(row['seconds'])) or float(row['seconds'])<=0:
            raise ValueError('invalid copy time')
        if not math.isfinite(float(row['bytes'])) or float(row['bytes'])<0:
            raise ValueError('invalid copy allocation')
        copies[tuple(row[k] for k in ('operation','type','p','old_active','new_active'))].append(row)
expected_copies={(operation,t,str(p),str(old),str(new))
    for operation in ("copy","copyto") for t in ("Float32","Float64")
    for p in (1000,100000,1000000)
    for old,new in ((10,10),(p,10),(p//8-1,p//8-1),(p//8,p//8),(p,p))}
if set(copies)!=expected_copies:
    raise ValueError("missing or unexpected complete copy case")
copy_summaries=[]
for key,rows in sorted(copies.items()):
    if len(rows)!=30 or sorted(int(row['round']) for row in rows)!=list(range(1,31)):
        raise ValueError('incomplete copy group')
    copy_summaries.append(dict(operation=key[0],type=key[1],p=int(key[2]),old_active=int(key[3]),new_active=int(key[4]),
        median_seconds=statistics.median(float(row['seconds']) for row in rows),
        allocation_bytes=sorted({int(row['bytes']) for row in rows})))
metadata=tomllib.loads((root/'metadata.toml').read_text())
report={'metadata':metadata,'solves':summaries,'copies':copy_summaries}
(root/'summary.json').write_text(json.dumps(report,indent=2)+'\n')
for row in summaries:
    print(row['comparison'],row['type'],f"{row['n']}x{row['p']}",row['occupancy'],
          f"ratio={row['median_ratio']:.4f}",f"bytes={row['allocation_bytes']}")
print('COPY_GROUPS',len(copy_summaries))
