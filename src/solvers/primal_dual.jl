"""
    CondatVu(; τ = nothing, σ = nothing, norm_d = nothing, L = nothing,
               abstol = 1e-6, reltol = 1e-4, adaptive = true, restart = true,
               checkevery = 25, max_adaptations = 50)

Primal–dual splitting for convex `f(x) + g(x) + h(D*x)`. Use
`solve!(x, f, g, h, D, method, options; y = nothing, gap = nothing)`.
`f` is smooth with a globally Lipschitz gradient; `g` and `h` are proximable.
`x` is a floating vector (including `SparseIterate`), and `D` a real matrix.
The dual proximal step uses `Conjugate(h)` and cached Moreau buffers.

Steps satisfy `τ*(L/2 + σ*norm_d^2) < 1`. `L` defaults to `lipschitz(f)`.
Some `lipschitz` implementations, including least squares, return a numerical
estimate; supply a known `L` bound when a certified step condition is needed.
`norm_d` defaults to the guaranteed matrix bound
`√(opnorm(D, 1)*opnorm(D, Inf))`; for faster steps, supply a tighter known
bound. ProximalBase's Lanczos estimate `sqrt(opnorm2(D))` can guide that
choice, but is not a certified upper bound. Explicit steps are checked
against the supplied bounds. Automatic steps have a 0.99 safety factor.

Both KKT residuals must meet absolute plus relative tolerances; small iterate
changes alone do not certify convergence. `adaptive` balances normalized
residuals, and `restart` compares the current point with the running average
using a proximal residual check every `checkevery` iterations. Restarts use
PDLP's sufficient-decrease, stalled-decrease and long-epoch criteria and its
smoothed primal-weight update (Applegate et al., 2021; also used by
CovarianceSelection's CLIME PDHG). These are heuristics for general convex
composites, not PDLP's LP convergence-rate theorem. At most
`max_adaptations` changes/restarts are allowed, after which fixed-step
Condat–Vũ convergence applies under the stated bounds.

Ordinary iterations use one product each by `D` and `D'`, two proximal calls
and one gradient call. Restart checks cost additional products and proximal
calls, all included in the result's counters. No matrices are factorized.
`Float32` iterates keep `Float32` buffers and steps.

Warm start with `CondatVu(; τ = res.τ, σ = res.σ, ...)` and `y = res.y`;
`x` and a supplied `y` are overwritten. `res` aliases those arrays.

Of `ProximalOptions`, the iteration/time/call limits, tracing and callback are
used. `gaptol > 0` selects a user-supplied relative duality gap
`gap(x, y)` as the stopping rule, evaluated every `gapevery` iterations and
at return. By default this uses `duality_gap(f, g, h, D, x, y)` when
its conjugate values are available. A custom callback must provide a valid
certificate for this composite problem. With `gaptol = 0`, residuals are used.
Gap computations and user callbacks are excluded from the evaluation counters. `ftol`, `xtol`, `gradtol` and
`allow_f_increases` are not used.
"""
struct CondatVu{T<:AbstractFloat} <: ProximalSolver
  τ::Union{Nothing,T}
  σ::Union{Nothing,T}
  norm_d::Union{Nothing,T}
  L::Union{Nothing,T}
  abstol::T
  reltol::T
  adaptive::Bool
  restart::Bool
  checkevery::Int
  max_adaptations::Int
end

