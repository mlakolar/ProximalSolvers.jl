# (copied from Stage 0 exp3_solves.jl) B: whole solves, master vs candidate bitwise. Original header: X1 experiment 3: whole solves on ordinary data. BASE vs X1A (bitwise) and X1B (distribution), + independent BigFloat certificate check.
# julia --project=ps-353 exp3_solves.jl
include("r1lib.jl")
using Statistics
sqrtlam_max(X, y) = (ny = norm(Float64.(y)); iszero(ny) ? 1.0 : norm(Float64.(X)' * Float64.(y), Inf) / ny)
function design(rng, T, n, p, kind)
  if kind == :gauss
    X = randn(rng, n, p)
  elseif kind == :corr       # AR(1) columns with rho = 0.9
    X = randn(rng, n, p); for j in 2:p; X[:, j] = 0.9 .* X[:, j-1] .+ sqrt(1 - 0.81) .* X[:, j]; end
  elseif kind == :collinear  # duplicated and near-duplicated columns
    X = randn(rng, n, p); for j in 2:2:p; X[:, j] = X[:, j-1]; end
    for j in 4:4:p; X[:, j] .+= 1e-8 .* randn(rng, n); end
  end
  T.(X)
end
function response(rng, T, X, kind)
  n, p = size(X); β0 = zeros(p); s = min(p, 5); β0[1:s] .= randn(rng, s) .* 2
  if kind == :noisy; y = X * β0 .+ randn(rng, n)
  elseif kind == :exact; y = Float64.(X) * β0           # exact fit up to rounding (noiseless)
  elseif kind == :zero; y = zeros(n)
  end
  T.(y)
end
function runone(P, T, X, y, λ, x0; order, sparse, momentum)
  p = size(X, 2)
  x = sparse ? SparseIterate(copy(x0)) : copy(x0)
  solver = P.CDSolver(; order, rng = Xoshiro(5), momentum)
  try
    res = with_logger(NullLogger()) do; P.solve!(x, SqrtLeastSquaresLoss(y, X), NormL1(λ), solver); end
    (ok = true, x = Vector{T}(sparse ? res.minimizer : x), minimum = res.minimum, passes = res.passes, conv = res.converged, gap = res.gap, msg = "")
  catch e
    (ok = false, x = Vector{T}(x0), minimum = T(NaN), passes = -1, conv = false, gap = T(NaN), msg = first(sprint(showerror, e), 80))
  end
end
# independent certificate check in BigFloat-256 from the returned x
function bigcheck(X::Matrix{T}, y, λ, x) where T
  setprecision(BigFloat, 256) do
    Xb, yb, xb, λb = big.(X), big.(y), big.(x), big(λ)
    r = yb .- Xb * xb
    N = sqrt(sum(abs2, r)); P = N + λb * sum(abs, xb)
    iszero(P) && return (0.0, 0.0)
    iszero(N) && return (NaN, Float64(P))     # exact fit: dual direction undefined, no check
    g = maximum(abs, Xb' * r) / N
    t = min(big(1), λb / g)
    D = t * sum(yb .* r) / N
    D > 0 || return (Inf, Float64(P))
    (Float64((P - D) / D), Float64(P))
  end
end
const SIZES = [(20, 10), (100, 60), (400, 40), (30, 120), (1000, 200)]

function main()
  rows = []
  for T in (Float32, Float64), kind in (:gauss, :corr, :collinear, :exactfit), (n, p) in SIZES, lf in (0.5, 0.1, 0.02)
    rng = Xoshiro(hash((T, kind, n, p, lf)))
    X = design(rng, T, n, p, kind === :exactfit ? :gauss : kind); y = response(rng, T, X, kind === :exactfit ? :exact : :noisy)
    λ = T(lf * sqrtlam_max(X, y))
    xw = runone(TREES.base, T, X, y, T(2λ), zeros(T, p); order = :cyclic, sparse = false, momentum = nothing).x
    for (cfg, order, sparse, momentum, warm) in ((:cyc_dense_cold, :cyclic, false, nothing, false), (:cyc_dense_warm, :cyclic, false, nothing, true),
          (:rnd_dense_cold, :random, false, nothing, false), (:rnd_sparse_mom_cold, :random, true, nothing, false), (:rnd_sparse_mom_warm, :random, true, nothing, true),
          (:rnd_sparse_nomom_cold, :random, true, false, false), (:cyc_sparse_cold, :cyclic, true, nothing, false))
      (n * p > 50000 && cfg ∉ (:cyc_dense_cold, :rnd_sparse_mom_cold)) && continue
      x0 = warm ? xw : zeros(T, p)
      res = Dict(t => runone(getproperty(TREES, t), T, X, y, λ, x0; order, sparse, momentum) for t in TNAMES)
      push!(rows, (T, kind, n, p, lf, cfg, res))
    end
  end
  for T in (Float32, Float64)
    rng = Xoshiro(3)
    cases = Dict{Symbol,Any}(
      :y_zero => (T.(randn(rng, 30, 8)), zeros(T, 30), T(0.5)),
      :p1 => (T.(randn(rng, 50, 1)), T.(randn(rng, 50)), T(0.3 * 7)),
      :p1_exact => (T.(randn(rng, 50, 1)), T.(2 .* randn(rng, 50)), T(0.1)),
      :n1 => (T.(randn(rng, 1, 6)), T[1.5], T(0.5)),
      :n1_p1 => (reshape(T[2], 1, 1), T[3], T(0.5)),
      :n_lt_p_exact => (T.(randn(rng, 10, 40)), T.(randn(rng, 10)), T(0.01)),
      :exact_dyadic => (T[1 0; 0 1; 1 1; 2 -1], T[1, 2, 3, 0] .* T(1.0), T(0.1)))
    for (nm, (X, y, λ)) in sort(collect(cases); by = first), (cfg, order, sparse, momentum) in ((:cyc, :cyclic, false, nothing), (:rnd_sp, :random, true, nothing))
      p = size(X, 2); x0 = zeros(T, p)
      res = Dict(t => runone(getproperty(TREES, t), T, X, y, λ, x0; order, sparse, momentum) for t in TNAMES)
      push!(rows, (T, nm, size(X, 1), p, NaN, cfg, res))
    end
  end
  same(a, b) = a.ok == b.ok && (!a.ok || (a.x == b.x && a.passes == b.passes && a.conv == b.conv && isequal(a.gap, b.gap) && a.minimum == b.minimum && a.msg == b.msg)) && (a.ok || a.msg == b.msg)
  dif = [r[1:6] for r in rows if !same(r[7][:base], r[7][:cand])]
  println("# julia ", VERSION, ": ", length(rows), " solve configurations; candidate bitwise identical to master (x, passes, converged, gap, minimum, error text): ", length(rows) - length(dif), " of ", length(rows), "; differing: ", length(dif))
  foreach(d -> println("   DIFF ", d), dif)
  oc(o) = !o.ok ? 'T' : (o.conv ? 'C' : 'u')
  println("outcomes by tree (C certified/converged, u uncertified, T throws): ", join([": " * join([string(c, "=", count(r -> oc(r[7][t]) == c, rows)) for c in ('C', 'u', 'T')], " ") for t in TNAMES], " | "))
  println("pass totals over converged rows: ", join([": " * string(sum(r[7][t].passes for r in rows if r[7][t].ok && r[7][t].conv)) for t in TNAMES], " | "))
  println("outcome-class changes: ", count(r -> oc(r[7][:base]) != oc(r[7][:cand]), rows), "; pass-count changes: ", count(r -> r[7][:base].passes != r[7][:cand].passes, rows))
end
main()
