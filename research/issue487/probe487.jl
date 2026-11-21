# #487 probe: inflated λmax from a free coordinate (offset response), weighted NormL1 / ElasticNet / GroupNormL2,
# PGD and APG, Float64 and Float32, plus logistic PGD (Float64). Rules:
#   cur   : the solver as merged (λmax = ‖∇f(0)‖)
#   profA : prototype — λmax replaced by ‖∇f(x_F*)‖, x_F* = minimizer over the free (zero-weight) coordinates with the
#           penalized coordinates at zero (ridge-penalized for ElasticNet λ2 > 0), computed in T
# Independent BigFloat reference by coordinate descent.
using ProximalSolvers, ProximalBase, LinearAlgebra, Random, Printf
const PS = ProximalSolvers
setprecision(BigFloat, 256)

const PROTO = Ref{Any}(nothing)        # nothing => current rule; otherwise a Vector{T} = ∇f(x_F*) computed in T
const NCHECK = Ref(0)
function PS._lambda_max!(state, nrm)
  state.λmax < 0 || return state.λmax
  if PROTO[] === nothing
    PS._zero_gradient!(state.xhat, state, state.model)
    state.λmax = nrm(state.xhat)
  else
    state.xhat .= PROTO[]
    state.λmax = nrm(state.xhat)
  end
end
PS._lambda_max!(state) = PS._lambda_max!(state, PS._norm_inf)

sigmoid(t) = 1 / (1 + exp(-t))
softplus(t) = t > 0 ? t + log1p(exp(-t)) : log1p(exp(t))

struct BP
  loss::Symbol
  X::Matrix{BigFloat}; y::Vector{BigFloat}
  c::Vector{BigFloat}            # per coordinate (or per group) L1 coefficient
  λ2::BigFloat
  groups::Union{Nothing, Vector{UnitRange{Int}}}
end
smooth(P, b) = P.loss === :ls ? sum(abs2, P.y - P.X * b) / 2 : sum(softplus.(P.X * b) .- P.y .* (P.X * b))
grad(P, b) = P.loss === :ls ? P.X' * (P.X * b - P.y) : P.X' * (sigmoid.(P.X * b) .- P.y)
pen(P, b) = (P.groups === nothing ? sum(P.c .* abs.(b)) : sum(P.c[k] * norm(b[G]) for (k, G) in enumerate(P.groups))) +
  P.λ2 * sum(abs2, b) / 2
obj(P, b) = smooth(P, b) + pen(P, b)
function scores(P, b)
  g = grad(P, b) .+ P.λ2 .* b
  P.groups === nothing ?
    [iszero(b[j]) ? max(abs(g[j]) - P.c[j], big(0)) : abs(g[j] + P.c[j] * sign(b[j])) for j in eachindex(b)] :
    [iszero(norm(b[G])) ? max(norm(g[G]) - P.c[k], big(0)) : norm(g[G] + P.c[k] * b[G] / norm(b[G])) for (k, G) in enumerate(P.groups)]
