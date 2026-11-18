include(joinpath(@__DIR__, "common.jl"))
println("E6 real APG solves with an exact BigFloat check of every certified trial, julia ", VERSION)
using ProximalBase: LeastSquaresLoss, NormL1
const SRC = "<WORK>/ps-353/src/solvers/accelerated_proximal_gradient_descent.jl"
txt = read(SRC, String)
call = "ok, fresh = _bound_certified!(state.dz,"
@assert occursin(call, txt)
txt = replace(txt, call => "ok, fresh = _checked_bound!(state, state.dz,")
# counters + the checker, defined inside PS
Core.eval(PS, quote
  const CNT = Dict{Symbol, Int}(:trials => 0, :accepted => 0, :fresh => 0, :acc_fresh => 0, :rej_cheap => 0, :iters => 0, :viol => 0, :uncertified_zero_step => 0,
                                :se_norm_two_pass => 0, :se_norm_diff_two_pass => 0, :nothing_N => 0)
  const TOL_MIN = Ref(Inf)
  function _checked_bound!(state, args...)
    ok, fresh = _bound_certified!(args...)
    CNT[:trials] += 1; CNT[:fresh] += fresh; CNT[:accepted] += ok; CNT[:acc_fresh] += (ok && fresh); CNT[:rej_cheap] += (!ok && !fresh)
    if ok
      T = eltype(state.x)
      m = state.model; α = m.α
      d = BigFloat.(state.x) .- BigFloat.(state.y)
      ρ = BigFloat(α) * sum(abs2, BigFloat.(m.X) * d) / (BigFloat(state.L) * sum(abs2, d))
      tol = (1 + 4eps(T))^2
      ρ <= tol || (CNT[:viol] += 1)
      TOL_MIN[] = min(TOL_MIN[], Float64((tol - ρ) / tol / eps(T)))
    end
    ok, fresh
  end
end)
# count the two-pass (scaled) fallbacks by re-defining the two functions with a counter
Core.eval(PS, quote
  function _se_norm(::Type{T}, v) where {T}
    CNT[:se_norm_two_pass] += 1
    m = T(maximum(abs, v))
    isfinite(m) || return nothing
    iszero(m) && return _se_zero(T)
    _se_mul(_SE{T}(m), _SE{T}(sqrt(_sumsq_scaled(v, m))))
  end
  function _se_norm_diff(::Type{T}, a, b) where {T}
    CNT[:se_norm_diff_two_pass] += 1
    m = _maxabs_diff(a, b)
    isfinite(m) || return nothing
    iszero(m) && return _se_zero(T)
    s = _sumsq_scaled_diff(a, b, m)
    isfinite(s) || return nothing
    _se_mul(_SE{T}(m), _SE{T}(sqrt(s)))
  end
end)
Base.include_string(PS, txt, SRC)     # redefines the APG solver methods in the loaded module with the checker
rng = Xoshiro(6)
const TOT = Dict{Symbol,Float64}(:solves=>0,:trials=>0,:accepted=>0,:fresh=>0,:acc_fresh=>0,:rej_cheap=>0,:viol=>0,:se_norm_two_pass=>0,:se_norm_diff_two_pass=>0,:iters=>0,:minmargin=>Inf)
function problem(T, n, p, kind, scale)
  X = randn(rng, n, p)
  if kind == :corr
    X = X * (0.2 .+ 0.8 * randn(rng, p, p)) ; X .+= 3 * randn(rng, n)         # strongly correlated columns
  elseif kind == :ill
    X = X * Diagonal(10.0 .^ range(-4, 0, length = p))
  end
  b = zeros(p); b[1:min(5, p)] .= 1 .+ rand(rng, min(5, p))
  y = X * b .+ 0.1 * randn(rng, n)
  Xs, ys = T.(X .* 2.0^scale), T.(y .* 2.0^scale)
  Xs, ys
end
for T in (Float32, Float64)
  for (n, p, kind, scale) in ((100, 40, :gauss, 0), (60, 150, :gauss, 0), (200, 60, :corr, 0), (150, 50, :ill, 0),
                              (100, 40, :gauss, T == Float32 ? 15 : 40), (100, 40, :gauss, T == Float32 ? -15 : -40),
                              (100, 40, :gauss, T == Float32 ? -45 : -400), (100, 40, :gauss, T == Float32 ? -62 : -520), (100, 40, :gauss, T == Float32 ? -75 : -600),
                              (60, 20, :gauss, T == Float32 ? 45 : 400), (60, 20, :gauss, T == Float32 ? 55 : 480))
    Xs, ys = problem(T, n, p, kind, scale)
    for lamfac in (0.5, 0.05, 0.005), α in (1.0, T(0.37))
      all(isfinite, Xs) && all(isfinite, ys) || continue
      f = α == 1.0 ? LeastSquaresLoss(ys, Xs) : α * LeastSquaresLoss(ys, Xs)
      λmax = maximum(abs, Xs' * ys) * Float64(α)
      g = NormL1(T(lamfac * λmax))
      x = zeros(T, p)
      for (k, v) in PS.CNT; PS.CNT[k] = 0; end
      local r
      try
        r = solve!(x, f, g, AccProxGradDescent(), ProximalOptions(maxiter = 300))
      catch err
        println("  ", T, " ", (n, p, kind, scale), " solve threw ", typeof(err)); continue
      end
      c = PS.CNT
      TOT[:solves] += 1
      for k in (:trials, :accepted, :fresh, :acc_fresh, :rej_cheap, :viol, :se_norm_two_pass, :se_norm_diff_two_pass); TOT[k] += c[k]; end
      TOT[:iters] += r.iterations
      TOT[:minmargin] = min(TOT[:minmargin], PS.TOL_MIN[])
      @printf("  %-8s n=%3d p=%3d %-5s 2^%3d lam=%.3f a=%.2f it=%3d conv=%-5s trials=%4d acc=%4d (by fresh product %3d) fresh_used=%3d viol=%d two-pass(norm=%d, diff=%d)\n",
              T, n, p, kind, scale, lamfac, Float64(α), r.iterations, r.converged, c[:trials], c[:accepted], c[:acc_fresh], c[:fresh], c[:viol], c[:se_norm_two_pass], c[:se_norm_diff_two_pass])
    end
  end
end

println("TOTAL ", sort(collect(TOT)))
