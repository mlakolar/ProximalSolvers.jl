# X1 experiment 3: whole solves on ordinary data. BASE vs X1A (bitwise) and X1B (distribution), + independent BigFloat certificate check.
# julia --project=ps-353 exp3_solves.jl
include("x1lib.jl")
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
  rows = []     # one per (config, T): outcomes of the three trees
  nviol = 0; ncheck = 0; nskip = 0; nzero = 0; nmine_gt = 0; worst_mine_over_rep = 0.0
  for T in (Float32, Float64), kind in (:gauss, :corr, :collinear, :exactfit), (n, p) in SIZES, lf in (0.5, 0.1, 0.02)
    rng = Xoshiro(hash((T, kind, n, p, lf)))
    X = design(rng, T, n, p, kind === :exactfit ? :gauss : kind); y = response(rng, T, X, kind === :exactfit ? :exact : :noisy)
    λ = T(lf * sqrtlam_max(X, y))
    # warm start: BASE solution at 2λ, rounded
    xw = runone(TREES.base, T, X, y, T(2λ), zeros(T, p); order = :cyclic, sparse = false, momentum = nothing).x
    for (cfg, order, sparse, momentum, warm) in ((:cyc_dense_cold, :cyclic, false, nothing, false), (:cyc_dense_warm, :cyclic, false, nothing, true),
          (:rnd_dense_cold, :random, false, nothing, false), (:rnd_sparse_mom_cold, :random, true, nothing, false), (:rnd_sparse_mom_warm, :random, true, nothing, true),
          (:rnd_sparse_nomom_cold, :random, true, false, false), (:cyc_sparse_cold, :cyclic, true, nothing, false))
      (n * p > 50000 && cfg ∉ (:cyc_dense_cold, :rnd_sparse_mom_cold)) && continue
      x0 = warm ? xw : zeros(T, p)
      res = Dict(t => runone(getproperty(TREES, t), T, X, y, λ, x0; order, sparse, momentum) for t in TNAMES)
      push!(rows, (T, kind, n, p, lf, cfg, res))
      for t in TNAMES
        r = res[t]
        if r.ok && r.conv && isfinite(r.gap)
          mine, P = bigcheck(X, y, λ, r.x); ncheck += 1
          isfinite(mine) || (nskip += 1); mine == 0 && (nzero += 1)
          if isfinite(mine)
            if mine > r.gap; nmine_gt += 1; worst_mine_over_rep = max(worst_mine_over_rep, mine / max(r.gap, floatmin())); end
            (r.gap > 1e-4 || mine > 1e-4) && (nviol += 1; println("VIOLATION ", T, kind, n, p, lf, cfg, t, " reported=", r.gap, " mine=", mine))
          end
        end
      end
    end
  end
  special = []
  # special cases: y = 0, p = 1, n = 1, exact fit n<p, all with all configs
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
      for t in TNAMES
        r = res[t]
        if r.ok && r.conv && isfinite(r.gap)
          mine, P = bigcheck(X, y, λ, r.x); ncheck += 1
          if isfinite(mine) && mine > r.gap; nmine_gt += 1; worst_mine_over_rep = max(worst_mine_over_rep, mine / max(r.gap, floatmin())); end
          isfinite(mine) && (r.gap > 1e-4 || mine > 1e-4) && (nviol += 1; println("VIOLATION special ", T, nm, cfg, t, " reported=", r.gap, " mine=", mine))
        end
      end
    end
  end
  open(joinpath(@__DIR__, "exp3_rows_$(VERSION.major).$(VERSION.minor).tsv"), "w") do io
    println(io, "T\tkind\tn\tp\tlf\tcfg\ttree\tok\tconv\tpasses\tgap\tminimum\tmsg")
    for r in rows, t in TNAMES
      o = r[7][t]; println(io, join([r[1], r[2], r[3], r[4], r[5], r[6], t, o.ok, o.conv, o.passes, o.gap, o.minimum, o.msg], "\t"))
    end
  end
  # ---------- summaries ----------
  println("# julia ", VERSION, ": ", length(rows), " solve configurations x 3 trees; certified results independently checked in BigFloat-256: ", ncheck, " (", nskip, " skipped by my check as dual direction undefined/non-positive; ", nzero, " trivial P=0)",
          "; true-gap-bound violations (reported > 1e-4 or mine > 1e-4): ", nviol, "; results where my own (P-D)/D exceeds the reported gap: ", nmine_gt, " (worst mine/reported ", worst_mine_over_rep, ")")
  same(a, b) = a.ok == b.ok && (!a.ok || (a.x == b.x && a.passes == b.passes && a.conv == b.conv && isequal(a.gap, b.gap) && a.minimum == b.minimum))
  difA = [(r[1:6]) for r in rows if !same(r[7][:base], r[7][:x1a])]
  println("X1A vs BASE: identical (x, passes, converged, gap, minimum bitwise): ", length(rows) - length(difA), " of ", length(rows), "; differing: ", length(difA))
  foreach(d -> println("   DIFF x1a ", d), difA)
  difB = [(r[1:6]) for r in rows if !same(r[7][:base], r[7][:x1b])]
  println("X1B vs BASE: bitwise identical: ", length(rows) - length(difB), " of ", length(rows), "; differing: ", length(difB))
  relobj = Float64[]; dgap = Float64[]; dpass = Int[]; dconv = []; dx = Float64[]; thrown = []
  for r in rows
    b, x = r[7][:base], r[7][:x1b]
    (b.ok && x.ok) || (b.ok != x.ok && push!(thrown, r[1:6]); continue)
    push!(relobj, abs(Float64(x.minimum) - Float64(b.minimum)) / max(abs(Float64(b.minimum)), floatmin()))
    isfinite(b.gap) && isfinite(x.gap) && push!(dgap, Float64(x.gap) - Float64(b.gap))
    push!(dpass, x.passes - b.passes)
    b.conv != x.conv && push!(dconv, (r[1:6], b.conv, x.conv))
    nb = norm(Float64.(b.x)); push!(dx, nb == 0 ? Float64(norm(Float64.(x.x))) : norm(Float64.(x.x) .- Float64.(b.x)) / nb)
  end
  q(v) = isempty(v) ? "n/a" : join([@sprintf("%.3g", quantile(v, p)) for p in (0, .5, .9, .99, 1)], " / ")
  println("X1B vs BASE over differing configs (min/median/90%/99%/max): relative objective difference ", q(relobj[relobj .> 0]), " (", count(==(0), relobj), " of ", length(relobj), " exactly equal)")
  println("   relative |x_B - x_base|/|x_base| ", q(dx[dx .> 0]), " (", count(==(0), dx), " exactly equal)")
  println("   gap difference (x1b - base), over pairs with both gaps ", q(dgap), "; relative: ", q([(x.gap - b.gap) / b.gap for r in rows for (b, x) in ((r[7][:base], r[7][:x1b]),) if b.ok && x.ok && isfinite(b.gap) && isfinite(x.gap) && b.gap != 0]))
  println("   pass count difference (x1b - base): min ", minimum(dpass), " max ", maximum(dpass), "; #differ ", count(!=(0), dpass), " of ", length(dpass), "; histogram ", sort(collect(Dict(k => count(==(k), dpass) for k in unique(dpass)))))
  println("   converged changes: ", length(dconv), " ", dconv, "; throw status changes: ", length(thrown), " ", thrown)
  println("outcomes by tree: ", join(["$t: " * join([string(c, "=", count(r -> (o = r[7][t]; !o.ok ? c == 'T' : (o.conv ? c == 'C' : c == 'u')), rows)) for c in ('C', 'u', 'T')], " ") for t in TNAMES], " | "))
  # ordinary (non-special) x1b-vs-base objective stats by type
  for T in (Float32, Float64)
    sub = [r for r in rows if r[1] == T]
    ro = [abs(Float64(r[7][:x1b].minimum) - Float64(r[7][:base].minimum)) / max(abs(Float64(r[7][:base].minimum)), floatmin()) for r in sub if r[7][:base].ok && r[7][:x1b].ok]
    println("   ", T, ": configs ", length(sub), "; X1B objective differs from BASE in ", count(>(0), ro), "; max rel obj diff ", maximum(ro), "; median of the nonzero ", isempty(ro[ro .> 0]) ? "n/a" : median(ro[ro .> 0]))
  end
end
main()
