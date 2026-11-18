# Parameter sweep of the start of PGD and APG against the BigFloat reference min(1, α‖X‖_F²).
using Pkg; VERSION >= v"1.11" && Pkg.instantiate()
using ProximalSolvers, ProximalBase, Random
const PS = ProximalSolvers
println("# Julia ", VERSION, " PS ", pkgdir(PS))
const OPTS = ProximalOptions()
ref(X, α) = setprecision(BigFloat, 256) do
  min(BigFloat(1), BigFloat(α) * sum(abs2, BigFloat.(X)))
end
function starts(X::Matrix{T}, α) where T
  n, p = size(X)
  f, g = Scaled(LeastSquaresLoss(zeros(T, n), X), α), NormL1(zero(T))
  (PS.initial_state(ProximalGradientDescent(), OPTS, f, g, zeros(T, p)).L,
   PS.initial_state(AccProxGradDescent(), OPTS, f, g, zeros(T, p)).L)
end
counts = Dict{String, Int}()
bump(k) = counts[k] = get(counts, k, 0) + 1
failures = String[]
crossings = String[]
crossref = Dict{DataType, Float64}(Float64 => 1.0, Float32 => 1.0)
function check(label, X::Matrix{T}, α) where T
  a_ok = try PS._check_loss_scale(α, T); true catch; false end
  a_ok || return bump("skipped (α refused for $T)")
  r = ref(X, α)
  lp, la = try starts(X, α) catch e; push!(failures, "$label THROW " * first(sprint(showerror, e), 100)); return bump("throw") end
  bad = String[]
  for (nm, L) in (("PGD", lp), ("APG", la))
    (L isa T && isfinite(L) && L > 0) || push!(bad, "$nm L=$L not a finite positive $T")
  end
  isempty(bad) || (push!(failures, "$label: " * join(bad, "; ")); return bump("bad value"))
  (lp === one(T)) == (la === one(T)) || push!(bad, "branch differs PGD=$lp APG=$la")
  if iszero(r) || all(iszero, X)
    lp === one(T) && la === one(T) || push!(bad, "zero X: starts $lp $la")
    bump("X = 0 -> one")
  elseif r >= 1
    lp === one(T) && la === one(T) || push!(bad, "ref ≥ 1 but starts $lp $la")
    bump("ref ≥ 1 -> one")
  elseif lp === one(T) && la === one(T)
    # the rounded-up bound crosses 1 for a reference just below 1
    Float64(r) >= 1 - 1e-5 ? (push!(crossings, "$label ref=$(Float64(r))"); crossref[T] = min(crossref[T], Float64(r)); bump("ref just below 1 -> one (crossing)")) :
      push!(bad, "ref=$(Float64(r)) < 1 but starts one")
  elseif r < floatmin(T)
    lp == floatmin(T) && la == floatmin(T) || push!(bad, "ref=$(Float64(r)) < floatmin but starts $lp $la")
    bump("ref < floatmin -> floatmin")
  else
    for (nm, L) in (("PGD", lp), ("APG", la))
      (r * (1 - 1e-6) <= L <= r * (1 + 1e-4)) || push!(bad, "$nm L=$L outside window of ref=$(Float64(r))")
    end
    bump("ref in (floatmin, 1) -> in window")
  end
  isempty(bad) || (push!(failures, "$label: " * join(bad, "; ")); bump("FAIL"))
  nothing
end

function design(::Type{T}, n, p, scale; seed = 1, zerocols = ()) where T
  rng = Xoshiro(seed + 100n + p)
  X = randn(rng, n, p)
  for j in zerocols; X[:, j] .= 0; end
  T.(scale .* X)
end

alphas(::Type{Float64}) = Float64[nextfloat(0.0), floatmin(Float64), 1e-300, 1e-100, 1e-30, 1e-20, 1e-12, 1e-6, 0.5, 1, 2, 1e30, 1e100, 1e300, floatmax(Float64),
  prevfloat(floatmin(Float64)), nextfloat(2 / floatmax(Float64)), prevfloat(2 / floatmax(Float64)), 2 / floatmax(Float64) * 4,
  prevfloat(2 / floatmin(Float64)), 2 / floatmin(Float64), nextfloat(2 / floatmin(Float64)), 1.7e308, 9e307]
