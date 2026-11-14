# Disposable #308 counterexample battery and randomized search (not part of the package).
#   julia --project=<env> cex308.jl <out.tsv> [nrandom=200] [maxiter=10000]
# Each problem runs the unchanged baseline (strict settings) to maxiter and logs per iteration
# the stall flag, whether a curvature-checked trial was rejected in the iteration, L, the exact
# Float64 objective and the independent relative duality gap. The candidate rules are then
# evaluated on the same trajectory (a rule only truncates it): A_K = K consecutive exact stalls,
# B = an exact stall in an iteration with a curvature-checked rejection.
out = ARGS[1]
nrandom = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 200
maxiter = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 10_000
const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const H = Module(:Harness308c)
Core.eval(H, :(import ProximalBase, ProximalSolvers; using LinearAlgebra, SparseArrays, Random, SHA, Printf, Statistics))
Core.eval(H, :(include(p) = Base.include($H, p)))
for f in ("problems.jl", "certificates.jl", "cases.jl")
  Base.include(H, joinpath(ROOT, "benchmark", f))
end
import ProximalSolvers, ProximalBase
using LinearAlgebra, Random, Printf
BLAS.set_num_threads(1)
const PS = ProximalSolvers
const PB = ProximalBase

function trajectory(X::Matrix{T}, y::Vector{T}, s, λ, x0::Vector{T}; maxiter = maxiter) where T
  f = T(s) * PB.LeastSquaresLoss(y, X); g = PB.NormL1(T(λ))
  X64, y64 = Float64.(X), Float64.(y); s64, λ64 = Float64(T(s)), Float64(T(λ))
  opts = PS.ProximalOptions(maxiter = maxiter, ftol = 0, xtol = 1e-300, gradtol = 1e-11, allow_f_increases = true)
  method = PS.ProximalGradientDescent()
  x = copy(x0); PS._check_problem(x, f, g)
  st = PS.initial_state(method, opts, f, g, x)
  stall = Bool[]; vrej = Bool[]; Ls = Float64[]; P = Float64[]; gap = Float64[]; prods = Int[]
  k, conv = 0, false
  while !conv && k < maxiter
    k += 1
    b0, v0 = st.backtrack_steps, st.verifications
    PS.update_state!(f, g, st, method)
    _, _, _, conv, _ = PS.convergence_assessment(st, f, g, opts)
    sk = st.x == st.x_previous
    push!(stall, sk); push!(vrej, hasproperty(st, :verified_rejection) ? st.verified_rejection : (st.verifications > v0 && st.backtrack_steps > b0))
    push!(Ls, Float64(st.L))
    xx = Float64.(st.x); r = y64 - X64 * xx
    push!(P, s64 * sum(abs2, r) / 2 + λ64 * sum(abs, xx))
    push!(gap, H.lasso_certificate(X64, y64, s64, λ64, ones(length(xx)), xx).value)
    push!(prods, st.prox_calls + st.grad_calls + st.verifications)
  end
  (; stall, vrej, Ls, P, gap, prods, conv, k)
end

const KS = (1, 2, 3, 5, 10, 20, 50, 100, 200)
function rules(t)
  N = length(t.stall); r = Dict{String, Int}()
  r["B"] = something(findfirst(i -> t.stall[i] && t.vrej[i], 1:N), 0)
  for K in KS
    c, kk = 0, 0
    for i in 1:N
      c = t.stall[i] ? c + 1 : 0
      c >= K && (kk = i; break)
    end
    r["A$K"] = kk
  end
  r
end

io = open(out, "w")
println(io, join(("case", "family", "iters", "base_conv", "base_hit", "base_gap_end", "base_gap_min", "rule", "stop", "gap_stop",
                  "later_gap_min", "later_P_gain", "premature", "prods_stop", "prods_end"), '\t'))
function report(name, fam, t)
  tgt = 1e-5; N = length(t.gap)
  hit = something(findfirst(<=(tgt), t.gap), 0)
  Pref = abs(minimum(t.P))
  for (rule, k) in sort(collect(rules(t)))
    if k == 0
      println(io, join((name, fam, N, t.conv, hit, t.gap[end], minimum(t.gap), rule, 0, NaN, NaN, NaN, false, t.prods[end], t.prods[end]), '\t'))
      continue
    end
    lg = k < N ? minimum(t.gap[k+1:end]) : Inf
    gain = k < N ? (t.P[k] - minimum(t.P[k+1:end])) / max(Pref, floatmin()) : 0.0
    # premature: the stop misses the target that the baseline later meets, or the exact objective
    # improves afterwards by more than 1e-3 of the target (relative)
    prem = (t.gap[k] > tgt && lg <= tgt) || gain > 1e-3 * tgt
    println(io, join((name, fam, N, t.conv, hit, t.gap[end], minimum(t.gap), rule, k, t.gap[k], lg, gain, prem, t.prods[k], t.prods[end]), '\t'))
  end
  flush(io)
end

