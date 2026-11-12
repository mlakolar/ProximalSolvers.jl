# Glossary

**Lasso:** Least-squares regression with an L1 penalty. A way to fit
a linear model that can make some coefficients exactly zero.

**L1 penalty:** The sum of absolute coefficient values, usually
multiplied by the strength parameter `lambda`.

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
in a `SparseIterate`'s storage.

**Compaction:** Removing zero-valued coordinates from the list of
active coordinates, possibly changing their storage order.

**Owner:** An internal name for the caller's mutable coefficient
storage. In beginner-facing pages, we call it the *coefficient
vector* or *coefficient storage*.

**Sentinel:** A placeholder value, such as `gap=NaN`, indicating that
a diagnostic was not computed.

**Gradient residual:** A numerical measure used by an optimizer's
stopping test. It is not the value of your penalty object.

**TFOCS / FASTA / IHT / C0:** Historical algorithm, implementation
or validation shorthand occasionally found in technical pages.
They are not needed for the currently supported beginner workflow.

Start with [What problem, which algorithm?](concepts.md) and
[Getting started](getting-started.md).

