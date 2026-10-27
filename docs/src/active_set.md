# Active-set proximal gradient

When the solution is sparse and there are many coordinates, most of the work
of a proximal gradient method goes into coordinates that stay at zero.
[`ActiveAccProxGradDescent`](@ref) runs the accelerated method of
[Proximal gradient methods](@ref) on an active set of coordinates only, and
grows the set by the coordinates that violate the optimality conditions. It
applies to a penalty that separates over coordinates, such as the weighted ℓ1
norm, or over groups, as the group lasso does.

## Optimality conditions

Let ``g(x) = \sum_k g_k(x_k)``, with ``x_k`` a coordinate or a group of
coordinates, and ``f`` smooth and convex. Then ``x`` minimizes ``f + g`` if
and only if, for every ``k``,

```math
0 \in \nabla_k f(x) + \partial g_k(x_k).
```

For a coordinate at zero this reads ``-\nabla_k f(x) \in \partial g_k(0)``,
and [`kkt_violation`](@extref ProximalBase.kkt_violation)`(g, ∇f(x), x, k)` of
ProximalBase measures how far it fails:

| Penalty | ``\partial g_k(0)`` | violation at ``x_k = 0`` |
|:--------|:--------------------|:-------------------------|
| ``\lambda w_k \lvert x_k\rvert`` (`NormL1`) | ``[-\lambda w_k, \lambda w_k]`` | ``\lvert\nabla_k f(x)\rvert - \lambda w_k`` |
| ``\lambda w_k x_k + \iota_{x_k \ge 0}`` (`NormL1Nonneg`) | ``(-\infty, \lambda w_k]`` | ``-\nabla_k f(x) - \lambda w_k`` |
| ``\lambda w_k \lVert x_{G_k}\rVert_2`` (`GroupNormL2`) | ``\{v : \lVert v\rVert_2 \le \lambda w_k\}`` | ``\lVert\nabla_{G_k} f(x)\rVert_2 - \lambda w_k`` |

A positive violation means that moving the coordinate away from zero
decreases the objective.

## The algorithm

The active set ``S`` is the set of stored entries of a `SparseIterate`, or of
active groups of an `AtomIterate`. Each outer iteration

1. removes the coordinates that are zero from ``S``;
2. computes the full gradient ``\nabla f(x)``, and the violations of the
   coordinates outside ``S``;
3. stops if no coordinate outside ``S`` has a positive violation and ``x``
   minimizes ``f + g`` over ``S`` (the last inner solve converged, or
   ``x = 0``). It also stops after a converged inner solve that changed no
   entry of ``x``, since the next solve would repeat it; this happens within
   rounding of the smallest penalty level with a zero solution, where the
   check flags a coordinate that the proximal step leaves at zero;
4. adds violators to ``S``, the largest violations first;
5. minimizes ``f + g`` over the vectors supported on ``S``, by
   [`AccProxGradDescent`](@ref) warm started from the current values.

**Stopping.** Before success, the full proximal fixed-point residual
`norm(x - prox(g, x - gradient), Inf)` must also be at most
`gradtol * max(1, norm(initial_gradient, Inf))`. An inner objective-change flag alone
does not establish full optimality. A repeated inner solution that fails this
check returns `converged = false`. For a convex problem the exact zero
fixed-point residual characterizes optimality; a small residual needs additional
curvature assumptions to bound coefficient or objective error.

**The restricted problem.** Step 5 runs on
[`restrict`](@extref ProximalBase.restrict)`(f, S)` and `restrict(g, S)`, the
functions of ``x_S`` that ``f`` and ``g`` become on the vectors supported on
``S``. For least squares, ``\tfrac12\|y - Xx\|^2`` restricted to ``S`` is
``\tfrac12\|y - X_S x_S\|^2``, with the columns ``S`` of ``X``. An inner
iteration then costs ``O(n|S|)`` instead of ``O(np)``, and the only step that
involves all coordinates is the gradient of step 2.

**How many to add.** At a poor starting point, such as zero for a small
penalty, most coordinates violate the optimality conditions, and adding all of
them would make the first inner problem as large as the original one. With
``s`` entries left in ``S`` after step 1, step 4 adds the largest violations
until they hold

```math
\max\{\texttt{max\_add},\ (\texttt{growth} - 1)\, s\}
```

entries, together with any violators tied with the last one added (the
coordinates of a group at zero share the violation of the group, so a tie
keeps a group whole). The active set thus grows by a factor of at most
`growth` over the nonzero entries, or by `max_add` entries if that is more: it
reaches a large support in a few outer iterations, and stays close to the
support. `growth = 1` adds `max_add` entries at a time, and
`max_add = typemax(Int)` removes the limit.

## Groups

For `GroupNormL2`, an `AtomIterate` that shares the groups of the penalty,
`AtomIterate(x, g.groups)`, makes the groups the coordinates, so that a group
joins and leaves the active set whole. A dense starting point takes this
route when the groups of ``g`` cover all coordinates. With a `SparseIterate`,
the coordinates of a group at zero share the violation of the group, and a
violating group joins whole as well.

## Settings and results

`ActiveAccProxGradDescent(; β, α, max_add, growth, max_outer)` takes the
backtracking factors ``\beta`` and ``\alpha`` of the inner method, the limits
above, and the largest number of outer iterations. The
[`ProximalOptions`](@ref) apply to each inner solve. The result, an
[`ActiveSetResults`](@ref ProximalSolvers.ActiveSetResults), reports the outer
and the summed inner iterations, whether the method stopped at step 3
(`converged`), whether every inner solve converged, the largest violation
outside the active set at the solution, and the size of the active set.