normcols!(X) = (for j in axes(X, 2); X[:, j] ./= sqrt(sum(abs2, X[:, j]) / size(X, 1)); end; X)
function design(rng, n, p, ρ)
  X = randn(rng, n, p)
  for j in 2:p
    X[:, j] .= ρ .* X[:, j-1] .+ sqrt(1 - ρ^2) .* X[:, j]
  end
  normcols!(X)
end
lmax(X, y, s) = s * maximum(abs, X' * y)

# --- deterministic counterexamples ---------------------------------------------------------
rng = Xoshiro(308)
# C1 badly scaled data, warm start far from the optimum: L starts at 1 >> L_f = c² α‖X‖²
for c in (1e-4, 1e-5, 1e-6, 1e-7)
  X = design(rng, 100, 32, 0.0); β = zeros(32); β[1:5] .= (1, -1, 1, -1, 1)
  y = X * β + 0.2 * randn(rng, 100)
  s = 1 / 100; λ = 0.15 * lmax(X, y, s)
  # f(c x) scaling: data scaled by c, so the gradient and curvature scale by c²
  t = trajectory(Float32.(c .* X), Float32.(c .* y), s, c^2 * λ, ones(Float32, 32))
  report("C1-scale-$c", "scaled-warm", t)
end
# C2 slow legitimate convergence: highly correlated design
for ρ in (0.99, 0.995, 0.999)
  X = design(rng, 200, 100, ρ); β = zeros(100); β[[3, 30, 60, 90]] .= (2, -1, 1.5, -2)
  y = X * β + 0.1 * randn(rng, 200); s = 1 / 200
  t = trajectory(Float32.(X), Float32.(y), s, 0.02 * lmax(X, y, s), zeros(Float32, 100); maxiter = 30_000)
  report("C2-corr-$ρ", "slow", t)
end
# C3 exact optima: lambda >= lambda_max from 0, and an exactly representable interpolant
let X = design(rng, 60, 20, 0.0), y = randn(rng, 60)
  t = trajectory(Float32.(X), Float32.(y), 1 / 60, 1.5 * lmax(X, y, 1 / 60), zeros(Float32, 20); maxiter = 3000)
  report("C3-lambda-max", "optimum", t)
  Xi = Float64.(rand(rng, -3:3, 60, 20)); βi = Float64.(rand(rng, -2:2, 20))
  t = trajectory(Float32.(Xi), Float32.(Xi * βi), 1 / 64, 0.0, Float32.(βi); maxiter = 3000)
  report("C3-interp", "optimum", t)
end
# C4 inaccurate stagnation: near interpolation, tiny lambda, so the Float32 floor exceeds 1e-5
for σ in (1e-3, 1e-4, 1e-5)
  X = design(rng, 100, 32, 0.5); β = randn(rng, 32); y = X * β + σ * randn(rng, 100); s = 1 / 100
  t = trajectory(Float32.(X), Float32.(y), s, 1e-4 * lmax(X, y, s), zeros(Float32, 32))
  report("C4-sigma-$σ", "inaccurate", t)
end
# C5 large dynamic range of coefficients (ulps differ by orders of magnitude)
for sc in (1e2, 1e4)
  X = design(rng, 120, 40, 0.3); D = [j <= 3 ? 1 / sc : 1.0 for j in 1:40]; Xs = X .* D'
  β = zeros(40); β[1:3] .= sc .* (1, -1, 0.5); β[10:12] .= (0.01, -0.02, 0.03)
  y = Xs * β + 0.05 * randn(rng, 120); s = 1 / 120
  t = trajectory(Float32.(Xs), Float32.(y), s, 0.05 * lmax(Xs, y, s), zeros(Float32, 40))
  report("C5-range-$sc", "range", t)
end

# --- randomized search -------------------------------------------------------------------
for i in 1:nrandom
  r = Xoshiro(10_000 + i)
  n = rand(r, (40, 100, 200, 400)); p = rand(r, (10, 30, 80, 300, 600))
  ρ = rand(r, (0.0, 0.5, 0.9, 0.99)); frac = rand(r, (0.01, 0.05, 0.15, 0.5, 0.9))
  σ = rand(r, (1e-4, 1e-2, 0.2, 1.0)); scale = rand(r, (1e-3, 1e-1, 1.0, 10.0, 1e3))
  warm = rand(r, (:zero, :ones, :perturbed))
  X = design(r, n, p, ρ); k = min(5, p); β = zeros(p); β[randperm(r, p)[1:k]] .= randn(r, k)
  y = X * β + σ * randn(r, n); s = 1 / n
  Xs, ys = scale .* X, scale .* y; λ = frac * lmax(Xs, ys, s)
  x0 = warm == :zero ? zeros(p) : warm == :ones ? ones(p) : β .+ 0.01 .* randn(r, p)
  t = try
    trajectory(Float32.(Xs), Float32.(ys), s, λ, Float32.(x0); maxiter = 5000)
  catch e
    println("random $i failed: ", sprint(showerror, e)); continue
  end
  report("R$i-n$n-p$p-rho$ρ-f$frac-s$σ-c$scale-$warm", "random", t)
end
close(io)
println("done")
