#!/usr/bin/env python3
"""solve_compare.py <dir> <before-label> <after-label>
Reads <dir>/<label>-rep<k>.tsv written by solve_timing.jl and prints, per case, the
median over repetitions of the paired ratio after/before of the minimum batch mean, the
min and max of the per-repetition ratios, bytes on both sides, and whether iterations and
minimizer hashes agree. Then the geometric mean of the per-case median ratios."""
import sys, glob, math, os, statistics

def load(d, label):
    reps = {}
    for f in sorted(glob.glob(os.path.join(d, f"{label}-rep*.tsv"))):
        k = int(f.rsplit("rep", 1)[1].split(".")[0])
        rows = {}
        with open(f) as fh:
            for line in fh:
                if line.startswith("#") or line.startswith("case\t"):
                    continue
                c, mn, md, b, it, h, inner = line.rstrip("\n").split("\t")
                rows[c] = (int(mn), int(md), int(b), int(it), h)
        reps[k] = rows
    return reps

d, a, b = sys.argv[1:4]
A, B = load(d, a), load(d, b)
common = sorted(set(A) & set(B))
if not common:
    sys.exit("no paired repetitions")
cases = sorted(A[common[0]])
print(f"paired repetitions: {common}")
print("case\tmedian_ratio\tmin_ratio\tmax_ratio\tbytes_before\tbytes_after\tsame_iterations\tsame_minimizer")
meds = []
for c in cases:
    rs = [B[k][c][0] / A[k][c][0] for k in common]
    m = statistics.median(rs); meds.append(m)
    same_it = all(A[k][c][3] == B[k][c][3] for k in common)
    same_x = all(A[k][c][4] == B[k][c][4] for k in common)
    print(f"{c}\t{m:.4f}\t{min(rs):.4f}\t{max(rs):.4f}\t{A[common[0]][c][2]}\t{B[common[0]][c][2]}\t{same_it}\t{same_x}")
print(f"geomean_of_median_ratios\t{math.exp(sum(map(math.log, meds)) / len(meds)):.4f}")
print(f"cases_above_1.05\t{sum(m > 1.05 for m in meds)}")
