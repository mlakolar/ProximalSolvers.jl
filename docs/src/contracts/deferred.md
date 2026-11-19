# [Deferred and refused features](@id DEF-01)

Verbatim migration checkpoint; source provenance is recorded below.

<!-- baseline: docs/src/developer/implementation-notes.md:238-256 -->

## Deferred

Sparse designs, sparse vectors and views as iterates, `SparseIterate` for proximal
gradient descent (plain or accelerated), matrix-shaped owners (other than the `Matrix` coefficient of CD with a matrix response and a row-group `GroupNormL2`, #396), group and symmetric owners, weighted
`ElasticNet`, `Scaled` penalties, group penalties other than `GroupNormL2` with CD, matrix responses other than least squares with CD and a row-group `GroupNormL2` (a private `BlockIterate` over `vec(B)`, #396), intercepts/offsets, generalized losses/compositions,
monotone/active-set acceleration and APG diagonal preconditioning, ADMM/Newton,
primal-dual/SLOPE/graphical models, paths/screening/workspaces/refit, certificates other
than the duality certificate of square-root lasso CD, and reweighting are deferred. Nondefault
feature requests are refused. CD kkt_checks=0 is a compatibility sentinel, and gap=NaN is one too,
except after a certified square-root lasso run of CD, where gap is the certified bound.

This is a breaking support reduction. Version/registration and any public
release remain a separate decision; existing releases are untouched. Protected
archive refs preserve the complete snapshot; legacy/full remains the historical
working branch. Restore capabilities selectively; do not merge it wholesale.


---

<!-- baseline: docs/src/support.md:385-390 -->

Some rejected keywords remain accepted by *constructors*, at their default
values only, to provide informative errors and compatibility with historical
signatures; the solvers and options do not store them.
Do not interpret their presence as available functionality.
CD's `kkt_checks=0` is a placeholder, and so is `gap=NaN`, except that a
certified square-root lasso run of `CDSolver` reports its certified bound in `gap`.
