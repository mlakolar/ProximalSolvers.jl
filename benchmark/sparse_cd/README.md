# Vector SparseIterate CD measurements

Run this harness under the root package project, whose exact ProximalBase pin
is checked against the loaded dependency source. The historical benchmark
environment is not used. No extra package is required.

```sh
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 julia --startup-file=no --project=. benchmark/sparse_cd/measure.jl BASE_TREE HEAD_TREE NEW_OUTPUT
python3 -I benchmark/sparse_cd/analyze.py NEW_OUTPUT
```

BASE_TREE and HEAD_TREE are clean Git checkouts with the same exact tested PB
pin. Both PS revisions, and a second copy of the head for a noise control, load
from source into separate modules in one process. The harness verifies clean
Git identities and source digests before and after measurement. Output records
the source identities, Julia/CPU/thread settings, load averages and harness hash.
Use a fresh output directory and serialize measurements with other work from
the same test run.

For each Float32/Float64, small/moderate dense design and low/full initial
occupancy, `solve.tsv` records 30 paired alternating rounds. A storage-heavy
8-row, 100,000-coordinate zero-design case also measures end-to-end costs with
low/full entry occupancy; its known zero solution isolates storage overhead
without ill-conditioned convergence dominating the comparison. Each side's round
time is the minimum of three warmed batches. Fresh caller storage and seeded
RNGs are prepared outside timing; solver validation, private storage, coordinate
work and final commit are included. The 2,000-pass cap bounds a failed fixture;
a nonconverged result fails the harness rather than being treated as a completed
solve timing. Numerical/stopping signatures and returned objectives are checked
independently from the input data. Canonical identical entry states are used for
the dense/owner timing comparison.

The three comparisons are dense base/head, dense head/head control, and dense
head/public owner. A slower public owner compared with dense input is reported
as measured end-to-end cost; it is not a comparison with an unsafe direct-owner
API. Dense and owner solves both allocate private working storage. The owner
input itself has O(p) capacity; it is not compressed sparse memory.

`copy.tsv` isolates `copy(x)` and same-shape `copyto!(x,work)` for 1,000,
100,000 and 1,000,000 logical coordinates. It covers low/low, full/low,
full/full and occupancies on both sides of PB's small-state traversal threshold.
The destination is prepared in its entry state outside timing for each commit
sample. State checks use public coordinate IDs and values, including active
signed zeros and unsorted order. Allocation/copy costs and final-state replacement
are separate measurements. Setup and state verification are excluded from them.

Run `python3 -I benchmark/sparse_cd/check_analysis.py` to exercise missing-case,
missing-row, numerical-corruption and nonfinite-timing refusal controls.

The analyzer recomputes medians, ratio spreads, exact allocation sets and
numerical equality from raw records. A material repeatable regression outside
the head/head control requires a maintainer decision; retaining caller state on
failure takes precedence over an optimization that weakens that contract.
