# Glossary

**Lasso:** Least-squares regression with an L1 penalty. A way to fit
a linear model that can make some coefficients exactly zero.

**L1 penalty:** The sum of absolute coefficient values, usually
multiplied by the strength parameter `lambda`.

**Weighted lasso:** The lasso with a weight per coefficient, `lambda * sum(w[j] * abs(beta[j]))`,
`NormL1(lambda, w)`. The weights are a `Vector` of the element type of the data, finite and nonnegative; the
coefficient that `solve!` checks for entry `j` is `T(lambda) * w[j]`, the product rounded in `T`, which must be zero or a
normal number of `T` (see [Supported problems](support.md)), and a zero weight leaves the entry unpenalized.

**Elastic net:** The penalty `lambda1 * sum(abs, beta) + lambda2/2 * sum(abs2, beta)`, an L1 term plus a
ridge (squared L2) term, `ElasticNet(lambda1, lambda2)`. CD, PGD and APG accept it.

**Proximal operator:** A minimization step balancing closeness to an
input point with the value of a penalty.

**Soft-thresholding:** The L1 proximal operator. It shrinks values
toward zero and makes small values exactly zero.

**CD:** Coordinate descent, which updates coefficients one at a time.
One *pass* visits a set of coordinates.

**PGD:** Proximal gradient descent, which uses a full-vector gradient
step followed by a proximal operation.

**KKT conditions:** First-order conditions used to check whether a
candidate point optimizes the lasso objective.

**`lambda_max`:** The smallest lasso penalty for which the all-zero
coefficient vector is optimal, for the normalized lasso without an
unpenalized intercept:
`maximum(abs, X' * y)/length(y)`.

**ProximalBase (PB):** The package providing losses, penalty functions
and iterate types used by ProximalSolvers (PS).

**SparseIterate:** A ProximalBase coefficient-storage type that
records which coordinates are *active* and their values. It is not
a sparse data/design matrix.

**Active coordinate:** A coefficient coordinate currently present
in a `SparseIterate`'s storage. For a `BlockIterate`, the coordinates are
groups and an active coordinate is a group number.

**BlockIterate:** A ProximalBase coefficient vector whose coordinates for
coordinate descent are groups of entries that partition `1:p`. `CDSolver`
uses it with a `GroupNormL2` penalty for the group lasso.

**Compaction:** Removing zero-valued coordinates from the list of
active coordinates, possibly changing their storage order.

**Owner:** An internal name for the caller's mutable coefficient
storage. In beginner-facing pages, we call it the *coefficient
vector* or *coefficient storage*.

**Sentinel:** A placeholder value, such as `kkt_checks=0`, or `gap=NaN` where no
certificate was computed or none passed, indicating that a diagnostic is not available.

**Gradient residual:** A numerical measure used by an optimizer's
stopping test. It is not the value of your penalty object.

**TFOCS:** *Templates for First-Order Conic Solvers*. A historical
first-order optimization framework; the name appears in descriptions
of PGD's inherited backtracking behavior. It is not a separate solver
offered by this minimal version.

**FASTA:** *Fast Adaptive Shrinkage/Thresholding Algorithm*. Historical
terminology for a first-order algorithm and a residual-style stopping
test. Its appearance in implementation notes does not mean this
package exposes a separate FASTA solver.

**IHT:** *Iterative hard thresholding*, a method for imposing a fixed
sparsity budget by retaining selected entries. `normalized=true`
IHT-style behavior is not supported by the current PGD constructor.

**C0:** An internal project label for the frozen baseline
characterization and regression tests used during the minimal-core
rebuild. It is **not** a solver option or a user-facing algorithm.

Start with [What problem, which algorithm?](concepts.md) and
[Getting started](getting-started.md).