end
soft(z, c) = sign(z) * max(abs(z) - c, big(0))
function logistic_coord(P, b, j)
  xj = P.X[:, j]; base = P.X * b - xj * b[j]; c = P.c[j]
  d(β) = xj' * (sigmoid.(base + xj * β) .- P.y)
  h(β) = (s = sigmoid.(base + xj * β); xj' * (s .* (1 .- s)))
  d0 = d(big(0)); abs(d0) <= c && return big(0)
  target = d0 < -c ? -c : c; β = b[j]
  for _ in 1:200
    v = d(β) - target; abs(v) < big(1e-70) && break
    β -= v / h(β)
  end
  β
end
# CD to a tiny KKT; groups: singleton groups except the fixtures' free group, which is solved by its exact LS block
function reference(P; sweeps = 400_000, b0 = zeros(BigFloat, size(P.X, 2)), tol = big(1e-60))
  b = copy(b0); p = size(P.X, 2)
  blocks = P.groups === nothing ? [j:j for j in 1:p] : P.groups
  cc = P.groups === nothing ? P.c : P.c
  sc = max(maximum(abs, grad(P, zeros(BigFloat, p))), maximum(P.c), big(1))
  for s in 1:sweeps
    for (k, G) in enumerate(blocks)
      if P.loss === :logistic
        b[first(G)] = logistic_coord(P, b, first(G)); continue
      end
      XG = P.X[:, G]; r = P.y - P.X * b + XG * b[G]
      if length(G) == 1
        nj = sum(abs2, XG); b[first(G)] = soft(dot(XG, r), cc[k]) / (nj + P.λ2)
      else
        @assert iszero(cc[k])            # free multi-column group: exact (ridge) LS block
        b[G] .= (XG' * XG + P.λ2 * I) \ (XG' * r)
      end
    end
    maximum(scores(P, b)) / sc < tol && return b
  end
  error("reference did not converge")
end

# x_F*: minimizer over free coordinates F (penalized at 0); returns the full-length gradient ∇f(x_F*) in type of X
function free_fit_gradient(loss, X::Matrix{T}, y::Vector{T}, F, λ2) where T
  p = size(X, 2); b = zeros(T, p)
  if !isempty(F)
    XF = X[:, F]
    if loss === :ls
      b[F] .= iszero(λ2) ? (XF \ y) : ([XF; sqrt(T(λ2)) * I(length(F))] \ [y; zeros(T, length(F))])
    else
      bF = zeros(T, length(F))
      for _ in 1:100                                  # Newton on the free logistic block
        η = XF * bF; s = sigmoid.(η)
        g = XF' * (s .- y); H = XF' * (XF .* (s .* (1 .- s)))
        bF .-= H \ g; norm(g, Inf) < 1e-14 * length(y) && break
      end
      b[F] .= bF
    end
  end
  g = loss === :ls ? X' * (X * b - y) : X' * (sigmoid.(X * b) .- y)
  g .+= T(λ2) .* b
  g
end

const HDR = join(["fixture", "pen", "λ2", "T", "method", "rule", "gradtol", "converged", "iter", "stagn", "f_incr",
  "gconv", "fconv", "xconv", "lmax", "lmax_ref_T", "lmax_P0", "relexcess", "free_score_rel", "kkt_rel_ref", "coef_relerr"], '\t')

function run!(rows, name, loss, X::Matrix{T}, y::Vector{T}, λ0, w::Vector{T}, λ2, pen;
              methods = (ProximalGradientDescent(), AccProxGradDescent()), groups = nothing, gw = nothing) where T
  c = groups === nothing ? big(T(λ0)) .* big.(w) : big(T(λ0)) .* big.(gw)
  P = BP(loss, big.(X), big.(y), c, big(T(λ2)), groups)
  F = groups === nothing ? findall(iszero, w) : reduce(vcat, [collect(G) for (k, G) in enumerate(groups) if iszero(gw[k])]; init = Int[])
  # reference: start from the BigFloat free fit
  b0 = zeros(BigFloat, size(X, 2))
  if !isempty(F) && loss === :ls
    XF = P.X[:, F]; b0[F] .= (XF' * XF + P.λ2 * I) \ (XF' * P.y)
  elseif F == [1] && loss === :logistic          # free intercept column of ones: logit of the mean
    bn = zeros(Float64, size(X, 2))
    solve!(bn, LogisticLoss(Float64.(y), Float64.(X)), NormL1(Float64(λ0), Float64.(w)), ProxNewton(maxiter = 500, tol = 1e-13))
    b0 .= big.(bn)
  end
  bstar = loss === :logistic ? b0 : reference(P; b0)   # logistic: Float64 ProxNewton (tol 1e-13) reference
  Fstar = obj(P, bstar)
  gref = grad(P, b0) .+ P.λ2 .* b0                      # exact gradient at x_F* (LS); logistic uses T-proto below
  Pidx = setdiff(1:size(X, 2), F)
  g0 = grad(P, zeros(BigFloat, size(X, 2)))
  lmaxP0 = isempty(Pidx) ? 0.0 : Float64(maximum(abs, g0[Pidx]))
  Gref_T = free_fit_gradient(loss, X, y, F, λ2)
  lref_exact = loss === :ls ? (groups === nothing ? maximum(abs, gref) : maximum(norm(gref[G]) for G in groups)) : big(PS._norm_inf(Gref_T))
  scale_ref = groups === nothing ? max.(c, lref_exact) : max.(c, lref_exact)
  for method in methods, rule in (:cur, :profA), gt in (1e-5, 1e-8)
    rule === :profA && gt != 1e-5 && continue
    PROTO[] = rule === :cur ? nothing : Gref_T
    b = zeros(T, size(X, 2))
    l = loss === :ls ? LeastSquaresLoss(y, X) : LogisticLoss(y, X)
    r = solve!(b, l, pen, method, ProximalOptions(gradtol = gt))
    PROTO[] = nothing
    bb = big.(b)
    sc = scores(P, bb)
    gb = grad(P, bb) .+ P.λ2 .* bb
    fs = isempty(F) ? NaN : Float64(maximum(abs, gb[F]) / lref_exact)
    lmax = groups === nothing ? Float64(maximum(abs, big.(T.(g0)))) : Float64(maximum(norm(g0[G]) for G in groups))
    lrefT = groups === nothing ? Float64(PS._norm_inf(Gref_T)) : Float64(maximum(norm(Gref_T[G]) for G in groups))
    row = join([name, string(nameof(typeof(pen))), string(λ2), string(T), method isa ProximalGradientDescent ? "PGD" : "APG",
      String(rule), string(gt), r.converged, r.iterations, r.stagnated, r.f_increased, r.grad_converged, r.f_converged,
      r.x_converged, @sprintf("%.3e", lmax), @sprintf("%.3e", lrefT), @sprintf("%.3e", lmaxP0),
      @sprintf("%.2e", Float64((obj(P, bb) - Fstar) / abs(Fstar))), @sprintf("%.2e", fs),
      @sprintf("%.2e", Float64(maximum(sc ./ scale_ref))),
      @sprintf("%.2e", Float64(maximum(abs, bb - bstar) / maximum(abs, bstar)))], '\t')
    push!(rows, row); println(row); flush(stdout)
  end
end

function profiled_l0max(X, y, w, F, λ2)
  Fy = Float64.(y); FX = Float64.(X)
  g = free_fit_gradient(:ls, FX, Fy, F, λ2)
  maximum(abs(g[j]) / w[j] for j in eachindex(w) if w[j] > 0)
end

function main()
  rows = String[]
  println(HDR)
  part = get(ENV, "PROBE_PART", "all")
  for T in (Float64, Float32)
    part == "logistic" && break
    # --- O1: #400 offset fixture, one free intercept, unit weights on the rest; offsets 0 (centered control) .. 1e6
    rng = MersenneTwister(400)
    Xo = hcat(ones(50), randn(rng, 50, 9))
    sig = Xo[:, 2:5] * [2.0, -1.5, 1.0, 0.5] .+ 0.5 .* randn(rng, 50)
    w1 = vcat(0.0, ones(9))
    for off in (0.0, 1e2, 1e4, 1e6), λ2 in (0.0, 1.0, 25.0), pk in (:l1, :en)
      pk === :l1 && λ2 != 0 && continue
      y = off .+ sig
      λ0 = 0.5 * profiled_l0max(Xo, y, w1, [1], λ2)
      pen = pk === :l1 ? NormL1(T(λ0), T.(w1)) : ElasticNet(T(λ0), T(λ2), T.(w1))
      run!(rows, "O1 off=$(off)", :ls, T.(Xo), T.(y), λ0, T.(w1), λ2, pen)
    end
    # reduced-design control for O1 (off=1e6, λ2 = 0): project out the intercept, drop it
    y = 1e6 .+ sig
    Xr = Xo[:, 2:end] .- sum(Xo[:, 2:end]; dims = 1) ./ 50; yr = y .- sum(y) / 50
    λ0 = 0.5 * profiled_l0max(Xo, y, w1, [1], 0.0)
    run!(rows, "O1 reduced control", :ls, T.(Xr), T.(yr), λ0, ones(T, 9), 0.0, NormL1(T(λ0), ones(T, 9)))
    # --- O2: #464 case O (intercept + one predictor free, random weights), offset 1e6
    rng = MersenneTwister(400)
    Xo2 = hcat(ones(50), randn(rng, 50, 9))
    yo2 = 1e6 .+ Xo2[:, 2:5] * [2.0, -1.5, 1.0, 0.5] .+ 0.5 .* randn(rng, 50)
    wo = vcat(0.0, 0.0, 2.0 .^ (4 .* rand(MersenneTwister(401), 8) .- 2))
    for λ2 in (0.0, 1.0), pk in (:l1, :en)
      pk === :l1 && λ2 != 0 && continue
      λ0 = 0.5 * profiled_l0max(Xo2, yo2, wo, [1, 2], λ2)
      pen = pk === :l1 ? NormL1(T(λ0), T.(wo)) : ElasticNet(T(λ0), T(λ2), T.(wo))
      run!(rows, "O2 case O", :ls, T.(Xo2), T.(yo2), λ0, T.(wo), λ2, pen)
    end
    # --- FC: a free non-intercept column with a large mean (no intercept; centering y is not a remedy)
    rng = MersenneTwister(402)
    Z = randn(rng, 50, 10); Z[:, 1] .+= 1e3
    yfc = 50.0 .* Z[:, 1] .+ Z[:, 2:5] * [2.0, -1.5, 1.0, 0.5] .+ 0.5 .* randn(rng, 50)
    wfc = vcat(0.0, ones(9))
    for λ2 in (0.0, 1.0), pk in (:l1, :en)
      pk === :l1 && λ2 != 0 && continue
      λ0 = 0.5 * profiled_l0max(Z, yfc, wfc, [1], λ2)
      pen = pk === :l1 ? NormL1(T(λ0), T.(wfc)) : ElasticNet(T(λ0), T(λ2), T.(wfc))
      run!(rows, "FC free column", :ls, T.(Z), T.(yfc), λ0, T.(wfc), λ2, pen)
    end
    # --- G: GroupNormL2, free intercept group, singleton groups otherwise, offset 1e6
    groups = [1:1, 2:2, 3:3, 4:4, 5:5, 6:6, 7:7, 8:8, 9:9, 10:10]
    gw = vcat(0.0, ones(9))
    λ0 = 0.5 * profiled_l0max(Xo, 1e6 .+ sig, w1, [1], 0.0)
    run!(rows, "G group offset", :ls, T.(Xo), T.(1e6 .+ sig), λ0, T.(w1), 0.0, GroupNormL2(T(λ0), groups, T.(gw)); groups, gw = T.(gw))
  end
  # --- L: logistic PGD, free intercept, imbalanced classes (Float64)
  rng = MersenneTwister(7)
  Xl = hcat(ones(200), randn(rng, 200, 5))
  for b0 in (0.0, 3.0, 5.0)
    yl = Float64.(rand(MersenneTwister(8), 200) .< sigmoid.(b0 .+ Xl[:, 2:6] * [1.0, -1.0, 0.5, 0, 0]))
    wl = vcat(0.0, ones(5))
    g = free_fit_gradient(:logistic, Xl, yl, [1], 0.0)
    λ0 = 0.5 * maximum(abs, g[2:end])
    run!(rows, "L logistic b0=$(b0) ybar=$(sum(yl)/200)", :logistic, Xl, yl, λ0, wl, 0.0, NormL1(λ0, wl);
         methods = (ProximalGradientDescent(),))
  end
  out = joinpath(@__DIR__, "probe487-$(VERSION).tsv")
  open(out, "w") do io; println(io, HDR); foreach(r -> println(io, r), rows); end
end
main()
