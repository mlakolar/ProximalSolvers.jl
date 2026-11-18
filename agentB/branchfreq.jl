# Branch-frequency probe on ordinary problems: drives the real solve! with the instrumented leastsquares.jl.
include(joinpath(@__DIR__, "instr_load.jl"))
using Logging
function design(T, n, p, kind, rng)
  X = randn(rng, T, n, p)
  if kind == :corr
    z = randn(rng, T, n); X .= 0.6f0 .* X .+ 0.8f0 .* z
  elseif kind == :sparsepat   # dense storage, ~90% zeros, some flat columns
    X .*= (rand(rng, n, p) .< 0.1); X[:, 1:max(1, p ÷ 20)] .= 0
  elseif kind == :stdized
    X .-= mean_cols(X); X ./= sqrt.(sum(abs2, X, dims=1) ./ n)
  end
  X
end
mean_cols(X) = sum(X, dims=1) ./ size(X, 1)
function problem(T, n, p, kind, rng)
  X = design(T, n, p, kind, rng); β = zeros(T, p); β[1:min(5, p)] .= 1
  y = X*β + T(0.5)*randn(rng, T, n); X, y
end
rows = []
function run1(label, T, f, g, mk, kw)
  cnt_reset!()
  x = mk()
  r = with_logger(NullLogger()) do
    solve!(x, f, g, CDSolver(; kw...))
  end
  push!(rows, (label, T, r.passes, r.converged, cnt_snapshot()))
end
rng = Xoshiro(2026)
for T in (Float32, Float64), (n, p) in ((20, 10), (100, 50), (100, 500), (1000, 100), (50, 1000)),
    kind in (:gauss, :corr, :sparsepat, :stdized), frac in (0.9, 0.5, 0.1, 0.01)
  X, y = problem(T, n, p, kind, rng)
  λmax = maximum(abs.(X'*y)); λ = T(frac*λmax)
  tol = T === Float32 ? 1e-6 : 1e-9
  for (sname, α) in (("s1", nothing), ("s1/n", one(T)/T(n)), ("f64s", T === Float32 ? 1.0/n : nothing))
    α === nothing && sname != "s1" && continue
    f = α === nothing ? LeastSquaresLoss(y, X) : α * LeastSquaresLoss(y, X)
    λ1 = α === nothing ? λ : T(λ*Float64(α)); 
    for (pen, g) in (("lasso", NormL1(α isa Float64 ? Float64(λ1) : λ1)), ("enet", ElasticNet(λ1, T(0.1)*λ1)))
      for (mom, kw) in (("cyclic", (order=:cyclic, momentum=false)), ("random-mom", (order=:random, rng=Xoshiro(1))), ("random-nomom", (order=:random, momentum=false, rng=Xoshiro(1))))
        for (xk, mk) in (("dense", () -> zeros(T, p)), ("sparseit", () -> SparseIterate(T, p)))
          xk == "sparseit" && mom == "cyclic" && continue
          run1("$T n=$n p=$p $kind frac=$frac $sname $pen $mom $xk", T, f, g, mk, (; tol=tol, maxpasses=3000, kw...))
        end
      end
    end
    # group lasso (cyclic, random), group sizes 1,5,20
    for gs in (1, 5, 20), (gname, gw) in (("g", nothing),)
      p % gs == 0 || continue
      groups = [collect((i-1)*gs+1:i*gs) for i in 1:p÷gs]
      λg = T(λ1 * 0.5)
      g = GroupNormL2(α isa Float64 ? Float64(λg) : λg, groups)
      for (mom, kw) in (("cyclic", (order=:cyclic,)), ("random", (order=:random, rng=Xoshiro(1))))
        run1("$T n=$n p=$p $kind frac=$frac $sname group$gs $mom", T, f, g, () -> BlockIterate(T, p, g), (; tol=T===Float32 ? 1e-5 : 1e-9, maxpasses=3000, kw...))
      end
    end
  end
end
# aggregate
using Printf
agg = Dict{Tuple{Symbol,String}, Dict{Symbol,Int}}()
function cat(label)
  occursin("group", label) ? "group" : occursin("enet", label) ? "enet" : "lasso"
end
open(joinpath(@__DIR__, "branchfreq.out"), "w") do io
  println(io, "problems: ", length(rows), "  nonconverged: ", count(r -> !r[4], rows))
  for T in (Float32, Float64), c in ("lasso", "enet", "group")
    sel = filter(r -> r[2] == T && cat(r[1]) == c, rows)
    tot = Dict{Symbol,Int}(); nz = Dict{Symbol,Int}()
    for r in sel, (k, v) in r[5]; tot[k] = get(tot, k, 0) + v; nz[k] = get(nz, k, 0) + 1; end
    println(io, "== $T $c: $(length(sel)) solves, passes total $(sum(r[3] for r in sel))")
    for k in sort!(collect(keys(tot))); @printf(io, "   %-22s total %12d  in %4d solves\n", k, tot[k], nz[k]); end
  end
end
println(read(joinpath(@__DIR__, "branchfreq.out"), String))
