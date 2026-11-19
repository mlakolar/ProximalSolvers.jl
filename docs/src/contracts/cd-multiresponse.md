# [Multi-response row-group coordinate descent](@id CDM-01)

<!-- Migration source: docs/src/support.md:L236-L284 -->

### Multi-response group lasso with coordinate descent

~~~math
\min_B\quad \frac{s}{2}\|Y-XB\|_F^2+\lambda\sum_{j=1}^p w_j\|B_{j,:}\|_2,
~~~

for `X` of size `n × p`, a response `Y` of size `n × K` and coefficients `B` of size `p × K`; row `j` of `B` is the
group `j`, and the default weights are `w_j = sqrt(K)`. The call is

```julia
groups = [collect(j:p:p*K) for j in 1:p]    # row j of the column-major B
f = (1/n) * LeastSquaresLoss(Y, X)
g = GroupNormL2(lambda, groups)
B = zeros(Float64, p, K)
r = solve!(B, f, g, CDSolver(order = :cyclic, momentum = false))
r.minimizer === B
```

The solver works from the original `X` and `Y`, without a Kronecker design or a response flattened into a
vector. It keeps an `n × K` residual and `O(p K)` further storage, and a visit to row `j` costs `O(n K)`. `solve!(B, f, g, CDSolver(...))` accepts this problem when

- `B`, `X` and `Y` are `Matrix{T}` with `T` equal to `Float32` or `Float64`, with `size(B) == (p, K)`, finite
  entries and positive sizes, and `B` shares no memory with `X`, `Y`, the penalty weights `g.w` or the scratch
  array that the loss writes when it is evaluated (a `DimensionMismatch` for a wrong shape, an `ArgumentError`
  for the others);
- `f` is `LeastSquaresLoss(Y, X)` or one positive scalar multiple of it, with the loss scales of the lasso above;
- `g` is a `GroupNormL2` whose element type is `Float32` or `Float64`, with a level and weights as for the group
  lasso above, and its groups are the rows of `B` in order: `g.groups[j] == j:p:p*K` for each `j`, otherwise `solve!`
  throws a `DimensionMismatch`. The groups index the entries of `vec(B)`, not the columns of `X`;
- the solver does not use momentum: `momentum = true` is refused with an `ArgumentError`.

A `BlockIterate` over `vec(B)` with the same groups and the same loss is accepted as well; the iterate is then the
`BlockIterate`, as for the group lasso. `B` is written only after a completed run with a finite objective, and
`minimizer` is `B` itself; a refusal, or a run that fails numerically, leaves `B` unchanged. The refusals of the
inputs above throw before `B` is copied or the random number generator is used. A column of `X` whose squared norm
is not finite or is below `floatmin(T)` (a column of zeros is not refused), or whose step is outside the normal
range of the arithmetic type, is refused with an `ArgumentError` that names the row, before the first pass and
the first random draw, when `maxpasses > 0`. A column of zeros sets its row to 0 at a visit
where the level and the weight are positive and leaves the row as it is where either is zero; with
`maxpasses = 0` no row is visited, the column checks are not made and `B` keeps its values. As for the other CD
problems, `converged` reports the change test and is not a KKT certificate: with `relative = true` and a positive
response scale `sqrt(s * sum(abs2, Y))`, the change of row `j` is the norm of its displacement times
`sqrt(s * a_j)`, with `a_j` the squared norm of column `j` of `X`. To check a fit, form `G = s * X' * (X * B - Y)`
for the loss scale `s` and test, for each row, `norm(G[j, :] + lambda * w[j] * B[j, :] / norm(B[j, :]))` where
the row is not zero and `norm(G[j, :]) <= lambda * w[j]` where it is; with positive weights, `B = 0` is the solution
at `lambda >= s * maximum(norm((X' * Y)[j, :]) / w[j] for j in 1:p)`. There is no intercept: center the columns of `X`
and `Y` first. `ProximalGradientDescent` and `AccProxGradDescent`, a `NormL1` or `ElasticNet` penalty, the
square-root loss, and a vector response with a `Matrix` coefficient are refused with an `ArgumentError`.

<!-- Migration source: src/cd/solver.jl:L115-L136 -->

**Multi-response group lasso.** With `T` equal to `Float32` or `Float64`, `X::Matrix{T}` (`n` by `p`),
`Y::Matrix{T}` (`n` by `K`), `B::Matrix{T}` (`p` by `K`), `f = LeastSquaresLoss(Y, X)` (or one positive scalar
multiple of it, with loss scale `s`) and
`g = GroupNormL2(lambda, [collect(j:p:p*K) for j in 1:p])` (or with weights, by default `sqrt(K)`), the call
`solve!(B, f, g, CDSolver(order=:cyclic, momentum=false))` minimizes
`(s/2) * sum(abs2, Y - X*B) + lambda * sum(w[j] * norm(B[j, :]) for j in 1:p)` from the original `X` and `Y`, without a
Kronecker design, and returns `B` itself as `minimizer`. The groups of `g` must be the rows of `B`,
`g.groups[j] == j:p:p*K`, in this order, otherwise a `DimensionMismatch` is thrown. A visit to row `j` costs
`O(n K)`, and the solver keeps an `n` by `K` residual and `O(p K)` further storage. The run is on a private
`BlockIterate` over `vec(B)`, and `B` is written only after a completed run with a finite objective. A
`BlockIterate` over `vec(B)` with the same groups and loss is accepted too. The penalty, the loss scale,
the refusal of `momentum = true` and the meaning of `converged` (the change test, not a KKT certificate) are
those of the group lasso above. `B` must share no memory with `X`, `Y`, the penalty weights or the scratch array
of the loss. With `maxpasses > 0`, an `ArgumentError` that names the row refuses, before the first pass, a column
of `X` whose squared norm `a` is not finite or is below `floatmin(T)`, unless the column is zero, and a column
for which `s * a` or its reciprocal is below `floatmin` of the type that combines `s` with `T`. With
`relative=true` and a positive response scale, the change of row `j` is `norm` of its displacement times
`sqrt(s * a)` and the response scale is `sqrt(s * sum(abs2, Y))`, both up to rounding in the normal range.
A zero column of `X` sets its row to 0 at a visit where the level and the weight are positive, and leaves the
row as it is where either is 0; with `maxpasses = 0` no row is visited, the column checks are not made and `B`
keeps its values. `ProximalGradientDescent`, `AccProxGradDescent`, a `NormL1` or `ElasticNet` penalty,
`SqrtLeastSquaresLoss` and a vector response with a `Matrix` coefficient are refused with an `ArgumentError`.

