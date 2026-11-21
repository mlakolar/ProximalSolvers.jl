# #320 Stage 2: finite and degenerate cases of the widened gap evaluator against BigFloat(256)
# (research only).   julia --project=<env> s2degen.jl <outprefix>
using Random
include(joinpath(@__DIR__, "s2common.jl"))
outprefix = ARGS[1]
mkpath(dirname(outprefix))
open(io -> provenance(io), outprefix * "-provenance.txt", "w")
BLAS.set_num_threads(1)
rng = MersenneTwister(2026)

cases = Tuple{String, Matrix{Float32}, Vector{Float32}, Float32, Float32, Vector{Float32}, String}[]
add!(name, X, y, s, λ, x, expect) = push!(cases, (name, Float32.(X), Float32.(y), Float32(s), Float32(λ), Float32.(x), expect))

X0 = randn(rng, Float32, 50, 20); y0 = randn(rng, Float32, 50)
λmax0 = maximum(abs, X0' * y0) / 50
add!("y=0, x=0 (P = 0)", X0, zeros(50), 1/50, 0.1λmax0, zeros(20), "P = 0, gap = 0, rel = 0")
add!("x=0, lambda >= lambdamax (x = 0 optimal)", X0, y0, 1/50, 1.5λmax0, zeros(20), "gap = 0")
Xi = Float32[2 1 0; 0 3 1; 1 0 2; 1 1 1]; xi = Float32[1, -2, 3]
add!("exact fit r = 0, x != 0", Xi, Xi * xi, 1, 0.5, xi, "gap = lambda*||x||_1, rel = 1")
add!("near-zero objective: s = 1e-30", X0, y0, 1f-30, 1f-30 * 50 * 0.1λmax0, zeros(20), "rel invariant to common scale")
add!("near-zero objective: data scaled 1e-18", 1f-18 .* X0, 1f-18 .* y0, 1/50, 1f-36 * 0.1λmax0, zeros(20), "P ~ 1e-38 relative to unscaled")
add!("large scale: y ~ 1e18", X0, 1f18 .* y0, 1/50, 1f18 * 0.1λmax0, zeros(20), "finite in Float64")
Xz = copy(X0); Xz[:, 3] .= 0
add!("zero column", Xz, y0, 1/50, 0.1λmax0, randn(rng, Float32, 20), "finite")
add!("tiny lambda 1e-30 lambdamax", X0, y0, 1/50, 1f-30 * λmax0, randn(rng, Float32, 20), "rel close to 1 off the solution")
add!("nonfinite coefficient", X0, y0, 1/50, 0.1λmax0, [Inf32; zeros(Float32, 19)], ":nonfinite")
# a nearly interpolating problem near its minimizer: n < p, lambda = 1e-6 lambdamax, Float64 PGD
# solution rounded to Float32 (the residual is small relative to y: cancellation in y - Xx)
Xw = randn(rng, 40, 120); yw = randn(rng, 40); λw = 1e-6 * maximum(abs, Xw' * yw) / 40
fw = (1 / 40) * PB.LeastSquaresLoss(yw, Xw); xw = zeros(120)
PS.solve!(xw, fw, PB.NormL1(λw), PS.ProximalGradientDescent(), PS.ProximalOptions(maxiter = 20000, ftol = 0, gradtol = 1e-14, allow_f_increases = true))
add!("near-interpolating, rounded Float64 solution", Xw, yw, 1/40, λw, xw, "small P, cancellation in r")
add!("random point", X0, y0, 1/50, 0.1λmax0, randn(rng, Float32, 20), "finite")
# a near-optimal Float32 point (Float32 PGD, strict options), evaluated at its own scale and with
# loss scale and level both multiplied by 1e-30 (same minimizer, objective near 1e-32)
x32 = zeros(Float32, 20)
PS.solve!(x32, Float32(1/50) * PB.LeastSquaresLoss(y0, X0), PB.NormL1(Float32(0.1λmax0)), PS.ProximalGradientDescent(),
          PS.ProximalOptions(maxiter = 20000, ftol = 0, gradtol = 1e-11, allow_f_increases = true))
add!("near-optimal Float32 point", X0, y0, 1/50, 0.1λmax0, x32, "small rel gap")
add!("near-optimal point, s and lambda times 1e-30", X0, y0, 1f-30 / 50, 1f-30 * 0.1λmax0, x32, "rel as unscaled up to rounding of s, lambda")

io = open(outprefix * "-degenerate.tsv", "w")
tsv(io, "julia", "case", "expect", "status", "P_w1", "P_big", "gap_w1_id", "gap_w1_pd", "gap_big", "rel_w1", "rel_w1_pd", "rel_w2", "rel_r32", "rel_big", "relerr_rel_w1")
for (name, X, y, s, λ, x, expect) in cases
  n, p = size(X)
  w1 = gap_widened!(GapWork(n, p), X, y, s, λ, x)
  w2 = gap_widened_blas!(GapWork(n, p), Float64.(X), y, s, λ, x, zeros(p))
  r32 = gap_rounded(X, y, s, λ, x)
  b = all(isfinite, x) ? gap_big(X, y, s, λ, x) : (; P = NaN, gap = NaN, rel = NaN)
  err = (isfinite(b.rel) && b.rel > 0) ? abs(w1.rel - b.rel) / b.rel : abs(w1.rel - b.rel)
  tsv(io, VERSION, name, expect, w1.status, w1.P, b.P, w1.gap_id, w1.gap_pd, b.gap, w1.rel, w1.rel_pd, w2.rel, r32.rel, b.rel, err)
end
close(io)
println(stderr, "s2degen finished")
