# [Cached-residual investigation](@id evidence-cached-residual-378)

<!-- Migration source: docs/src/stopping-limits.md:L229-L357 -->

### What the study of issue #378 measured

[Issue #378](https://github.com/mlakolar/ProximalSolvers.jl/issues/378) measured how far this limit
reaches: revision `8cc0222`, Julia 1.13.4 and 1.10.13, two CPU kinds, and 1,667,350 solves per run on
49 designs (ten of the designs of the audit and 39 generated ones, up to 5000×20 and 50×200) with lasso,
elastic-net, ridge and group-lasso penalties, in Float32 and Float64. Each returned point was
evaluated in 600-bit arithmetic. Most of the starts were built to provoke the failure:
`x_ref + 2^j z` for a reference solution `x_ref`, up to five directions `z` per design, scaled so that the largest
column image of `z` has the norm of `y`, and `j` up to 28 in Float32 and 60 in Float64. The counts are
for those designs and starts; they are not rates to expect on other problems. They are from one run
under Julia 1.13.4. The other three runs give close counts: 264,651 to 264,960 false stops where this
run has 264,795, and 443 to 464 where it has 434.

A *false stop* below is a solve with `converged = true` whose returned point is above the benchmark
target (a relative suboptimality of `1e-8` in Float64 and `1e-5` in Float32) and at which an exact
first visit would change a coefficient or group by more than `p` times the threshold, in the scaled
unit of the change test, with `p` the number of columns. In exact arithmetic a converged full pass
does not leave that much: a visit changes its coordinate by at most the KKT residual divided by the curvature, so
the bounds of
[What the change test of coordinate descent implies](@ref "What the change test of coordinate descent implies")
limit that change to `p − 1` times the threshold for the lasso and the elastic net, and to the number
of groups times the threshold for the group lasso.

- **The cache was stale at each false stop.** With `relative = true` the run has 264,795 false
  stops, 163,901 with a vector penalty and 100,894 with the group lasso. At each of them the cache
  differed from `y − Xx` at the returned point by at least `tol ‖y‖` in the Euclidean norm, which is
  the threshold divided by `√s`. Converged solves above the target occur with `relative = false` as
  well (3,606 Float32 solves with a vector penalty from the starts `x_ref + 2^j z` ended above the
  target after a pass that changed nothing); the study did not classify them further.
- **A pass that changed nothing is not the marker.** 30,258 of the false stops (11%) ended, as the
  example does, with a full pass in which no coefficient or group changed. In the others the last
  pass moved coefficients or groups, each by a scaled change below the threshold. One hand-built case of the study: from the
  start `2^50 e_1` on the Gaussian design of the audit, a Float64 solve with cyclic order and no
  momentum converged in 16 passes at a point whose exact KKT residual is `5.9e-3` of
  `max(λ, λmax)`; with the default options the same start ended at `2.3e-10`.
- **The size of the start.** Converged solves with a vector penalty, and the false stops among them
  (a dash: `j` is not in the ladder of that precision):

  | start | Float32 | Float64 |
  | --- | --- | --- |
  | zero, or the next point of a λ path | 0 of 36,383 | 0 of 44,840 |
  | the reference solution, or a perturbation of it | 128 of 54,850 | 64 of 67,933 |
  | an unpenalized least-squares point | 158 of 24,080 | 196 of 29,955 |
  | `x_ref + 2^j z`, `j = 0` | 80 of 28,881 | 80 of 28,930 |
  | `j = 8` | 122 of 27,086 | 80 of 27,244 |
  | `j = 12` | 653 of 24,922 | – |
  | `j = 16` | 7,785 of 23,601 | 80 of 23,848 |
  | `j = 20` | 15,319 of 23,526 | – |
  | `j = 36` | – | 480 of 22,454 |
  | `j = 40` | – | 4,154 of 22,256 |
  | `j = 48` | – | 13,920 of 22,197 |

  In this table the false stops become frequent between `j = 12` and `j = 16` in Float32 and between
  `j = 36` and `j = 40` in Float64, where the largest column image of `2^j z` is that power of two
  times `‖y‖`. The study does not establish a size of the start
  below which the stop is reliable: the false stops of the second and third rows, and those at
  `j = 0`, are on the rank-deficient design of the audit, and two Float32 false stops at `j = 4` on
  another design started from column images whose norms sum to 29 `‖y‖`.
- **An ordinary start that meets it.** The 158 and 196 false stops of the third row are warm starts
  of a problem with a positive penalty from the unpenalized least-squares point of the
  rank-deficient design. That point has cancelling coefficients, and the norms of its column images
  sum to `7e6 ‖y‖` in Float32 and `2e15 ‖y‖` in Float64. The false stops of the second row are on the same
  design with `λ = 0`, where the reference solution is itself such a point. From zero, from a λ-path
  point, and from the reference solution or its perturbation on a problem with a positive penalty,
  the sweep has no false stop.
- **The configuration.** Float32, starts `x_ref + 2^j z`; the three rows for a vector penalty are on
  the same designs and differ in the number of solves (the second row passed a `SparseIterate`, the
  other two a dense vector):

  | configuration | converged | false stops |
  | --- | --- | --- |
  | vector penalty, cyclic order, no momentum | 69,244 | 27,116 |
  | vector penalty, random order, no momentum | 75,612 | 30,924 |
  | vector penalty, random order, default momentum (`CDSolver()`) | 74,694 | 434 |
  | group lasso, cyclic order | 44,594 | 19,174 |
  | group lasso, random order | 90,625 | 38,936 |

  The default configuration for a vector iterate, which is the one that computes the cache again
  during the solve, is much less exposed. It is not immune: with the default options (random order,
  default momentum) CD also returns the start of the example above with `converged = true` after one
  pass. The group lasso runs without momentum.

### No change to the solver

The study built four changes to the solver and compared them with requirements fixed before the
measurements: stop without `converged = true` on the example above and on its `λ = 0` variant; with
constants fixed on the designs of the audit, lose none of the solves that must keep converging,
there and on the generated designs (ordinary starts, a positive penalty, converged at a point that
is not above the target); and stay within the repository's limit of 5% on the time of an ordinary
solve. None of the four met them.

- A statistic of the visits that changed nothing caught 6% of the false stops, and not the `λ = 0`
  variant of the example.
- Two rules triggered by a statistic of the rounding accumulated along the solve, one that compares
  the cache with a recomputed residual and reports, and one that recomputes the residual and
  continues, left 22 and 0 of the 114,053 false stops (vector penalties) of their comparison with
  the unchanged solver. They lost 64 and 17 Float32 solves that must keep converging, and 23 and 51
  of 260 timing cases, small warm-started solves among them, were more than 5% slower.
- A rule that recomputes the residual when a first-order estimate of the rounding error of the
  last computation of the cache is large, and stops without `converged = true` when that estimate
  is large at the stop, lost none of those solves and left 18 of the 114,053. It was designed after the results were
  known, and its constant has no validation on designs that were held out. It reports
  `converged = false` at some exact minimizers with heavy cancellation, its group form is looser
  than its vector form and not range-safe, and one of its timing cases was above 5% in both of
  two runs. Its estimate is not a bound on the error of the cache, so passing its tests would not
  certify the residual either.

The stopping rule, its defaults and the work of a solve are therefore unchanged, and the limit of
this section remains; [issue #392](https://github.com/mlakolar/ProximalSolvers.jl/issues/392) tracks
it. The measurements are in the
[report](https://github.com/mlakolar/ProximalSolvers.jl/issues/378#issuecomment-6977946590); the
scripts, tables and prototype patches are on the branch
[`archive/issue-378-evidence`](https://github.com/mlakolar/ProximalSolvers.jl/tree/archive/issue-378-evidence).

What you can do:

- Start from zero, or from a point at the scale of the solution such as the previous point of a
  λ path.
- Do not warm-start from a point whose column images are far larger than the response. An
  unpenalized fit whose column images are large and cancel, as on the rank-deficient design of the
  study, is such a point; the study gives no size below which a start is safe.
- Evaluate the [KKT residual independently](../../sparsity-and-kkt.md) at the returned point. It forms
  `y − Xx` from the returned coefficients, so it does not inherit the error of the cache; where the
  returned coefficients are still far above the scale of the solution, as in the example, evaluate
  it in higher precision.
- Calling `solve!` again from the returned point also computes the cache from the returned
  coefficients. The study did not measure this, and it is not guaranteed to improve the result: it
  still fails on the example above, which returns its start.

