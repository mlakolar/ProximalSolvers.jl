# Hybrid SLOPE decision pilot (issue #95)

This directory preserves the original prototype evaluation. The subsequently
authorized opt-in implementation and matched Discovery comparison are in
[`optimized/`](optimized/README.md).

This bounded evaluation targets repeated least-squares SLOPE paths with highly
correlated predictors and tied coefficient magnitudes, as arise in the existing
HighDimensionalModels integration. The proposed benefit is fewer design products
at independently certified accuracy on difficult paths. Matching libslope is
not a requirement. APG remains the default.

## Protocol fixed before the pilot

- Compare the existing screened `SLOPEAPG` with a benchmark-only hybrid through
  the same path driver, screening rule, repairs and final full residual.
- Use seeds 1–3 initially, then unused seeds 11–12 for confirmation. Include
  independent and correlated dense designs, sparse designs, two weight sequences
  (linear and stepped), two signal sparsities, and paths of 6 and 12 levels.
- Use a full fixed-point target of `1e-7` in null-gradient-normalized units and
  independently check every level with a feasible least-squares dual gap at
  `1e-6`. Retain every failure and compare timing only for certified pairs.
- A production candidate requires all pilot levels certified, at least a twofold
  reduction of full design products on the correlated cohort, and no new
  convergence failures on controls. Warm time and Julia allocations are
  secondary observations, with no universal speed or RSS claim.
- Before production, verify exact scalar cluster minimization, signs, rank
  crossings, merges, zero curvature, splitting by PG, excluded predictors,
  dense/sparse/implicit representations, budgets, and APG fallback.

The algorithm follows Larsson, Klopfenstein, Massias and Wallin (2023),
[Sections 2.1–2.3](https://proceedings.mlr.press/v206/larsson23a.html).
Each cluster direction sums signed columns. Its exact one-dimensional minimizer
searches all positive magnitude breakpoints using the corresponding **rank**
weights; it can cross ranks, merge and flip the signs of an entire cluster.
Zero coefficients are left to the regularly scheduled PG steps, which can also
split clusters. Every fifth iteration is PG, with four intervening nonzero
cluster sweeps. Failed or increasing sweeps restore the previous point and
disable cluster updates for that reduced solve, continuing with APG. These are
algorithmic safeguards, not a statistical calibration or FDR claim.

This is a small local development pilot with one Julia/BLAS thread. It does not
replace the broader Discovery comparisons. Process RSS is measured in separate
processes if a production candidate passes the numerical/work gate. Prior
benchmark evidence, including the 36 unscreened correlated FISTA failures, is
unchanged.
