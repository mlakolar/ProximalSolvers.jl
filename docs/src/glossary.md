# Glossary

**Lasso:** Least-squares regression with an L1 penalty. A way to fit
a linear model that can make some coefficients exactly zero.

**L1 penalty:** The sum of absolute coefficient values, usually
multiplied by the strength parameter `lambda`.

**Weighted lasso:** Lasso with one weight per coefficient,
`lambda * sum(w[j] * abs(beta[j]))`, represented by `NormL1(lambda, w)`.
A zero weight leaves an entry unpenalized. See [weight validation](@ref IN-03).

**Elastic net:** The penalty `lambda1 * sum(abs, beta) + lambda2/2 * sum(abs2, beta)`, an L1 term plus a
ridge (squared L2) term, `ElasticNet(lambda1, lambda2)`. CD, PGD and APG accept it.

**Ridge:** Least-squares regression with the squared L2 penalty
`(lambda/2) * sum(abs2, beta)`. CD accepts the uncentered `SqrNormL2(lambda)`;
the same objective is an elastic net with its L1 level set to zero. Ridge
shrinks coefficients continuously and does not generally produce exact zeros.
See [the supported ridge interface](support.md).

**Square-root lasso:** The optimization problem `min_β ‖y − Xβ‖₂/√n + λₙ‖β‖₁` (Belloni, Chernozhukov and
Wang, 2011). In this package, `SqrtLeastSquaresLoss(y, X)` with `NormL1(λ)` is the unnormalized form
`‖y − Xβ‖₂ + λ‖β‖₁`, which has the same minimizers at `λ = √n λₙ`; `CDSolver` solves it.

**Scaled lasso:** The statistical estimator of Sun and Zhang (2012),
`(β̂, σ̂) ∈ argmin_{β, σ > 0} ‖y − Xβ‖₂²/(2nσ) + σ/2 + λ₀‖β‖₁`, which estimates the coefficients and the
noise level jointly. For fixed `β` with `y ≠ Xβ`, the minimum over `σ > 0` is at `σ = ‖y − Xβ‖₂/√n`, with
value `‖y − Xβ‖₂/√n + λ₀‖β‖₁`; so `β̂` is a square-root lasso minimizer at `λₙ = λ₀` (that is,
`λ = √n λ₀` in the unnormalized form), and `σ̂ = ‖y − Xβ̂‖₂/√n` when `y ≠ Xβ̂` (at an exact fit the
infimum over `σ > 0` is not attained). ProximalSolvers does not provide the scaled lasso as a separate
method; [the scaled-lasso tutorial](examples/problems/scaled_lasso.md) shows the computation. It is not
`Scaled(LeastSquaresLoss(y, X), s)`, which is the least-squares loss multiplied by a fixed
`s` (for example `s = 1/n` for the normalized lasso) and estimates no noise level.

References: Belloni, A., Chernozhukov, V. and Wang, L. (2011), Square-root lasso: pivotal recovery of sparse
signals via conic programming, *Biometrika* 98(4), 791–806. Sun, T. and Zhang, C.-H. (2012), Scaled sparse
linear regression, *Biometrika* 99(4), 879–898.

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
uses it with a `GroupNormL2` penalty for the group lasso; PGD and APG solve the group lasso on a dense
`Vector` instead and refuse a `BlockIterate`.

**Compaction:** Removing zero-valued coordinates from the list of
active coordinates, possibly changing their storage order.

**Gradient residual:** A numerical measure used by an optimizer's
stopping test. It is not the value of your penalty object.

Start with [What problem, which algorithm?](concepts.md) and
[Getting started](getting-started.md).

