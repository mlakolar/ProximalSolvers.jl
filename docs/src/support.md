# Supported API, ownership and migration

Only Vector x/y and Matrix X with the same Float32 or Float64 element type are
supported. Require positive consistent dimensions and finite entries. Use raw PB
LS or one positive finite scalar Scaled LS, and unweighted finite nonnegative
NormL1. Parameters must be representable; positive values must not round to zero.
Scaling is explicit: raw LS means sum(abs2,y-X*x)/2; divide by n explicitly for
normalized lasso. Accepted wider scalars retain historical conversion sites.

X/y are borrowed read-only during solves and must not alias mutable x. Results
share x; extended traces copy x/gradient. Unsupported requests fail before
mutation. CD exceptions before scatter preserve input x; PGD numerical step
exceptions restore its last accepted point and rethrow. Counters/buffers are
not generally transactional. Shape errors are DimensionMismatch; unsupported
combinations/options are informative ArgumentError.

Sparse inputs/designs, views, weighted/group penalties, matrix responses,
intercepts/offsets, generalized losses/compositions, acceleration, ADMM/Newton,
primal-dual/SLOPE/graphical models, paths/screening/certificates/workspaces/refit
and reweighting are deferred. Nondefault feature requests are refused. gap=NaN
and CD kkt_checks=0 are compatibility sentinels, not computed diagnostics.

This is a breaking support reduction. Version/registration and any public
release remain a separate decision; existing releases are untouched. Protected
archive refs preserve the complete snapshot; legacy/full remains the historical
working branch. Restore capabilities selectively; do not merge it wholesale.
