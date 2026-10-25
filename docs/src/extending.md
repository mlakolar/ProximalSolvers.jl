# A coordinate descent model of your own

Coordinate descent reaches a loss through a [`CDModel`](@ref): an object that
holds the loss and a cache, such as the residuals of least squares, from
which the derivative and the curvature along a coordinate are cheap. A new
loss is a subtype of `CDModel{T}` that implements a few functions. They are
public but not exported, so extend them with their full names,
`ProximalSolvers.initialize!` and so on.

## The interface

| Function | Returns | Needed by |
|:---------|:--------|:----------|
| [`initialize!`](@ref ProximalSolvers.initialize!)`(m, x)` | `m`, with the cache current for the iterate `x` | everything |
| [`coordinate_derivatives`](@ref ProximalSolvers.coordinate_derivatives)`(m, x, k)` | `(G, a)`: the derivative ``G = \partial_k f(x)`` and the curvature ``a`` along coordinate `k`, exact for a quadratic and an upper bound otherwise | the default coordinate step, [`refit!`](@ref) |
| [`update_cache!`](@ref ProximalSolvers.update_cache!)`(m, x, k, h)` | `m`, with the cache updated after coordinate `k` moved by `h` (already written into `x`) | the default coordinate step, [`refit!`](@ref) |
| [`coordinate_step!`](@ref ProximalSolvers.coordinate_step!)`(m, g, x, k)` | the change of coordinate `k` after its step, with `x` and the cache updated | optional: replaces the two above in the passes, to fuse their work or to minimize exactly over a coordinate |
| [`coordinate_scale`](@ref ProximalSolvers.coordinate_scale)`(m, x, k)` | ``\sqrt{a_k}``, the scale of a change of coordinate `k` | the relative stopping rule (default 1) |
| [`response_scale`](@ref ProximalSolvers.response_scale)`(m, x)` | the scale ``\sigma`` that multiplies `tol` | the relative stopping rule (default 0: an absolute rule) |
| [`loss_value`](@ref ProximalSolvers.loss_value)`(m, x)` | ``f(x)``, from the cache | the reported minimum, Anderson acceleration (default `NaN`) |
| `ProximalBase.gradient!(G, m, x)` | ``\nabla f(x)`` in `G`, an array of the size of `x` | [`lambda_max`](@ref), screening, continuation, [`solve_path`](@ref) |
| [`check_penalty`](@ref ProximalSolvers.check_penalty)`(m, g)` | throws an `ArgumentError` for a penalty the model cannot take | optional |

From `coordinate_derivatives` and `update_cache!`, the default step takes

```math
x_k^+ = \operatorname{prox}_{\mu g_i / a}\Big(x_k - \frac{G}{a}\Big)
```

with [`prox_entry`](@extref ProximalBase.prox_entry), where ``i`` is the entry
of the coordinate and ``\mu`` the number of entries it sets (2 off the
diagonal of a `SymmetricSparseIterate`), and writes the change only when the
coordinate moves; see [The coordinate step](@ref). A coordinate with zero
curvature goes to the minimizer of the penalty nearest zero.

## An example

This example implements least squares with a sparse design matrix,
``f(\beta) = \frac{s}{2}\|y - X\beta\|^2`` with ``X`` a `SparseMatrixCSC`.
A coordinate step visits only the stored entries of a column, at a cost of
``O(\operatorname{nnz}(X_k))``. The built-in least-squares model also uses
sparse column kernels, including with an intercept or observation weights;
the small model below illustrates the extension interface.

```julia
using ProximalBase, ProximalSolvers, SparseArrays, LinearAlgebra

mutable struct SparseLeastSquares <: CDModel{Float64}
    X::SparseMatrixCSC{Float64, Int}
    y::Vector{Float64}
    s::Float64
    r::Vector{Float64}           # the residuals y - Xβ
    a::Vector{Float64}           # the curvatures s ‖X[:, k]‖²
end
SparseLeastSquares(X, y, s) = SparseLeastSquares(X, y, s, copy(y), s .* vec(sum(abs2, X; dims = 1)))

function ProximalSolvers.initialize!(m::SparseLeastSquares, β)
    rows, vals = rowvals(m.X), nonzeros(m.X)
    m.r .= m.y
    for k in activecoordinates(β), i in nzrange(m.X, k)
        m.r[rows[i]] -= vals[i] * β[k]
    end
    m
end

function ProximalSolvers.coordinate_derivatives(m::SparseLeastSquares, β, k::Int)
    rows, vals = rowvals(m.X), nonzeros(m.X)
    d = 0.0
    for i in nzrange(m.X, k)
        d += vals[i] * m.r[rows[i]]
    end
    (-m.s * d, m.a[k])
end

function ProximalSolvers.update_cache!(m::SparseLeastSquares, β, k::Int, h)
    rows, vals = rowvals(m.X), nonzeros(m.X)
    for i in nzrange(m.X, k)
        m.r[rows[i]] -= vals[i] * h
    end
    m
end

ProximalSolvers.coordinate_scale(m::SparseLeastSquares, β, k::Int) = sqrt(m.a[k])
ProximalSolvers.response_scale(m::SparseLeastSquares, β) = sqrt(m.s) * norm(m.y)
ProximalSolvers.loss_value(m::SparseLeastSquares, β) = m.s * sum(abs2, m.r) / 2
ProximalBase.gradient!(G, m::SparseLeastSquares, β) = (mul!(G, m.X', m.r); G .*= -m.s)
```

The model then goes wherever a loss does:

```julia
m = SparseLeastSquares(X, y, 1 / n)
λmax = lambda_max(m, NormL1(1.0), SparseIterate(p))
solve!(SparseIterate(p), m, NormL1(0.1λmax), CDSolver())
solve_path(m, NormL1(1.0), λmax .* 10 .^ range(0, -2; length = 30); x = SparseIterate(p))
```

[A model of your own](examples/13_custom_model.md) runs this example and
compares it with the built-in model on a dense copy of ``X``.

## Notes

- **Iterates.** The functions receive the iterate, a `SparseIterate` or a
  `SymmetricSparseIterate`; a model may support either. On a
  `SymmetricSparseIterate`, coordinate ``k`` is the lower-triangle entry
  ``(r, c)`` = `tril_cartesian(x.p, k)`, and `coordinate_derivatives` returns
  the derivative and the curvature along ``E_{rc} + E_{cr}``, as for the
  [Kronecker quadratic](@ref "Kronecker quadratics"). Group penalties work
  with the built-in models only.
- **Momentum.** Momentum is off by default for a model of your own. With
  `CDSolver(; momentum = true)`, coordinate descent calls `initialize!` at
  each extrapolated point, which pays off only when `initialize!` is cheap
  compared with a pass.
- **The relative stopping rule.** Choose the scales so that
  ``|\Delta x_k|\sqrt{a_k}`` and ``\sigma`` are in the same units, the units of
  the loss's square root: for least squares, changes of the fitted values
  against the size of the response. Without them, `tol` is an absolute bound
  on the change of a coordinate.
- **Testing.** Compare the solution with that of a built-in model on a small
  problem, and check the optimality conditions of the penalized problem, as
  the examples do.

## Running the package suite

From the package checkout, run `julia scripts/test_master.jl` after adding or
changing an implementation. This uses the complete test extras and workspace
master dependencies on Julia 1.10 and newer, with bounds checking enabled,
while leaving the package's `Project.toml` unchanged.
