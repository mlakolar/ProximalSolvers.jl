# X3 item 7 (A-): _scaled_norm (BASE) vs _se_norm(Float64, ·) (X3) at its two call sites, against BigFloat.
#   julia +lts|+release --project=<WORK>/ps-353 x3_item7_scalednorm.jl
const HERE = @__DIR__
include(joinpath(HERE, "loadtrees.jl"))
using Random, LinearAlgebra, ProximalBase
using ProximalBase: SparseIterate, SqrtLeastSquaresLoss, NormL1
B = BaseMod.ProximalSolvers; X3 = X3Mod.ProximalSolvers
println("Julia ", VERSION, " CPU ", Sys.CPU_NAME)
rng = Xoshiro(7)
bigsum(f, v) = setprecision(() -> f(v), BigFloat, 400)
exactnorm(v) = setprecision(() -> sqrt(sum(abs2, BigFloat.(v))), BigFloat, 400)
u64 = eps(1.0)

# ---- (1) floor64 = 16 eps(T) ‖y‖ at _prepare! ---------------------------------------------------------
println("\n(1) floor64: relative error vs BigFloat (units of eps(Float64)) and bit differences, BASE _scaled_norm vs X3 _se_norm")
function floor_of(PS, y::Vector{T}) where T
  X = ones(T, length(y), 2)
  xs = SparseIterate(T, 2)
  m = PS.cdmodel(SqrtLeastSquaresLoss(y, X), xs); PS.initialize!(m, xs); PS._prepare!(m, NormL1(T(0.1)), xs)
  m.floor64
end
global nsub = 0
for T in (Float32, Float64)
  global nsub = 0
  nb = 0; nd = 0; maxb = 0.0; maxx = 0.0; tot = 0; sumb = 0.0; sumx = 0.0
  for trial in 1:6000
    n = rand(rng, (1, 2, 5, 17, 100, 1000, 20000))
    ex = T === Float32 ? rand(rng, -149:120) : rand(rng, -1074:1000)
    y = T.(randn(rng, n) .* 2.0^clamp(ex, -1000, 1000))
    all(isfinite, y) || continue
    all(isfinite, y) && any(!iszero, y) || continue
    if trial % 5 == 1 && n > 1       # mixed ranges: a few entries rescaled by powers of two
      mx = exponent(maximum(abs, y)); room = exponent(floatmax(T)) - mx - 2
      for _ in 1:3; i = rand(rng, 1:n); y[i] *= T(2)^rand(rng, -min(20, mx - exponent(floatmin(T)) + 20):max(0, min(20, room))); end
    end
    if trial % 7 == 0 && n > 1; room = exponent(floatmax(T)) - exponent(maximum(abs, y)) - 2; room > 0 && (y[rand(rng, 1:n)] *= T(2)^rand(rng, 0:min(40, room))); end
    trial % 11 == 0 && (y .= 0)
    all(isfinite, y) || continue
    a = floor_of(B, y); b = floor_of(X3, y)
    ref = 16 * BigFloat(eps(T)) * exactnorm(y)
    tot += 1; a === b || (nd += 1)
    if iszero(ref) ; (a == 0 && b == 0) || println("  ZERO MISMATCH ", a, " ", b); continue; end
    ref > BigFloat(floatmin(Float64)) * 2^60 || (global nsub += 1; continue)   # floor64 itself underflows (ldexp): same in both, excluded from the error statistics
    # floor64 may leave the normal Float64 range only at the edges (ldexp of the result)
    ra = Float64(abs(BigFloat(a) - ref) / ref) / u64; rb = Float64(abs(BigFloat(b) - ref) / ref) / u64
    maxb = max(maxb, ra); maxx = max(maxx, rb); sumb += ra; sumx += rb
    isnormal = ref > BigFloat(floatmin(Float64))
  end
  println("  $T: cases=$tot  floor64 bits differ in $nd; max rel err (eps64): BASE $(round(maxb, digits=1))  X3 $(round(maxx, digits=1)); mean: BASE $(round(sumb/tot, digits=2)) X3 $(round(sumx/tot, digits=2)) (excluded because floor64 underflows: $nsub)")