function CondatVu(; τ::Union{Nothing,Real} = nothing, σ::Union{Nothing,Real} = nothing,
                  norm_d::Union{Nothing,Real} = nothing, L::Union{Nothing,Real} = nothing,
                  abstol::Real = 1e-6, reltol::Real = 1e-4,
                  adaptive::Bool = true, restart::Bool = true,
                  checkevery::Integer = 25, max_adaptations::Integer = 50)
  for (name, v) in ((:τ, τ), (:σ, σ))
    v === nothing || (isfinite(v) && v > 0) || throw(ArgumentError("$name must be finite and positive"))
  end
  for (name, v) in ((:norm_d, norm_d), (:L, L))
    v === nothing || (isfinite(v) && v >= 0) || throw(ArgumentError("$name must be finite and nonnegative"))
  end
  isfinite(abstol) && abstol >= 0 && isfinite(reltol) && reltol >= 0 && abstol + reltol > 0 ||
    throw(ArgumentError("tolerances must be finite, nonnegative and not both zero"))
  checkevery > 0 && max_adaptations >= 0 || throw(ArgumentError("invalid adaptation limits"))
  T = float(promote_type(typeof(abstol), typeof(reltol), map(v -> v === nothing ? Bool : typeof(v), (τ, σ, norm_d, L))...))
  cv(v) = v === nothing ? nothing : T(v)
  CondatVu{T}(cv(τ), cv(σ), cv(norm_d), cv(L), T(abstol), T(reltol), adaptive, restart, checkevery, max_adaptations)
end
Base.summary(::CondatVu) = "Condat–Vũ primal–dual splitting"

"""
    PrimalDualResults

Result of [`CondatVu`](@ref): `minimizer`, `minimum`, `y` (dual minimizer),
`τ`, `σ` (final steps), `iterations`, `converged`, primal and dual KKT
residuals `r_norm`, `s_norm`, their tolerances `eps_pri`, `eps_dual`,
`restarts`, `adaptations`, `gap` (relative certificate or `NaN`), `trace`,
`f_calls`, `grad_calls`, `prox_calls`, `D_calls`, `Dt_calls`, and
`call_limit_reached`. Counts include initialization, restart checks and final
objective evaluation. Residuals refer to the returned pair, including after
an average is selected. `minimizer` and `y` alias the supplied arrays.
"""
struct PrimalDualResults{T,X,Y,M}
  minimizer::X
  minimum::T
  y::Y
  τ::T
  σ::T
  iterations::Int
  converged::Bool
  r_norm::T
  s_norm::T
  eps_pri::T
  eps_dual::T
  restarts::Int
  adaptations::Int
  gap::Float64
  trace::OptimizationTrace{M}
  f_calls::Int
  grad_calls::Int
  prox_calls::Int
  D_calls::Int
  Dt_calls::Int
  call_limit_reached::Bool
end
Base.summary(::PrimalDualResults) = "Condat–Vũ primal–dual splitting"
for name in (:minimizer, :minimum, :iterations, :converged, :f_calls, :grad_calls, :prox_calls, :call_limit_reached)
  @eval $name(r::PrimalDualResults) = getfield(r, $(QuoteNode(name)))
end
function Base.show(io::IO, r::PrimalDualResults)
  println(io, summary(r))
  @printf io " * Minimum: %e\n * Iterations: %d\n * Converged: %s\n" r.minimum r.iterations r.converged
  @printf io " * KKT residuals: %.2e / %.2e (tolerances %.2e / %.2e)\n" r.r_norm r.s_norm r.eps_pri r.eps_dual
  @printf io " * Steps: τ = %.2e, σ = %.2e; restarts: %d\n" r.τ r.σ r.restarts
end

# All arithmetic buffers are dense vectors; the primal iterate can retain
# SparseIterate storage, so D*x can use the sparse-support product methods.
struct _PDState{T,X,Y}
  x::X
  y::Y
  xp::Vector{T}
  yp::Vector{T}
  Dx::Vector{T}
  Dxp::Vector{T}
  Dty::Vector{T}
  Dtyp::Vector{T}
  grad::Vector{T}
  gradp::Vector{T}
  tx::Vector{T}
  ty::Vector{T}
end
function _pd_state(x::AbstractVector{T}, y::Vector{T}, f, D) where {T}
  p, m = length(x), length(y)
  st = _PDState(x, y, zeros(T,p), zeros(T,m), zeros(T,m), zeros(T,m),
                zeros(T,p), zeros(T,p), zeros(T,p), zeros(T,p), zeros(T,p), zeros(T,m))
  _pd_initialize!(st, f, D)
  st
