# Aggregate paired296 output: per case, the per-round paired ratios (side / base), median over rounds;
# then geo-mean over the cases of a cell (group, opts, method, T), with the A/A controls
# (base2/base and head2/head), iteration ratios, extra APG gradient calls and allocations.
#   python3 -I benchagg.py <paired output file>
import sys, math, collections, statistics as st
lines = open(sys.argv[1]).read().splitlines()
info = {}; times = collections.defaultdict(dict); alloc = []
for l in lines:
    f = l.split('\t')
    if f[0] == 'INFO' and f[1] != 'group':
        info[(f[1], f[2], f[3], f[4], f[5])] = dict(it=int(f[6]), conv=f[7], gc=int(f[14]), bytes=int(f[16]), relkkt=float(f[18]))
    elif f[0] == 'TIME' and f[1] != 'round':
        times[(f[2], f[3], f[4], f[5])][(int(f[1]), f[6])] = float(f[7])
    elif f[0] == 'ALLOC' and f[1] != 'case':
        alloc.append(f[1:])
def T(case): return 'F32' if 'Float32' in case else 'F64'
cells = collections.defaultdict(lambda: collections.defaultdict(list))
for key, tv in times.items():
    grp, case, meth, opts = key
    rounds = sorted({r for r, _ in tv})
    def med(num, den):
        return st.median(tv[(r, num)] / tv[(r, den)] for r in rounds if (r, num) in tv and (r, den) in tv)
    c = cells[(grp, opts, meth, T(case))]
    c['head'].append(med('head', 'base')); c['fgr'].append(med('fgr', 'base'))
    c['aa_base'].append(med('base2', 'base')); c['aa_head'].append(med('head2', 'head'))
    ib, ih, ifg = (info[(grp, case, meth, opts, s)] for s in ('base', 'head', 'fgr'))
    c['it_head'].append(ih['it'] / ib['it']); c['it_fgr'].append(ifg['it'] / ib['it'])
    c['t_per_it'].append(c['head'][-1] / c['it_head'][-1])
    c['gc_extra'].append((ih['gc'] - ib['gc'] * ih['it'] / ib['it']) / max(1, ih['it']) if meth == 'APG' else 0.0)
    c['bytes'].append(ih['bytes'] - ib['bytes'])
    c['us_base'].append(tv[(rounds[0], 'base')])
gm = lambda v: math.exp(sum(map(math.log, v)) / len(v))
print('cell (group, opts, method, T) | n | wall head/base geo [min,max] | wall F+G+R/base geo | A/A base2/base geo [min,max] | A/A head2/head geo | iter head/base geo | wall per iteration head/base geo | APG extra grad/iter mean | alloc bytes head-base max | base us median')
for k in sorted(cells):
    c = cells[k]
    print(f"{k} | {len(c['head'])} | {gm(c['head']):.3f} [{min(c['head']):.2f},{max(c['head']):.2f}] | {gm(c['fgr']):.3f} | "
          f"{gm(c['aa_base']):.3f} [{min(c['aa_base']):.2f},{max(c['aa_base']):.2f}] | {gm(c['aa_head']):.3f} | {gm(c['it_head']):.3f} | "
          f"{gm(c['t_per_it']):.3f} | {st.mean(c['gc_extra']):.3f} | {max(c['bytes'])} | {st.median(c['us_base']):.0f}")
print()
print('ALLOC (case, side, bytes at maxiter 50, 100): equal means no per-iteration allocation')
bad = [a for a in alloc if a[2] != a[3]]
print('  rows', len(alloc), 'unequal', len(bad)); [print('  ', a) for a in bad]