end
# the largest relative change of floor64 between the two versions (what could flip `tol >= floor64`)
let worst = 0.0
  for T in (Float32, Float64), _ in 1:3000
    n = rand(rng, (1, 10, 1000, 100000)); y = T.(randn(rng, n))
    a, b = floor_of(B, y), floor_of(X3, y); worst = max(worst, abs(a - b) / a / u64)
  end
  println("  worst |floor64_X3 - floor64_BASE| / floor64 on randn y, n up to 1e5: $(round(worst, digits=1)) eps(Float64)")
end

# ---- (2) the off-range step ------------------------------------------------------------------------
println("\n(2) _sqrt_offrange_step: BASE vs X3 against the BigFloat step formula (centre c = old + b/a, τ = (λ/√a) d /√(a − λ²), d = ‖r − (b/a) x‖)")
function offrange_new(PS, X::Matrix{T}, y, old, λ, k) where T
  xs = SparseIterate(T, size(X, 2)); xs[k] = old
  m = PS.cdmodel(SqrtLeastSquaresLoss(y, X), xs); PS.initialize!(m, xs); PS._prepare!(m, NormL1(λ), xs)
  PS._sqrt_offrange_step(m, old, k), copy(m.ls.r)
end
function ref_step(X::Matrix{T}, r, old, λ, k) where T
  setprecision(BigFloat, 400) do
    x = BigFloat.(X[:, k]); rb = BigFloat.(r); a = sum(abs2, x); b = dot(x, rb)
    l = BigFloat(λ); ra = sqrt(a)
    l >= ra && return BigFloat(0)
    q = b / a; d = sqrt(sum(abs2, rb .- q .* x))
    c = BigFloat(old) + q
    τ = (l / ra) * d / sqrt(a - l^2)
    sign(c) * max(abs(c) - τ, BigFloat(0))
  end
end
for T in (Float32, Float64)
  tot = 0; differ = 0; maxrel_b = 0.0; maxrel_x = 0.0; bigger_x = 0; bigger_b = 0; fell = 0
  for trial in 1:12000
    n = rand(rng, (2, 5, 30, 200)); p = 3; k = rand(rng, 1:p)
    sc = T === Float32 ? 2.0^rand(rng, [-75, -70, -60, -50, 60, 64, 70]) : 2.0^rand(rng, [-560, -530, -520, 520, 530, 560])
    X = T.(randn(rng, n, p)) .* T(sc)
    # the residual: mostly parallel to the column (the recomputation branch d² < ‖s‖²/16), sometimes generic
    mode = rand(rng, 1:3)
    y = mode == 1 ? X[:, k] .* T(rand(rng) * 3 + 0.5) .+ T.(randn(rng, n)) .* T(sc) .* T(1e-3) :
        mode == 2 ? X[:, k] .* T(rand(rng) * 3 + 0.5) .+ T.(randn(rng, n)) .* T(sc) .* T(1e-6) :
                    T.(randn(rng, n)) .* T(sc)
    all(isfinite, X) && all(isfinite, y) || continue
    a = setprecision(() -> sum(abs2, BigFloat.(X[:, k])), BigFloat, 400)
    λ = T(sqrt(a) * rand(rng, [0.05, 0.3, 0.7, 0.95]))
    (isfinite(λ) && λ > 0) || continue
    old = rand(rng, Bool) ? zero(T) : T(randn(rng) * 0.1 * sc / sc)
    local nb, nx, r
    try
      nb, r = offrange_new(B, X, y, old, λ, k); nx, _ = offrange_new(X3, X, y, old, λ, k)
    catch e
      fell += 1; continue
    end
    tot += 1
    ref = ref_step(X, r, old, λ, k)
    nb === nx || (differ += 1)
    scale = max(abs(ref), abs(BigFloat(old)), abs(BigFloat(r[1])) / sqrt(a) * 0 + BigFloat(floatmin(T)))
    eb = abs(BigFloat(nb) - ref) / scale; ex = abs(BigFloat(nx) - ref) / scale
    maxrel_b = max(maxrel_b, Float64(eb) / eps(T)); maxrel_x = max(maxrel_x, Float64(ex) / eps(T))
    ex > eb && (bigger_x += 1); eb > ex && (bigger_b += 1)
  end
  println("  $T: cases=$tot (errors/refusals skipped: $fell); results differ in $differ ($(round(100differ/tot, digits=2))%); max error vs BigFloat (eps(T) of max(|step|,|old|)): BASE $(round(maxrel_b, digits=3)), X3 $(round(maxrel_x, digits=3)); X3 farther in $bigger_x, BASE farther in $bigger_b")
end