alphas(::Type{Float32}) = Float64[1.5e-45, 1e-40, Float64(floatmin(Float32)), 1e-30, 1e-20, 1e-12, 1e-6, 0.5, 1, 2, 1e30, 1e38, Float64(floatmax(Float32))]
scales(::Type{Float64}) = [1e-155, 1e-150, 1e-100, 1e-20, 1.0, 1e20, 1e150, 1e154, 1e160]
scales(::Type{Float32}) = [1e-20, 1e-10, 1.0, 1e10, 1e18, 1e19]   # entries of 1e19·randn stay below floatmax(Float32)
shapes = ((1, 1), (5, 1), (4, 1), (30, 3), (100, 20), (20, 50), (50, 50))

for T in (Float64, Float32), α0 in alphas(T), sc in scales(T), (n, p) in shapes
  for α in (α0, T === Float32 ? Float32(α0) : α0)
    isfinite(α) || continue
    αt = α isa Float32 ? α : α
    check("$T α=$αt scale=$sc $(n)x$p", design(T, n, p, sc), αt)
  end
end
# the reviewer's cases: a subnormal scale with a finite threshold, and a scale whose threshold is subnormal
for α in (prevfloat(floatmin(Float64)), 1.7e308, 9e307), v in (1e154, 1e153, 1e-154, 1e150)
  check("Float64 X=[$(v)] α=$α", fill(v, 1, 1), α)
  check("Float64 X=[$(v)] 3x2 α=$α", fill(v, 3, 2), α)
end
# zero columns, and X = 0
for T in (Float64, Float32), α in (1e-6, 1.0, 1e6)
  check("$T α=$α zero cols", design(T, 30, 6, 1.0; zerocols = (1, 3, 6)), α)
  check("$T α=$α X=0", zeros(T, 4, 3), α)
  check("$T α=$α zero col + single", design(T, 30, 1, 1.0; zerocols = (1,)), α)
end
# integer and Bool scales
for T in (Float64, Float32), α in (1, 2, 3, 1000, 65536, true, Int32(7), UInt8(200)), sc in (1e-3, 1.0, 1e3)
  check("$T α=$(repr(α)) scale=$sc", design(T, 30, 4, sc), α)
end
# boundary: α‖X‖_F² = 1 ± k ulps and the early-exit test s ≥ 2/α just met or just missed
function step(a, k)
  for _ in 1:abs(k); a = k > 0 ? nextfloat(a) : prevfloat(a); end
  a
end
for T in (Float64, Float32), n in (1, 2, 4, 5, 7, 64), p in (1, 2, 3), k in -16:16
  X = ones(T, n, p)
  N = n * p
  check("$T ones($n,$p) α=(1/N)±$k ulps", X, step(T(1) / T(N), k))
  check("$T ones($n,$p) α=(2/N)±$k ulps (exit threshold)", X, step(T(2) / T(N), k))
  check("$T ones($n,$p) α=(1/N)±$k ulps, Float64 α", X, step(1.0 / N, k))
  check("$T ones($n,$p) α=(2/N)±$k ulps, Float64 α", X, step(2.0 / N, k))
end
# X entries 2^k: exact squares, boundary at the exponent edge
for T in (Float64, Float32), e in (-60, -20, 0, 20, 60)
  X = fill(T(2.0)^e, 3, 2)
  for α in (T(2.0)^(-2e) / 6, T(2.0)^(-2e) / 3, T(2.0)^(-2e) / 12)
    check("$T 2^$e entries, α=$α", X, α)
  end
end
println("\nbranch counts:")
for (k, v) in sort!(collect(counts); by = first); println("  ", rpad(k, 48), v); end
println("\ncrossings (ref just below 1, start one): ", length(crossings), "; smallest ref per T: ", crossref, "; as 1 - ref: ", Dict(k => 1 - v for (k, v) in crossref))
for c in first(crossings, 12); println("  ", c); end
println("\nfailures: ", length(failures))
for f in first(failures, 40); println("  ", f); end
println(isempty(failures) ? "SWEEP PASS" : "SWEEP FAIL")