end
function _pd_initialize!(s, f, D)
  mul!(s.Dx, D, s.x)
  mul!(s.Dty, D', s.y)
  gradient!(s.grad, f, s.x)
end

# KKT residuals at the updated pair, using the subgradients supplied by its
# two proximal steps. Caches make the next step's products reusable.
function _pd_step!(s::_PDState{T}, f, g, hc, D, τ, σ, abstol, reltol) where {T}
  copyto!(s.xp, s.x); copyto!(s.yp, s.y)
  copyto!(s.Dxp, s.Dx); copyto!(s.Dtyp, s.Dty); copyto!(s.gradp, s.grad)
  @. s.tx = s.xp - τ * (s.gradp + s.Dtyp)
  prox!(s.x, g, s.tx, τ)
  _drop!(s.x)
  mul!(s.Dx, D, s.x)
  @. s.ty = s.yp + σ * (2 * s.Dx - s.Dxp)
  prox!(s.y, hc, s.ty, σ)
  mul!(s.Dty, D', s.y)
  gradient!(s.grad, f, s.x)
  r2 = s2 = a2 = b2 = zero(T)
  @inbounds for i in eachindex(s.x)
    a = (s.xp[i] - s.x[i]) / τ - s.gradp[i] - s.Dtyp[i]
    r2 += abs2(a + s.grad[i] + s.Dty[i])
    a2 += abs2(a)
  end
  @inbounds for i in eachindex(s.y)
    b = (s.yp[i] - s.y[i]) / σ + 2*s.Dx[i] - s.Dxp[i]
    s2 += abs2(b - s.Dx[i])
    b2 += abs2(b)
  end
  ep = sqrt(T(length(s.x))) * abstol + reltol * max(sqrt(a2), norm(s.grad), norm(s.Dty))
  ed = sqrt(T(length(s.y))) * abstol + reltol * max(sqrt(b2), norm(s.Dx))
  (sqrt(r2), sqrt(s2), ep, ed)
end
_pd_merit(r) = hypot(r[1] / max(r[3], eps(typeof(r[3]))), r[2] / max(r[4], eps(typeof(r[4]))))
_pd_converged(r) = r[1] <= r[3] && r[2] <= r[4]

# τ = η/ω, σ = η*ω. Solving η*L/(2ω) + η²*norm_d² = 0.99
# preserves the step condition even when the primal weight changes.
function _pd_steps(ω::T, L, nD) where {T}
  a, b = L / (2ω), nD*nD
  η = iszero(b) ? (iszero(a) ? one(T) : T(0.99)/a) : 2*T(0.99)/(a + sqrt(a*a + 4*b*T(0.99)))
  η/ω, η*ω
end
function _pd_startsteps(method, f, D, ::Type{T}) where {T}
  L = T(method.L === nothing ? lipschitz(f) : method.L)
  nD = T(method.norm_d === nothing ? sqrt(T(opnorm(D,1)))*sqrt(T(opnorm(D,Inf))) : method.norm_d)
  isfinite(L) && L >= 0 && isfinite(nD) || throw(ArgumentError("finite global L and norm_d bounds are required"))
  τ, σ = method.τ, method.σ
  if τ === nothing && σ === nothing
    τ, σ = _pd_steps(one(T), L, nD)
  elseif τ === nothing
    σ = T(σ); τ = iszero(L/2 + σ*nD*nD) ? one(T) : T(0.99)/(L/2 + σ*nD*nD)
  elseif σ === nothing
    τ = T(τ)
    τ*L/2 < 1 || throw(ArgumentError("τ*L/2 must be below one"))
    σ = iszero(nD) ? one(T) : T(0.99)*(inv(τ)-L/2)/(nD*nD)
  end
  τ, σ = T(τ), T(σ)
  isfinite(τ) && τ > 0 && isfinite(σ) && σ > 0 && τ*(L/2 + σ*nD*nD) < 1 ||
    throw(ArgumentError("steps must satisfy τ*(L/2 + σ*norm_d^2) < 1 in the iterate's precision"))
  τ, σ, L, nD
end

function solve!(x::AbstractVector{T}, f::AbstractFunction, g::AbstractFunction,
                h::AbstractFunction, D::AbstractMatrix{<:Real}, method::CondatVu,
                options::ProximalOptions = ProximalOptions();
                y::Union{Nothing,Vector{T}} = nothing, gap = nothing) where {T<:AbstractFloat}
  issmooth(f) && isconvex(f) || throw(ArgumentError("CondatVu needs a smooth convex f"))
  isproximable(g) && isconvex(g) && isproximable(h) && isconvex(h) ||
    throw(ArgumentError("CondatVu needs convex proximable g and h"))
  size(D,2) == length(x) || throw(DimensionMismatch("D must have length(x) columns"))
  y === nothing && (y = zeros(T, size(D,1)))
  length(y) == size(D,1) || throw(DimensionMismatch("y must have size(D,1) entries"))
  (Base.mightalias(x,y) || Base.mightalias(x,D) || Base.mightalias(y,D)) && throw(ArgumentError("x, y and D must not alias"))
  all(isfinite,x) && all(isfinite,y) || throw(ArgumentError("initial iterates must be finite"))
  if options.gaptol > 0 && gap === nothing
    gap = (x,y) -> begin
      cert = duality_gap(f,g,h,D,x,y)
      _relative_gap(cert.primal, cert.dual)
    end
  end
  t0 = time()
  τ, σ, L, nD = _pd_startsteps(method, f, D, T)
  s = _pd_state(x,y,f,D)
  hc = Conjugate(h)
  a, rtol = T(method.abstol), T(method.reltol)
  r = (T(Inf),T(Inf),T(Inf),T(Inf))
  tr = OptimizationTrace{typeof(method)}()
  # Averaging and restart storage are only needed when enabled.
  candidate = method.restart ? _pd_state(copy(x),copy(y),f,D) : nothing
  xa = method.restart ? zeros(T,length(x)) : T[]
  ya = method.restart ? zeros(T,length(y)) : T[]
  xr, yr = method.restart ? (Vector(x),copy(y)) : (T[],T[])
  epoch = 0
  reference = previous = T(Inf)
  adaptations = restarts = iteration = 0
  gradcount = dc = dtc = method.restart ? 2 : 1
  pc = fc = 0
  done = limited = stopped = false
  relgap = NaN
  gapiter = -1
  while !done && !limited && !stopped && iteration < options.maxiter && time()-t0 <= options.time_limit
    iteration += 1
    r = _pd_step!(s,f,g,hc,D,τ,σ,a,rtol)
    pc += 2; gradcount += 1; dc += 1; dtc += 1
    all(isfinite,r) || break
    merit = _pd_merit(r)
    if method.restart && adaptations < method.max_adaptations
      epoch += 1
      @. xa += (s.x - xa)/epoch
      @. ya += (s.y - ya)/epoch
      isinf(reference) && (reference = merit)
      if iteration % method.checkevery == 0
        copyto!(candidate.x,xa); copyto!(candidate.y,ya)
        _pd_initialize!(candidate,f,D)
        ra = _pd_step!(candidate,f,g,hc,D,τ,σ,a,rtol)
        pc += 2; gradcount += 2; dc += 2; dtc += 2
        ma = _pd_merit(ra)
        best = min(ma,merit)
        due = best <= T(0.2)*reference || (best <= T(0.8)*reference && best > previous) || epoch >= T(0.36)*iteration
        if due
          if ma < merit
            copyto!(s.x,candidate.x); copyto!(s.y,candidate.y)
            copyto!(s.Dx,candidate.Dx); copyto!(s.Dty,candidate.Dty); copyto!(s.grad,candidate.grad)
            r = ra; merit = ma
          end
          dx, dy = norm_diff(s.x,xr), norm_diff(s.y,yr)
          ω = sqrt(σ/τ)
          if method.adaptive && dx > eps(T) && dy > eps(T)
            ω = clamp(sqrt(ω * dy/dx), T(1e-6), T(1e6))
            τ,σ = _pd_steps(ω,L,nD)
          end
          copyto!(xr,s.x); copyto!(yr,s.y)
          epoch = 0; reference = merit
          restarts += 1; adaptations += 1
        end
        previous = best
      end
    elseif method.adaptive && adaptations < method.max_adaptations && iteration % method.checkevery == 0
      rp, rd = r[1]/max(r[3],eps(T)), r[2]/max(r[4],eps(T))
      if rp > 10rd || rd > 10rp
        ω = sqrt(σ/τ) * (rp > rd ? T(0.5) : T(2))
        τ,σ = _pd_steps(clamp(ω,T(1e-6),T(1e6)),L,nD)
        adaptations += 1
      end
    end
    done = _pd_converged(r)
    if options.gaptol > 0
      if iteration % options.gapevery == 0
        relgap = Float64(gap(x,y)); gapiter = iteration
        done = isfinite(relgap) && 0 <= relgap <= options.gaptol
      else
        done = false
      end
    end
    if (options.store_trace || options.show_trace || options.callback !== nothing) && iteration % options.print_every == 0
      F = f(x)+g(x)+h(s.Dx); fc += 1
      md = Dict{String,Any}("primal_residual"=>r[1], "dual_residual"=>r[2], "σ"=>σ)
      if options.extended_trace
        md["x"] = copy(x); md["y"] = copy(y)
      end
      os = OptimizationState{typeof(method)}(iteration,F,Float64(norm_diff(x,s.xp)/max(norm(x),one(T))),Float64(inv(τ)),md)
      options.store_trace && push!(tr,os)
      options.show_trace && show(stdout,os)
      options.callback === nothing || (stopped = options.callback(options.store_trace ? tr : os) === true)
    end
    limited = (options.grad_calls_limit > 0 && gradcount >= options.grad_calls_limit) ||
              (options.prox_calls_limit > 0 && pc >= options.prox_calls_limit) ||
              (options.f_calls_limit > 0 && fc >= options.f_calls_limit)
  end
  if options.gaptol > 0
    gapiter == iteration || (relgap = Float64(gap(x,y)))
    done = isfinite(relgap) && 0 <= relgap <= options.gaptol
  end
  F = T(f(x)+g(x)+h(s.Dx)); fc += 1
  PrimalDualResults(x,F,y,τ,σ,iteration,done,r...,restarts,adaptations,relgap,tr,
                   fc,gradcount,pc,dc,dtc,limited)
end

"""
    duality_gap(f, g, h, D, x, y) -> (gap, primal, dual)

A Fenchel certificate for convex `f(x) + g(x) + h(D*x)` at primal/dual
vectors `x,y`. Requires the relevant conjugate values in ProximalBase.
For `g = ZeroFunction()` and a squared Euclidean loss, the dual is
`-f*(-D'y) - h*(y)`. Otherwise set
`u = ∇f(x)` and use `f*(u) = dot(x,u) - f(x)` and the dual
`-f*(u) - g*(-u-D'y) - h*(y)`. An infeasible dual point gives an infinite
gap. When `f = ZeroFunction()` and `g = NormL1(...)`, scale `y` toward zero
so `-D'y` lies in the domain of `g*`; this also preserves feasibility of a
translated/scaled check loss. This does not change the returned solver dual.
The routine allocates working vectors; it is intended for occasional checks.
"""
function duality_gap(f::AbstractFunction, g::AbstractFunction, h::AbstractFunction,
                     D::AbstractMatrix, x::AbstractVector{T}, y::AbstractVector{T}) where {T<:AbstractFloat}
  isconvex(f) && isconvex(g) && isconvex(h) || throw(ArgumentError("duality gaps require convex functions"))
  size(D) == (length(y),length(x)) || throw(DimensionMismatch())
  Dx, Dty = D*x, D'*y
  primal = f(x)+g(x)+h(Dx)
  if g isa ZeroFunction && f isa SqrNormL2 && f.λ > 0
    dual = -Conjugate(f)(-Dty)-Conjugate(h)(y)
  elseif f isa ZeroFunction
    t = g isa NormL1 ? something(_dualscale(g,Dty),zero(T)) : one(T)
    dual = -Conjugate(g)(-t .* Dty)-Conjugate(h)(t .* y)
  else
    u = zeros(T,length(x))
    fx = value_and_gradient!(u,f,x)
    dual = fx-dot(x,u)-Conjugate(g)(-u-Dty)-Conjugate(h)(y)
  end
  (;gap=primal-dual,primal,dual)
end
