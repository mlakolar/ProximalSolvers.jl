# X1 experiment 4b: independent BigFloat-256 check of every certified (C) result of the one-axis scans (exp4), all trees.
# For each: true relative gap <= my (P-D)/D from my own dual point <= reported gap <= 1e-4.   julia --project=ps-353 exp4b_cert.jl Float32|Float64
include("x1lib.jl")
const T = ARGS[1] == "Float32" ? Float32 : Float64
sqrtlam_max(X, y) = (sy = maximum(abs, Float64.(y)); sx = maximum(abs, Float64.(X)); (iszero(sy) || iszero(sx)) ? 0.0 : norm((Float64.(X)./sx)' * (Float64.(y)./sy), Inf) / norm(Float64.(y)./sy) * sx)
function inst(sy, sx; col1 = false, n = 30, p = 8, lf = 0.3)
  rng = Xoshiro(11); X0 = randn(rng, n, p); y0 = randn(rng, n)
  if col1; X = T.(X0); X[:, 1] = T.(ldexp.(X0[:, 1], sx)); else X = T.(ldexp.(X0, sx)); end
  y = T.(ldexp.(y0, sy))
  (all(isfinite, X) && all(isfinite, y) && any(!iszero, X) && any(!iszero, y)) || return nothing
  λ = try T(lf*sqrtlam_max(X, y)) catch; return nothing end
  (isfinite(λ) && λ > 0) || return nothing
  X, y, λ
end
function check(X, y, λ, x)
  setprecision(BigFloat, 256) do
    Xb, yb, xb, λb = big.(X), big.(y), big.(x), big(λ)
    r = yb .- Xb * xb; N = sqrt(sum(abs2, r)); P = N + λb*sum(abs, xb)
    iszero(N) && return NaN
    g = maximum(abs, Xb' * r) / N; t = min(big(1), λb / g); D = t * sum(yb .* r) / N
    D > 0 ? Float64((P - D) / D) : Inf
  end
end
rs = T === Float32 ? (-170:140) : (-1100:1040)
scans = [("y", s -> inst(s, 0)), ("X", s -> inst(0, s)), ("joint", s -> inst(s, s)), ("col1", s -> inst(0, s; col1 = true)), ("opp", s -> inst(s, -s)), ("opp2", s -> inst(-s, s))]
tot = Dict(t => 0 for t in TNAMES); bad = Dict(t => 0 for t in TNAMES); nanc = Dict(t => 0 for t in TNAMES); worstrat = Dict(t => 0.0 for t in TNAMES); maxgap = Dict(t => 0.0 for t in TNAMES)
for (nm, f) in scans, s in rs
  i = f(s); i === nothing && continue
  X, y, λ = i
  for t in TNAMES
    P = getproperty(TREES, t)
    xs = zeros(T, size(X, 2))
    r = try with_logger(NullLogger()) do; P.solve!(xs, SqrtLeastSquaresLoss(y, X), NormL1(λ), P.CDSolver(; order = :cyclic, rng = Xoshiro(5))); end catch; continue end
    (r.converged && isfinite(r.gap)) || continue
    tot[t] += 1
    mine = check(X, y, λ, xs)
    isfinite(mine) || (nanc[t] += 1; continue)
    maxgap[t] = max(maxgap[t], Float64(r.gap))
    worstrat[t] = max(worstrat[t], mine / max(Float64(r.gap), floatmin()))
    (mine > r.gap || r.gap > 1e-4) && (bad[t] += 1; println("VIOLATION ", nm, " s=", s, " ", t, " mine=", mine, " reported=", r.gap))
  end
end
println("# ", T, " Julia ", VERSION, ": certified scan results checked in BigFloat: ", join(["$t: $(tot[t]) (violations $(bad[t]), unchecked $(nanc[t]), max reported gap $(maxgap[t]), worst mine/reported $(worstrat[t]))" for t in TNAMES], " | "))
